import SwiftUI

struct HSGlobalSearchView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService
    @State private var query = ""

    private var viewModel: HSGlobalSearchViewModel {
        HSGlobalSearchViewModel(
            query: query,
            users: data.users,
            currentUser: data.currentUser,
            groups: data.groups,
            conversations: data.conversations,
            messages: data.conversations.flatMap { data.messages(for: $0.id) },
            recentSearches: data.recentSearches
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HSNavigationBar(title: "搜索")
            List {
                Section {
                    HSSearchBar(text: $query, placeholder: "全局搜索")
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(data.themeConfig.groupedBackgroundColor.color)
                }
                if query.isEmpty {
                    Section("最近搜索") {
                        ForEach(viewModel.recentSearches, id: \.self) { item in
                            Button { query = item } label: { Label(item, systemImage: "clock") }
                        }
                    }
                }
                Section("用户") {
                    if viewModel.userResults.isEmpty {
                        Text("没有匹配用户").foregroundStyle(data.themeConfig.secondaryTextColor.color)
                    } else {
                        ForEach(viewModel.userResults) { user in
                            Button { router.open(.profile(user.id)) } label: { searchUserRow(user) }.buttonStyle(.plain)
                        }
                    }
                }
                Section("群组") {
                    if viewModel.groupResults.isEmpty {
                        Text("没有匹配群组").foregroundStyle(data.themeConfig.secondaryTextColor.color)
                    } else {
                        ForEach(viewModel.groupResults) { group in
                            if let conversation = viewModel.conversation(for: group) {
                                Button { router.open(.chat(conversation.id)) } label: {
                                    HStack(spacing: 12) {
                                        HSAvatarView(initials: "HS", colorHex: group.avatarHex, size: 42, isGroup: true)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(group.title).font(.body.weight(.semibold))
                                            Text("\(group.memberCount) 位成员").font(.caption).foregroundStyle(data.themeConfig.secondaryTextColor.color)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Section("消息") {
                    if viewModel.messageResults.isEmpty {
                        Text(query.isEmpty ? "输入关键词搜索消息" : "没有匹配消息").foregroundStyle(data.themeConfig.secondaryTextColor.color)
                    } else {
                        ForEach(viewModel.messageResults) { message in
                            Button { router.open(.chat(message.conversationID)) } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(message.sender.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(data.themeConfig.primaryTextColor.color)
                                    Text(message.body).font(.subheadline).foregroundStyle(data.themeConfig.secondaryTextColor.color).lineLimit(2)
                                }
                                .padding(.vertical, 3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: HSLayoutMetrics.rootTabBarClearance)
            }
            .background(data.themeConfig.groupedBackgroundColor.color)
        }
        .background(data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea())
    }

    private func searchUserRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            HSAvatarView(initials: user.initials, colorHex: user.accentHex, size: 42, isOnline: user.isOnline)
            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName).font(.body.weight(.semibold)).foregroundStyle(data.themeConfig.primaryTextColor.color)
                Text("@\(user.username)").font(.caption).foregroundStyle(data.themeConfig.secondaryTextColor.color)
            }
        }
    }
}
