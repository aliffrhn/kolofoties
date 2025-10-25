import AVFoundation
import Foundation

@MainActor
final class VoiceOutput: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var voice: AVSpeechSynthesisVoice?
    private var rate: Float = 0.47
    private var pitch: Float = 1.05

    private(set) var isEnabled: Bool = true
    enum SpeechState {
        case started
        case finished
        case cancelled
    }

    var speechStateHandler: ((SpeechState) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
        voice = chooseVoice(identifier: nil)
    }

    func configure(voiceIdentifier: String?, rate: Double?, pitch: Double?) {
        let resolvedVoice = chooseVoice(identifier: voiceIdentifier)
        if let identifier = voiceIdentifier, resolvedVoice == nil {
            Logger.warning("Requested voice identifier '\(identifier)' not available. Falling back to best match.")
        }
        voice = resolvedVoice
        if let rate {
            self.rate = Self.clamp(Float(rate), min: 0.2, max: 0.7)
        }
        if let pitch {
            self.pitch = Self.clamp(Float(pitch), min: 0.5, max: 2.0)
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    func speak(_ text: String) {
        guard isEnabled else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice ?? chooseVoice(identifier: nil)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.preUtteranceDelay = 0.02
        utterance.postUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    var currentVoiceDescription: String {
        if let voice {
            return "\(voice.name) (\(voice.language))"
        }
        return "System default"
    }

    private func chooseVoice(identifier: String?) -> AVSpeechSynthesisVoice? {
        if let identifier, let customVoice = AVSpeechSynthesisVoice(identifier: identifier) {
            return customVoice
        }

        let voices = AVSpeechSynthesisVoice.speechVoices()
        guard !voices.isEmpty else { return nil }

        let locale = Locale.current
        var languageCandidates: [String] = []
        languageCandidates.append(locale.identifier)
        if let languageCode = locale.language.languageCode?.identifier {
            languageCandidates.append(languageCode)
        } else if let legacyCode = locale.languageCode {
            languageCandidates.append(legacyCode)
        }
        languageCandidates.append(contentsOf: ["en-US", "en-GB"])

        let qualityPreference: [AVSpeechSynthesisVoiceQuality] = [.premium, .enhanced, .default]

        for language in languageCandidates {
            for quality in qualityPreference {
                if let match = voices.first(where: { $0.language == language && $0.quality == quality }) {
                    return match
                }
            }
        }

        for quality in qualityPreference {
            if let match = voices.first(where: { $0.quality == quality }) {
                return match
            }
        }

        return voices.first
    }

    private static func clamp(_ value: Float, min: Float, max: Float) -> Float {
        Swift.max(min, Swift.min(max, value))
    }
}

extension VoiceOutput: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.speechStateHandler?(.started)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.speechStateHandler?(.finished)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.speechStateHandler?(.cancelled)
        }
    }
}
