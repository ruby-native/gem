# @ruby-native/react

React components for [Ruby Native](https://rubynative.com). Use these in an Inertia.js + React app to emit the signal elements that Ruby Native's iOS and Android apps read to render native tabs, navigation bars, forms, and more.

## Install

```sh
npm install @ruby-native/react
```

## Usage

```jsx
import { NativeTabs, NativeNavbar, NativeButton, NativeForm } from "@ruby-native/react"

export default function Show({ product }) {
  return (
    <>
      <NativeNavbar title={product.name}>
        <NativeButton icon="bag" href="/cart" />
      </NativeNavbar>

      <NativeForm />

      {/* your page content */}
    </>
  )
}
```

Each component renders a hidden `data-native-*` signal element that the Ruby Native runtime picks up and turns into the corresponding native UI.

## Components

- `NativeTabs` - show the native tab bar
- `NativePush` - request push notification permission
- `NativeForm` - mark the current page as a form so back navigation skips it
- `NativePresentation` - declare that this page lands as a root, with no back button
- `NativeReview` - ask for an App Store review prompt when the page loads
- `NativeToast` - show a transient native toast above all app chrome
- `NativeNavbar` - native navigation bar with title and buttons
- `NativeButton` - native nav bar button (icon, title, href, or click target)
- `NativeMenuItem` - item inside a native menu
- `NativeMenu` - native menu attached to any element on the page via a CSS selector
- `NativeSegment` - segmented button in the nav bar (iOS only)
- `NativeShareButton` - native nav bar button that opens the share sheet
- `NativeShareMenuItem` - menu item that opens the share sheet
- `NativeSubmitButton` - native "Save" button that submits a form
- `NativeFab` - floating action button (icon, optional title)
- `NativeOverscroll` - per-page overscroll colors
- `NativeBadge` - set the badge count on a home screen or tab bar icon
- `NativeBackButton` - visible button that pops the native navigation stack

`NativeBackButton` renders a chevron unless you pass children, and forwards extra props to the underlying `<button>`. An `onClick` handler runs first and can call `preventDefault()` to cancel the back:

```jsx
<NativeBackButton className="mr-2" aria-label="Go back" />
```

## Helpers

- `nativePlatform()` - returns `"ios"`, `"android"`, or `null` on the web. The counterpart of the `native_platform` Rails helper.
- `nativeHaptic(feedback = "success", data = {})` - returns props to spread onto a clickable element so tapping it triggers native haptic feedback:

  ```jsx
  <button {...nativeHaptic("success")}>Save</button>
  ```

## TypeScript

Type declarations ship with the package. There is nothing to install and no `@types` companion package. Importing a component gives you autocomplete and prop checking:

```tsx
import { NativeNavbar, NativeButton } from "@ruby-native/react"

<NativeNavbar title="Books" pullToRefresh={false}>
  <NativeButton position="leading" icon="chevron.left" href="/books" />
</NativeNavbar>
```

The `NativeIcons`, `NativeButtonPosition`, and `NativeHapticFeedback` types are exported too.

## Docs

Full guides at [rubynative.com/docs](https://rubynative.com/docs).

## License

MIT
