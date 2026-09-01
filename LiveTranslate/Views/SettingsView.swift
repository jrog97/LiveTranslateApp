import SwiftUI
import Translation

struct SettingsView: View {
    @Bindable var coordinator: PipelineCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Your languages") {
                    Picker("I speak", selection: myLanguage) {
                        ForEach(AppLanguage.supported) { language in
                            Text(language.name).tag(language.id)
                        }
                    }
                    Picker("They speak", selection: theirLanguage) {
                        ForEach(AppLanguage.supported) { language in
                            Text(language.name).tag(language.id)
                        }
                    }
                }

                Section {
                    Toggle("On-device speech only", isOn: onDeviceSpeech)
                    Toggle("Speak translations aloud", isOn: speakTranslations)
                } footer: {
                    Text("On-device speech never leaves the iPhone. AirPods are used automatically when connected. Speak mode always plays from the speaker so the other person can hear.")
                }

                Section("Offline translation") {
                    ForEach(coordinator.packStates) { pack in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(pack.source.name) → \(pack.target.name)")
                                Text(coordinator.packLabel(for: pack.status))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            statusIcon(pack.status)
                        }
                    }
                    Button {
                        coordinator.prepareLanguagePacks()
                    } label: {
                        if coordinator.isPreparingTranslation {
                            Label("Downloading…", systemImage: "arrow.down.circle")
                        } else {
                            Label("Download / prepare pair", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(coordinator.isPreparingTranslation)
                }

                Section("How to use") {
                    labeled("Listen", "They talk. You read and optionally hear the translation in AirPods.")
                    labeled("Speak", "You talk. The phone speaks their language from the speaker.")
                    labeled("Talk", "Switch They speak / I speak as the conversation turns.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await coordinator.refreshPacks()
            }
        }
    }

    private var onDeviceSpeech: Binding<Bool> {
        Binding(
            get: { coordinator.settings.requireOnDeviceSpeech },
            set: { coordinator.settings.requireOnDeviceSpeech = $0 }
        )
    }

    private var speakTranslations: Binding<Bool> {
        Binding(
            get: { coordinator.settings.speakTranslations },
            set: { coordinator.settings.speakTranslations = $0 }
        )
    }

    private var myLanguage: Binding<String> {
        Binding(
            get: { coordinator.settings.myLanguageID },
            set: { newValue in
                coordinator.settings.myLanguageID = newValue
                coordinator.rebuildTranslationConfiguration()
                Task { await coordinator.refreshPacks() }
            }
        )
    }

    private var theirLanguage: Binding<String> {
        Binding(
            get: { coordinator.settings.theirLanguageID },
            set: { newValue in
                coordinator.settings.theirLanguageID = newValue
                coordinator.rebuildTranslationConfiguration()
                Task { await coordinator.refreshPacks() }
            }
        )
    }

    @ViewBuilder
    private func statusIcon(_ status: LanguageAvailability.Status) -> some View {
        switch status {
        case .installed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .supported:
            Image(systemName: "arrow.down.circle").foregroundStyle(.orange)
        case .unsupported:
            Image(systemName: "xmark.circle").foregroundStyle(.red)
        @unknown default:
            Image(systemName: "questionmark.circle")
        }
    }

    private func labeled(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
