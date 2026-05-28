import SwiftUI

@main
struct HSgramNativeApp: App {
    @UIApplicationDelegateAdaptor(HSAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authStore = AuthStore(api: .shared)
    @StateObject private var syncStore = HSSyncStore(api: .shared)
    @StateObject private var passcodeStore = PasscodeStore()
    @StateObject private var notificationPushStore = NotificationPushStore(api: .shared)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authStore)
                .environmentObject(syncStore)
                .environmentObject(passcodeStore)
                .environmentObject(notificationPushStore)
                .task {
                    syncStore.start(session: authStore.session)
                }
                .onChange(of: authStore.session) { session in
                    if scenePhase == .active {
                        syncStore.start(session: session)
                    } else {
                        syncStore.stop()
                    }
                }
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        passcodeStore.resumeActive()
                        syncStore.start(session: authStore.session)
                        Task {
                            _ = try? HSMediaCacheStore.shared.applyAutomaticEviction()
                            await notificationPushStore.refreshAuthorizationStatus()
                            await notificationPushStore.syncRegistration(
                                session: authStore.session,
                                savedAccounts: authStore.savedAccounts
                            )
                            notificationPushStore.clearBadge()
                        }
                    case .inactive, .background:
                        syncStore.stop()
                        passcodeStore.noteInactive()
                    @unknown default:
                        break
                    }
                }
        }
    }
}
