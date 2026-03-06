import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "form"]

  select(event) {
    const btn = event.currentTarget
    const value = btn.dataset.cadenceValue

    this.inputTarget.value = value

    this.element.querySelectorAll(".cadence-btn").forEach(b => b.classList.remove("selected"))
    btn.classList.add("selected")

    // Small delay so the selection is visible before submit
    setTimeout(() => this.formTarget.requestSubmit(), 150)
  }
}
