import AVFoundation
import Foundation
import Translation

@Observable
@MainActor
final class PipelineCoordinator {
    var settings = AppSettings()
    var mode: SessionMode = .listen
    var turn: ConversationTurn = .them
    var isListening = false
    var isPreparingTranslation = false
    var usingOnDeviceSpeech = true
    var route = AudioRouteSnapshot.unknown
    var liveTranscript = ""
    var lastHeard = ""
    var translatedText = ""
    var statusMessage = "Ready"
    var errorMessage: String?
    var packStates: [LanguagePackState] = []
    var translationConfiguration: TranslationSession.Configuration?
    var pendingSourceText: String?

    private let audio = AudioSessionManager()
    private let speech = SpeechRecognitionService()
    private let playback = SpeechPlaybackService()
    private let packs = LanguagePackService()
    private var lastTranslatedSource = ""

    var sourceLanguage: AppLanguage {
        switch (mode, turn) {
        case (.listen, _), (.conversation, .them):
            settings.theirLanguage
        case (.speak, _), (.conversation, .me):
            settings.myLanguage
        }
    }

    var targetLanguage: AppLanguage {
        switch (mode, turn) {
        case (.listen, _), (.conversation, .them):
            settings.myLanguage
        case (.speak, _), (.conversation, .me):
            settings.theirLanguage
        }
    }

    var playbackTarget: AudioPlaybackTarget {
        switch (mode, turn) {
        case (.speak, _), (.conversation, .me):
            .speaker
        default:
            .personal
        }
    }

    var micHint: String {
        switch (mode, turn) {
        case (.listen, _), (.conversation, .them):
            "Point the mic at them"
        case (.speak, _), (.conversation, .me):
            "Speak clearly, then pause"
        }
    }

    init() {
        speech.onPartial = { [weak self] text in
            self?.liveTranscript = text
        }
        speech.onFinal = { [weak self] text in
            self?.handleFinalTranscript(text)
        }
        speech.onError = { [weak self] error in
            self?.errorMessage = error.localizedDescription
            self?.statusMessage = "Speech hiccup — still listening"
        }
        speech.onUsingOnDevice = { [weak self] onDevice in
            self?.usingOnDeviceSpeech = onDevice
        }
        updateRoute()
    }

    func appear() async {
        updateRoute()
        await refreshPacks()
        rebuildTranslationConfiguration()
    }

    func setMode(_ newMode: SessionMode) {
        let wasListening = isListening
        if wasListening { stop() }
        mode = newMode
        if newMode != .conversation { turn = .them }
        liveTranscript = ""
        rebuildTranslationConfiguration()
        if wasListening {
            Task { await start() }
        }
    }

    func setTurn(_ newTurn: ConversationTurn) {
        let wasListening = isListening
        if wasListening { stop() }
        turn = newTurn
        liveTranscript = ""
        rebuildTranslationConfiguration()
        if wasListening {
            Task { await start() }
        }
    }

    func swapLanguages() {
        let wasListening = isListening
        if wasListening { stop() }
        settings.swapLanguages()
        rebuildTranslationConfiguration()
        Task { await refreshPacks() }
        if wasListening {
            Task { await start() }
        }
    }

    func start() async {
        errorMessage = nil
        let allowed = await speech.requestAccess()
        guard allowed else {
            errorMessage = SpeechServiceError.notAuthorized.localizedDescription
            statusMessage = "Permissions needed"
            return
        }

        do {
            try audio.configure(playback: playbackTarget)
            updateRoute()
            try speech.start(
                locale: sourceLanguage.speechLocale,
                requireOnDevice: settings.requireOnDeviceSpeech
            )
            isListening = true
            statusMessage = "Listening · \(sourceLanguage.name) → \(targetLanguage.name)"
        } catch {
            isListening = false
            errorMessage = error.localizedDescription
            statusMessage = "Could not start"
        }
    }

    func stop() {
        speech.stop()
        playback.stop()
        isListening = false
        liveTranscript = ""
        statusMessage = "Paused"
    }

    func toggle() async {
        if isListening {
            stop()
        } else {
            await start()
        }
    }

    func prepareLanguagePacks() {
        isPreparingTranslation = true
        statusMessage = "Downloading translation languages…"
        rebuildTranslationConfiguration()
        translationConfiguration?.invalidate()
    }

    func handle(session: TranslationSession) async {
        do {
            if isPreparingTranslation {
                try await session.prepareTranslation()
                isPreparingTranslation = false
                statusMessage = "Languages ready offline"
                await refreshPacks()
                return
            }

            guard let text = pendingSourceText, !text.isEmpty else { return }
            pendingSourceText = nil
            try await session.prepareTranslation()
            let response = try await session.translate(text)
            translatedText = response.targetText
            statusMessage = "Translated"
            if settings.speakTranslations {
                playback.speak(response.targetText, languageCode: targetLanguage.speechLocaleIdentifier)
            }
        } catch {
            isPreparingTranslation = false
            errorMessage = error.localizedDescription
            statusMessage = "Translation failed"
        }
    }

    func refreshPacks() async {
        packStates = await packs.refresh(myLanguage: settings.myLanguage, theirLanguage: settings.theirLanguage)
    }

    func packLabel(for status: LanguageAvailability.Status) -> String {
        packs.label(for: status)
    }

    private func handleFinalTranscript(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != lastTranslatedSource else { return }
        lastHeard = trimmed
        liveTranscript = ""
        lastTranslatedSource = trimmed
        pendingSourceText = trimmed
        statusMessage = "Translating…"
        if translationConfiguration == nil {
            rebuildTranslationConfiguration()
        } else {
            translationConfiguration?.invalidate()
        }
    }

    func rebuildTranslationConfiguration() {
        translationConfiguration = TranslationSession.Configuration(
            source: sourceLanguage.translationLanguage,
            target: targetLanguage.translationLanguage
        )
    }

    func updateRoute() {
        route = audio.currentRoute()
    }
}
