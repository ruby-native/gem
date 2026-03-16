pin "ruby_native/bridge", to: "ruby_native/bridge/index.js"
pin_all_from RubyNative::Engine.root.join("app/javascript/ruby_native/bridge"), under: "ruby_native/bridge"
pin "ruby_native/back", to: "ruby_native/back.js"
