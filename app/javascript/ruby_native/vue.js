import { defineComponent, h, onMounted, onUnmounted } from "vue"
import { router } from "@inertiajs/vue3"

window.__inertiaRouter = router

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

export const NativeNavbar = defineComponent({
  name: "NativeNavbar",
  props: { title: { type: String, required: true } },
  render() {
    return h("div", { "data-native-navbar": this.title, hidden: true }, this.$slots.default?.())
  }
})

export const NativeButton = defineComponent({
  name: "NativeButton",
  props: {
    position: { type: String, default: "trailing" },
    icon: String,
    title: String,
    href: String,
    action: String,
    selected: { type: Boolean, default: undefined }
  },
  render() {
    const attrs = { "data-native-button": true }
    if (this.icon) attrs["data-native-icon"] = this.icon
    if (this.title) attrs["data-native-title"] = this.title
    if (this.href) attrs["data-native-href"] = this.href
    if (this.action) attrs["data-native-action"] = this.action
    if (this.position) attrs["data-native-position"] = this.position
    if (this.selected) attrs["data-native-selected"] = ""
    return h("div", attrs, this.$slots.default?.())
  }
})

export const NativeMenuItem = defineComponent({
  name: "NativeMenuItem",
  props: {
    title: String,
    value: String,
    icon: String,
    selected: { type: Boolean, default: undefined }
  },
  render() {
    const attrs = { "data-native-menu-item": true }
    if (this.title) attrs["data-native-title"] = this.title
    if (this.value) attrs["data-native-value"] = this.value
    if (this.icon) attrs["data-native-icon"] = this.icon
    if (this.selected) attrs["data-native-selected"] = ""
    return h("div", attrs)
  }
})

export const NativeSubmitButton = defineComponent({
  name: "NativeSubmitButton",
  props: {
    title: { type: String, default: "Save" },
    selector: { type: String, default: "[type='submit']" }
  },
  render() {
    return h("div", {
      "data-native-submit-button": true,
      "data-native-title": this.title,
      "data-native-selector": this.selector,
      hidden: true
    })
  }
})

export function useNativeButton(name, callback) {
  function handler(event) {
    if (event.detail.action === name) {
      callback(event.detail.value)
    }
  }
  onMounted(() => {
    document.addEventListener("ruby-native:button", handler)
  })
  onUnmounted(() => {
    document.removeEventListener("ruby-native:button", handler)
  })
}
