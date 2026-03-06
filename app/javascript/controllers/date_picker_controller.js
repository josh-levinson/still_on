import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["value", "custom", "customInput", "display", "label", "submit"]

  selectQuick(event) {
    const btn = event.currentTarget
    const date = btn.dataset.date
    const label = btn.querySelector(".quick-date-label").textContent + " (" + btn.querySelector(".quick-date-sub").textContent + ")"

    this.valueTarget.value = date
    this.showSelected(label)
    this.highlightButton(btn)
    this.customTarget.style.display = "none"
    this.enableSubmit()
  }

  showCustom() {
    this.customTarget.style.display = "block"
    this.clearHighlights()
    document.querySelectorAll(".quick-date-btn").forEach(b => {
      if (b.querySelector(".quick-date-sub").textContent === "Custom") {
        b.classList.add("selected")
      }
    })
    this.customInputTarget.focus()
  }

  selectCustom(event) {
    const date = event.target.value
    if (!date) return

    const parsed = new Date(date + "T00:00:00")
    const label = parsed.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })

    this.valueTarget.value = date
    this.showSelected(label)
    this.enableSubmit()
  }

  showSelected(label) {
    this.displayTarget.style.display = "block"
    this.labelTarget.textContent = label
  }

  highlightButton(btn) {
    this.clearHighlights()
    btn.classList.add("selected")
  }

  clearHighlights() {
    this.element.querySelectorAll(".quick-date-btn").forEach(b => b.classList.remove("selected"))
  }

  enableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
    }
  }
}
