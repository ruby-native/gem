import { createElement, useEffect } from "react"
import { router } from "@inertiajs/react"

window.__inertiaRouter = router

export function NativeTabs() {
  return createElement("div", { "data-native-tabs": true, hidden: true })
}

export function NativePush() {
  return createElement("div", { "data-native-push": true, hidden: true })
}

export function NativeForm() {
  return createElement("div", { "data-native-form": true, hidden: true })
}

export function NativeNavbar({ title, children }) {
  return createElement("div", { "data-native-navbar": title, hidden: true }, children)
}

export function NativeButton({ position = "trailing", icon, title, href, action, selected, children }) {
  const props = { "data-native-button": true }
  if (icon) props["data-native-icon"] = icon
  if (title) props["data-native-title"] = title
  if (href) props["data-native-href"] = href
  if (action) props["data-native-action"] = action
  if (position) props["data-native-position"] = position
  if (selected) props["data-native-selected"] = ""
  return createElement("div", props, children)
}

export function NativeMenuItem({ title, value, icon, selected }) {
  const props = { "data-native-menu-item": true }
  if (title) props["data-native-title"] = title
  if (value) props["data-native-value"] = value
  if (icon) props["data-native-icon"] = icon
  if (selected) props["data-native-selected"] = ""
  return createElement("div", props)
}

export function NativeSubmitButton({ title = "Save", selector = "[type='submit']" }) {
  return createElement("div", {
    "data-native-submit-button": true,
    "data-native-title": title,
    "data-native-selector": selector,
    hidden: true
  })
}

export function useNativeButton(name, callback) {
  useEffect(() => {
    function handler(event) {
      if (event.detail.action === name) {
        callback(event.detail.value)
      }
    }
    document.addEventListener("ruby-native:button", handler)
    return () => document.removeEventListener("ruby-native:button", handler)
  }, [name, callback])
}
