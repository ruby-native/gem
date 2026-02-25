import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "tabs"
  static values = { enabled: Boolean }

  connect() {
    super.connect()
    this.send("connect", { enabled: this.enabledValue })
  }
}
