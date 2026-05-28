import Foundation
import SwiftUI

@MainActor
final class HSMockChatService: HSChatDataProviding {
    @Published var currentUser: User
    @Published var users: [User]
    @Published var conversations: [Conversation]
    @Published var contacts: [Contact]
    @Published var groups: [Group]
    @Published var settingsItems: [SettingsItem]
    @Published var themeConfig: ThemeConfig
    @Published var recentSearches: [String]
    @Published private var messagesByConversationID: [UUID: [Message]]

    init() {
        let seed = HSMockSeed.make()
        currentUser = seed.currentUser
        users = seed.users
        conversations = seed.conversations
        contacts = seed.contacts
        groups = seed.groups
        settingsItems = seed.settings
        themeConfig = seed.theme
        recentSearches = seed.recentSearches
        messagesByConversationID = seed.messages
    }

    func messages(for conversationID: UUID) -> [Message] { messagesByConversationID[conversationID, default: []] }
    func conversation(id: UUID) -> Conversation? { conversations.first { $0.id == id } }
    func user(id: UUID) -> User? { users.first { $0.id == id } }
    func group(id: UUID) -> Group? { groups.first { $0.id == id } }

    func sendText(_ text: String, in conversationID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        append(Message(conversationID: conversationID, sender: currentUser, body: trimmed, sentAt: Date(), isOutgoing: true, deliveryState: .read), to: conversationID)
    }

    func sendAttachment(_ attachment: Attachment, caption: String, in conversationID: UUID) {
        let kind: MessageKind = attachment.kind == .image ? .image : attachment.kind == .voice ? .voice : .file
        append(Message(conversationID: conversationID, sender: currentUser, body: caption, kind: kind, attachment: attachment, sentAt: Date(), isOutgoing: true, deliveryState: .read), to: conversationID)
    }

    func toggleReaction(_ emoji: String, for messageID: UUID, in conversationID: UUID) {
        guard var messages = messagesByConversationID[conversationID],
              let index = messages.firstIndex(where: { $0.id == messageID })
        else { return }
        var message = messages[index]
        if let reactionIndex = message.reactions.firstIndex(where: { $0.emoji == emoji }) {
            if message.reactions[reactionIndex].isSelectedByCurrentUser {
                message.reactions[reactionIndex].count = max(0, message.reactions[reactionIndex].count - 1)
                message.reactions[reactionIndex].isSelectedByCurrentUser = false
                if message.reactions[reactionIndex].count == 0 { message.reactions.remove(at: reactionIndex) }
            } else {
                message.reactions[reactionIndex].count += 1
                message.reactions[reactionIndex].isSelectedByCurrentUser = true
            }
        } else {
            message.reactions.append(MessageReaction(emoji: emoji, count: 1, isSelectedByCurrentUser: true))
        }
        messages[index] = message
        messagesByConversationID[conversationID] = messages
    }

    func pin(_ conversation: Conversation) { updateConversation(conversation.id) { $0.isPinned.toggle() } }
    func mute(_ conversation: Conversation) { updateConversation(conversation.id) { $0.isMuted.toggle() } }
    func archive(_ conversation: Conversation) { updateConversation(conversation.id) { $0.isArchived.toggle() } }
    func delete(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        messagesByConversationID[conversation.id] = nil
    }

    func deleteMessage(_ messageID: UUID, in conversationID: UUID) {
        guard var messages = messagesByConversationID[conversationID] else { return }
        messages.removeAll { $0.id == messageID }
        messagesByConversationID[conversationID] = messages
        updateConversation(conversationID) { conversation in
            conversation.lastMessage = messages.last
            conversation.updatedAt = messages.last?.sentAt ?? Date()
        }
    }

    func refresh() async {
        try? await Task.sleep(nanoseconds: 550_000_000)
        sortConversations()
    }

    private func append(_ message: Message, to conversationID: UUID) {
        messagesByConversationID[conversationID, default: []].append(message)
        updateConversation(conversationID) {
            $0.lastMessage = message
            $0.updatedAt = message.sentAt
            $0.unreadCount = 0
        }
    }

    private func updateConversation(_ id: UUID, mutate: (inout Conversation) -> Void) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        mutate(&conversations[index])
        sortConversations()
    }

    private func sortConversations() {
        conversations.sort {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }
}

private enum HSMockSeed {
    struct Payload {
        var currentUser: User
        var users: [User]
        var conversations: [Conversation]
        var messages: [UUID: [Message]]
        var groups: [Group]
        var contacts: [Contact]
        var settings: [SettingsItem]
        var theme: ThemeConfig
        var recentSearches: [String]
    }

