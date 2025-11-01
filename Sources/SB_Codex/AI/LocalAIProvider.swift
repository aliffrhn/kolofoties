import Foundation

struct LocalAIProvider: AIProvider, Sendable {
    func sendContext(imageData: Data, metadata: CaptureMetadata, mode: InteractionMode) async throws -> AIResponse {
        let hint = metadata.contextualHint()?.replacingOccurrences(of: "\n", with: " · ") ?? "not much on screen right now, but you’ve got this."
        let message: String
        switch mode {
        case .casual:
            message = "Mock mode — if I could see it I’d toss a quick little reaction like a buddy. Maybe glance at \(hint)."
        case .focus:
            message = "Mock focus mode: I’d highlight one useful action around \(hint)."
        case .accessibility:
            message = "Mock accessibility mode: I’d describe the visible screen so voiceover has context. Picture something near \(hint)."
        }
        return AIResponse(text: message, usage: nil)
    }
}
