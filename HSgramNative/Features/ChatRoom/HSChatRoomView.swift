import SwiftUI

struct HSChatRoomView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService
    @Environment(\.dismiss) private var dismiss
    let conversationID: UUID
    @State private var draft = ""
    @State private var showAttachmentSheet = false
    @State private var showReactionForMessageID: UUID?
    @State private var showGroupInfo = false
    @State private var selectedMessageIDs: Set<UUID> = []
    @State private var statusMessage: String?

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
            HSChatBackgroundView(style: viewModel.themeConfig.chatBackground)
            VStack(spacing: 0) {
                topBar
                if let statusMessage {
                    statusBanner(statusMessage)
                }
                if !selectedMessageIDs.isEmpty {
                    selectionBar
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            servicePill("今天")
                            if viewModel.isGroupChat { groupQuickPanel(viewModel) }
                            ForEach(viewModel.messages) { message in
                                ZStack(alignment: .top) {
                                    HSMessageBubble(
                                        message: message,
                                        showAuthor: viewModel.isGroupChat,
                                        onAvatarTap: { router.open(.profile(message.sender.id)) },
                                        onReactionTap: { data.toggleReaction($0, for: message.id, in: conversationID) },
                                        onShowReactionBar: {
                                            withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) { showReactionForMessageID = message.id }
                                        },
                                        onReply: {
                                            draft = viewModel.replyDraft(for: message)
                                            statusMessage = "已准备回复 \(message.sender.displayName)"
                                        },
                                        onForward: {
                                            data.sendText(viewModel.forwardText(for: message), in: conversationID)
                                            statusMessage = "已转发到当前会话"
                                        },
                                        onDelete: {
                                            data.deleteMessage(message.id, in: conversationID)
                                            selectedMessageIDs.remove(message.id)
                                            statusMessage = "消息已删除"
                                        },
                                        onSelect: {
                                            if selectedMessageIDs.contains(message.id) {
                                                selectedMessageIDs.remove(message.id)
                                            } else {
                                                selectedMessageIDs.insert(message.id)
                                            }
                                        }
                                    )
                                    .id(message.id)
                                    if showReactionForMessageID == message.id {
                                        HSReactionBar(reactions: ["❤️", "👍", "🔥", "😂", "😮", "👏"]) { emoji in
                                            data.toggleReaction(emoji, for: message.id, in: conversationID)
                                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) { showReactionForMessageID = nil }
                                        }
                                        .offset(y: -48)
                                        .transition(.scale.combined(with: .opacity))
                                        .zIndex(2)
                                    }
                                }
                                .padding(.top, showReactionForMessageID == message.id ? 48 : 0)
                            }
                        }
                        .padding(.top, 10)
                        .padding(.bottom, HSLayoutMetrics.chatInputClearance)
                    }
                    .onAppear { scrollToBottom(proxy) }
                    .onChange(of: viewModel.messages.count) { _ in scrollToBottom(proxy) }
                }
                HSMessageInputBar(text: $draft, onSend: send, onAttach: { showAttachmentSheet = true }, onEmoji: { showReactionForMessageID = viewModel.messages.last?.id }, onVoice: sendVoice)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("附件", isPresented: $showAttachmentSheet, titleVisibility: .visible) {
            Button("图片") { sendAttachment(kind: .image) }
            Button("文件") { sendAttachment(kind: .file) }
            Button("链接") { sendAttachment(kind: .link) }
        }
        .sheet(isPresented: $showGroupInfo) {
            if let conversation = viewModel.conversation {
                HSGroupInfoSheet(conversation: conversation).presentationDetents([.medium, .large])
            }
        }
    }

    private var topBar: some View {
        HSNavigationBar(title: viewModel.title, subtitle: viewModel.subtitle) {
            Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)) }
                .buttonStyle(.plain).foregroundStyle(HSPrototypeTheme.accent)
        } trailing: {
            HStack(spacing: 10) {
                Button { if let conversation = viewModel.conversation { router.open(.media(conversation.id)) } } label: { Image(systemName: "rectangle.stack") }
                    .buttonStyle(.plain)
                Button {
                    if viewModel.isGroupChat {
                        showGroupInfo = true
                    } else if let user = viewModel.profilePeer {
                        router.open(.profile(user.id))
                    }
                } label: {
                    if let conversation = viewModel.conversation {
                        HSAvatarView(initials: conversation.avatarInitials, colorHex: conversation.avatarHex, size: 34, isGroup: conversation.isGroup, isOnline: conversation.participants.contains(where: \.isOnline))
                    }
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(HSPrototypeTheme.accent)
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Button("取消") {
                selectedMessageIDs.removeAll()
            }
            .buttonStyle(.plain)
            .foregroundStyle(HSPrototypeTheme.accent)

            Text("已选择 \(selectedMessageIDs.count) 条消息")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HSPrototypeTheme.primaryText)

            Spacer()

            Button(role: .destructive) {
                for id in selectedMessageIDs {
                    data.deleteMessage(id, in: conversationID)
                }
                selectedMessageIDs.removeAll()
                statusMessage = "已删除所选消息"
            } label: {
                Label("删除", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Rectangle().fill(HSPrototypeTheme.separator.opacity(0.65)).frame(height: 1 / UIScreen.main.scale) }
    }

    private func statusBanner(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(HSPrototypeTheme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(HSPrototypeTheme.accent.opacity(0.10))
            .onTapGesture {
                statusMessage = nil
            }
    }

    private func groupQuickPanel(_ viewModel: HSChatRoomViewModel) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "megaphone.fill").foregroundStyle(HSPrototypeTheme.accent)
            Text("群公告").font(.caption.weight(.semibold))
            Text(viewModel.groupAnnouncement).font(.caption).foregroundStyle(HSPrototypeTheme.secondaryText).lineLimit(1)
            Spacer()
            Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(HSPrototypeTheme.tertiaryText)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    private func servicePill(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5).background(Color.black.opacity(0.22), in: Capsule()).padding(.vertical, 4)
    }

    private func send() {
        data.sendText(draft, in: conversationID)
        draft = ""
    }

    private func sendVoice() { sendAttachment(kind: .voice) }

    private func sendAttachment(kind: AttachmentKind) {
        let attachment = viewModel.makeAttachment(kind: kind)
        data.sendAttachment(attachment, caption: kind == .voice ? "" : "来自附件入口", in: conversationID)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let id = viewModel.messages.last?.id else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { proxy.scrollTo(id, anchor: .bottom) }
        }
    }
}

