import SwiftUI

struct HSChatRoomView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService
    @Environment(\.dismiss) private var dismiss

    let conversationID: UUID

    @State private var draft = ""
    @State private var showAttachmentSheet = false
    @State private var showStickerPanel = false
    @State private var showReactionForMessageID: UUID?
    @State private var showPinnedBanner = true
    @State private var blockedUserBanner = false
    @State private var selectedMessageIDs: Set<UUID> = []

    private var viewModel: HSChatRoomViewModel {
        let conversation = data.conversation(id: conversationID)
        return HSChatRoomViewModel(
            conversationID: conversationID,
            conversation: conversation,
            messages: data.messages(for: conversationID),
            currentUser: data.currentUser,
            group: conversation?.groupID.flatMap { data.group(id: $0) },
            themeConfig: data.themeConfig
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            HSChatWallpaperView(theme: data.themeConfig.activeChatTheme)

            VStack(spacing: 0) {
                HSFloatingChatNavBar(
                    title: viewModel.title,
                    subtitle: viewModel.subtitle ?? "",
                    avatarInitials: viewModel.conversation?.avatarInitials ?? "H",
                    avatarHex: viewModel.conversation?.avatarHex ?? 0x56B4F4,
                    isGroup: viewModel.isGroupChat,
                    onBack: { dismiss() },
                    onProfile: { openProfile() },
                    onSelectTheme: { data.setChatTheme($0) }
                )

                if showPinnedBanner, let group = viewModel.group {
                    HSPinnedBanner(title: "置顶消息", message: group.announcement) {
                        withAnimation(.easeInOut(duration: 0.18)) { showPinnedBanner = false }
                    }
                    .padding(.top, 8)
                } else if blockedUserBanner {
                    HSPinnedBanner(title: "屏蔽此用户", message: "这个会话已被屏蔽，可从资料页恢复。") {
                        withAnimation(.easeInOut(duration: 0.18)) { blockedUserBanner = false }
                    }
                    .padding(.top, 8)
                }

                if !selectedMessageIDs.isEmpty {
                    selectionBar
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(timeline) { item in
                                switch item.kind {
                                case .date(let title):
                                    HSDateDivider(title: title)
                                case .message(let message):
                                    messageRow(message)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, bottomClearance)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear { scrollToBottom(proxy) }
                    .onChange(of: viewModel.messages.count) { _ in scrollToBottom(proxy) }
                }
            }

            VStack(spacing: 0) {
                HSMessageInputBar(
                    text: $draft,
                    isStickerPanelVisible: showStickerPanel,
                    onSend: send,
                    onAttach: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            showAttachmentSheet = true
                            showStickerPanel = false
                        }
                    },
                    onEmoji: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            showStickerPanel.toggle()
                            showAttachmentSheet = false
                        }
                    },
                    onVoice: sendVoice
                )
                if showStickerPanel {
                    HSStickerPanel(isPresented: $showStickerPanel) { sticker in
                        data.sendSticker(sticker, in: conversationID)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            HSAttachmentSheet(isPresented: $showAttachmentSheet) { kind in
                sendAttachment(kind: kind)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if viewModel.group == nil {
                blockedUserBanner = false
            }
        }
    }

    private var timeline: [TimelineItem] {
        var result: [TimelineItem] = []
        var lastDay: String?
        for message in viewModel.messages {
            let label = HSDateText.dayLabel(message.sentAt)
            if label != lastDay {
                result.append(TimelineItem(kind: .date(label)))
                lastDay = label
            }
            result.append(TimelineItem(kind: .message(message)))
        }
        return result
    }

    private var selectionBar: some View {
        HStack {
            Button("取消") {
                selectedMessageIDs.removeAll()
            }
            .foregroundStyle(data.themeConfig.primaryAccentColor.color)

            Text("已选择 \(selectedMessageIDs.count) 条消息")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(data.themeConfig.primaryTextColor.color)

            Spacer()

            Button(role: .destructive) {
                for id in selectedMessageIDs {
                    data.deleteMessage(id, in: conversationID)
                }
                selectedMessageIDs.removeAll()
            } label: {
                Image(systemName: "trash")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func messageRow(_ message: Message) -> some View {
        ZStack(alignment: .top) {
            HSMessageBubble(
                message: message,
                showAuthor: viewModel.isGroupChat,
                onAvatarTap: { router.open(.profile(message.sender.id)) },
                onReactionTap: { data.toggleReaction($0, for: message.id, in: conversationID) },
                onShowReactionBar: {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                        showReactionForMessageID = showReactionForMessageID == message.id ? nil : message.id
                    }
                },
                onReply: {
                    draft = "@\(message.sender.username) "
                },
                onForward: {
                    data.sendText(viewModel.forwardText(for: message), in: conversationID)
                },
                onDelete: {
                    data.deleteMessage(message.id, in: conversationID)
                    selectedMessageIDs.remove(message.id)
                },
                onSelect: {
                    if selectedMessageIDs.contains(message.id) {
                        selectedMessageIDs.remove(message.id)
                    } else {
                        selectedMessageIDs.insert(message.id)
                    }
                }
            )

            if showReactionForMessageID == message.id {
                HSReactionBar(reactions: ["♥", "👍", "🔥", "😂", "😮", "👏"]) { emoji in
                    data.toggleReaction(emoji, for: message.id, in: conversationID)
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        showReactionForMessageID = nil
                    }
                }
                .offset(y: -50)
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
            }
        }
        .padding(.top, showReactionForMessageID == message.id ? 50 : 0)
    }

    private var bottomClearance: CGFloat {
        showStickerPanel ? 410 : 78
    }

    private func openProfile() {
        if let groupID = viewModel.conversation?.groupID {
            router.open(.groupProfile(groupID))
        } else if let user = viewModel.profilePeer {
            router.open(.profile(user.id))
        }
    }

    private func send() {
        data.sendText(draft, in: conversationID)
        draft = ""
    }

    private func sendVoice() {
        sendAttachment(kind: .voice)
    }

    private func sendAttachment(kind: AttachmentKind) {
        let attachment = viewModel.makeAttachment(kind: kind)
        data.sendAttachment(attachment, caption: kind == .voice ? "" : "来自附件面板", in: conversationID)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let id = viewModel.messages.last?.id else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }
}

private struct TimelineItem: Identifiable {
    let id = UUID()
    let kind: Kind

    enum Kind {
        case date(String)
        case message(Message)
    }
}
