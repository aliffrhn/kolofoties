import Foundation

struct LocalAIProvider: AIProvider, Sendable {
    func sendContext(imageData: Data, metadata: CaptureMetadata) async throws -> AIResponse {
        let hint = metadata.contextualHint()?.replacingOccurrences(of: "\n", with: " · ") ?? "not much on screen right now, but you’ve got this."
        let message = "Mock mode — if I could see it I’d toss a quick little reaction like a buddy. Maybe glance at \(hint)."
        return AIResponse(text: message, usage: nil)
    }
}
