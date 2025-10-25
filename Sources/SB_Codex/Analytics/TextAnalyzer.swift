import CoreGraphics
import Foundation
import Vision

final class TextAnalyzer {
    private let request: VNRecognizeTextRequest

    init() {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.03
        self.request = request
    }

    func recognizeText(in image: CGImage, screenRect: CGRect) -> [ScreenHotspot] {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            Logger.warning("Text recognition failed: \(error.localizedDescription)")
            return []
        }

        guard let observations = request.results else { return [] }
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        guard imageWidth > 0, imageHeight > 0 else { return [] }
        let scaleX = screenRect.width / imageWidth
        let scaleY = screenRect.height / imageHeight

        var hotspots: [ScreenHotspot] = []
        hotspots.reserveCapacity(observations.count)

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let confidence = candidate.confidence
            if confidence < 0.4 { continue }

            let box = observation.boundingBox
            let rectInImage = CGRect(
                x: box.minX * imageWidth,
                y: box.minY * imageHeight,
                width: box.width * imageWidth,
                height: box.height * imageHeight
            )

            let screenBounds = CGRect(
                x: screenRect.origin.x + rectInImage.origin.x * scaleX,
                y: screenRect.origin.y + rectInImage.origin.y * scaleY,
                width: rectInImage.width * scaleX,
                height: rectInImage.height * scaleY
            )

            let trimmedText = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { continue }

            hotspots.append(ScreenHotspot(text: trimmedText, bounds: screenBounds, confidence: confidence))
        }

        return hotspots
    }
}
