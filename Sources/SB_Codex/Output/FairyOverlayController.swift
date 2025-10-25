import AppKit
import QuartzCore

@MainActor
final class FairyOverlayController {
    private let window: NSWindow
    private let textField: NSTextField
    private let backgroundView: NSVisualEffectView
    private let tailLayer = CAShapeLayer()
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
        backgroundView.material = .hudWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = contentSize.height / 2
        backgroundView.layer?.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner]
        backgroundView.layer?.borderColor = NSColor(calibratedRed: 0.7, green: 0.6, blue: 1.0, alpha: 0.6).cgColor
        backgroundView.layer?.borderWidth = 1.2
        backgroundView.alphaValue = 0.0

        textField = NSTextField(labelWithString: "")
        textField.textColor = .white
        textField.maximumNumberOfLines = 0
        textField.font = .systemFont(ofSize: 14, weight: .medium)
        textField.lineBreakMode = .byWordWrapping
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.setContentCompressionResistancePriority(.required, for: .horizontal)
        textField.setContentCompressionResistancePriority(.required, for: .vertical)

        let contentView = NSView(frame: backgroundView.bounds)
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = backgroundView.layer?.cornerRadius ?? 0
        contentView.layer?.masksToBounds = false
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

        tailLayer.fillColor = NSColor(calibratedRed: 0.68, green: 0.64, blue: 1.0, alpha: 0.85).cgColor
        tailLayer.shadowColor = NSColor.black.withAlphaComponent(0.4).cgColor
        tailLayer.shadowOpacity = 0.4
        tailLayer.shadowRadius = 3
        tailLayer.shadowOffset = CGSize(width: 1, height: -1)
        contentView.layer?.addSublayer(tailLayer)
    }

    func showMessage(_ message: String, anchorProvider: (CGSize) -> CGPoint) {
        guard isEnabled else { return }

        textField.stringValue = message
        textField.sizeToFit()

        let maxWidth: CGFloat = 320
        let minWidth: CGFloat = 220
        let maxHeight: CGFloat = 180
        let minHeight: CGFloat = 100
        let textBounding = textField.attributedStringValue.boundingRect(
            with: NSSize(width: maxWidth - 32, height: maxHeight - 24),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let desiredSize = CGSize(
            width: min(max(textBounding.width + 32, minWidth), maxWidth),
            height: min(max(textBounding.height + 24, minHeight), maxHeight)
        )
        textField.preferredMaxLayoutWidth = desiredSize.width - 32
        currentSize = desiredSize

        let targetOrigin = clampAnchor(anchorProvider(desiredSize), size: desiredSize)
        updateTailPath(for: desiredSize)

        if !window.isVisible {
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
        }

        repositionWindow(to: targetOrigin, size: desiredSize, animated: true)
        backgroundView.alphaValue = 1
        window.alphaValue = 1

        scheduleHide()
        addSparkle()
    }

    func moveToAnchor(_ anchor: CGPoint, animated: Bool) {
        guard window.isVisible, isEnabled else { return }
        let adjusted = clampAnchor(anchor, size: currentSize)
        repositionWindow(to: adjusted, size: currentSize, animated: animated)
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
        let frame = NSRect(origin: origin, size: size)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
        }
    }

    private func addSparkle() {
        guard let contentView = window.contentView else { return }
        let sparkle = CALayer()
        sparkle.backgroundColor = NSColor(calibratedRed: 0.9, green: 0.8, blue: 1.0, alpha: 0.7).cgColor
        sparkle.cornerRadius = 3
        sparkle.frame = CGRect(x: CGFloat.random(in: 10...(contentView.frame.width - 10)), y: contentView.frame.height - 8, width: 6, height: 6)

        contentView.layer?.addSublayer(sparkle)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.6
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let move = CABasicAnimation(keyPath: "position.y")
        move.byValue = -14
        move.duration = 0.6
        move.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let group = CAAnimationGroup()
        group.animations = [fade, move]
        group.duration = 0.6
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards

        sparkle.add(group, forKey: "sparkleFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            sparkle.removeFromSuperlayer()
        }
    }

    private func updateTailPath(for size: CGSize) {
        let tailWidth: CGFloat = 20
        let tailHeight: CGFloat = 18
        let path = CGMutablePath()
        path.move(to: CGPoint(x: tailWidth, y: tailHeight / 2))
        path.addLine(to: CGPoint(x: 0, y: tailHeight))
        path.addLine(to: CGPoint(x: 2, y: tailHeight / 2))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        tailLayer.path = path
        tailLayer.bounds = CGRect(x: 0, y: 0, width: tailWidth, height: tailHeight)
        tailLayer.position = CGPoint(x: 12, y: size.height / 2)
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
