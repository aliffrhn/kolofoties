import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appController = AppController()
    private var menuController: MenuController!
    private let voiceOutput = VoiceOutput()
    private let notificationDispatcher = NotificationDispatcher()
    private let hotkeyManager = GlobalHotkeyManager()
    private let fairyOverlay = FairyOverlayController()
    private let anchorManager = OverlayAnchorManager()
    private var overlayEnabled = true
    private var overlayPreferenceBeforeAccessibility: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        notificationDispatcher.configure()

        let configuration = appController.appConfiguration
        voiceOutput.configure(
            voiceIdentifier: configuration.voiceIdentifier,
            rate: configuration.voiceRate,
            pitch: configuration.voicePitch
        )
        Logger.info("Voice assistant using: \(voiceOutput.currentVoiceDescription)")

        voiceOutput.speechStateHandler = { [weak self] state in
            guard let self else { return }
            guard self.overlayEnabled else { return }
            switch state {
            case .started:
                self.fairyOverlay.beginSpeaking()
            case .finished, .cancelled:
                self.fairyOverlay.endSpeaking()
            }
        }

        menuController = MenuController(appController: appController, overlayEnabled: overlayEnabled)
        fairyOverlay.isEnabled = overlayEnabled
        menuController.overlayToggleHandler = { [weak self] isEnabled in
            guard let self else { return }
            guard self.appController.interactionMode != .accessibility else {
                self.menuController.updateOverlayEnabled(false)
                self.overlayEnabled = false
                return
            }
            overlayEnabled = isEnabled
            fairyOverlay.isEnabled = isEnabled
            if !isEnabled {
                fairyOverlay.hide(animated: true)
            }
        }
        appController.commentaryHandler = { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                Logger.info("AI Commentary: \(response.text)")
                if overlayEnabled {
                    fairyOverlay.beginSpeaking()
                    let metadata = self.appController.latestCaptureMetadata
                    let focusRect = metadata?.foregroundWindowBounds
                    fairyOverlay.showMessage(response.text) { [weak self] bubbleSize in
                        guard let self else { return CGPoint(x: 60, y: 60) }
                        return self.anchorManager.nextAnchor(
                            bubbleSize: bubbleSize,
                            cursorLocation: self.appController.latestCursorLocation,
                            focusRect: focusRect,
                            hotspots: metadata?.textHotspots ?? []
                        )
                    }
                }
                voiceOutput.speak(response.text)
                notificationDispatcher.deliver(body: response.text)
                menuController.refresh()
            case .failure(let error):
                Logger.error("AI Commentary failed: \(error.localizedDescription)")
                notificationDispatcher.deliver(body: "⚠️ Commentary failed: \(error.localizedDescription)")
                if overlayEnabled {
                    fairyOverlay.beginSpeaking()
                    let metadata = self.appController.latestCaptureMetadata
                    let focusRect = metadata?.foregroundWindowBounds
                    fairyOverlay.showMessage("Oops, I hit a snag: \(error.localizedDescription)") { [weak self] bubbleSize in
                        guard let self else { return CGPoint(x: 60, y: 60) }
                        return self.anchorManager.nextAnchor(
                            bubbleSize: bubbleSize,
                            cursorLocation: self.appController.latestCursorLocation,
                            focusRect: focusRect,
                            hotspots: metadata?.textHotspots ?? []
                        )
                    }
                    fairyOverlay.endSpeaking()
                }
            }
        }

        appController.stateChangeHandler = { [weak self] isActive in
            guard let self else { return }
            menuController.refresh()
            if !isActive {
                fairyOverlay.hide(animated: true)
            }
        }
        appController.modeChangeHandler = { [weak self] _ in
            self?.applyInteractionMode()
            self?.menuController.refresh()
        }

        appController.start()
        menuController.setupMenuBarItem()
        applyInteractionMode(initial: true)

        hotkeyManager.handler = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.appController.toggle()
            }
        }

        do {
            try hotkeyManager.register()
        } catch {
            Logger.error("Failed to register global hotkey: \(error)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        fairyOverlay.hide(animated: false)
        appController.stop()
    }

    private func applyInteractionMode(initial: Bool = false) {
        guard menuController != nil else { return }
        let mode = appController.interactionMode
        switch mode {
        case .casual:
            if let previous = overlayPreferenceBeforeAccessibility {
                overlayEnabled = previous
                overlayPreferenceBeforeAccessibility = nil
            }
            fairyOverlay.isEnabled = overlayEnabled
            if !overlayEnabled {
                fairyOverlay.hide(animated: true)
            }
            menuController.updateOverlayEnabled(overlayEnabled)
        case .focus:
            if let previous = overlayPreferenceBeforeAccessibility {
                overlayEnabled = previous
                overlayPreferenceBeforeAccessibility = nil
            }
            fairyOverlay.isEnabled = overlayEnabled
            if !overlayEnabled {
                fairyOverlay.hide(animated: true)
            }
            menuController.updateOverlayEnabled(overlayEnabled)
        case .accessibility:
            if overlayPreferenceBeforeAccessibility == nil {
                overlayPreferenceBeforeAccessibility = overlayEnabled
            }
            overlayEnabled = false
            fairyOverlay.isEnabled = false
            fairyOverlay.hide(animated: true)
            menuController.updateOverlayEnabled(false)
        }

        guard !initial else { return }
        let message: String
        switch mode {
        case .casual:
            message = "Mode set to Casual. Commentary stays friendly."
        case .focus:
            message = "Mode set to Focus. Expect punchier, task-oriented tips."
        case .accessibility:
            message = "Mode set to Accessibility. Overlay hidden for clearer narration."
        }
        notificationDispatcher.deliver(body: message)
    }
}
