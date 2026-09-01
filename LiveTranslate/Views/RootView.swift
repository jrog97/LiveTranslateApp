import AVFoundation
import SwiftUI
import Translation

struct RootView: View {
    @Bindable var coordinator: PipelineCoordinator
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            SessionView(coordinator: coordinator)
                .navigationTitle("LiveTranslate")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        RoutePill(route: coordinator.route)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView(coordinator: coordinator)
                }
                .translationTask(coordinator.translationConfiguration) { session in
                    await coordinator.handle(session: session)
                }
                .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
                    coordinator.updateRoute()
                }
                .task {
                    await coordinator.appear()
                }
        }
    }
}

#Preview {
    RootView(coordinator: PipelineCoordinator())
        .preferredColorScheme(.dark)
}
