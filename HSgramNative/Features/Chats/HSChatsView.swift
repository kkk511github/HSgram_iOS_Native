import SwiftUI

struct HSChatsView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService
    @State private var query = ""

    private var visibleConversations: [Conversation] {
        data.conversations
            .filter { !$0.isArchived }
            .filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || ($0.lastMessage?.body.localizedCaseInsensitiveContains(query) ?? false) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HSNavigationBar(title: "HSgram")
            List {
                Section {
                    HSSearchBar(text: $query, placeholder: "搜索消息或用户").padding(.horizontal, 16).padding(.vertical, 10)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(HSPrototypeTheme.surface)
                }
                if visibleConversations.isEmpty {
                    Section {
                        HSEmptyStateView(
                            systemImage: "bubble.left.and.bubble.right",
                            title: query.isEmpty ? "还没有会话" : "没有找到会话",
                            message: query.isEmpty ? "新的聊天、群组和收藏消息会显示在这里。" : "换个关键词试试，或清空搜索回到全部会话。",
                            actionTitle: query.isEmpty ? nil : "清空搜索",
                            action: query.isEmpty ? nil : { query = "" }
                        )
                        .frame(minHeight: 420)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(HSPrototypeTheme.surface)
                    }
                } else {
                    Section {
                        ForEach(visibleConversations) { conversation in
                            Button {
                                router.open(.chat(conversation.id))
                            } label: {
                                HSConversationCell(conversation: conversation) {
                                    if let user = conversation.participants.first(where: { $0.id != data.currentUser.id }) {
                                        router.open(.profile(user.id))
                                    }
                                }
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(HSPrototypeTheme.separator.opacity(0.55))
                                        .frame(height: 1 / UIScreen.main.scale)
                                        .padding(.leading, 82)
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { data.pin(conversation) } label: { Label(conversation.isPinned ? "取消置顶" : "置顶", systemImage: "pin") }.tint(HSPrototypeTheme.accent)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { data.delete(conversation) } label: { Label("删除", systemImage: "trash") }
                                Button { data.archive(conversation) } label: { Label("归档", systemImage: "archivebox") }.tint(.gray)
                                Button { data.mute(conversation) } label: { Label(conversation.isMuted ? "取消静音" : "静音", systemImage: "bell.slash") }.tint(HSPrototypeTheme.orange)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(conversation.isPinned ? HSPrototypeTheme.secondarySurface.opacity(0.65) : HSPrototypeTheme.surface)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await data.refresh() }
            .background(HSPrototypeTheme.surface)
        }
        .background(HSPrototypeTheme.surface.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}
