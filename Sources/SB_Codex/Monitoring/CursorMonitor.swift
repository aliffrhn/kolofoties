import AppKit

struct CursorSnapshot {
    let location: CGPoint
    let timestamp: Date
}

extension CursorSnapshot: Sendable {}

final class CursorMonitor {
    typealias SnapshotHandler = @Sendable (CursorSnapshot) -> Void

    private let queue = DispatchQueue(label: "cursor.monitor.queue")
    private var timer: DispatchSourceTimer?
    private let pollInterval: TimeInterval
    private let handler: SnapshotHandler

    init(pollInterval: TimeInterval = 0.5, handler: @escaping SnapshotHandler) {
        self.pollInterval = pollInterval
        self.handler = handler
    }

    func start() {
        stop()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: pollInterval)
        timer.setEventHandler { [weak self] in
            self?.emitSnapshot()
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func emitSnapshot() {
        let location = NSEvent.mouseLocation
        let snapshot = CursorSnapshot(location: location, timestamp: Date())
        let handler = self.handler
        DispatchQueue.main.async {
            handler(snapshot)
        }
    }
}
