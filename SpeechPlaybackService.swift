import AVFoundation
import Foundation

@MainActor
final class SpeechPlaybackService: NSObject, AVSpeechSynthesizerDelegate {

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(
        _ text: String,
        languageCode: String
    ) {
        let trimmedText = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedText.isEmpty else {
            return
        }

        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: trimmedText)

        utterance.voice =
            AVSpeechSynthesisVoice(language: languageCode)
            ?? AVSpeechSynthesisVoice(
                language: String(languageCode.prefix(2))
            )

        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.96
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.05

        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
