import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var passcodeStore: PasscodeStore
    @AppStorage("HSAppearanceColorScheme") private var appearanceColorScheme = "system"
    @AppStorage("HSAppearanceTextSize") private var appearanceTextSize = "system"
    @AppStorage("HSPreferredLanguage") private var preferredLanguage = "system"

    var body: some View {
        Group {
            if authStore.session == nil {
                AuthView()
            } else if passcodeStore.isEnabled && passcodeStore.isLocked {
                PasscodeLockView()
            } else {
                MainTabsView()
            }
        }
        .tint(HSTheme.accent)
        .preferredColorScheme(preferredColorScheme)
        .environment(\.locale, preferredLocale)
        .modifier(HSDynamicTypePreferenceModifier(choice: appearanceTextSize))
        .overlay {
            if shouldShowPrivacyCover {
                HSLockedWindowCoverView()
            }
        }
    }

    private var shouldShowPrivacyCover: Bool {
        authStore.session != nil && passcodeStore.isEnabled && scenePhase != .active
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceColorScheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    private var preferredLocale: Locale {
        preferredLanguage == "system" ? .autoupdatingCurrent : Locale(identifier: preferredLanguage)
    }
}

private struct HSDynamicTypePreferenceModifier: ViewModifier {
    let choice: String

    @ViewBuilder
    func body(content: Content) -> some View {
        switch choice {
        case "small":
            content.dynamicTypeSize(.small)
        case "large":
            content.dynamicTypeSize(.large)
        case "xlarge":
            content.dynamicTypeSize(.xLarge)
        case "xxlarge":
            content.dynamicTypeSize(.xxLarge)
        default:
            content
        }
    }
}

private struct HSLockedWindowCoverView: View {
    var body: some View {
        ZStack {
            HSTheme.grouped.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(HSTheme.accent)
                Text("HSgram")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(HSTheme.primaryText)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct MainTabsView: View {
    @State private var selection: HSRootTab = .today

    var body: some View {
        ZStack {
            WorkspaceView()
                .opacity(selection == .today ? 1 : 0)
                .allowsHitTesting(selection == .today)
                .accessibilityHidden(selection != .today)
                .zIndex(selection == .today ? 1 : 0)

            ChatListView()
                .opacity(selection == .chats ? 1 : 0)
                .allowsHitTesting(selection == .chats)
                .accessibilityHidden(selection != .chats)
                .zIndex(selection == .chats ? 1 : 0)

            SettingsView()
                .opacity(selection == .settings ? 1 : 0)
                .allowsHitTesting(selection == .settings)
                .accessibilityHidden(selection != .settings)
                .zIndex(selection == .settings ? 1 : 0)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HSRootTabBar(selection: $selection)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
        }
    }
}

private enum HSRootTab: String, CaseIterable, Identifiable {
    case today
    case chats
    case settings

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .today:
            return "今日"
        case .chats:
            return "聊天"
        case .settings:
            return "设置"
        }
    }

    var icon: String {
        switch self {
        case .today:
            return "person.2"
        case .chats:
            return "bubble.left.and.bubble.right"
        case .settings:
            return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .today:
            return "person.2.fill"
        case .chats:
            return "bubble.left.and.bubble.right.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}

private struct HSRootTabBar: View {
    @Binding var selection: HSRootTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(HSRootTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: selection == tab ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(height: 23)
                        Text(tab.title)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(selection == tab ? HSTheme.accent : HSTheme.RootTab.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(HSTheme.RootTab.selection)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(4)
        .frame(maxWidth: 500)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(HSTheme.RootTab.stroke, lineWidth: 1 / UIScreen.main.scale)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 8)
    }
}
