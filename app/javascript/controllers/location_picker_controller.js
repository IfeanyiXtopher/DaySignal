import { Controller } from "@hotwired/stimulus"

// Location search + "use my location" for preferences.
// Fills label / lat / lng / timezone; coordinates stay editable.
export default class extends Controller {
  static targets = [
    "query",
    "results",
    "label",
    "latitude",
    "longitude",
    "timezone",
    "status",
    "coordsPanel",
    "coordsToggle"
  ]

  static values = {
    searchUrl: String,
    reverseUrl: String
  }

  connect() {
    this.abortController = null
    this.hideResults()
    this.refreshStatus()
  }

  disconnect() {
    this.abortController?.abort()
  }

  async onQueryInput() {
    const q = this.queryTarget.value.trim()
    if (q.length < 2) {
      this.hideResults()
      return
    }

    clearTimeout(this._debounce)
    this._debounce = setTimeout(() => this.search(q), 280)
  }

  async search(q) {
    this.abortController?.abort()
    this.abortController = new AbortController()

    try {
      const url = new URL(this.searchUrlValue, window.location.origin)
      url.searchParams.set("q", q)
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal
      })
      const data = await response.json()
      this.renderResults(data.results || [])
    } catch (error) {
      if (error.name !== "AbortError") {
        this.setStatus("Could not search locations. Try again.", true)
      }
    }
  }

  renderResults(results) {
    if (!results.length) {
      this.resultsTarget.innerHTML = `<li class="location-picker__empty">No matches. Try a city name.</li>`
      this.resultsTarget.hidden = false
      return
    }

    this.resultsTarget.innerHTML = results.map((r, index) => `
      <li>
        <button type="button"
                class="location-picker__option"
                data-action="location-picker#pick"
                data-index="${index}"
                data-label="${this.escape(r.label)}"
                data-latitude="${r.latitude}"
                data-longitude="${r.longitude}">
          <span class="location-picker__option-title">${this.escape(r.label)}</span>
          <span class="location-picker__option-meta">${Number(r.latitude).toFixed(4)}, ${Number(r.longitude).toFixed(4)}</span>
        </button>
      </li>
    `).join("")
    this.resultsTarget.hidden = false
  }

  async pick(event) {
    const button = event.currentTarget
    const label = button.dataset.label
    const latitude = button.dataset.latitude
    const longitude = button.dataset.longitude

    this.applyPlace({ label, latitude, longitude })
    this.hideResults()
    this.queryTarget.value = label
    this.setStatus("Looking up timezone…")

    await this.enrichTimezone(latitude, longitude)
  }

  async useMyLocation(event) {
    event.preventDefault()
    if (!navigator.geolocation) {
      this.setStatus("Geolocation is not supported in this browser.", true)
      this.openCoords()
      return
    }

    this.setStatus("Getting your location…")
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        const latitude = pos.coords.latitude
        const longitude = pos.coords.longitude
        this.applyPlace({ label: "Current location", latitude, longitude })
        this.queryTarget.value = "Current location"
        await this.reverseLookup(latitude, longitude)
      },
      () => {
        this.setStatus("Could not access your location. Search a city or enter coordinates.", true)
        this.openCoords()
      },
      { enableHighAccuracy: false, timeout: 10000 }
    )
  }

  async reverseLookup(latitude, longitude) {
    try {
      const url = new URL(this.reverseUrlValue, window.location.origin)
      url.searchParams.set("latitude", latitude)
      url.searchParams.set("longitude", longitude)
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      const data = await response.json()
      if (data.error) throw new Error(data.error)

      if (data.label) {
        this.labelTarget.value = data.label
        this.queryTarget.value = data.label
      }
      if (data.timezone) this.selectTimezone(data.timezone)
      this.refreshStatus()
      this.setStatus("Location set. You can still edit the details below.")
    } catch {
      this.setStatus("Coordinates set. Pick a timezone if it was not detected.", true)
      this.openCoords()
    }
  }

  async enrichTimezone(latitude, longitude) {
    try {
      const url = new URL(this.reverseUrlValue, window.location.origin)
      url.searchParams.set("latitude", latitude)
      url.searchParams.set("longitude", longitude)
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      const data = await response.json()
      if (data.timezone) this.selectTimezone(data.timezone)
      this.refreshStatus()
      this.setStatus("Location set. Review alert time and save.")
    } catch {
      this.refreshStatus()
      this.setStatus("Location set. Choose a timezone, then save.")
    }
  }

  applyPlace({ label, latitude, longitude }) {
    this.labelTarget.value = label
    this.latitudeTarget.value = Number(latitude).toFixed(6)
    this.longitudeTarget.value = Number(longitude).toFixed(6)
    this.refreshStatus()
  }

  selectTimezone(name) {
    const select = this.timezoneTarget
    const match = Array.from(select.options).find((opt) => opt.value === name)
    if (match) {
      select.value = name
      return
    }
    // Add IANA zone if Rails list omitted it (e.g. Africa/Lagos extras already present).
    const option = new Option(name, name, true, true)
    select.add(option)
    select.value = name
  }

  onCoordsChanged() {
    this.refreshStatus()
  }

  toggleCoords(event) {
    event.preventDefault()
    const open = this.coordsPanelTarget.hasAttribute("hidden")
    if (open) this.openCoords()
    else this.closeCoords()
  }

  openCoords() {
    this.coordsPanelTarget.hidden = false
    if (this.hasCoordsToggleTarget) {
      this.coordsToggleTarget.setAttribute("aria-expanded", "true")
      this.coordsToggleTarget.textContent = "Hide coordinates"
    }
  }

  closeCoords() {
    this.coordsPanelTarget.hidden = true
    if (this.hasCoordsToggleTarget) {
      this.coordsToggleTarget.setAttribute("aria-expanded", "false")
      this.coordsToggleTarget.textContent = "Edit coordinates manually"
    }
  }

  hideResults() {
    if (this.hasResultsTarget) {
      this.resultsTarget.hidden = true
      this.resultsTarget.innerHTML = ""
    }
  }

  hideResultsLater() {
    setTimeout(() => this.hideResults(), 180)
  }

  refreshStatus() {
    if (!this.hasStatusTarget) return
    const label = this.labelTarget.value
    const lat = this.latitudeTarget.value
    const lng = this.longitudeTarget.value
    if (label && lat && lng) {
      this.statusTarget.textContent = `${label} · ${Number(lat).toFixed(4)}, ${Number(lng).toFixed(4)}`
      this.statusTarget.hidden = false
    } else {
      this.statusTarget.hidden = true
    }
  }

  setStatus(message, isError = false) {
    if (!this.hasStatusTarget) return
    this.statusTarget.hidden = false
    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("location-picker__status--error", isError)
  }

  escape(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
  }
}
