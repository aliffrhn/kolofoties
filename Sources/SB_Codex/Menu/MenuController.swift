import AppKit

@MainActor
final class MenuController {
    private let appController: AppController
    private let statusItem: NSStatusItem
    private var overlayEnabled: Bool
    var overlayToggleHandler: ((Bool) -> Void)?

    init(appController: AppController, overlayEnabled: Bool) {
        self.appController = appController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.overlayEnabled = overlayEnabled
    }

    func setupMenuBarItem() {
        if let button = statusItem.button {
            button.image = nil
            button.title = "⚡️"
            button.setAccessibilityLabel("Cursor Companion")
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let toggleTitle = appController.isActive ? "Pause" : "Resume"
        menu.addItem(NSMenuItem(title: toggleTitle, action: #selector(toggleActive), keyEquivalent: "p"))
        let overlayItem = NSMenuItem(title: overlayEnabled ? "Hide Fairy Overlay" : "Show Fairy Overlay", action: #selector(toggleOverlay), keyEquivalent: "o")
        overlayItem.target = self
        menu.addItem(overlayItem)
        menu.addItem(.separator())

        let providerItem = NSMenuItem(title: "AI: \(appController.providerSummary)", action: nil, keyEquivalent: "")
        providerItem.isEnabled = false
        menu.addItem(providerItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        updateButtonAppearance()
    }

    @objc private func toggleActive() {
        appController.toggle()
        rebuildMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func refresh() {
        rebuildMenu()
    }

    func updateOverlayEnabled(_ isEnabled: Bool) {
        overlayEnabled = isEnabled
        rebuildMenu()
    }

    private func updateButtonAppearance() {
        guard let button = statusItem.button else { return }
        button.title = appController.isActive ? "⚡️" : "⏸"
    }

    @objc private func toggleOverlay() {
        overlayEnabled.toggle()
        overlayToggleHandler?(overlayEnabled)
        rebuildMenu()
    }
}
