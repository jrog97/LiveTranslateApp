import SwiftUI

@main
struct LiveTranslateApp: App {
    @State private var coordinator = PipelineCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
                .preferredColorScheme(.dark)
        }
    }
}
