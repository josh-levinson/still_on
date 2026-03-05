import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "customInput", "customWrapper"]

  select(event) {
    const btn = event.currentTarget
    const value = btn.dataset.hangoutNameValue

    this.element.querySelectorAll(".chip").forEach(c => c.classList.remove("active"))
    btn.classList.add("active")

    if (value === "custom") {
      this.customWrapperTarget.style.display = "block"
      this.customInputTarget.focus()
      this.inputTarget.value = this.customInputTarget.value
    } else {
      this.customWrapperTarget.style.display = "none"
      this.customInputTarget.value = ""
      this.inputTarget.value = value
    }
  }

  updateCustom(event) {
    this.inputTarget.value = event.target.value
  }
}
