import AppKit
import CoreGraphics
import Foundation

final class SystemContextProvider {
    func metadata(for cursorLocation: CGPoint, screenSize: CGSize) -> CaptureMetadata {
        let workspace = NSWorkspace.shared
        let frontmostApp = workspace.frontmostApplication

        let windowInfo = Self.activeWindowInfo(for: frontmostApp)

        return CaptureMetadata(
            timestamp: Date(),
            cursorLocation: cursorLocation,
            screenSize: screenSize,
            foregroundAppName: frontmostApp?.localizedName,
            foregroundBundleIdentifier: frontmostApp?.bundleIdentifier,
            foregroundWindowTitle: windowInfo.title,
            foregroundWindowBounds: windowInfo.bounds,
            textHotspots: []
        )
    }

    private static func activeWindowInfo(for application: NSRunningApplication?) -> (title: String?, bounds: CGRect?) {
        guard let app = application else { return (nil, nil) }
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return (nil, nil)
        }

        let targetPID = app.processIdentifier
        let windowEntry = infoList.first { entry in
            guard let ownerPID = entry[kCGWindowOwnerPID as String] as? pid_t else { return false }
            return ownerPID == targetPID && (entry[kCGWindowLayer as String] as? Int == 0)
        }

        let title = windowEntry?[kCGWindowName as String] as? String
        let bounds = Self.bounds(from: windowEntry)
        return (title, bounds)
    }

    private static func bounds(from entry: [String: Any]?) -> CGRect? {
        guard
            let entry,
            let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
            let x = boundsDict["X"] as? CGFloatConvertible,
            let y = boundsDict["Y"] as? CGFloatConvertible,
            let width = boundsDict["Width"] as? CGFloatConvertible,
            let height = boundsDict["Height"] as? CGFloatConvertible
        else {
            return nil
        }

        return CGRect(x: x.cgFloat, y: y.cgFloat, width: width.cgFloat, height: height.cgFloat)
    }
}

private protocol CGFloatConvertible {
    var cgFloat: CGFloat { get }
}

extension Double: CGFloatConvertible {
    var cgFloat: CGFloat { CGFloat(self) }
}

extension CGFloat: CGFloatConvertible {
    var cgFloat: CGFloat { self }
}

extension Int: CGFloatConvertible {
    var cgFloat: CGFloat { CGFloat(self) }
}
