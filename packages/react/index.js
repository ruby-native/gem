import { createElement } from "react"

import("@inertiajs/react").then(m => { window.__inertiaRouter = m.router }).catch(() => {})

/**
 * Per-platform icon names. iOS uses SF Symbols, Android uses Material icons.
 * @typedef {object} NativeIcons
 * @property {string} [ios]
 * @property {string} [android]
 */

/**
 * @typedef {"success" | "warning" | "error" | "impact" | "selection"} NativeHapticFeedback
 */

/**
 * "title" turns the nav-bar title into a dropdown menu. Give the button a
 * `menu` and no icon or label of its own.
 * @typedef {"leading" | "trailing" | "title"} NativeButtonPosition
 */

/**
 * How a menu item's page lands. "replace" swaps the current history entry,
 * which is what a page switcher wants.
 * @typedef {"push" | "replace"} NativeAction
 */

function rubyNativePlatform() {
  if (typeof navigator === "undefined") return null
  const ua = navigator.userAgent || ""
  if (ua.includes("Ruby Native iOS")) return "ios"
  if (ua.includes("Ruby Native Android")) return "android"
  return null
}

const ACTIONS = ["push", "replace"]
const PRESENTATION_INTENTS = ["root"]
const TOAST_APPEARANCES = ["inverted", "system"]

/**
 * @param {string} value
 * @returns {string}
 */
function validateAction(value) {
  if (!ACTIONS.includes(value)) {
    throw new Error(`action must be "push" or "replace", got ${JSON.stringify(value)}`)
  }
  return value
}

/**
 * @param {string} [icon]
 * @param {NativeIcons} [icons]
 * @returns {string | undefined}
 */
function resolveIcon(icon, icons) {
  if (icons != null && (typeof icons !== "object" || Array.isArray(icons))) {
    throw new Error(`icons must be an object like { ios: "square.and.arrow.up", android: "share" }`)
  }
  if (icons) {
    const platform = rubyNativePlatform()
    if (platform && icons[platform]) return icons[platform]
  }
  return icon || fallbackIcon(icons)
}

// A web render has no platform, so `icons` alone must still resolve (ios then
// android, like the Rails helper) or NativeFab would throw on pages that are fine in the app.
/**
 * @param {NativeIcons} [icons]
 * @returns {string | undefined}
 */
function fallbackIcon(icons) {
  if (!icons) return undefined
  return icons.ios || icons.android
}

/**
 * Sends a message over the native bridge. Deliberately not exported: app code
 * talks to the app through signal elements, not the raw message protocol.
 * @param {Record<string, unknown>} message
 * @returns {boolean}
 */
function postMessage(message) {
  if (typeof window === "undefined") return false
  const bridge = window.RubyNative
  if (!bridge || typeof bridge.postMessage !== "function") return false
  bridge.postMessage(message)
  return true
}

/**
 * Returns "ios" or "android" inside a Ruby Native app, and null on the web.
 * The counterpart of the `native_platform` Rails helper.
 * @returns {"ios" | "android" | null}
 */
export function nativePlatform() {
  return rubyNativePlatform()
}

/**
 * @param {object} props
 * @param {boolean} [props.enabled]
 * @returns {import("react").ReactElement | null}
 */
export function NativeTabs({ enabled = true }) {
  if (!enabled) return null
  return createElement("div", { "data-native-tabs": true, hidden: true })
}

/**
 * @returns {import("react").ReactElement}
 */
export function NativePush() {
  return createElement("div", { "data-native-push": true, hidden: true })
}

/**
 * Who is signed in, as an opaque server-computed token (`native_identity_token`
 * shared as an Inertia prop). Render on every page: an empty or missing token
 * means signed out, and the app clears its screens when the value changes.
 * @param {object} props
 * @param {string | null} [props.token]
 * @returns {import("react").ReactElement}
 */
export function NativeIdentity({ token }) {
  return createElement("div", { "data-native-identity": token ?? "", hidden: true })
}

/**
 * @returns {import("react").ReactElement}
 */
export function NativeForm() {
  return createElement("div", { "data-native-form": true, hidden: true })
}

