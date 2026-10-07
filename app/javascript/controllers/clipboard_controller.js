import { Controller } from "@hotwired/stimulus"

// Copies the source target's text, or a `text` action param when one is given
// (e.g. a prewritten message for apps like Discord that have no share URL).
export default class extends Controller {
  static targets = ["source", "button"]

  copy(event) {
    const param = event.params.text
    const text = param || this.sourceTarget.textContent.trim()
    const btn = param ? event.currentTarget : this.buttonTarget
    navigator.clipboard.writeText(text).then(() => {
      const original = btn.textContent
      btn.textContent = "Copied!"
      btn.classList.add("copied")
      setTimeout(() => {
        btn.textContent = original
        btn.classList.remove("copied")
      }, 2000)
    })
  }
}
