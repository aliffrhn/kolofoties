import Foundation

struct OpenAIProvider: AIProvider, Sendable {
    private let apiKey: String
    private let model: String
    private let baseURL: URL
    private let session: URLSession

    init(apiKey: String, model: String = "gpt-4o-mini", baseURL: URL = URL(string: "https://api.openai.com/v1")!, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.session = session
    }

    func sendContext(imageData: Data, metadata: CaptureMetadata) async throws -> AIResponse {
        let base64Image = imageData.base64EncodedString()
        var contentItems: [OpenAIMessage.OpenAIContent] = [
            .text("New screenshot. React like their laid-back friend in 1–2 sentences (under ~35 words). Keep it natural, focus on what actually looks new, and only use an emoji when it genuinely adds something.")
        ]
        if let hint = metadata.contextualHint() {
            contentItems.append(.text(hint))
        }
        let imageContent = OpenAIMessage.OpenAIContent.imageData("data:image/png;base64,\(base64Image)")
        contentItems.append(imageContent)

        let systemPrompt = """
        You are the user’s relaxed friend — warm, observant, conversational. Reply in at most two sentences and stay under 35 words. Make every response feel fresh: avoid recycled phrases, skip filler, and speak like a real person who just glanced at the screen. Trust the image above all else; treat hints as optional and ignore anything that doesn’t match what you see. Do not mention capture mechanics or old apps unless they are visibly present right now. Default to zero emojis; if you absolutely need one, use no more than a single emoji and make sure it earns its spot.
        """

        let requestPayload = OpenAIChatRequest(
            model: model,
            messages: [
                OpenAIMessage(role: "system", content: [.text(systemPrompt)]),
                OpenAIMessage(role: "user", content: contentItems)
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let body = try encoder.encode(requestPayload)

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIProviderError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "<unreadable>"
                throw AIProviderError.httpError(statusCode: httpResponse.statusCode, body: errorMessage)
            }

            let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            guard let message = decoded.choices.first?.message.content else {
                throw AIProviderError.invalidResponse
            }

            return AIResponse(text: message.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw AIProviderError.transportError(message: error.localizedDescription)
        }
    }
}

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
}

private struct OpenAIMessage: Encodable {
    let role: String
    let content: [OpenAIContent]

    enum OpenAIContent: Encodable {
        case text(String)
        case imageData(String)

        private enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let value):
                try container.encode("text", forKey: .type)
                try container.encode(value, forKey: .text)
            case .imageData(let urlString):
                try container.encode("image_url", forKey: .type)
                try container.encode(OpenAIImageURL(url: urlString), forKey: .imageURL)
            }
        }
    }
}

private struct OpenAIImageURL: Encodable {
    let url: String
}

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }

    let choices: [Choice]
}
