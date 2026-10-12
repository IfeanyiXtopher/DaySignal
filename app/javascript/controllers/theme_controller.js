import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "daysignal-theme"

// Light / dark toggle. Persists choice; falls back to system preference.
export default class extends Controller {
  static targets = ["button", "label"]

  connect() {
    this.apply(this.storedTheme() || this.systemTheme())
  }

  toggle() {
    const next = this.currentTheme() === "dark" ? "light" : "dark"
    localStorage.setItem(STORAGE_KEY, next)
    this.apply(next)
  }

  apply(theme) {
    document.documentElement.dataset.theme = theme
    document.documentElement.style.colorScheme = theme

    if (this.hasButtonTarget) {
      const other = theme === "dark" ? "light" : "dark"
      this.buttonTarget.setAttribute("aria-label", `Switch to ${other} mode`)
      this.buttonTarget.setAttribute("title", `Switch to ${other} mode`)
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = theme === "dark" ? "Light" : "Dark"
    }
  }

  currentTheme() {
    return document.documentElement.dataset.theme === "dark" ? "dark" : "light"
  }

  storedTheme() {
    const value = localStorage.getItem(STORAGE_KEY)
    return value === "light" || value === "dark" ? value : null
  }

  systemTheme() {
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }
}
