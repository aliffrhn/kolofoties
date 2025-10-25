import Foundation

actor AIOrchestrator {
    private let provider: any AIProvider

    init(provider: any AIProvider) {
        self.provider = provider
    }

    func requestCommentary(for artifact: ScreenshotArtifact, metadata: CaptureMetadata) async throws -> AIResponse {
        try await provider.sendContext(imageData: artifact.pngData, metadata: metadata)
    }
}