private struct HSGroupInfoSheet: View {
    @EnvironmentObject private var data: HSMockChatService
    let conversation: Conversation
    private var group: Group? { conversation.groupID.flatMap { data.group(id: $0) } }

    var body: some View {
        NavigationStack {
            List {
                if let group {
                    Section {
                        VStack(spacing: 10) {
                            HSAvatarView(initials: conversation.avatarInitials, colorHex: group.avatarHex, size: 82, isGroup: true)
                            Text(group.title).font(.title3.weight(.bold))
                            Text("\(group.memberCount) 位成员").font(.subheadline).foregroundStyle(HSPrototypeTheme.secondaryText)
                            Text(group.about).font(.footnote).foregroundStyle(HSPrototypeTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    Section("入口") {
                        Label(group.announcement, systemImage: "megaphone.fill")
                        Label("群成员列表", systemImage: "person.3.fill")
                        Label("群设置", systemImage: "slider.horizontal.3")
                    }
                    Section("成员") {
                        ForEach(group.members) { member in
                            HStack {
                                HSAvatarView(initials: member.initials, colorHex: member.accentHex, size: 38, isOnline: member.isOnline)
                                VStack(alignment: .leading) {
                                    Text(member.displayName)
                                    if let role = group.role(for: member) { Text(role).font(.caption).foregroundStyle(HSPrototypeTheme.accent) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("群资料")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
