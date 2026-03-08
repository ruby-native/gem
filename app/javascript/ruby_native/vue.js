import { defineComponent, h } from "vue"

export const NativeTabs = defineComponent({
  name: "NativeTabs",
  render() {
    return h("div", { "data-native-tabs": true, hidden: true })
  }
})

export const NativePush = defineComponent({
  name: "NativePush",
  render() {
    return h("div", { "data-native-push": true, hidden: true })
  }
})

export const NativeForm = defineComponent({
  name: "NativeForm",
  render() {
    return h("div", { "data-native-form": true, hidden: true })
  }
})
