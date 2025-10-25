import Foundation

struct AIResponse: Sendable {
    let text: String
}

enum AIProviderError: Error, Sendable {
    case missingAPIKey
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case transportError(message: String)
}

extension AIProviderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing. Set OPENAI_API_KEY and restart."
        case .invalidResponse:
            return "AI provider returned an unexpected response."
        case .httpError(let statusCode, let body):
            return "HTTP \(statusCode): \(body)"
        case .transportError(let message):
            return message
        }
    }
}

protocol AIProvider: Sendable {
    func sendContext(imageData: Data, metadata: CaptureMetadata) async throws -> AIResponse
}
