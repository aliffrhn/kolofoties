import AppKit
import ApplicationServices
import CoreGraphics

struct PermissionStatus {
    let screenRecordingGranted: Bool
    let accessibilityGranted: Bool

    var allGranted: Bool {
        screenRecordingGranted && accessibilityGranted
    }
}

@MainActor
final class PermissionManager {
    func currentStatus() -> PermissionStatus {
        PermissionStatus(
            screenRecordingGranted: CGPreflightScreenCaptureAccess(),
            accessibilityGranted: AXIsProcessTrusted()
        )
    }

    @discardableResult
    func requestMissingPermissions() -> PermissionStatus {
        let screenGranted: Bool
        if CGPreflightScreenCaptureAccess() {
            screenGranted = true
        } else {
            screenGranted = CGRequestScreenCaptureAccess()
            if !screenGranted {
                Logger.warning("Screen recording permission denied or pending user approval.")
            }
        }

        let accessibilityGranted = requestAccessibilityPermissionIfNeeded()

        return PermissionStatus(
            screenRecordingGranted: screenGranted,
            accessibilityGranted: accessibilityGranted
        )
    }

    private func requestAccessibilityPermissionIfNeeded() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let options = [NSString(string: "AXTrustedCheckOptionPrompt"): NSNumber(value: true)] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            Logger.warning("Accessibility permission denied or pending user approval.")
        }
        return trusted
    }
}
