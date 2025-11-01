import AppKit
import QuartzCore

@MainActor
final class FairyOverlayController {
    private let window: NSWindow
    private let textField: NSTextField
    private let backgroundView: NSVisualEffectView
    private var hideWorkItem: DispatchWorkItem?
    private var currentSize: CGSize = CGSize(width: 220, height: 120)
    private var isSpeaking: Bool = false
    private let floatAnimationKey = "fairy.float"

    var isEnabled: Bool = true {
        didSet {
            if !isEnabled {
                hide(animated: true)
            }
        }
    }

    init() {
        let contentSize = CGSize(width: 280, height: 120)

        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary, .canJoinAllSpaces]

        backgroundView = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentSize))
        backgroundView.material = .contentBackground
        backgroundView.blendingMode = .withinWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 18
        backgroundView.layer?.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMinYCorner,
            .layerMaxXMaxYCorner
        ]
        backgroundView.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.85).cgColor
        backgroundView.layer?.borderWidth = 0
        backgroundView.alphaValue = 0.0

        textField = NSTextField(labelWithString: "")
        textField.textColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)
        textField.maximumNumberOfLines = 0
        textField.font = .systemFont(ofSize: 13, weight: .semibold)
        textField.lineBreakMode = .byWordWrapping
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.setContentCompressionResistancePriority(.required, for: .horizontal)
        textField.setContentCompressionResistancePriority(.required, for: .vertical)

        let contentView = NSView(frame: backgroundView.bounds)
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = backgroundView.layer?.cornerRadius ?? 0
        contentView.layer?.masksToBounds = false
        contentView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
        contentView.layer?.shadowOpacity = 1
        contentView.layer?.shadowRadius = 18
        contentView.layer?.shadowOffset = CGSize(width: 0, height: -6)
        contentView.addSubview(backgroundView)
        contentView.addSubview(textField)

        backgroundView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])

        window.contentView = contentView
    }

    func showMessage(_ message: String, anchorProvider: (CGSize) -> CGPoint) {
        guard isEnabled else { return }

        textField.stringValue = message

        let maxWidth: CGFloat = 300
        let minWidth: CGFloat = 180
        let maxHeight: CGFloat = 200
        let minHeight: CGFloat = 96
        let textBounding = textField.attributedStringValue.boundingRect(
            with: NSSize(width: maxWidth - 32, height: maxHeight - 32),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let desiredSize = CGSize(
            width: min(max(textBounding.width + 32, minWidth), maxWidth),
            height: min(max(textBounding.height + 24, minHeight), maxHeight)
        )
        textField.preferredMaxLayoutWidth = desiredSize.width - 32
        textField.invalidateIntrinsicContentSize()
        currentSize = desiredSize

        let targetOrigin = clampAnchor(anchorProvider(desiredSize), size: desiredSize)

        if !window.isVisible {
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
        }

        repositionWindow(to: targetOrigin, size: desiredSize, animated: true)
        window.contentView?.layoutSubtreeIfNeeded()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            self.backgroundView.animator().alphaValue = 1
            self.window.animator().alphaValue = 1
        }

        scheduleHide()
    }

    func moveToAnchor(_ anchor: CGPoint, animated: Bool) {
        guard window.isVisible, isEnabled else { return }
        let adjusted = clampAnchor(anchor, size: currentSize)
        repositionWindow(to: adjusted, size: currentSize, animated: animated)
        window.contentView?.layoutSubtreeIfNeeded()
    }

    func beginSpeaking() {
        isSpeaking = true
        hideWorkItem?.cancel()
        hideWorkItem = nil
        startFloatAnimation()
    }

    func endSpeaking() {
        isSpeaking = false
        stopFloatAnimation()
        scheduleHide(delay: 2.0)
    }

    func hide(animated: Bool) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        isSpeaking = false
        stopFloatAnimation()
        guard window.isVisible else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                self.window.animator().alphaValue = 0
                self.backgroundView.animator().alphaValue = 0
            } completionHandler: {
                self.window.orderOut(nil)
            }
        } else {
            window.orderOut(nil)
        }
    }

    private func scheduleHide(delay: TimeInterval = 5.0) {
        guard !isSpeaking else { return }
        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.hide(animated: true)
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func clampAnchor(_ anchor: CGPoint, size: CGSize) -> CGPoint {
        let screens = NSScreen.screens
        let containingScreen = screens.first { NSPointInRect(anchor, $0.frame) } ?? NSScreen.main
        let bounds = containingScreen?.frame ?? NSRect(origin: .zero, size: size)
        let minX = bounds.minX + 20
        let maxX = bounds.maxX - size.width - 20
        let minY = bounds.minY + 20
        let maxY = bounds.maxY - size.height - 20
        return CGPoint(
            x: max(minX, min(anchor.x, maxX)),
            y: max(minY, min(anchor.y, maxY))
        )
    }

    private func repositionWindow(to origin: CGPoint, size: CGSize, animated: Bool) {
        let frame = NSRect(origin: origin, size: size).integral

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
        }

        if let layer = window.contentView?.layer {
            layer.shadowPath = CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: 18, cornerHeight: 18, transform: nil)
        }
    }

    private func startFloatAnimation() {
        guard let layer = window.contentView?.layer, layer.animation(forKey: floatAnimationKey) == nil else { return }
        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        animation.byValue = 6
        animation.duration = 1.6
        animation.autoreverses = true
        animation.repeatCount = .greatestFiniteMagnitude
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: floatAnimationKey)
    }

    private func stopFloatAnimation() {
        window.contentView?.layer?.removeAnimation(forKey: floatAnimationKey)
    }
}
