// The signal contract shared by packages/react and packages/vue. Each fixture
// renders one component and pins the exact data-native-* output, so the two
// packages cannot drift from each other or from the Rails helpers they mirror.
// Consumed by each package's test/parity.test.mjs; never published.

const USER_AGENTS = {
  web: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Safari/605.1.15",
  ios: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Ruby Native iOS/1.0",
  android: "Mozilla/5.0 (Linux; Android 15) Ruby Native Android/1.0"
}

// Node 21+ defines a real global navigator, so swap it rather than assign.
export async function withPlatform(platform, fn) {
  const userAgent = USER_AGENTS[platform]
  if (!userAgent) throw new Error(`unknown platform ${JSON.stringify(platform)}`)
  const original = Object.getOwnPropertyDescriptor(globalThis, "navigator")
  Object.defineProperty(globalThis, "navigator", {
    value: { userAgent },
    configurable: true,
    writable: true
  })
  try {
    return await fn()
  } finally {
    if (original) Object.defineProperty(globalThis, "navigator", original)
    else delete globalThis.navigator
  }
}

const CONTRACT_ATTRIBUTES = ["hidden", "class", "type"]

function unescapeHtml(value) {
  return value
    .replace(/&quot;|&#34;/g, '"')
    .replace(/&#x27;|&#39;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
}

// Flattens rendered markup into [{ tag, attrs }] in document order, keeping
// only the attributes that are part of the signal contract. Frameworks render
// boolean attributes differently (hidden="" vs hidden), so bare attrs become "".
export function parseElements(markup) {
  const withoutComments = markup.replace(/<!--.*?-->/gs, "")
  const elements = []
  const tagPattern = /<([a-zA-Z][a-zA-Z0-9-]*)((?:\s+[^<>]*?)?)\s*\/?>/g
  let match
  while ((match = tagPattern.exec(withoutComments))) {
    const attrs = {}
    const attrPattern = /([a-zA-Z][a-zA-Z0-9:._-]*)(?:="([^"]*)")?/g
    let attr
    while ((attr = attrPattern.exec(match[2]))) {
      const name = attr[1]
      if (!name.startsWith("data-native-") && !CONTRACT_ATTRIBUTES.includes(name)) continue
      attrs[name] = attr[2] === undefined ? "" : unescapeHtml(attr[2])
    }
    elements.push({ tag: match[1], attrs })
  }
  return elements
}

// A hidden signal div, the shape every non-visible component renders.
function signal(attrs) {
  return { tag: "div", attrs: { ...attrs, hidden: "" } }
}

// A signal div without hidden: nav bar and menu children render bare.
function item(attrs) {
  return { tag: "div", attrs }
}

// Fixture shape: { name, component, props?, children?, platform? ("web"
// default), expected? ([{ tag, attrs }], [] for nothing), throws? (message
// substring both frameworks must raise) }.
export const fixtures = [
  {
    name: "renders the tabs signal",
    component: "NativeTabs",
    expected: [signal({ "data-native-tabs": "true" })]
  },
  {
    name: "renders nothing when disabled",
    component: "NativeTabs",
    props: { enabled: false },
    expected: []
  },
  {
    name: "renders the push signal",
    component: "NativePush",
    expected: [signal({ "data-native-push": "true" })]
  },
  {
    name: "renders the token",
    component: "NativeIdentity",
    props: { token: "3f9a1c" },
    expected: [signal({ "data-native-identity": "3f9a1c" })]
  },
  {
    name: "renders an empty token when signed out",
    component: "NativeIdentity",
    expected: [signal({ "data-native-identity": "" })]
  },
  {
    name: "renders the form signal",
    component: "NativeForm",
    expected: [signal({ "data-native-form": "true" })]
  },
  {
    name: "defaults to root",
    component: "NativePresentation",
    expected: [signal({ "data-native-presentation": "root" })]
  },
  {
    name: "rejects unknown intents",
    component: "NativePresentation",
    props: { intent: "modal" },
    throws: 'intent must be "root"'
  },
  {
    name: "renders the review signal",
    component: "NativeReview",
    expected: [signal({ "data-native-review": "true" })]
  },
  {
    name: "renders nothing without a message",
    component: "NativeToast",
    expected: []
  },
  {
    name: "renders the message with defaults",
    component: "NativeToast",
    props: { message: "Saved!" },
    expected: [signal({
      "data-native-toast": "",
      "data-native-toast-message": "Saved!",
      "data-native-toast-duration": "4",
      "data-native-toast-appearance": "inverted",
      "data-native-toast-icon": "checkmark.circle.fill"
    })]
  },
  {
    name: "defaults to the Material checkmark on Android",
    component: "NativeToast",
    props: { message: "Saved!" },
    platform: "android",
    expected: [signal({
      "data-native-toast": "",
      "data-native-toast-message": "Saved!",
      "data-native-toast-duration": "4",
      "data-native-toast-appearance": "inverted",
      "data-native-toast-icon": "check_circle"
    })]
  },
  {
    name: "icon false hides the icon",
    component: "NativeToast",
    props: { message: "Saved!", icon: false, duration: 2, appearance: "system" },
    expected: [signal({
      "data-native-toast": "",
      "data-native-toast-message": "Saved!",
      "data-native-toast-duration": "2",
      "data-native-toast-appearance": "system",
      "data-native-toast-icon": ""
    })]
  },
  {
    name: "picks the platform icon from icons",
    component: "NativeToast",
    props: { message: "Done", icons: { ios: "star.fill", android: "star" } },
    platform: "ios",
    expected: [signal({
      "data-native-toast": "",
      "data-native-toast-message": "Done",
      "data-native-toast-duration": "4",
      "data-native-toast-appearance": "inverted",
      "data-native-toast-icon": "star.fill"
    })]
  },
  {
    name: "icons alone fall back to the iOS name on the web",
    component: "NativeToast",
    props: { message: "Done", icons: { ios: "star.fill", android: "star" } },
    expected: [signal({
      "data-native-toast": "",
      "data-native-toast-message": "Done",
      "data-native-toast-duration": "4",
      "data-native-toast-appearance": "inverted",
      "data-native-toast-icon": "star.fill"
    })]
  },
  {
    name: "rejects unknown appearances",
    component: "NativeToast",
    props: { message: "Saved!", appearance: "loud" },
    throws: 'appearance must be "inverted" or "system"'
  },
  {
    name: "renders the title",
    component: "NativeNavbar",
    props: { title: "Today" },
    expected: [signal({ "data-native-navbar": "Today" })]
  },
  {
    name: "renders an empty title by default",
    component: "NativeNavbar",
    expected: [signal({ "data-native-navbar": "" })]
  },
  {
    name: "can disable pull to refresh",
    component: "NativeNavbar",
    props: { title: "Today", pullToRefresh: false },
    expected: [signal({ "data-native-navbar": "Today", "data-native-pull-to-refresh": "false" })]
  },
  {
    name: "renders buttons as children",
    component: "NativeNavbar",
    props: { title: "Today" },
    children: [
      { component: "NativeButton", props: { title: "Add", href: "/add" } },
      { component: "NativeSubmitButton" }
    ],
    expected: [
      signal({ "data-native-navbar": "Today" }),
      item({
        "data-native-button": "true",
        "data-native-title": "Add",
        "data-native-href": "/add",
        "data-native-position": "trailing"
      }),
      signal({
        "data-native-submit-button": "true",
        "data-native-title": "Save",
        "data-native-click": "[type='submit']"
      })
    ]
  },
  {
    name: "icons alone fall back to the iOS name on the web",
    component: "NativeButton",
    props: { icons: { ios: "plus", android: "add" } },
    expected: [item({
      "data-native-button": "true",
      "data-native-icon": "plus",
      "data-native-position": "trailing"
    })]
  },
  {
    name: "icons pick the platform name on Android",
    component: "NativeButton",
    props: { icons: { ios: "plus", android: "add" } },
    platform: "android",
    expected: [item({
      "data-native-button": "true",
      "data-native-icon": "add",
      "data-native-position": "trailing"
    })]
  },
  {
    name: "a platform match in icons beats icon",
    component: "NativeButton",
    props: { icon: "gear", icons: { android: "settings" } },
    platform: "android",
    expected: [item({
      "data-native-button": "true",
      "data-native-icon": "settings",
      "data-native-position": "trailing"
    })]
  },
  {
    name: "icon wins on the web when the platform has no icons entry",
    component: "NativeButton",
    props: { icon: "gear", icons: { android: "settings" } },
    expected: [item({
      "data-native-button": "true",
      "data-native-icon": "gear",
      "data-native-position": "trailing"
    })]
  },
  {
    name: "renders title, click, position, and selected",
    component: "NativeButton",
    props: { title: "Filter", click: "#open-filters", position: "leading", selected: true },
    expected: [item({
      "data-native-button": "true",
      "data-native-title": "Filter",
      "data-native-click": "#open-filters",
      "data-native-position": "leading",
      "data-native-selected": ""
    })]
  },
  {
    name: "rejects icons given as an array",
    component: "NativeButton",
    props: { icons: [{ ios: "plus" }] },
    throws: "icons must be an object"
  },
  {
    name: "renders menu items as children",
    component: "NativeButton",
    props: { icon: "ellipsis.circle" },
    children: [
      { component: "NativeMenuItem", props: { title: "All", href: "/all" } },
      { component: "NativeMenuItem", props: { title: "Delete", click: "#delete", destructive: true } }
    ],
    expected: [
      item({
        "data-native-button": "true",
        "data-native-icon": "ellipsis.circle",
        "data-native-position": "trailing"
      }),
      item({
        "data-native-menu-item": "true",
        "data-native-title": "All",
        "data-native-href": "/all"
      }),
      item({
        "data-native-menu-item": "true",
        "data-native-title": "Delete",
        "data-native-click": "#delete",
        "data-native-destructive": ""
      })
    ]
  },
  {
    name: "renders icon, selected, and a replace action",
    component: "NativeMenuItem",
    props: { title: "All", href: "/all", icon: "list.bullet", selected: true, action: "replace" },
    expected: [item({
      "data-native-menu-item": "true",
      "data-native-title": "All",
      "data-native-href": "/all",
      "data-native-icon": "list.bullet",
      "data-native-selected": "",
      "data-native-action": "replace"
    })]
  },
  {
    name: "accepts a push action",
    component: "NativeMenuItem",
    props: { title: "Open", href: "/open", action: "push" },
    expected: [item({
      "data-native-menu-item": "true",
      "data-native-title": "Open",
      "data-native-href": "/open",
      "data-native-action": "push"
    })]
  },
  {
    name: "rejects unknown actions",
    component: "NativeMenuItem",
    props: { title: "All", href: "/all", action: "root" },
    throws: 'action must be "push" or "replace"'
  },
  {
    name: "renders the anchor with items",
    component: "NativeMenu",
    props: { anchor: "#status-pill" },
    children: [
      { component: "NativeMenuItem", props: { title: "Currently reading", click: "#status-reading" } }
    ],
    expected: [
      signal({ "data-native-menu": "", "data-native-anchor": "#status-pill" }),
      item({
        "data-native-menu-item": "true",
        "data-native-title": "Currently reading",
        "data-native-click": "#status-reading"
      })
    ]
  },
  {
    name: "rejects a blank anchor",
    component: "NativeMenu",
    props: { anchor: "  " },
    throws: "anchor"
  },
  {
    name: "renders title, href, and selected",
    component: "NativeSegment",
    props: { title: "Books", href: "/books", selected: true },
    expected: [item({
      "data-native-segment": "",
      "data-native-title": "Books",
      "data-native-href": "/books",
      "data-native-selected": ""
    })]
  },
  {
    name: "defaults to the share icon and title",
    component: "NativeShareButton",
    expected: [item({
      "data-native-button": "true",
      "data-native-share": "",
      "data-native-title": "Share",
      "data-native-icon": "square.and.arrow.up",
      "data-native-position": "trailing"
    })]
  },
  {
    name: "defaults to the Material share glyph on Android",
    component: "NativeShareButton",
    platform: "android",
    expected: [item({
      "data-native-button": "true",
      "data-native-share": "",
      "data-native-title": "Share",
      "data-native-icon": "share",
      "data-native-position": "trailing"
    })]
  },
  {
    name: "renders the share url",
    component: "NativeShareButton",
    props: { url: "/posts/1" },
    expected: [item({
      "data-native-button": "true",
      "data-native-share": "",
      "data-native-title": "Share",
      "data-native-icon": "square.and.arrow.up",
      "data-native-position": "trailing",
      "data-native-share-url": "/posts/1"
    })]
  },
  {
    name: "defaults to the share icon and title",
    component: "NativeShareMenuItem",
    expected: [item({
      "data-native-menu-item": "true",
      "data-native-share": "",
      "data-native-title": "Share",
      "data-native-icon": "square.and.arrow.up"
    })]
  },
  {
    name: "defaults to the Material share glyph on Android",
    component: "NativeShareMenuItem",
    platform: "android",
    expected: [item({
      "data-native-menu-item": "true",
      "data-native-share": "",
      "data-native-title": "Share",
      "data-native-icon": "share"
    })]
  },
  {
    name: "renders the share url and selected",
    component: "NativeShareMenuItem",
    props: { url: "/posts/1", selected: true },
    expected: [item({
      "data-native-menu-item": "true",
      "data-native-share": "",
      "data-native-title": "Share",
      "data-native-icon": "square.and.arrow.up",
      "data-native-share-url": "/posts/1",
      "data-native-selected": ""
    })]
  },
  {
    name: "renders icon, href, click, and color",
    component: "NativeFab",
    props: { icon: "plus", href: "/posts/new", click: "#new-post", color: "#D97706" },
    expected: [signal({
      "data-native-fab": "true",
      "data-native-icon": "plus",
      "data-native-href": "/posts/new",
      "data-native-click": "#new-post",
      "data-native-color": "#D97706"
    })]
  },
  {
    name: "icons alone fall back to the iOS name on the web",
    component: "NativeFab",
    props: { icons: { ios: "plus", android: "add" }, href: "/posts/new" },
    expected: [signal({
      "data-native-fab": "true",
      "data-native-icon": "plus",
      "data-native-href": "/posts/new"
    })]
  },
  {
    name: "icons alone fall back to the Android name when iOS is missing",
    component: "NativeFab",
    props: { icons: { android: "add" }, href: "/posts/new" },
    expected: [signal({
      "data-native-fab": "true",
      "data-native-icon": "add",
      "data-native-href": "/posts/new"
    })]
  },
  {
    name: "icons pick the platform name on Android",
    component: "NativeFab",
    props: { icons: { ios: "plus", android: "add" }, href: "/posts/new" },
    platform: "android",
    expected: [signal({
      "data-native-fab": "true",
      "data-native-icon": "add",
      "data-native-href": "/posts/new"
    })]
  },
  {
    name: "still requires some icon",
    component: "NativeFab",
    props: { href: "/posts/new" },
    throws: "NativeFab requires"
  },
  {
    name: "rejects empty icons",
    component: "NativeFab",
    props: { icons: {} },
    throws: "NativeFab requires"
  },
  {
    name: "rejects icons given as an array",
    component: "NativeFab",
    props: { icons: [{ ios: "plus" }] },
    throws: "icons must be an object"
  },
  {
    name: "bottom defaults to top",
    component: "NativeOverscroll",
    props: { top: "#0f172a" },
    expected: [signal({
      "data-native-overscroll-top": "#0f172a",
      "data-native-overscroll-bottom": "#0f172a"
    })]
  },
  {
    name: "renders distinct top and bottom",
    component: "NativeOverscroll",
    props: { top: "#0f172a", bottom: "#f8fafc" },
    expected: [signal({
      "data-native-overscroll-top": "#0f172a",
      "data-native-overscroll-bottom": "#f8fafc"
    })]
  },
  {
    name: "hides the keyboard toolbar by default",
    component: "NativeKeyboard",
    expected: [signal({ "data-native-keyboard-toolbar": "false" })]
  },
  {
    name: "renders nothing when the toolbar is kept",
    component: "NativeKeyboard",
    props: { toolbar: true },
    expected: []
  },
  {
    name: "defaults to Save and the submit selector",
    component: "NativeSubmitButton",
    expected: [signal({
      "data-native-submit-button": "true",
      "data-native-title": "Save",
      "data-native-click": "[type='submit']"
    })]
  },
  {
    name: "renders a custom title and click",
    component: "NativeSubmitButton",
    props: { title: "Send", click: "#send" },
    expected: [signal({
      "data-native-submit-button": "true",
      "data-native-title": "Send",
      "data-native-click": "#send"
    })]
  },
  {
    name: "count sets home and tab",
    component: "NativeBadge",
    props: { count: 3 },
    expected: [signal({
      "data-native-badge": "",
      "data-native-badge-home": "3",
      "data-native-badge-tab": "3"
    })]
  },
  {
    name: "count zero still renders",
    component: "NativeBadge",
    props: { count: 0 },
    expected: [signal({
      "data-native-badge": "",
      "data-native-badge-home": "0",
      "data-native-badge-tab": "0"
    })]
  },
  {
    name: "home alone renders only home",
    component: "NativeBadge",
    props: { home: 1 },
    expected: [signal({
      "data-native-badge": "",
      "data-native-badge-home": "1"
    })]
  },
  {
    name: "an explicit tab beats count",
    component: "NativeBadge",
    props: { count: 5, tab: 0 },
    expected: [signal({
      "data-native-badge": "",
      "data-native-badge-home": "5",
      "data-native-badge-tab": "0"
    })]
  },
  {
    name: "true tab renders a dot",
    component: "NativeBadge",
    props: { tab: true },
    expected: [signal({
      "data-native-badge": "",
      "data-native-badge-tab": "true"
    })]
  },
  {
    name: "tabs badge by key",
    component: "NativeBadge",
    props: { tabs: { library: 3, features: true } },
    expected: [signal({
      "data-native-badge": "",
      "data-native-badge-tabs": '{"library":3,"features":true}'
    })]
  },
  {
    name: "renders the bare badge signal without counts",
    component: "NativeBadge",
    expected: [signal({ "data-native-badge": "" })]
  },
  {
    name: "renders a button with the default chevron",
    component: "NativeBackButton",
    expected: [
      { tag: "button", attrs: { type: "button", class: "native-back-button" } },
      { tag: "svg", attrs: {} },
      { tag: "path", attrs: {} }
    ]
  }
]

// [args, expected] pairs for the nativeHaptic data helper.
export const hapticFixtures = [
  { args: [], expected: { "data-native-haptic": "success" } },
  { args: ["warning"], expected: { "data-native-haptic": "warning" } },
  { args: [""], expected: { "data-native-haptic": "success" } },
  {
    args: ["impact", { controller: "rows" }],
    expected: { controller: "rows", "data-native-haptic": "impact" }
  }
]
