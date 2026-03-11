import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "haptic"
  static values = { feedback: { type: String, default: "success" } }

  vibrate() {
    const feedback = this.feedbackValue || "success"
    this.send("vibrate", { feedback })
  }
}
