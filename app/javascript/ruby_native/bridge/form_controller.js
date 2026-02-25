import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "form"
  static targets = ["submit"]

  connect() {
    super.connect()

    const title = new BridgeElement(this.submitTarget).title
    this.send("connect", { submitTitle: title.trim() }, () => {
      this.submitTarget.click()
    })

    this.element.addEventListener("turbo:submit-start", this.submitStarted)
    this.element.addEventListener("turbo:submit-end", this.submitEnded)
  }

  disconnect() {
    super.disconnect()
    this.element.removeEventListener("turbo:submit-start", this.submitStarted)
    this.element.removeEventListener("turbo:submit-end", this.submitEnded)
  }

  submitStarted = () => this.send("submitDisabled")
  submitEnded = () => this.send("submitEnabled")
}
