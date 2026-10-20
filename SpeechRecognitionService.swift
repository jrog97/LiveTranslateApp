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
            return "Speech recognition is not available for this language on this device."

        case .onDeviceUnavailable:
            return "On-device speech recognition is not available for this language. Download the required language resources in Settings, or allow network speech."

        case .notAuthorized:
            return "Microphone or speech recognition permission is missing."

        case .engineFailed(let message):
            return message
        }
    }
}

final class SpeechRecognitionService {

    // MARK: - Callbacks

    var onPartial: (@MainActor (String) -> Void)?
    var onFinal: (@MainActor (String) -> Void)?
    var onError: (@MainActor (Error) -> Void)?
    var onUsingOnDevice: (@MainActor (Bool) -> Void)?

    // MARK: - Audio and Recognition

    private let audioEngine = AVAudioEngine()

    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    private var shouldKeepListening = false

    private var locale = Locale(identifier: "en-US")
    private var requireOnDevice = true

    // MARK: - Permissions

    func requestAccess() async -> Bool {
        let microphoneGranted =
            await AVAudioApplication.requestRecordPermission()

        guard microphoneGranted else {
            return false
        }

        let speechStatus: SFSpeechRecognizerAuthorizationStatus =
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }

        return speechStatus == .authorized
    }

    // MARK: - Start

    func start(
        locale: Locale,
        requireOnDevice: Bool
    ) throws {
        stop()

        self.locale = locale
        self.requireOnDevice = requireOnDevice
        shouldKeepListening = true

        do {
            try beginSession()
        } catch {
            shouldKeepListening = false
            throw error
        }
    }

    // MARK: - Stop

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

    // MARK: - Begin Recognition Session

    private func beginSession() throws {
        guard
            let recognizer = SFSpeechRecognizer(locale: locale),
            recognizer.isAvailable
        else {
            throw SpeechServiceError.recognizerUnavailable
        }

        self.recognizer = recognizer

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

        Task { @MainActor [weak self] in
            self?.onUsingOnDevice?(onDevice)
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.removeTap(onBus: 0)

        input.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()

        if !audioEngine.isRunning {
            try audioEngine.start()
        }

        task = recognizer.recognitionTask(with: request) {
            [weak self] result, error in

            self?.handleRecognition(
                result: result,
                error: error
            )
        }
    }

    // MARK: - Handle Recognition Results

    private func handleRecognition(
        result: SFSpeechRecognitionResult?,
        error: Error?
    ) {
        if let result {
            let text = result.bestTranscription.formattedString

            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

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

            let cancelled =
                (
                    nsError.domain == "kAFAssistantErrorDomain"
                    && nsError.code == 216
                )
                || nsError.code == 301

            if shouldKeepListening && !cancelled {
                Task { @MainActor [weak self] in
                    self?.onError?(error)
                }
            }

            restartIfNeeded()
        }
    }

    // MARK: - Restart Recognition

    private func restartIfNeeded() {
        guard shouldKeepListening else {
            return
        }

        task?.cancel()
        task = nil

        request?.endAudio()
        request = nil

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.35
        ) { [weak self] in

            guard
                let self,
                self.shouldKeepListening
            else {
                return
            }

            do {
                try self.beginSession()
            } catch {
                self.shouldKeepListening = false

                Task { @MainActor [weak self] in
                    self?.onError?(error)
                }
            }
        }
    }
}
