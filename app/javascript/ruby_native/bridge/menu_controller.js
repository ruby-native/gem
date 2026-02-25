import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "menu"
  static targets = ["item"]
  static values = { title: String, side: { type: String, default: "right" } }

  connect() {
    super.connect()

    const items = this.itemTargets.map((el, index) => ({
      title: new BridgeElement(el).title,
      index,
      destructive: el.hasAttribute("data-destructive")
    }))

    this.send("connect", { title: this.titleValue, items, side: this.sideValue }, (message) => {
      const { selectedIndex } = message.data
      this.itemTargets[selectedIndex]?.click()
    })
  }
}
