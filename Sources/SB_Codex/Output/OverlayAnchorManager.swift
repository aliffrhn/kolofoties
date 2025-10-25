import AppKit

final class OverlayAnchorManager {
    private let normalizedAnchors: [CGPoint] = [
        CGPoint(x: 0.25, y: 0.75),
        CGPoint(x: 0.75, y: 0.75),
        CGPoint(x: 0.5, y: 0.55),
        CGPoint(x: 0.25, y: 0.35),
        CGPoint(x: 0.75, y: 0.35)
    ]

    private var lastAnchorIndex: Int?
    private var rotationIndex: Int = 0
    private var lastAnchorCenter: CGPoint?

    func nextAnchor(bubbleSize: CGSize, cursorLocation: CGPoint?, focusRect: CGRect?, hotspots: [ScreenHotspot]) -> CGPoint {
        if let hotspotPoint = hotspotAnchor(bubbleSize: bubbleSize, hotspots: hotspots) {
            lastAnchorCenter = hotspotPoint.center
            return hotspotPoint.origin
        }

        if let focusRect, let point = focusBasedAnchor(bubbleSize: bubbleSize, focusRect: focusRect) {
            lastAnchorCenter = CGPoint(x: point.x + bubbleSize.width / 2, y: point.y + bubbleSize.height / 2)
            return point
        }

        guard let screen = visibleFrame(for: cursorLocation) else {
            return CGPoint(x: 60, y: 60)
        }

        let centers = normalizedAnchors.map { normalized in
            CGPoint(
                x: screen.minX + normalized.x * screen.width,
                y: screen.minY + normalized.y * screen.height
            )
        }

        let chosenIndex: Int
        if let cursor = cursorLocation {
            var bestIndex: Int?
            var bestDistance: CGFloat = -CGFloat.infinity
            for (index, center) in centers.enumerated() {
                let dx = center.x - cursor.x
                let dy = center.y - cursor.y
                let distance = dx * dx + dy * dy
                if distance > bestDistance && index != lastAnchorIndex {
                    bestDistance = distance
                    bestIndex = index
                }
            }
            chosenIndex = bestIndex ?? rotationIndex
        } else {
            chosenIndex = rotationIndex
        }

        rotationIndex = (chosenIndex + 1) % centers.count
        lastAnchorIndex = chosenIndex

        let origin = convertToOrigin(centers[chosenIndex], bubbleSize: bubbleSize, jitter: true)
        lastAnchorCenter = CGPoint(x: origin.x + bubbleSize.width / 2, y: origin.y + bubbleSize.height / 2)
        return origin
    }

    private func hotspotAnchor(bubbleSize: CGSize, hotspots: [ScreenHotspot]) -> (origin: CGPoint, center: CGPoint)? {
        guard !hotspots.isEmpty else { return nil }
        let sorted = hotspots.sorted { lhs, rhs in
            if abs(lhs.confidence - rhs.confidence) > 0.05 {
                return lhs.confidence > rhs.confidence
            }
            return lhs.bounds.width * lhs.bounds.height > rhs.bounds.width * rhs.bounds.height
        }

        for hotspot in sorted.prefix(5) {
            let center = CGPoint(x: hotspot.bounds.midX, y: hotspot.bounds.midY)
            if let last = lastAnchorCenter, distanceSquared(center, to: last) < 40_000 {
                continue
            }
            let origin = convertToOrigin(center, bubbleSize: bubbleSize, jitter: true)
            return (origin, CGPoint(x: origin.x + bubbleSize.width / 2, y: origin.y + bubbleSize.height / 2))
        }

        return nil
    }

    private func focusBasedAnchor(bubbleSize: CGSize, focusRect: CGRect) -> CGPoint? {
        let candidates = focusAnchorCenters(for: focusRect)
        let filtered = candidates.sorted { lhs, rhs in
            guard let last = lastAnchorCenter else { return true }
            let lhsDist = distanceSquared(lhs, to: last)
            let rhsDist = distanceSquared(rhs, to: last)
            return lhsDist > rhsDist
        }
        if let candidate = filtered.first {
            return convertToOrigin(candidate, bubbleSize: bubbleSize, jitter: true)
        }
        return nil
    }

    private func focusAnchorCenters(for rect: CGRect) -> [CGPoint] {
        let offset: CGFloat = 72
        return [
            CGPoint(x: rect.maxX + offset, y: rect.midY),
            CGPoint(x: rect.midX, y: rect.maxY + offset),
            CGPoint(x: rect.minX - offset, y: rect.midY),
            CGPoint(x: rect.midX, y: rect.minY - offset)
        ]
    }

    private func convertToOrigin(_ center: CGPoint, bubbleSize: CGSize, jitter: Bool) -> CGPoint {
        var origin = CGPoint(
            x: center.x - (bubbleSize.width / 2),
            y: center.y - (bubbleSize.height / 2)
        )

        if jitter {
            let jitterRange: ClosedRange<CGFloat> = -16...16
            origin.x += CGFloat.random(in: jitterRange)
            origin.y += CGFloat.random(in: jitterRange)
        }

        return origin
    }

    private func visibleFrame(for point: CGPoint?) -> NSRect? {
        if let point {
            if let screen = NSScreen.screens.first(where: { NSPointInRect(point, $0.frame) }) {
                return screen.visibleFrame
            }
        }
        return NSScreen.main?.visibleFrame
    }

    private func distanceSquared(_ center: CGPoint, to previousCenter: CGPoint) -> CGFloat {
        let dx = center.x - previousCenter.x
        let dy = center.y - previousCenter.y
        return dx * dx + dy * dy
    }
}
