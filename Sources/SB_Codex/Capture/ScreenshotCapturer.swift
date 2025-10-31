import AppKit
import CoreGraphics

struct ScreenshotArtifact: Sendable {
    let image: CGImage
    let pngData: Data
    let pixelSize: CGSize
    let screenRect: CGRect
}

enum ScreenshotError: Error {
    case captureFailed
    case encodingFailed
}

final class ScreenshotCapturer {
    private let defaultDisplayID: CGDirectDisplayID
    private let cropSize: CGSize?

    init(displayID: CGDirectDisplayID = CGMainDisplayID(), cropSize: CGSize? = CGSize(width: 900, height: 650)) {
        self.defaultDisplayID = displayID
        self.cropSize = cropSize
    }

    func capture(around location: CGPoint, screenSize: CGSize, scale: CGFloat) throws -> ScreenshotArtifact {
        let screen = NSScreen.screens.first { NSPointInRect(location, $0.frame) } ?? NSScreen.main
        let resolvedDisplayID = screen?
            .deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let displayID = resolvedDisplayID.map { CGDirectDisplayID($0.uint32Value) } ?? defaultDisplayID

        guard let cgImage = CGDisplayCreateImage(displayID) else {
            throw ScreenshotError.captureFailed
        }

        let screenFrame = screen?.frame ?? CGRect(origin: .zero, size: screenSize)
        let screenScale = screen?.backingScaleFactor ?? scale

        let desiredSize: CGSize
        if let cropSize {
            desiredSize = CGSize(
                width: min(cropSize.width, screenFrame.width),
                height: min(cropSize.height, screenFrame.height)
            )
        } else {
            desiredSize = screenFrame.size
        }

        var screenRect = CGRect(
            x: location.x - desiredSize.width / 2,
            y: location.y - desiredSize.height / 2,
            width: desiredSize.width,
            height: desiredSize.height
        )

        if screenRect.minX < screenFrame.minX {
            screenRect.origin.x = screenFrame.minX
        }
        if screenRect.maxX > screenFrame.maxX {
            screenRect.origin.x = screenFrame.maxX - screenRect.width
        }
        if screenRect.minY < screenFrame.minY {
            screenRect.origin.y = screenFrame.minY
        }
        if screenRect.maxY > screenFrame.maxY {
            screenRect.origin.y = screenFrame.maxY - screenRect.height
        }

        let cropRect = CGRect(
            x: (screenRect.origin.x - screenFrame.minX) * screenScale,
            y: (screenFrame.maxY - screenRect.maxY) * screenScale,
            width: screenRect.width * screenScale,
            height: screenRect.height * screenScale
        )

        let croppedImage = cgImage.cropping(to: cropRect) ?? cgImage

        let bitmap = NSBitmapImageRep(cgImage: croppedImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotError.encodingFailed
        }

        return ScreenshotArtifact(
            image: croppedImage,
            pngData: data,
            pixelSize: CGSize(width: croppedImage.width, height: croppedImage.height),
            screenRect: screenRect
        )
    }
}
