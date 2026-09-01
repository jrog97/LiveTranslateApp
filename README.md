# LiveTranslate

LiveTranslate is an iPhone app that listens to speech, transcribes it, translates it on the device, and shows (and optionally speaks) the result. AirPods are optional: if they are connected, personal translations play in the buds; if not, the iPhone speaker or receiver is used.

It targets **iOS 18+** and uses Apple’s Speech, Translation, and AVFoundation APIs. There is no custom cloud translation backend.

## How a session works

Everything runs through one pipeline:

```
Microphone
    → on-device speech-to-text (Speech framework)
    → Apple Translation (on-device language packs)
    → captions on screen
    → optional spoken translation (AVSpeechSynthesizer)
```

1. You choose a mode (Listen, Speak, or Talk) and two languages: **I speak** and **They speak**.
2. Tapping the mic asks for microphone and speech-recognition permission, then starts `AVAudioEngine`.
3. Partial transcripts stream into the top caption card (marked LIVE).
4. When the recognizer finishes an utterance (a pause), that text is treated as final.
5. SwiftUI’s `.translationTask` receives a `TranslationSession` and translates the final text.
6. The translation appears in the lower caption card. If **Speak translations aloud** is on, the phone speaks it in the target language.
7. Speech recognition restarts so listening can continue until you tap Stop.

`PipelineCoordinator` owns this flow. The UI does not call Speech or Translation directly except for the `translationTask` modifier, which Apple requires for `TranslationSession`.

## Modes

Language direction and where the spoken translation plays depend on the mode.

| Mode | Who is talking | Source → target | Spoken translation plays |
| --- | --- | --- | --- |
| **Listen** | The other person | They speak → I speak | AirPods / receiver (personal) |
| **Speak** | You | I speak → they speak | iPhone **speaker** so they can hear |
| **Talk · They speak** | The other person | Same as Listen | Personal |
| **Talk · I speak** | You | Same as Speak | Speaker |

Talk is turn-taking, not two microphones at once. Switch **They speak** / **I speak** when the conversation changes direction.

The header swap control exchanges “I speak” and “They speak”.

## AirPods and audio routing

AirPods are a playback/capture route, not a separate product mode.

- The audio session is `.playAndRecord` with `.voiceChat`, Bluetooth A2DP/HFP allowed.
- The toolbar pill shows **AirPods**, another Bluetooth headset, or **iPhone**.
- **Listen** and **They speak** do not force the speaker, so connected AirPods stay the output.
- **Speak** and **I speak** override output to the speaker so the other person hears the translation even if you are wearing buds.

The other person does not need the app or AirPods.

## Offline and privacy

**Translation** uses Apple’s Translation framework. After language packs are installed, pairs work without a network. Settings shows each direction of the current pair:

- **On this iPhone** — pack installed
- **Download needed** — pair is supported; tap **Download / prepare pair** (system sheet)
- **Not supported** — Apple does not offer that pair

The first real translation of a pair can also trigger Apple’s download prompt via `prepareTranslation()`.

**Speech** defaults to **On-device speech only**. Audio is not sent to Apple’s servers when that toggle is on. If the locale has no on-device recognizer, start fails until you download the dictation language in iOS Settings or turn the toggle off (network speech).

Spoken output is always on-device (`AVSpeechSynthesizer`).

Settings (languages, on-device speech, speak-aloud) persist in `UserDefaults`.

## Languages

Defined in `LiveTranslate/Models/AppLanguage.swift`. Default pair is English ↔ Spanish.

| Language | Speech locale | Translation id |
| --- | --- | --- |
| English | `en-US` | `en` |
| Spanish | `es-ES` | `es` |
| French | `fr-FR` | `fr` |
| Japanese | `ja-JP` | `ja` |
| Korean | `ko-KR` | `ko` |
| Mandarin | `zh-CN` | `zh-Hans` |
| Russian | `ru-RU` | `ru` |

On-device speech and translation packs are separate. You may need both for a language to work fully offline.

## Permissions

The app requests:

- **Microphone** — capture speech
- **Speech recognition** — transcribe audio

The mic indicator is only on while a session is running. The app is not designed to record silently in the background.

## Project layout

```
LiveTranslate.xcodeproj          Xcode project (iOS 18, Swift 5)
LiveTranslate/
  LiveTranslateApp.swift         App entry; owns PipelineCoordinator
  Models/
    AppLanguage.swift            Supported languages
    SessionMode.swift            Listen / Speak / Talk
    AppSettings.swift            Persisted preferences
  Services/
    PipelineCoordinator.swift    Session state and pipeline
    AudioSessionManager.swift    Play-and-record + AirPods/speaker
    SpeechRecognitionService.swift  Live transcription
    SpeechPlaybackService.swift  Text-to-speech
    LanguagePackService.swift    Translation pack status
  Views/
    RootView.swift               Navigation, translationTask, route updates
    SessionView.swift            Main live UI
    SettingsView.swift           Languages, offline packs, toggles
```

Bundle ID: `app.livetranslate.LiveTranslate`  
Version: `0.1.0`

## Run it

1. Install **Xcode 16+** (full Xcode, not only Command Line Tools).
2. Open `LiveTranslate.xcodeproj`.
3. Select the **LiveTranslate** scheme, your **Team** under Signing & Capabilities, and a connected **iPhone**.
4. Run on a **physical device** with iOS 18 or later.

Apple’s Translation API does not work in Simulator or SwiftUI Previews. Speech and language downloads also need a real iPhone.

On first launch:

1. Allow microphone and speech recognition.
2. Open Settings in the app and set **I speak** / **They speak**.
3. Download the translation pair.
4. If on-device speech fails, install that language under iOS **Settings → General → Keyboard → Dictation** (or disable **On-device speech only**).
5. Tap the mic. Pause after a sentence so a final transcript can translate.

## Limitations

- Not simultaneous two-way audio; Talk is manual turn-taking.
- Quality and latency follow Apple’s recognizer and translator, not a cloud LLM.
- Some language pairs or on-device speech locales may be unavailable on a given device.
- No Apple Watch companion, glossary, or cloud “enhance translation” yet.

## Architecture note

`TranslationSession` is created only inside `.translationTask` on `RootView`. When a final transcript arrives, the coordinator stores the text and calls `invalidate()` on `TranslationSession.Configuration` so that task runs again. That is the supported way to do programmatic translation in iOS 18.
