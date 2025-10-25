import AppKit

// Top-level entry point. Avoids @main conflict with any other top-level code in the module.
let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.accessory)
app.run()
