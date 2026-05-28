import SwiftUI

struct HSPrototypeRootView: View {
    @StateObject private var router = HSAppRouter()
    @StateObject private var data = HSMockChatService()

    var body: some View {
        ZStack {
            if router.isAuthenticated {
                HSPrototypeMainShell()
            } else {
                HSPrototypeAuthView()
            }
        }
        .environmentObject(router)
        .environmentObject(data)
        .tint(HSPrototypeTheme.accentColor(data.themeConfig))
        .preferredColorScheme(HSPrototypeTheme.preferredScheme(for: data.themeConfig))
    }
}

private struct HSPrototypeMainShell: View {
    @EnvironmentObject private var router: HSAppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack {
                switch router.selectedTab {
                case .chats:
                    HSChatsView()
                case .contacts:
                    HSContactsView()
                case .search:
                    HSGlobalSearchView()
                case .settings:
                    HSSettingsHomeView()
                }
            }
            .navigationDestination(for: HSRoute.self) { route in
                switch route {
                case .chat(let id):
                    HSChatRoomView(conversationID: id)
                case .profile(let id):
                    HSProfileView(userID: id)
                case .media(let id):
                    HSMediaLibraryView(conversationID: id)
                case .appearance:
                    HSAppearanceView()
                case .settingsDetail(let destination):
                    HSSettingsDetailView(destination: destination)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if router.path.isEmpty {
                HSTabBar(selection: $router.selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: router.path.isEmpty)
    }
}
