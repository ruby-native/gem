import { createElement } from "react"

import("@inertiajs/react").then(m => { window.__inertiaRouter = m.router }).catch(() => {})

export function NativeTabs({ enabled = true }) {
  if (!enabled) return null
  return createElement("div", { "data-native-tabs": true, hidden: true })
}

export function NativePush() {
  return createElement("div", { "data-native-push": true, hidden: true })
}

export function NativeForm() {
  return createElement("div", { "data-native-form": true, hidden: true })
}

export function NativeNavbar({ title = "", children }) {
  return createElement("div", { "data-native-navbar": title, hidden: true }, children)
}

export function NativeButton({ position = "trailing", icon, title, href, click, selected, children }) {
  const props = { "data-native-button": true }
  if (icon) props["data-native-icon"] = icon
  if (title) props["data-native-title"] = title
  if (href) props["data-native-href"] = href
  if (click) props["data-native-click"] = click
  if (position) props["data-native-position"] = position
  if (selected) props["data-native-selected"] = ""
  return createElement("div", props, children)
}

export function NativeMenuItem({ title, href, click, icon, selected }) {
  const props = { "data-native-menu-item": true }
  if (title) props["data-native-title"] = title
  if (href) props["data-native-href"] = href
  if (click) props["data-native-click"] = click
  if (icon) props["data-native-icon"] = icon
  if (selected) props["data-native-selected"] = ""
  return createElement("div", props)
}

export function NativeFab({ icon, href, click }) {
  const props = { "data-native-fab": true, "data-native-icon": icon, hidden: true }
  if (href) props["data-native-href"] = href
  if (click) props["data-native-click"] = click
  return createElement("div", props)
}

export function NativeOverscroll({ top, bottom }) {
  return createElement("div", {
    "data-native-overscroll-top": top,
    "data-native-overscroll-bottom": bottom || top,
    hidden: true
  })
}

export function NativeSubmitButton({ title = "Save", click = "[type='submit']" }) {
  return createElement("div", {
    "data-native-submit-button": true,
    "data-native-title": title,
    "data-native-click": click,
    hidden: true
  })
}

