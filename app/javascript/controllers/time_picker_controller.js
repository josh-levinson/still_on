import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["value", "custom", "customInput"]

  connect() {
    if (!this.valueTarget.value) this.valueTarget.value = "19:00"
    this.highlightCurrent()
  }

  selectQuick(event) {
    const btn = event.currentTarget
    this.valueTarget.value = btn.dataset.time
    this.customTarget.style.display = "none"
    this.highlightButton(btn)
  }

  showCustom(event) {
    this.clearHighlights()
    event.currentTarget.classList.add("selected")
    this.customTarget.style.display = "block"
    this.customInputTarget.focus()
  }

  selectCustom(event) {
    if (event.target.value) this.valueTarget.value = event.target.value
  }

  highlightCurrent() {
    const current = this.valueTarget.value
    const btn = this.element.querySelector(`.quick-time-btn[data-time="${current}"]`)
    if (btn) btn.classList.add("selected")
  }

  highlightButton(btn) {
    this.clearHighlights()
    btn.classList.add("selected")
  }

  clearHighlights() {
    this.element.querySelectorAll(".quick-time-btn").forEach(b => b.classList.remove("selected"))
  }
}