/**
 * Declares that this page lands as a root, with nothing behind it and no back
 * affordance.
 *
 * Emits only the element half of `native_presentation_tag`, so Advanced Mode
 * applies it once the page has rendered rather than before the navigation
 * commits. Set the `Native-Presentation` response header from the controller as
 * well to get the earlier path.
 *
 * @param {object} props
 * @param {"root"} [props.intent]
 * @returns {import("react").ReactElement}
 */
export function NativePresentation({ intent = "root" } = {}) {
  if (!PRESENTATION_INTENTS.includes(intent)) {
    throw new Error(`intent must be "root", got ${JSON.stringify(intent)}`)
  }
  return createElement("div", { "data-native-presentation": intent, hidden: true })
}

/**
 * @returns {import("react").ReactElement}
 */
export function NativeReview() {
  return createElement("div", { "data-native-review": true, hidden: true })
}

/**
 * A transient native toast shown above all app chrome. The signal is consumed
 * the moment it fires, so a restored page cannot re-toast. Renders nothing
 * visible on the web. The counterpart of the `native_toast_tag` Rails helper.
 * @param {object} props
 * @param {string} [props.message] Nothing renders when blank.
 * @param {string | false} [props.icon] `false` hides the default checkmark.
 * @param {NativeIcons} [props.icons]
 * @param {number} [props.duration]
 * @param {"inverted" | "system"} [props.appearance]
 * @returns {import("react").ReactElement | null}
 */
export function NativeToast({ message, icon, icons, duration = 4, appearance = "inverted" }) {
  if (!message) return null
  if (!TOAST_APPEARANCES.includes(appearance)) {
    throw new Error(`appearance must be "inverted" or "system", got ${JSON.stringify(appearance)}`)
  }
  /** @type {Record<string, any>} */
  const props = {
    "data-native-toast": "",
    "data-native-toast-message": message,
    "data-native-toast-duration": duration,
    "data-native-toast-appearance": appearance,
    hidden: true
  }
  // An absent icon attribute means "use the default" to the shell (the JS API
  // omits it), so `icon={false}` emits an empty value to mean "none".
  if (icon === false) {
    props["data-native-toast-icon"] = ""
  } else {
    const fallback = rubyNativePlatform() === "android" ? "check_circle" : "checkmark.circle.fill"
    props["data-native-toast-icon"] = resolveIcon(icon, icons) || fallback
  }
  return createElement("div", props)
}

/**
 * @param {object} props
 * @param {string} [props.title]
 * @param {boolean} [props.pullToRefresh]
 * @param {import("react").ReactNode} [props.children]
 * @returns {import("react").ReactElement}
 */
export function NativeNavbar({ title = "", pullToRefresh = true, children }) {
  /** @type {Record<string, any>} */
  const props = { "data-native-navbar": title, hidden: true }
  if (!pullToRefresh) props["data-native-pull-to-refresh"] = "false"
  return createElement("div", props, children)
}

/**
 * @param {object} props
 * @param {NativeButtonPosition} [props.position]
 * @param {string} [props.icon]
 * @param {NativeIcons} [props.icons]
 * @param {string} [props.title]
 * @param {string} [props.href]
 * @param {string} [props.click]
 * @param {boolean} [props.selected]
 * @param {import("react").ReactNode} [props.children]
 * @returns {import("react").ReactElement}
 */
export function NativeButton({ position = "trailing", icon, icons, title, href, click, selected, children }) {
  const resolved = resolveIcon(icon, icons)
  /** @type {Record<string, any>} */
  const props = { "data-native-button": true }
  if (resolved) props["data-native-icon"] = resolved
  if (title) props["data-native-title"] = title
  if (href) props["data-native-href"] = href
  if (click) props["data-native-click"] = click
  if (position) props["data-native-position"] = position
  if (selected) props["data-native-selected"] = ""
  return createElement("div", props, children)
}

