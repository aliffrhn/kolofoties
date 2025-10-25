import CoreGraphics
import Foundation

struct CaptureMetadata: Sendable {
    let timestamp: Date
    let cursorLocation: CGPoint
    let screenSize: CGSize
    let foregroundAppName: String?
    let foregroundBundleIdentifier: String?
    let foregroundWindowTitle: String?
    let foregroundWindowBounds: CGRect?
    let textHotspots: [ScreenHotspot]
}

extension CaptureMetadata {
    func contextualHint() -> String? {
        var hints: [String] = []
        if let appName = foregroundAppName {
            hints.append("Hint - front app might be \(appName).")
        }
        if let title = foregroundWindowTitle, !title.isEmpty {
            hints.append("Hint - window title shows \"\(title)\".")
        }
        if !textHotspots.isEmpty {
            let samples = textHotspots
                .prefix(3)
                .map { "\"\($0.text)\"" }
                .joined(separator: ", ")
            hints.append("Hint - saw text: \(samples)")
        }
        return hints.isEmpty ? nil : hints.joined(separator: "\n")
    }

    func updatingHotspots(_ hotspots: [ScreenHotspot]) -> CaptureMetadata {
        CaptureMetadata(
            timestamp: timestamp,
            cursorLocation: cursorLocation,
            screenSize: screenSize,
            foregroundAppName: foregroundAppName,
            foregroundBundleIdentifier: foregroundBundleIdentifier,
            foregroundWindowTitle: foregroundWindowTitle,
            foregroundWindowBounds: foregroundWindowBounds,
            textHotspots: hotspots
        )
    }
}
