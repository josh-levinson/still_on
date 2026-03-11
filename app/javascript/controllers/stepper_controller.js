import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["value"]

  increment() {
    const input = this.valueTarget
    const max = parseInt(input.max)
    const current = parseInt(input.value) || 0
    if (isNaN(max) || current < max) {
      input.value = current + 1
    }
  }

  decrement() {
    const input = this.valueTarget
    const min = parseInt(input.min) || 0
    const current = parseInt(input.value) || 0
    if (current > min) {
      input.value = current - 1
    }
  }
}
