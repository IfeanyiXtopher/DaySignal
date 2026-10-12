import { Controller } from "@hotwired/stimulus"

// Mapbox GL globe explorer — real map place labels (zoom LOD built-in).
// Click / geolocate / search → DaySignal conditions panel.
export default class extends Controller {
  static targets = [
    "globe", "panel", "place", "coords", "temp", "summary", "icon",
    "feels", "humidity", "wind", "status", "query", "suggest", "hint", "play",
    "clock", "scrub"
  ]

  static values = {
    conditionsUrl: String,
    searchUrl: String,
    geocodeUrl: String,
    mapboxToken: String,
    weatherTileUrl: String
  }

  async connect() {
    this.abortController = null
    this.layer = "temperatures"
    this.focus = { lat: 6.5244, lng: 3.3792 }
    this.spinning = false
    this.spinTimer = null
    this.marker = null

    this.setStatus("Loading map…")
    this.introDone = false
    await this.mountMap()
    this.startClock()
    // World view first; fly-to-user starts after the globe has painted.
  }

  disconnect() {
    this.abortController?.abort()
    this.stopSpin()
    if (this.clockTimer) clearInterval(this.clockTimer)
    window.removeEventListener("resize", this.onWindowResize)
    this.marker?.remove()
    this.map?.remove()
    this.map = null
  }

  async mountMap() {
    if (!this.mapboxTokenValue) {
      this.showMapSetupNeeded()
      return
    }

    try {
      const mapboxgl = await this.loadMapbox()
      mapboxgl.accessToken = this.mapboxTokenValue

      this.mapboxgl = mapboxgl
      // Dedicated child container — never wipe map canvas via innerHTML.
      this.map = new mapboxgl.Map({
        container: this.globeTarget,
        style: "mapbox://styles/mapbox/streets-v12",
        // Start at the wide globe view (Atlantic / Africa facing), then fly in.
        center: [0, 10],
        zoom: 1.15,
        projection: "globe",
        attributionControl: true,
        antialias: true
      })

      // Keep Mapbox logo + legal attribution on the bottom edge; nav sits up top.
      this.map.addControl(new mapboxgl.NavigationControl({ visualizePitch: true }), "top-right")

      this.map.on("style.load", () => {
        this.applyFog()
        // Wait a tick so base style paints before optional weather raster.
        requestAnimationFrame(() => this.applyWeatherOverlay())
      })

      this.map.on("click", (event) => {
        const { lng, lat } = event.lngLat
        this.inspect(lat, lng)
      })

      this.map.on("error", (event) => {
        const msg = event?.error?.message || "Mapbox failed to load the style"
        this.setStatus(msg, true)
      })

      this.map.on("load", () => {
        this.map.resize()
        this.clearStatus()
        if (this.hasHintTarget) {
          this.hintTarget.textContent = "Finding your location…"
        }
        // Second resize after layout/fonts settle (common blank-map fix).
        setTimeout(() => this.map?.resize(), 100)
        setTimeout(() => this.map?.resize(), 400)
        // Let the world globe sit briefly, then zoom into the user.
        setTimeout(() => this.locate({ silent: true, intro: true }), 700)
      })

      window.addEventListener("resize", this.onWindowResize)

      if (this.hasPlayTarget) this.playTarget.textContent = "▶"
    } catch (err) {
      this.showMapSetupNeeded(err.message || "Could not load Mapbox GL")
    }
  }

  onWindowResize = () => {
    this.map?.resize()
  }

  showMapSetupNeeded(detail = null) {
    // Overlay on the globe wrapper, not inside the Mapbox container.
    const host = this.globeTarget.parentElement || this.globeTarget
    let setup = host.querySelector(".explorer__setup")
    if (!setup) {
      setup = document.createElement("div")
      setup.className = "explorer__setup"
      host.appendChild(setup)
    }
    setup.hidden = false
    setup.innerHTML = `
      <h2>Map needs a Mapbox token</h2>
      <p>The weather panel can load without it, but the globe map cannot.</p>
      <ol>
        <li>Open <a href="https://account.mapbox.com/access-tokens/" target="_blank" rel="noreferrer">mapbox.com access tokens</a></li>
        <li>Copy a default public token (<code>pk.…</code>)</li>
        <li>In <code>.env</code> set <code>MAPBOX_ACCESS_TOKEN=pk.…</code></li>
        <li>Restart <code>bin/rails s</code> and hard-refresh</li>
      </ol>
      ${detail ? `<p class="explorer__setup-detail">${this.escape(detail)}</p>` : ""}
    `
    this.setStatus(detail || "MAPBOX_ACCESS_TOKEN is missing in .env", true)
  }