    static func make() -> Payload {
        let me = User(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, displayName: "林河", username: "linhe", email: "linhe@hsgram.app", phone: "+86 138 0000 1024", bio: "把重要的对话留在清爽的地方。", initials: "LH", accentHex: 0x168BFF, presence: .online)
        let ada = User(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, displayName: "Ada Chen", username: "ada", email: "ada@hsgram.app", phone: "+86 139 0000 2100", bio: "iOS designer. Coffee optional, pixels mandatory.", initials: "AC", accentHex: 0x30B7C5, presence: .typing)
        let ming = User(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, displayName: "周明", username: "ming", email: "ming@hsgram.app", phone: "+86 136 0000 3001", bio: "群组管理员，负责把混乱变成 checklist。", initials: "ZM", accentHex: 0xAF52DE, presence: .recently)
        let yan = User(id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!, displayName: "许言", username: "yan", email: "yan@hsgram.app", phone: nil, bio: "前端工程师，喜欢把交互做轻。", initials: "XY", accentHex: 0xFF9500, presence: .online)
        let nina = User(id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!, displayName: "Nina Park", username: "nina", email: "nina@hsgram.app", phone: nil, bio: "Product lead.", initials: "NP", accentHex: 0x34C759, presence: .offline)
        let chatAda = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let chatGroup = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let chatMing = UUID(uuidString: "20000000-0000-0000-0000-000000000003")!
        let chatFiles = UUID(uuidString: "20000000-0000-0000-0000-000000000004")!
        let groupID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let now = Date()
        let image = Attachment(id: UUID(), kind: .image, title: "界面预览", subtitle: "1280 x 960", previewSystemImage: "photo", accentHex: 0x168BFF)
        let file = Attachment(id: UUID(), kind: .file, title: "HSgram_UI_Spec.pdf", subtitle: "2.4 MB PDF", previewSystemImage: "doc.text.fill", accentHex: 0xFF9500)
        let voice = Attachment(id: UUID(), kind: .voice, title: "语音消息", subtitle: "00:18", previewSystemImage: "waveform", accentHex: 0x34C759)
        let adaMessages = [
            Message(conversationID: chatAda, sender: ada, body: "新版聊天页的输入框我想保持轻一点，按钮都用 SF Symbols。", sentAt: now.addingTimeInterval(-5400), isOutgoing: false, reactions: [MessageReaction(emoji: "👍", count: 2)]),
            Message(conversationID: chatAda, sender: me, body: "同意。气泡、导航栏、搜索都走 HSgram 自己的命名和组件。", sentAt: now.addingTimeInterval(-5000), isOutgoing: true, deliveryState: .read),
            Message(conversationID: chatAda, sender: ada, body: "这张图可以先做图片消息占位。", kind: .image, attachment: image, sentAt: now.addingTimeInterval(-4200), isOutgoing: false, reactions: [MessageReaction(emoji: "✨", count: 1)])
        ]
        let groupMessages = [
            Message(conversationID: chatGroup, sender: ming, body: "@linhe 今天先把 Mock 原型跑通，真实 API 放到协议后面。", sentAt: now.addingTimeInterval(-3800), isOutgoing: false, reactions: [MessageReaction(emoji: "🔥", count: 4)], mentions: ["linhe"], senderRole: "管理员"),
            Message(conversationID: chatGroup, sender: yan, body: "我补了联系人和搜索页的空状态，视觉尽量蓝白清爽。", sentAt: now.addingTimeInterval(-3400), isOutgoing: false, replyPreview: "今天先把 Mock 原型跑通"),
            Message(conversationID: chatGroup, sender: me, body: "收到，我把外观设置和媒体/文件/链接页也一起接上。", sentAt: now.addingTimeInterval(-3000), isOutgoing: true, deliveryState: .delivered)
        ]
        let mingMessages = [
            Message(conversationID: chatMing, sender: ming, body: "这是文件消息的样式，左边图标、右边标题和大小。", kind: .file, attachment: file, sentAt: now.addingTimeInterval(-2100), isOutgoing: false),
            Message(conversationID: chatMing, sender: me, body: "语音占位也要有波形和时长。", kind: .voice, attachment: voice, sentAt: now.addingTimeInterval(-1800), isOutgoing: true, deliveryState: .read)
        ]
        let savedMessages = [Message(conversationID: chatFiles, sender: me, body: "收藏：登录页支持邮箱为主、手机号为辅、验证码和登录/注册切换。", sentAt: now.addingTimeInterval(-1600), isOutgoing: true, deliveryState: .read)]
        let group = Group(id: groupID, title: "HSgram Design Lab", about: "讨论 iOS 原型、组件和消息体验。", announcement: "今晚 20:00 前完成第一版可运行 UI 原型。", members: [me, ada, ming, yan, nina], adminIDs: [ming.id, me.id], avatarHex: 0x168BFF)
        let conversations = [
            Conversation(id: chatAda, kind: .privateChat, title: ada.displayName, subtitle: ada.presence.label, avatarInitials: ada.initials, avatarHex: ada.accentHex, participants: [me, ada], lastMessage: adaMessages.last, updatedAt: adaMessages.last?.sentAt ?? now, unreadCount: 2, isPinned: true, isMuted: false, isArchived: false),
            Conversation(id: chatGroup, kind: .groupChat, title: group.title, subtitle: "\(group.memberCount) 位成员", avatarInitials: "HL", avatarHex: group.avatarHex, participants: group.members, groupID: group.id, lastMessage: groupMessages.last, updatedAt: groupMessages.last?.sentAt ?? now, unreadCount: 5, isPinned: true, isMuted: true, isArchived: false),
            Conversation(id: chatMing, kind: .privateChat, title: ming.displayName, subtitle: ming.presence.label, avatarInitials: ming.initials, avatarHex: ming.accentHex, participants: [me, ming], lastMessage: mingMessages.last, updatedAt: mingMessages.last?.sentAt ?? now, unreadCount: 0, isPinned: false, isMuted: false, isArchived: false),
            Conversation(id: chatFiles, kind: .privateChat, title: "收藏夹", subtitle: "个人笔记和转发消息", avatarInitials: "HS", avatarHex: 0x34C759, participants: [me], lastMessage: savedMessages.last, updatedAt: savedMessages.last?.sentAt ?? now, unreadCount: 0, isPinned: false, isMuted: false, isArchived: false)
        ]
        let settings = [
            SettingsItem(id: "account", icon: "lock.shield.fill", title: "账号与安全", subtitle: "邮箱、手机号、登录设备和验证码", accentHex: 0x168BFF, destination: .accountSecurity),
            SettingsItem(id: "privacy", icon: "hand.raised.fill", title: "隐私设置", subtitle: "黑名单、最后在线、资料可见性", accentHex: 0x30B7C5, destination: .privacy),
            SettingsItem(id: "notifications", icon: "bell.badge.fill", title: "通知设置", subtitle: "消息预览、声音、免打扰", accentHex: 0xFF9500, destination: .notifications),
            SettingsItem(id: "chat", icon: "bubble.left.and.text.bubble.right.fill", title: "聊天设置", subtitle: "输入、贴纸、文件和自动下载", accentHex: 0xAF52DE, destination: .chat),
            SettingsItem(id: "appearance", icon: "paintpalette.fill", title: "外观设置", subtitle: "浅色/深色、字体、主题色和背景", accentHex: 0x168BFF, destination: .appearance),
            SettingsItem(id: "storage", icon: "internaldrive.fill", title: "存储与数据", subtitle: "缓存、流量和自动清理", accentHex: 0x34C759, destination: .storage),
            SettingsItem(id: "devices", icon: "iphone.gen3", title: "设备管理", subtitle: "当前在线设备和登录记录", accentHex: 0x5E5CE6, destination: .devices),
            SettingsItem(id: "about", icon: "info.circle.fill", title: "关于 HSgram", subtitle: "版本、协议和开源声明", accentHex: 0x777E89, destination: .about)
        ]
        return Payload(
            currentUser: me,
            users: [me, ada, ming, yan, nina],
            conversations: conversations.sorted { $0.isPinned == $1.isPinned ? $0.updatedAt > $1.updatedAt : $0.isPinned },
            messages: [chatAda: adaMessages, chatGroup: groupMessages, chatMing: mingMessages, chatFiles: savedMessages],
            groups: [group],
            contacts: [Contact(id: ada.id, user: ada, note: "设计协作", isFavorite: true), Contact(id: ming.id, user: ming, note: "群管理员", isFavorite: true), Contact(id: yan.id, user: yan, note: "前端工程师", isFavorite: false), Contact(id: nina.id, user: nina, note: "产品负责人", isFavorite: false)],
            settings: settings,
            theme: ThemeConfig(),
            recentSearches: ["外观设置", "HSgram Design Lab", "文件"]
        )
    }
}
