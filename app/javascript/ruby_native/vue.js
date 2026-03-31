import { defineComponent, h } from "vue"
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
    click: String,
    selected: { type: Boolean, default: undefined }
  },
  render() {
    const attrs = { "data-native-button": true }
    if (this.icon) attrs["data-native-icon"] = this.icon
    if (this.title) attrs["data-native-title"] = this.title
    if (this.href) attrs["data-native-href"] = this.href
    if (this.click) attrs["data-native-click"] = this.click
    if (this.position) attrs["data-native-position"] = this.position
    if (this.selected) attrs["data-native-selected"] = ""
    return h("div", attrs, this.$slots.default?.())
  }
})

export const NativeMenuItem = defineComponent({
  name: "NativeMenuItem",
  props: {
    title: String,
    href: String,
    click: String,
    icon: String,
    selected: { type: Boolean, default: undefined }
  },
  render() {
    const attrs = { "data-native-menu-item": true }
    if (this.title) attrs["data-native-title"] = this.title
    if (this.href) attrs["data-native-href"] = this.href
    if (this.click) attrs["data-native-click"] = this.click
    if (this.icon) attrs["data-native-icon"] = this.icon
    if (this.selected) attrs["data-native-selected"] = ""
    return h("div", attrs)
  }
})

export const NativeSubmitButton = defineComponent({
  name: "NativeSubmitButton",
  props: {
    title: { type: String, default: "Save" },
    click: { type: String, default: "[type='submit']" }
  },
  render() {
    return h("div", {
      "data-native-submit-button": true,
      "data-native-title": this.title,
      "data-native-click": this.click,
      hidden: true
    })
  }
})
