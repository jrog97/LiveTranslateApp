import SwiftUI

struct SessionView: View {
    @Bindable var coordinator: PipelineCoordinator

    var body: some View {
        VStack(spacing: 20) {
            ModePicker(mode: coordinator.mode) { mode in
                coordinator.setMode(mode)
            }

            LanguageBar(
                source: coordinator.sourceLanguage,
                target: coordinator.targetLanguage,
                onSwap: { coordinator.swapLanguages() }
            )

            if coordinator.mode == .conversation {
                ConversationTurnPicker(turn: coordinator.turn) { turn in
                    coordinator.setTurn(turn)
                }
            }

            CaptionCard(
                title: coordinator.sourceLanguage.name,
                text: coordinator.liveTranscript.isEmpty ? coordinator.lastHeard : coordinator.liveTranscript,
                placeholder: coordinator.isListening ? "Listening…" : "Tap the mic to start",
                isLive: !coordinator.liveTranscript.isEmpty
            )

            CaptionCard(
                title: coordinator.targetLanguage.name,
                text: coordinator.translatedText,
                placeholder: "Translation appears here",
                isLive: false,
                emphasized: true
            )

            Spacer(minLength: 0)

            statusRow

            MicButton(
                isListening: coordinator.isListening,
                title: coordinator.isListening ? "Stop" : "Start",
                hint: coordinator.micHint
            ) {
                Task { await coordinator.toggle() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Color.black.ignoresSafeArea())
    }

    private var statusRow: some View {
        VStack(spacing: 6) {
            if let errorMessage = coordinator.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 8) {
                Circle()
                    .fill(coordinator.usingOnDeviceSpeech ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(coordinator.statusMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(coordinator.usingOnDeviceSpeech ? "On-device speech" : "Network speech")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

struct ModePicker: View {
    let mode: SessionMode
    let onSelect: (SessionMode) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(SessionMode.allCases) { item in
                Button {
                    onSelect(item)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(mode == item ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.06))
                    .foregroundStyle(mode == item ? Color.white : Color.white.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct LanguageBar: View {
    let source: AppLanguage
    let target: AppLanguage
    let onSwap: () -> Void

    var body: some View {
        HStack {
            languageName(source)
            Spacer()
            Button(action: onSwap) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.body.weight(.semibold))
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Swap languages")
            Spacer()
            languageName(target)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 4)
    }

    private func languageName(_ language: AppLanguage) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(language.nativeName)
                .font(.headline)
            Text(language.name)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: 120)
    }
}

struct ConversationTurnPicker: View {
    let turn: ConversationTurn
    let onSelect: (ConversationTurn) -> Void

    var body: some View {
        HStack(spacing: 8) {
            turnButton(.them)
            turnButton(.me)
        }
    }

    private func turnButton(_ value: ConversationTurn) -> some View {
        Button {
            onSelect(value)
        } label: {
            Text(value.label)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(turn == value ? Color.accentColor : Color.white.opacity(0.08))
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CaptionCard: View {
    let title: String
    let text: String
    let placeholder: String
    var isLive: Bool = false
    var emphasized: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.45))
                if isLive {
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                }
            }
            Text(text.isEmpty ? placeholder : text)
                .font(emphasized ? .title3.weight(.semibold) : .body)
                .foregroundStyle(text.isEmpty ? .white.opacity(0.35) : .white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.15), value: text)
        }
        .padding(16)
        .frame(minHeight: 112, alignment: .topLeading)
        .background(Color.white.opacity(emphasized ? 0.1 : 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct MicButton: View {
    let isListening: Bool
    let title: String
    let hint: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(isListening ? Color.red.opacity(0.9) : Color.accentColor)
                        .frame(width: 84, height: 84)
                        .shadow(color: (isListening ? Color.red : Color.accentColor).opacity(0.4), radius: 16)
                    Image(systemName: isListening ? "stop.fill" : "mic.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }
            .accessibilityLabel(title)
            Text(hint)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

struct RoutePill: View {
    let route: AudioRouteSnapshot

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: route.isAirPods ? "airpods" : (route.isBluetooth ? "headphones" : "iphone"))
            Text(route.displayName)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .foregroundStyle(.white.opacity(0.85))
    }
}
