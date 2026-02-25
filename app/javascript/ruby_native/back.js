export function goBack() {
  webkit.messageHandlers.rubyNative.postMessage({ action: "back" })
}
