import SwiftUI

struct HSChatsView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService
    @State private var query = ""

    private var viewModel: HSChatListViewModel {
        HSChatListViewModel(conversations: data.conversations, query: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 0) {
                    HSSearchBar(text: $query, placeholder: "搜索")
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                        .padding(.bottom, 10)

                    if viewModel.visibleConversations.isEmpty {
                        HSEmptyStateView(
                            systemImage: "bubble.left.and.bubble.right",
                            title: viewModel.isFiltering ? "没有找到会话" : "还没有会话",
                            message: viewModel.isFiltering ? "换个关键词试试，或清空搜索回到全部会话。" : "新的聊天、群组和收藏消息会显示在这里。",
                            actionTitle: viewModel.isFiltering ? "清空搜索" : nil,
                            action: viewModel.isFiltering ? { query = "" } : nil
                        )
                        .frame(height: 420)
                    } else {
                        ForEach(viewModel.visibleConversations) { conversation in
                            Button {
                                router.open(.chat(conversation.id))
                            } label: {
                                HSConversationCell(conversation: conversation) {
                                    if conversation.isGroup, let groupID = conversation.groupID {
                                        router.open(.groupProfile(groupID))
                                    } else if let user = conversation.participants.first(where: { $0.id != data.currentUser.id }) {
                                        router.open(.profile(user.id))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    data.pin(conversation)
                                } label: {
                                    Label(conversation.isPinned ? "取消置顶" : "置顶", systemImage: "pin")
                                }
                                Button {
                                    data.mute(conversation)
                                } label: {
                                    Label(conversation.isMuted ? "取消静音" : "静音", systemImage: "bell.slash")
                                }
                                Button {
                                    data.archive(conversation)
                                } label: {
                                    Label("归档", systemImage: "archivebox")
                                }
                                Button(role: .destructive) {
                                    data.delete(conversation)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, HSLayoutMetrics.rootTabBarClearance + 10)
            }
            .scrollIndicators(.hidden)
            .refreshable { await data.refresh() }
        }
        .background(data.themeConfig.appBackgroundColor.color.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button("编辑") {}
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(data.themeConfig.primaryTextColor.color)
                .frame(height: 44)
                .padding(.horizontal, 13)
                .background(data.themeConfig.cardBackgroundColor.color.opacity(0.78), in: Capsule())

            Spacer()

            HStack(spacing: 6) {
                Text("聊天")
                    .font(.system(size: 19, weight: .bold))
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(data.themeConfig.primaryTextColor.color)

            Spacer()

            Button(action: {}) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                    .frame(width: 44, height: 44)
                    .background(data.themeConfig.cardBackgroundColor.color.opacity(0.78), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(data.themeConfig.navigationBarBackground.color.opacity(0.02))
    }
}
