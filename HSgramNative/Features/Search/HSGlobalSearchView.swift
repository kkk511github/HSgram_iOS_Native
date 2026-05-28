import SwiftUI

struct HSGlobalSearchView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService
    @State private var query = ""

    private var userResults: [User] {
        data.users.filter { $0.id != data.currentUser.id && (query.isEmpty || $0.displayName.localizedCaseInsensitiveContains(query) || $0.username.localizedCaseInsensitiveContains(query)) }
    }
    private var groupResults: [Group] {
        data.groups.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.about.localizedCaseInsensitiveContains(query) }
    }
    private var messageResults: [Message] {
        guard !query.isEmpty else { return [] }
        return data.conversations.flatMap { data.messages(for: $0.id) }.filter { $0.body.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HSNavigationBar(title: "搜索")
            List {
                Section {
                    HSSearchBar(text: $query, placeholder: "全局搜索")
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(HSPrototypeTheme.background)
                }
                if query.isEmpty {
                    Section("最近搜索") {
                        ForEach(data.recentSearches, id: \.self) { item in
                            Button { query = item } label: { Label(item, systemImage: "clock") }
                        }
                    }
                }
                Section("用户") {
                    if userResults.isEmpty {
                        Text("没有匹配用户").foregroundStyle(HSPrototypeTheme.secondaryText)
                    } else {
                        ForEach(userResults) { user in
                            Button { router.open(.profile(user.id)) } label: { searchUserRow(user) }.buttonStyle(.plain)
                        }
                    }
                }
                Section("群组") {
                    if groupResults.isEmpty {
                        Text("没有匹配群组").foregroundStyle(HSPrototypeTheme.secondaryText)
                    } else {
                        ForEach(groupResults) { group in
                            if let conversation = data.conversations.first(where: { $0.groupID == group.id }) {
                                Button { router.open(.chat(conversation.id)) } label: {
                                    HStack(spacing: 12) {
                                        HSAvatarView(initials: "HS", colorHex: group.avatarHex, size: 42, isGroup: true)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(group.title).font(.body.weight(.semibold))
                                            Text("\(group.memberCount) 位成员").font(.caption).foregroundStyle(HSPrototypeTheme.secondaryText)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Section("消息") {
                    if messageResults.isEmpty {
                        Text(query.isEmpty ? "输入关键词搜索消息" : "没有匹配消息").foregroundStyle(HSPrototypeTheme.secondaryText)
                    } else {
                        ForEach(messageResults) { message in
                            Button { router.open(.chat(message.conversationID)) } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(message.sender.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(HSPrototypeTheme.primaryText)
                                    Text(message.body).font(.subheadline).foregroundStyle(HSPrototypeTheme.secondaryText).lineLimit(2)
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
            .background(HSPrototypeTheme.background)
        }
        .background(HSPrototypeTheme.background.ignoresSafeArea())
    }

    private func searchUserRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            HSAvatarView(initials: user.initials, colorHex: user.accentHex, size: 42, isOnline: user.isOnline)
            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName).font(.body.weight(.semibold)).foregroundStyle(HSPrototypeTheme.primaryText)
                Text("@\(user.username)").font(.caption).foregroundStyle(HSPrototypeTheme.secondaryText)
            }
        }
    }
}
