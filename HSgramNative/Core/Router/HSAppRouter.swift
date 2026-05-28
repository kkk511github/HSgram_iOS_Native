import SwiftUI

enum HSAppTab: String, CaseIterable, Identifiable, Hashable {
    case chats
    case contacts
    case search
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chats: return "聊天"
        case .contacts: return "联系人"
        case .search: return "搜索"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .chats: return "bubble.left.and.bubble.right"
        case .contacts: return "person.2"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .chats: return "bubble.left.and.bubble.right.fill"
        case .contacts: return "person.2.fill"
        case .search: return "magnifyingglass.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

enum HSRoute: Hashable {
    case chat(UUID)
    case profile(UUID)
    case media(UUID)
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