/**
 * @param {object} props
 * @param {string} [props.title]
 * @param {string} [props.href]
 * @param {string} [props.click]
 * @param {string} [props.icon]
 * @param {NativeIcons} [props.icons]
 * @param {boolean} [props.selected]
 * @param {boolean} [props.destructive] Renders red, for destructive actions.
 * @param {NativeAction} [props.action]
 * @returns {import("react").ReactElement}
 */
export function NativeMenuItem({ title, href, click, icon, icons, selected, destructive, action }) {
  const resolved = resolveIcon(icon, icons)
  /** @type {Record<string, any>} */
  const props = { "data-native-menu-item": true }
  if (title) props["data-native-title"] = title
  if (href) props["data-native-href"] = href
  if (click) props["data-native-click"] = click
  if (resolved) props["data-native-icon"] = resolved
  if (selected) props["data-native-selected"] = ""
  if (destructive) props["data-native-destructive"] = ""
  if (action) props["data-native-action"] = validateAction(action)
  return createElement("div", props)
}

/**
 * Attaches a native menu to an element already on the page. `anchor` is a CSS
 * selector for that element; tapping it in the app opens a native menu
 * anchored to it with the `NativeMenuItem` children, and picking one navigates
 * or clicks a web element exactly like a nav bar menu item does. The anchor
 * element stays an ordinary element on the web, so give it its own web
 * behavior there. The counterpart of the `native_menu_tag` Rails helper.
 * @param {object} props
 * @param {string} props.anchor
 * @param {import("react").ReactNode} [props.children]
 * @returns {import("react").ReactElement}
 */
export function NativeMenu({ anchor, children }) {
  if (!anchor || !anchor.trim()) throw new Error("NativeMenu requires an `anchor` CSS selector")
  return createElement("div", { "data-native-menu": "", "data-native-anchor": anchor, hidden: true }, children)
}

/**
 * A segmented button in the nav bar. Render the same set on each sibling page
 * and mark the current one `selected`. iOS only.
 * @param {object} props
 * @param {string} [props.title]
 * @param {string} [props.href]
 * @param {string} [props.click]
 * @param {boolean} [props.selected]
 * @returns {import("react").ReactElement}
 */
export function NativeSegment({ title, href, click, selected }) {
  /** @type {Record<string, any>} */
  const props = { "data-native-segment": "" }
  if (title) props["data-native-title"] = title
  if (href) props["data-native-href"] = href
  if (click) props["data-native-click"] = click
  if (selected) props["data-native-selected"] = ""
  return createElement("div", props)
}

/**
 * @param {object} props
 * @param {NativeButtonPosition} [props.position]
 * @param {string} [props.title]
 * @param {string} [props.icon]
 * @param {NativeIcons} [props.icons]
 * @param {string} [props.url]
 * @returns {import("react").ReactElement}
 */
export function NativeShareButton({ position = "trailing", title = "Share", icon = "square.and.arrow.up", icons = { android: "share" }, url }) {
  const resolved = resolveIcon(icon, icons)
  /** @type {Record<string, any>} */
  const props = { "data-native-button": true, "data-native-share": "" }
  if (title) props["data-native-title"] = title
  if (resolved) props["data-native-icon"] = resolved
  if (position) props["data-native-position"] = position
  if (url) props["data-native-share-url"] = url
  return createElement("div", props)
}

/**
 * @param {object} props
 * @param {string} [props.title]
 * @param {string} [props.url]
 * @param {string} [props.icon]
 * @param {NativeIcons} [props.icons]
 * @param {boolean} [props.selected]
 * @returns {import("react").ReactElement}
 */
export function NativeShareMenuItem({ title = "Share", url, icon = "square.and.arrow.up", icons = { android: "share" }, selected }) {
  const resolved = resolveIcon(icon, icons)
  /** @type {Record<string, any>} */
  const props = { "data-native-menu-item": true, "data-native-share": "", "data-native-title": title }
  if (url) props["data-native-share-url"] = url
  if (resolved) props["data-native-icon"] = resolved
  if (selected) props["data-native-selected"] = ""
  return createElement("div", props)
}

/**
 * @param {object} props
 * @param {string} [props.icon]
 * @param {NativeIcons} [props.icons]
 * @param {string} [props.href]
 * @param {string} [props.click]
 * @param {string} [props.color]
 * @returns {import("react").ReactElement}
 */
