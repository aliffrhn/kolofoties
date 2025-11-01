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
        overlayItem.isEnabled = appController.interactionMode != .accessibility
        menu.addItem(overlayItem)
        menu.addItem(.separator())

        let providerItem = NSMenuItem(title: "AI: \(appController.providerSummary)", action: nil, keyEquivalent: "")
        providerItem.isEnabled = false
        menu.addItem(providerItem)

        let modeMenuItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        modeMenuItem.isEnabled = true
        modeMenuItem.submenu = buildModeSubmenu()
        menu.addItem(modeMenuItem)

        if let stats = appController.tokenUsageStats {
            if let last = stats.last {
                let lastItem = NSMenuItem(title: tokensTitle(prefix: "Last", usage: last), action: nil, keyEquivalent: "")
                lastItem.isEnabled = false
                menu.addItem(lastItem)
            }
            let sessionItem = NSMenuItem(
                title: tokensTitle(
                    prefix: "Session",
                    usage: TokenUsage(
                        promptTokens: stats.totalPromptTokens,
                        completionTokens: stats.totalCompletionTokens,
                        totalTokens: stats.totalTokens
                    )
                ),
                action: nil,
                keyEquivalent: ""
            )
            sessionItem.isEnabled = false
            menu.addItem(sessionItem)
        }
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

    private func tokensTitle(prefix: String, usage: TokenUsage) -> String {
        "Tokens (\(prefix)): in \(usage.promptTokens) • out \(usage.completionTokens) • total \(usage.totalTokens)"
    }

    private func buildModeSubmenu() -> NSMenu {
        let submenu = NSMenu()
        for mode in InteractionMode.allCases {
            let item = NSMenuItem(title: mode.displayName, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == appController.interactionMode ? .on : .off
            submenu.addItem(item)
        }
        return submenu
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let mode = InteractionMode(rawValue: rawValue)
        else { return }
        appController.updateMode(mode)
        rebuildMenu()
    }
}