  async loadMapbox() {
    if (window.mapboxgl) return window.mapboxgl

    await Promise.all([
      this.loadStylesheet("https://api.mapbox.com/mapbox-gl-js/v3.9.4/mapbox-gl.css"),
      this.loadScript("https://api.mapbox.com/mapbox-gl-js/v3.9.4/mapbox-gl.js")
    ])

    if (!window.mapboxgl) throw new Error("Mapbox GL failed to load")
    return window.mapboxgl
  }

  loadScript(src) {
    return new Promise((resolve, reject) => {
      const existing = document.querySelector(`script[src="${src}"]`)
      if (existing) {
        if (window.mapboxgl) {
          resolve()
          return
        }
        existing.addEventListener("load", () => resolve(), { once: true })
        existing.addEventListener("error", () => reject(new Error(`Failed to load ${src}`)), { once: true })
        return
      }
      const el = document.createElement("script")
      el.src = src
      el.async = true
      el.onload = () => resolve()
      el.onerror = () => reject(new Error(`Failed to load ${src}`))
      document.head.appendChild(el)
    })
  }

  loadStylesheet(href) {
    return new Promise((resolve, reject) => {
      if (document.querySelector(`link[href="${href}"]`)) {
        resolve()
        return
      }
      const el = document.createElement("link")
      el.rel = "stylesheet"
      el.href = href
      el.onload = () => resolve()
      el.onerror = () => reject(new Error(`Failed to load ${href}`))
      document.head.appendChild(el)
    })
  }

  applyFog() {
    if (!this.map) return
    // Keep atmosphere visible — pure black fog made the globe look “missing”.
    this.map.setFog({
      color: "rgb(186, 210, 235)",
      "high-color": "rgb(36, 92, 180)",
      "horizon-blend": 0.02,
      "space-color": "rgb(11, 18, 32)",
      "star-intensity": 0.45
    })
  }

  applyWeatherOverlay() {
    if (!this.map || !this.weatherTileUrlValue) return

    const sourceId = "owm-weather"
    const layerId = "owm-weather-layer"
    if (this.map.getLayer(layerId)) this.map.removeLayer(layerId)
    if (this.map.getSource(sourceId)) this.map.removeSource(sourceId)

    let layerKey = null
    if (this.layer === "temperatures") layerKey = "temp"
    if (this.layer === "wind") layerKey = "wind"
    if (!layerKey) return

    const template = this.weatherTileUrlValue.replace("__LAYER__", layerKey)

    this.map.addSource(sourceId, {
      type: "raster",
      tiles: [ template ],
      tileSize: 256,
      attribution: "© OpenWeatherMap"
    })

    this.map.addLayer({
      id: layerId,
      type: "raster",
      source: sourceId,
      paint: { "raster-opacity": 0.55 }
    })
  }