export function NativeFab({ icon, icons, href, click, color }) {
  const resolved = resolveIcon(icon, icons)
  if (!resolved) throw new Error("NativeFab requires `icon` or `icons`")
  /** @type {Record<string, any>} */
  const props = { "data-native-fab": true, "data-native-icon": resolved, hidden: true }
  if (href) props["data-native-href"] = href
  if (click) props["data-native-click"] = click
  if (color) props["data-native-color"] = color
  return createElement("div", props)
}

/**
 * @param {object} props
 * @param {string} props.top
 * @param {string} [props.bottom]
 * @returns {import("react").ReactElement}
 */
export function NativeOverscroll({ top, bottom }) {
  return createElement("div", {
    "data-native-overscroll-top": top,
    "data-native-overscroll-bottom": bottom || top,
    hidden: true
  })
}

/**
 * Hides the iOS keyboard toolbar (the previous/next/Done bar) on this page.
 * Page-level: the toolbar belongs to the web view, not to individual fields.
 *
 * @param {object} props
 * @param {boolean} [props.toolbar]
 * @returns {import("react").ReactElement | null}
 */
export function NativeKeyboard({ toolbar = false }) {
  if (toolbar) return null
  return createElement("div", { "data-native-keyboard-toolbar": "false", hidden: true })
}

/**
 * @param {object} props
 * @param {string} [props.title]
 * @param {string} [props.click]
 * @returns {import("react").ReactElement}
 */
export function NativeSubmitButton({ title = "Save", click = "[type='submit']" }) {
  return createElement("div", {
    "data-native-submit-button": true,
    "data-native-title": title,
    "data-native-click": click,
    hidden: true
  })
}

/**
 * @param {object} props
 * @param {number} [props.count] Sets both `home` and `tab` unless they are given explicitly.
 * @param {number} [props.home]
 * @param {number | boolean | string} [props.tab] A count, `true` for a dot, or a short string.
 * @param {Record<string, number | boolean | string>} [props.tabs] Badges by tab `key`.
 * @returns {import("react").ReactElement}
 */
export function NativeBadge({ count, home, tab, tabs }) {
  if (count != null && home == null) home = count
  if (count != null && tab == null) tab = count
  /** @type {Record<string, any>} */
  const props = { "data-native-badge": "", hidden: true }
  if (home != null) props["data-native-badge-home"] = home
  if (tab != null) props["data-native-badge-tab"] = String(tab)
  if (tabs != null) props["data-native-badge-tabs"] = JSON.stringify(tabs)
  return createElement("div", props)
}

/**
 * A visible button that pops the native navigation stack on tap. Renders a
 * chevron unless you pass children. Extra props are forwarded to the button.
 * An `onClick` handler runs first and may `preventDefault()` to cancel the pop.
 * The counterpart of the `native_back_button_tag` Rails helper.
 * @param {import("react").ButtonHTMLAttributes<HTMLButtonElement>} props
 * @returns {import("react").ReactElement}
 */
export function NativeBackButton({ children, className, onClick, ...rest }) {
  const classes = ["native-back-button", className].filter(Boolean).join(" ")
  /** @param {import("react").MouseEvent<HTMLButtonElement>} event */
  const handleClick = event => {
    if (onClick) onClick(event)
    if (!event.defaultPrevented) postMessage({ action: "back" })
  }
  const content = children != null ? children : createElement(
    "svg",
    { width: 24, height: 24, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 2.5, "aria-hidden": true },
    createElement("path", { d: "M15.75 19.5L8.25 12l7.5-7.5", strokeLinecap: "round", strokeLinejoin: "round" })
  )
  return createElement("button", { type: "button", ...rest, className: classes, onClick: handleClick }, content)
}

/**
 * @param {NativeHapticFeedback} [feedback]
 * @param {Record<string, unknown>} [data]
 * @returns {Record<string, unknown>}
 */
export function nativeHaptic(feedback = "success", data = {}) {
  return { ...data, "data-native-haptic": feedback || "success" }
}
