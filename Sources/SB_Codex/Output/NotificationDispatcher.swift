import Foundation
import UserNotifications

final class NotificationDispatcher: NSObject, UNUserNotificationCenterDelegate {
    private var center: UNUserNotificationCenter?
    private var authorizationRequested = false

    func configure() {
        guard !authorizationRequested else { return }
        authorizationRequested = true
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            Logger.warning("Notification center disabled: app is not running from a bundled .app (bundleURL=\(Bundle.main.bundleURL)).")
            center = nil
            authorizationRequested = false
            return
        }
        let center = UNUserNotificationCenter.current()
        self.center = center
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                Logger.error("Notification authorization error: \(error.localizedDescription)")
            } else {
                Logger.info("Notification authorization granted: \(granted)")
            }
        }
    }

    func deliver(body: String) {
        guard let center, Bundle.main.bundleURL.pathExtension == "app" else {
            Logger.warning("Skipping notification delivery; app is not running from a bundled .app.")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Cursor Companion"
        content.body = body
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request) { error in
            if let error {
                Logger.error("Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
