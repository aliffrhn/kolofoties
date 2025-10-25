import CoreGraphics
import Foundation

struct CaptureSchedulerConfiguration {
    let minimumInterval: TimeInterval
    let maximumInterval: TimeInterval
    let minimumMovement: CGFloat

    static let `default` = CaptureSchedulerConfiguration(
        minimumInterval: 5,
        maximumInterval: 60,
        minimumMovement: 40
    )
}

final class CaptureScheduler {
    private let configuration: CaptureSchedulerConfiguration
    private var lastCaptureSnapshot: CursorSnapshot?
    private var lastMovementSnapshot: CursorSnapshot?

    init(configuration: CaptureSchedulerConfiguration = .default) {
        self.configuration = configuration
    }

    func register(snapshot: CursorSnapshot) -> Bool {
        defer {
            if let previous = lastMovementSnapshot {
                let distance = hypot(snapshot.location.x - previous.location.x, snapshot.location.y - previous.location.y)
                if distance >= configuration.minimumMovement {
                    lastMovementSnapshot = snapshot
                }
            } else {
                lastMovementSnapshot = snapshot
            }
        }

        guard let lastSnapshot = lastCaptureSnapshot else {
            lastCaptureSnapshot = snapshot
            lastMovementSnapshot = snapshot
            return true
        }

        let elapsed = snapshot.timestamp.timeIntervalSince(lastSnapshot.timestamp)
        if elapsed < configuration.minimumInterval {
            return false
        }

        if let lastMovement = lastMovementSnapshot {
            let distance = hypot(snapshot.location.x - lastMovement.location.x, snapshot.location.y - lastMovement.location.y)
            if distance >= configuration.minimumMovement {
                lastCaptureSnapshot = snapshot
                lastMovementSnapshot = snapshot
                return true
            }
        }

        if configuration.maximumInterval > 0, elapsed >= configuration.maximumInterval {
            lastCaptureSnapshot = snapshot
            return true
        }

        return false
    }

    func reset() {
        lastCaptureSnapshot = nil
        lastMovementSnapshot = nil
    }
}
