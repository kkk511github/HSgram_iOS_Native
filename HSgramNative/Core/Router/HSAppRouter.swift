import SwiftUI

enum HSAppTab: String, CaseIterable, Identifiable, Hashable {
    case contacts
    case chats
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .contacts: return "今日"
        case .chats: return "聊天"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .contacts: return "person.2"
        case .chats: return "bubble.left.and.bubble.right"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .contacts: return "person.2.fill"
        case .chats: return "bubble.left.and.bubble.right.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

enum HSRoute: Hashable {
    case chat(UUID)
    case profile(UUID)
    case media(UUID)
    case groupProfile(UUID)
    case groupSettings(UUID)
    case groupMembers(UUID)
    case groupPermissions(UUID)
    case groupInviteLinks(UUID)
    case groupReactionSettings(UUID)
    case groupRemovedUsers(UUID)
    case groupRecentActions(UUID)
    case appearance
    case settingsDetail(SettingsDestination)
}

@MainActor
final class HSAppRouter: ObservableObject {
    @Published var isAuthenticated = false
    @Published var selectedTab: HSAppTab = .chats
    @Published var path = NavigationPath()

    func signIn() {
        isAuthenticated = true
        selectedTab = .chats
        path = NavigationPath()
    }

    func signOut() {
        isAuthenticated = false
        path = NavigationPath()
    }

    func open(_ route: HSRoute) {
        path.append(route)
    }

    func resetToRoot(tab: HSAppTab? = nil) {
        if let tab {
            selectedTab = tab
        }
        path = NavigationPath()
    }
}
