import Foundation

struct AppConfiguration: Codable {
    var openAIAPIKey: String?
    var openAIModel: String?
    var openAIBaseURL: String?
    var voiceIdentifier: String?
    var voiceRate: Double?
    var voicePitch: Double?
}

final class ConfigurationLoader {
    private let fileManager = FileManager.default
    private let directoryURL: URL
    private let fileURL: URL

    init(directoryName: String = "CursorCompanion") {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let dir = appSupport.appendingPathComponent(directoryName, isDirectory: true)
        directoryURL = dir
        fileURL = dir.appendingPathComponent("config.json", isDirectory: false)
    }

    func load() -> AppConfiguration {
        let environment = ProcessInfo.processInfo.environment
        var config = AppConfiguration(
            openAIAPIKey: environment["OPENAI_API_KEY"],
            openAIModel: environment["OPENAI_MODEL"],
            openAIBaseURL: environment["OPENAI_BASE_URL"],
            voiceIdentifier: environment["VOICE_IDENTIFIER"],
            voiceRate: environment["VOICE_RATE"].flatMap(Double.init),
            voicePitch: environment["VOICE_PITCH"].flatMap(Double.init)
        )

        guard config.openAIAPIKey?.isEmpty != false else {
            // Environment already provided the key; no need to read from disk.
            return config
        }

        do {
            if !fileManager.fileExists(atPath: fileURL.path) {
                return config
            }
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(AppConfiguration.self, from: data)
            if let key = decoded.openAIAPIKey, !(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                config.openAIAPIKey = key
            }
            if config.openAIModel == nil {
                config.openAIModel = decoded.openAIModel
            }
            if config.openAIBaseURL == nil {
                config.openAIBaseURL = decoded.openAIBaseURL
            }
            if config.voiceIdentifier == nil, let voice = decoded.voiceIdentifier, !voice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                config.voiceIdentifier = voice
            }
            if config.voiceRate == nil {
                config.voiceRate = decoded.voiceRate
            }
            if config.voicePitch == nil {
                config.voicePitch = decoded.voicePitch
            }
        } catch {
            Logger.error("Failed to load configuration: \(error.localizedDescription)")
        }

        return config
    }

    func ensureDirectoryExists() {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            Logger.error("Unable to create configuration directory: \(error.localizedDescription)")
        }
    }

    func configurationFileURL() -> URL {
        ensureDirectoryExists()
        return fileURL
    }
}
