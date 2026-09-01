import AVFoundation
import Foundation
import Speech

enum SpeechServiceError: LocalizedError {
    case recognizerUnavailable
    case onDeviceUnavailable
    case notAuthorized
    case engineFailed(String)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            "Speech recognition is not available for this language on this device."
        case .onDeviceUnavailable:
            "On-device speech is not installed for this language. Download it in Settings, or allow network speech."
        case .notAuthorized:
            "Microphone or speech recognition permission is missing."
        case .engineFailed(let message):
            message
        }
    }
}

final class SpeechRecognitionService {
    var onPartial: (@MainActor (String) -> Void)?
    var onFinal: (@MainActor (String) -> Void)?
    var onError: (@MainActor (Error) -> Void)?
    var onUsingOnDevice: (@MainActor (Bool) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var shouldKeepListening = false
    private var locale = Locale(identifier: "en-US")
    private var requireOnDevice = true

    func requestAccess() async -> Bool {
        let mic = await AVAudioApplication.requestRecordPermission()
        guard mic else { return false }

        let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        return speech == .authorized
    }

    func start(locale: Locale, requireOnDevice: Bool) throws {
        stop()
        self.locale = locale
        self.requireOnDevice = requireOnDevice
        shouldKeepListening = true
        try beginSession()
    }

    func stop() {
        shouldKeepListening = false
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
    }

    private func beginSession() throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SpeechServiceError.recognizerUnavailable
        }
        self.recognizer = recognizer

        let useOnDevice = requireOnDevice || recognizer.supportsOnDeviceRecognition
        if requireOnDevice && !recognizer.supportsOnDeviceRecognition {
            throw SpeechServiceError.onDeviceUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = requireOnDevice
        }
        self.request = request

        let onDevice = request.requiresOnDeviceRecognition
        Task { @MainActor in
            self.onUsingOnDevice?(onDevice)
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        if !audioEngine.isRunning {
            try audioEngine.start()
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognition(result: result, error: error)
        }
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            let text = result.bestTranscription.formattedString
            Task { @MainActor in
                if result.isFinal {
                    self.onFinal?(text)
                } else {
                    self.onPartial?(text)
                }
            }
            if result.isFinal {
                restartIfNeeded()
            }
        }

        if let error {
            let nsError = error as NSError
            let cancelled = nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216
                || nsError.code == 301
            if shouldKeepListening, !cancelled {
                Task { @MainActor in
                    self.onError?(error)
                }
            }
            restartIfNeeded()
        }
    }

    private func restartIfNeeded() {
        guard shouldKeepListening else { return }
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.shouldKeepListening else { return }
            do {
                try self.beginSession()
            } catch {
                Task { @MainActor in
                    self.onError?(error)
                }
            }
        }
    }
}
