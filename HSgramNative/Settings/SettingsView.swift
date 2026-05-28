import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        NavigationStack {
            List {
                if let session = authStore.session {
                    Section {
                        NavigationLink {
                            ProfileSettingsView()
                        } label: {
                            HStack(spacing: 12) {
                                HSClassicAvatar(title: session.displayName, icon: "person.fill", tint: HSTheme.accent, size: 60)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.displayName)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(HSTheme.primaryText)
                                    Text(session.email)
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundStyle(HSTheme.secondaryText)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if !authStore.savedAccounts.isEmpty {
                    Section("账号列表") {
                        ForEach(authStore.savedAccounts, id: \.userID) { account in
                            Button {
                                authStore.switchAccount(userID: account.userID)
                            } label: {
                                SettingsAccountRow(
                                    account: account,
                                    isCurrent: account.userID == authStore.session?.userID
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(account.userID == authStore.session?.userID)
                        }

                        Button {
                            authStore.beginAddingAccount()
                        } label: {
                            Label("添加另一个账号", systemImage: "person.crop.circle.badge.plus")
                        }
                    }
                }

                Section("账号") {
                    NavigationLink {
                        TrustCenterView()
                    } label: {
                        Label("信任中心", systemImage: "checkmark.shield")
                    }
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        Label("隐私和安全", systemImage: "hand.raised")
                    }
                }

                Section("沟通入口") {
                    NavigationLink {
                        SavedMessagesDestinationView()
                    } label: {
                        Label("收藏夹", systemImage: "bookmark.fill")
                    }
                    NavigationLink {
                        DevicesView()
                    } label: {
                        Label("设备", systemImage: "iphone.gen3")
                    }
                    NavigationLink {
                        ChatFolderSettingsView()
                    } label: {
                        Label("聊天文件夹", systemImage: "folder")
                    }
                }

                Section("体验偏好") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("通知和声音", systemImage: "bell")
                    }
                    NavigationLink {
                        DataStorageSettingsView()
                    } label: {
                        Label("数据和存储", systemImage: "externaldrive")
                    }
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("外观", systemImage: "paintpalette")
                    }
                    NavigationLink {
                        DataStorageSettingsView()
                    } label: {
                        Label("省电", systemImage: "bolt.fill")
                    }
                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        Label("语言", systemImage: "globe")
                    }
                }

                Section("支持与说明") {
                    NavigationLink {
                        SupportSettingsView()
                    } label: {
                        Label("联系客服", systemImage: "questionmark.circle")
                    }
                    NavigationLink {
                        SupportSettingsView()
                    } label: {
                        Label("HSgram 功能", systemImage: "lightbulb")
                    }
                }

                Section {
                    NavigationLink {
                        LogoutOptionsView()
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(HSTheme.warning)
                    }
                    NavigationLink {
                        DeleteAccountView()
                    } label: {
                        Label("删除账号", systemImage: "trash")
                            .foregroundStyle(HSTheme.warning)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(HSTheme.grouped)
            .navigationTitle("设置")
        }
    }
}

private struct SavedMessagesDestinationView: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        Group {
            if let session = authStore.session {
                ChatThreadView(chat: savedMessagesChat(session: session), mode: .savedMessages)
            } else {
                Text("请先登录。")
                    .foregroundStyle(HSTheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(HSTheme.grouped)
            }
        }
        .navigationTitle("收藏夹")
    }

    private func savedMessagesChat(session: HSUserSession) -> HSChat {
        HSChat(
            id: session.userID,
            title: "收藏夹",
            subtitle: "",
            unreadCount: 0,
            isCircle: false,
            peerKind: .user,
            isContact: true,
            updatedAt: nil
        )
    }
}

private struct ChatFolderSettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var filtersState = HSChatListFiltersState(tagsEnabled: false, filters: [])
    @State private var selectedFilter: ChatListFilterScope = .all
    @State private var availableChats: [HSChat] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("正在加载聊天文件夹")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(HSTheme.grouped)
            } else if let errorMessage {
                List {
                    HSErrorBanner(message: errorMessage)
                    Button {
                        Task {
                            await load()
                        }
                    } label: {
                        Label("重新加载", systemImage: "arrow.clockwise")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(HSTheme.grouped)
            } else {
                ChatListFolderManagementSheet(
                    filtersState: $filtersState,
                    selectedFilter: $selectedFilter,
                    availableChats: availableChats,
                    wrapsInNavigationStack: false,
                    showsCloseButton: false
                )
            }
        }
        .navigationTitle("聊天文件夹")
        .task {
            await load()
        }
    }

    private func load() async {
        guard let session = authStore.session else {
            errorMessage = "请先登录。"
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            async let filters = authStore.api.dialogFilters(session: session)
            async let chats = authStore.api.dialogs(session: session)
            let (loadedFilters, loadedChats) = try await (filters, chats)
            filtersState = loadedFilters
            availableChats = loadedChats
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SettingsAccountRow: View {
    let account: HSUserSession
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            HSClassicAvatar(title: account.displayName, icon: "person.fill", tint: HSTheme.accent, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(HSTheme.primaryText)
                Text(account.email)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HSTheme.secondaryText)
            }

            Spacer()

            if isCurrent {
                Image(systemName: "checkmark")
                    .font(.headline)
                    .foregroundStyle(HSTheme.accent)
            }
        }
    }
}
