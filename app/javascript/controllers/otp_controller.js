import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["digit", "code", "form"]

  connect() {
    // Auto-focus first digit on load
    if (this.hasDigitTarget) {
      this.digitTargets[0].focus()
    }
  }

  onInput(event) {
    const input = event.target
    const index = this.digitTargets.indexOf(input)
    const filtered = input.value.replace(/\D/g, "")

    // Handle autofill (e.g. iOS/Android SMS autofill) dropping the full code into one field
    if (filtered.length > 1) {
      this.distributeDigits(filtered)
      return
    }

    const digit = filtered.slice(-1)
    input.value = digit

    if (digit && index < this.digitTargets.length - 1) {
      this.digitTargets[index + 1].focus()
    }

    this.checkComplete()
  }

  onKeydown(event) {
    const input = event.target
    const index = this.digitTargets.indexOf(input)

    if (event.key === "Backspace" && !input.value && index > 0) {
      this.digitTargets[index - 1].focus()
    }
  }

  onPaste(event) {
    event.preventDefault()
    const text = (event.clipboardData || window.clipboardData).getData("text")
    this.distributeDigits(text)
  }

  distributeDigits(text) {
    const digits = text.replace(/\D/g, "").slice(0, 6)

    digits.split("").forEach((digit, i) => {
      if (this.digitTargets[i]) {
        this.digitTargets[i].value = digit
      }
    })

    const lastIndex = Math.min(digits.length, this.digitTargets.length) - 1
    if (lastIndex >= 0) this.digitTargets[lastIndex].focus()

    this.checkComplete()
  }

  checkComplete() {
    const code = this.digitTargets.map(d => d.value).join("")
    if (code.length === 6) {
      this.codeTarget.value = code
      // Small delay so the last digit renders before submit
      setTimeout(() => this.formTarget.requestSubmit(), 100)
    }
  }
}
