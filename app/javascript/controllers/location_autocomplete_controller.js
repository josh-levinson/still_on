import { Controller } from "@hotwired/stimulus"
import { SearchBoxCore, SessionToken } from "@mapbox/search-js-core"

export default class extends Controller {
  static targets = ["input", "suggestions"]
  static values = { accessToken: String }

  connect() {
    this.searchBox = new SearchBoxCore({
      accessToken: this.accessTokenValue,
      language: "en"
    })
    this.sessionToken = new SessionToken()
    this.proximity = null
    this.fetchProximity()
    this.selectedFromSuggestions = false

    this.inputTarget.setAttribute("autocomplete", "off")
    this.inputTarget.addEventListener("input", this.onInput.bind(this))
    this.inputTarget.addEventListener("blur", this.onBlur.bind(this))
    this.inputTarget.addEventListener("keydown", this.onKeydown.bind(this))

    this.highlightedIndex = -1
  }

  fetchProximity() {
    if (!navigator.geolocation) return
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        this.proximity = [pos.coords.longitude, pos.coords.latitude]
      },
      () => { /* permission denied or unavailable — country bias still applies */ }
    )
  }

  disconnect() {
    this.inputTarget.removeEventListener("input", this.onInput.bind(this))
    this.inputTarget.removeEventListener("blur", this.onBlur.bind(this))
    this.inputTarget.removeEventListener("keydown", this.onKeydown.bind(this))
    this.hideSuggestions()
  }

  async onInput(event) {
    const query = event.target.value.trim()
    this.selectedFromSuggestions = false
    this.highlightedIndex = -1

    if (query.length < 2) {
      this.hideSuggestions()
      return
    }

    try {
      const options = { sessionToken: this.sessionToken }
      if (this.proximity) options.proximity = this.proximity
      const response = await this.searchBox.suggest(query, options)
      this.showSuggestions(response.suggestions || [])
    } catch (error) {
      this.hideSuggestions()
    }
  }

  onBlur() {
    // Delay so click on suggestion registers first
    setTimeout(() => this.hideSuggestions(), 150)
  }

  onKeydown(event) {
    const items = this.suggestionsTarget.querySelectorAll(".location-suggestion-item")
    if (!items.length) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.highlightedIndex = Math.min(this.highlightedIndex + 1, items.length - 1)
      this.updateHighlight(items)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.highlightedIndex = Math.max(this.highlightedIndex - 1, 0)
      this.updateHighlight(items)
    } else if (event.key === "Enter" && this.highlightedIndex >= 0) {
      event.preventDefault()
      items[this.highlightedIndex].click()
    } else if (event.key === "Escape") {
      this.hideSuggestions()
    }
  }

  updateHighlight(items) {
    items.forEach((item, i) => {
      item.classList.toggle("highlighted", i === this.highlightedIndex)
    })
  }

  showSuggestions(suggestions) {
    this.suggestionsTarget.innerHTML = ""

    if (!suggestions.length) {
      this.hideSuggestions()
      return
    }

    suggestions.forEach((suggestion) => {
      const item = document.createElement("div")
      item.className = "location-suggestion-item"
      item.textContent = suggestion.full_address || suggestion.place_formatted || suggestion.name
      item.addEventListener("mousedown", (e) => {
        e.preventDefault()
        this.selectSuggestion(suggestion)
      })
      this.suggestionsTarget.appendChild(item)
    })

    this.suggestionsTarget.classList.remove("hidden")
  }

  selectSuggestion(suggestion) {
    this.inputTarget.value = suggestion.full_address || suggestion.place_formatted || suggestion.name
    this.selectedFromSuggestions = true
    this.sessionToken = new SessionToken()
    this.hideSuggestions()
  }

  hideSuggestions() {
    this.suggestionsTarget.innerHTML = ""
    this.suggestionsTarget.classList.add("hidden")
    this.highlightedIndex = -1
  }
}
