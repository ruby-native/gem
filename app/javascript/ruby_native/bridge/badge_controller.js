import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "badge"
  static values = { home: Number, tab: Number }

  connect() {
    super.connect()
    this.#update()
  }

  homeValueChanged() { this.#update() }
  tabValueChanged() { this.#update() }

  #update() {
    const data = {}
    if (this.hasHomeValue) data.home = this.homeValue
    if (this.hasTabValue) data.tab = this.tabValue
    this.send("connect", data)
  }
}
