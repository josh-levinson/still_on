import { Controller } from "@hotwired/stimulus"

// Applies the light/dark choice instantly and saves it in the same cookie
// ThemesController sets, so the server renders the right theme next time.
export default class extends Controller {
  static targets = ["option"]
  static values = { colors: Object }

  choose(event) {
    const theme = event.submitter?.value
    if (!theme) return
    event.preventDefault()

    const root = document.documentElement
    if (theme === "system") {
      delete root.dataset.theme
      document.cookie = "theme=; path=/; max-age=0; samesite=lax"
    } else {
      root.dataset.theme = theme
      document.cookie = `theme=${theme}; path=/; max-age=${60 * 60 * 24 * 365 * 20}; samesite=lax`
    }

    this.optionTargets.forEach((option) => {
      option.setAttribute("aria-pressed", option.value === theme)
    })
    this.updateThemeColor(theme)
  }

  updateThemeColor(theme) {
    document.querySelectorAll('meta[name="theme-color"]').forEach((meta) => meta.remove())
    const entries = theme === "system"
      ? [["light", "(prefers-color-scheme: light)"], ["dark", "(prefers-color-scheme: dark)"]]
      : [[theme, null]]

    entries.forEach(([name, media]) => {
      const meta = document.createElement("meta")
      meta.name = "theme-color"
      meta.content = this.colorsValue[name]
      if (media) meta.media = media
      document.head.appendChild(meta)
    })
  }
}