  locate({ silent = false, intro = false } = {}) {
    if (!navigator.geolocation) {
      if (!silent) this.setStatus("Geolocation not supported — search or click the map", true)
      this.arriveAt(6.5244, 3.3792, { zoom: 6, intro })
      return
    }

    if (!silent) this.setStatus("Locating you…")

    navigator.geolocation.getCurrentPosition(
      (pos) => this.arriveAt(pos.coords.latitude, pos.coords.longitude, { zoom: 6.5, intro }),
      () => {
        if (!silent) this.setStatus("Location blocked — showing Lagos", true)
        this.arriveAt(6.5244, 3.3792, { zoom: 6, intro })
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
    )
  }

  arriveAt(lat, lng, { zoom = 6, intro = false } = {}) {
    this.focus = { lat, lng }
    this.flyTo(lat, lng, {
      zoom,
      duration: intro ? 3200 : 1200,
      curve: intro ? 1.4 : 1.2
    })
    this.inspect(lat, lng)

    if (intro && this.hasHintTarget) {
      this.map?.once("moveend", () => {
        this.hintTarget.textContent = "Scroll to zoom · cities appear as you zoom in · click for weather"
        this.introDone = true
      })
    }
  }

  flyTo(lat, lng, zoomOrOpts = null) {
    if (!this.map) return
    const opts = {
      center: [ lng, lat ],
      essential: true,
      duration: 1200
    }

    if (zoomOrOpts != null && typeof zoomOrOpts === "object") {
      Object.assign(opts, zoomOrOpts)
    } else if (zoomOrOpts != null) {
      opts.zoom = zoomOrOpts
    }

    this.map.flyTo(opts)
  }

  setMarker(lat, lng) {
    if (!this.map || !this.mapboxgl) return
    if (!this.marker) {
      const el = document.createElement("div")
      el.className = "map-pin"
      this.marker = new this.mapboxgl.Marker({ element: el }).setLngLat([ lng, lat ]).addTo(this.map)
    } else {
      this.marker.setLngLat([ lng, lat ])
    }
  }

  async inspect(lat, lng) {
    // Skip near-duplicate clicks (map click + intro landing can double-fire).
    const key = `${lat.toFixed(3)},${lng.toFixed(3)}`
    const now = Date.now()
    if (this.lastInspectKey === key && now - (this.lastInspectAt || 0) < 1500) {
      this.openPanel()
      this.setMarker(lat, lng)
      return
    }
    this.lastInspectKey = key
    this.lastInspectAt = now

    this.openPanel()
    this.setMarker(lat, lng)
    this.focus = { lat, lng }
    this.placeTarget.textContent = "Loading…"
    this.coordsTarget.textContent = `${lat.toFixed(4)}, ${lng.toFixed(4)}`
    this.setStatus("Fetching conditions…")

    this.abortController?.abort()
    this.abortController = new AbortController()

    try {
      const url = new URL(this.conditionsUrlValue, window.location.origin)
      url.searchParams.set("latitude", lat)
      url.searchParams.set("longitude", lng)

      const res = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || "Could not load weather")

      this.renderConditions(data)
      this.clearStatus()
    } catch (err) {
      if (err.name === "AbortError") return
      this.setStatus(err.message || "Weather unavailable", true)
      this.summaryTarget.textContent = "Could not load conditions"
    }
  }

  renderConditions(data) {
    this.placeTarget.textContent = data.label || "Selected location"
    this.coordsTarget.textContent = `${Number(data.latitude).toFixed(5)}, ${Number(data.longitude).toFixed(5)}`
    this.tempTarget.textContent = data.temperature_c != null ? `${Math.round(data.temperature_c)}°C` : "—°"
    this.summaryTarget.textContent = data.summary || "—"
    this.feelsTarget.textContent = data.feels_like_c != null ? `${Math.round(data.feels_like_c)}°C` : "—"
    this.humidityTarget.textContent = data.humidity != null ? `${data.humidity}%` : "—"
    this.windTarget.textContent =
      data.wind_speed_kmh != null ? `${data.wind_speed_kmh} km/h` : "—"

    if (data.icon_url && this.hasIconTarget) {
      this.iconTarget.src = data.icon_url
      this.iconTarget.alt = data.summary || "Weather"
      this.iconTarget.hidden = false
    }

    this.focus = { lat: data.latitude, lng: data.longitude }
    this.setMarker(data.latitude, data.longitude)
  }

  zoomIn() {
    this.map?.zoomTo(this.map.getZoom() + 1.2, { duration: 350 })
  }

  zoomOut() {
    this.map?.zoomTo(this.map.getZoom() - 1.2, { duration: 350 })
  }

  resetView() {
    this.flyTo(this.focus.lat, this.focus.lng, 1.6)
  }

  toggleSpin() {
    if (this.spinning) {
      this.stopSpin()
    } else {
      this.startSpin()
    }
  }

  startSpin() {
    if (!this.map) return
    this.spinning = true
    if (this.hasPlayTarget) this.playTarget.textContent = "❚❚"
    const tick = () => {
      if (!this.spinning || !this.map) return
      const center = this.map.getCenter()
      this.map.setCenter([ center.lng + 0.12, center.lat ])
      this.spinTimer = requestAnimationFrame(tick)
    }
    this.spinTimer = requestAnimationFrame(tick)
  }

