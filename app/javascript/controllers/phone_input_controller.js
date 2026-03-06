import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display"]

  format(event) {
    const input = event.target
    const raw = input.value.replace(/\D/g, "").slice(0, 10)

    let formatted = raw
    if (raw.length >= 7) {
      formatted = `(${raw.slice(0, 3)}) ${raw.slice(3, 6)}-${raw.slice(6)}`
    } else if (raw.length >= 4) {
      formatted = `(${raw.slice(0, 3)}) ${raw.slice(3)}`
    } else if (raw.length >= 1) {
      formatted = `(${raw}`
    }

    input.value = formatted
  }
}
