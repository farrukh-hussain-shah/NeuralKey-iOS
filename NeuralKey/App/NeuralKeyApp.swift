import SwiftUI

@main
struct NeuralKeyApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(appState.keyboardMonitor)
                // The supplied designs are dark-only. The Appearance setting
                // (System / Dark / Light) arrives with Settings in Phase 2.
                .preferredColorScheme(.dark)
                .tint(NKColor.brand)
        }
    }
}