  stopSpin() {
    this.spinning = false
    if (this.spinTimer) cancelAnimationFrame(this.spinTimer)
    this.spinTimer = null
    if (this.hasPlayTarget) this.playTarget.textContent = "▶"
  }

  setLayer(event) {
    this.layer = event.currentTarget.dataset.layer
    this.element.querySelectorAll(".explorer__layer").forEach((btn) => {
      btn.classList.toggle("is-active", btn.dataset.layer === this.layer)
    })

    if (!this.map) return

    const styleFor = {
      temperatures: "mapbox://styles/mapbox/streets-v12",
      wind: "mapbox://styles/mapbox/outdoors-v12",
      night: "mapbox://styles/mapbox/dark-v11"
    }

    const next = styleFor[this.layer] || styleFor.temperatures
    const center = this.map.getCenter()
    const zoom = this.map.getZoom()
    const bearing = this.map.getBearing()
    const pitch = this.map.getPitch()

    this.map.setStyle(next)
    this.map.once("style.load", () => {
      this.map.setCenter(center)
      this.map.setZoom(zoom)
      this.map.setBearing(bearing)
      this.map.setPitch(pitch)
      this.map.setProjection("globe")
      this.applyFog()
      this.applyWeatherOverlay()
      if (this.focus) this.setMarker(this.focus.lat, this.focus.lng)
    })
  }

  async searchSuggest() {
    const q = this.queryTarget.value.trim()
    if (q.length < 2) {
      this.suggestTarget.hidden = true
      this.suggestTarget.innerHTML = ""
      return
    }

    try {
      const url = new URL(this.geocodeUrlValue, window.location.origin)
      url.searchParams.set("q", q)
      const res = await fetch(url, { headers: { Accept: "application/json" } })
      const data = await res.json()
      const results = data.results || []
      if (!results.length) {
        this.suggestTarget.hidden = true
        return
      }

      this.suggestTarget.innerHTML = results.map((r) =>
        `<li><button type="button" data-lat="${r.latitude}" data-lng="${r.longitude}" data-action="globe-explorer#pickSuggest">${this.escape(r.label)}</button></li>`
      ).join("")
      this.suggestTarget.hidden = false
    } catch (_) {
      this.suggestTarget.hidden = true
    }
  }

  pickSuggest(event) {
    const btn = event.currentTarget
    const lat = parseFloat(btn.dataset.lat)
    const lng = parseFloat(btn.dataset.lng)
    this.queryTarget.value = btn.textContent
    this.suggestTarget.hidden = true
    this.arriveAt(lat, lng, { zoom: 7 })
  }

  searchSubmit(event) {
    event.preventDefault()
    const q = this.queryTarget.value.trim()
    if (!q) return
    this.suggestTarget.hidden = true
    this.openPanel()
    this.setStatus("Searching…")

    const url = new URL(this.searchUrlValue, window.location.origin)
    url.searchParams.set("q", q)

    fetch(url, { headers: { Accept: "application/json" } })
      .then(async (res) => {
        const data = await res.json()
        if (!res.ok) throw new Error(data.error || "Not found")
        this.renderConditions(data)
        this.flyTo(data.latitude, data.longitude, 7)
        this.clearStatus()
      })
      .catch((err) => this.setStatus(err.message, true))
  }

  closePanel() {
    this.panelTarget.classList.add("is-collapsed")
  }

  openPanel() {
    this.panelTarget.classList.remove("is-collapsed")
  }

  startClock() {
    const tick = () => {
      if (!this.hasClockTarget) return
      const now = new Date()
      this.clockTarget.textContent = now.toLocaleString(undefined, {
        weekday: "short", month: "short", day: "numeric",
        hour: "numeric", minute: "2-digit"
      })
      if (this.hasScrubTarget) {
        const pct = ((now.getHours() * 60 + now.getMinutes()) / (24 * 60)) * 100
        this.scrubTarget.style.left = `${pct}%`
      }
    }
    tick()
    this.clockTimer = setInterval(tick, 30000)
  }

  setStatus(message, isError = false) {
    if (!this.hasStatusTarget) return
    this.statusTarget.hidden = !message
    this.statusTarget.textContent = message || ""
    this.statusTarget.classList.toggle("is-error", Boolean(isError))
  }

  clearStatus() {
    this.setStatus("")
  }

  escape(text) {
    return String(text)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
  }
}
