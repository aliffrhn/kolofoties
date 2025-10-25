import Foundation

enum Logger {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    static func info(_ message: String) {
        log(prefix: "INFO", message: message)
    }

    static func warning(_ message: String) {
        log(prefix: "WARN", message: message)
    }

    static func error(_ message: String) {
        log(prefix: "ERROR", message: message)
    }

    private static func log(prefix: String, message: String) {
        let timestamp = formatter.string(from: Date())
        print("[\(timestamp)] [\(prefix)] \(message)")
    }
}
