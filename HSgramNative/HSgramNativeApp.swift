import SwiftUI

@main
struct HSgramNativeApp: App {
    @StateObject private var authStore = AuthStore(api: .shared)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authStore)
        }
    }
}

