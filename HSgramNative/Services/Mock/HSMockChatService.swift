import Foundation
import SwiftUI

@MainActor
final class HSMockChatService: HSChatDataProviding {
    @Published var currentUser: User
    @Published var users: [User]
    @Published var conversations: [Conversation]
    @Published var contacts: [Contact]
    @Published var groups: [HSGroup]
    @Published var settingsItems: [SettingsItem]
    @Published var themeConfig: ThemeConfig
    @Published var recentSearches: [String]
    @Published var stickers: [HSSticker]
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
        stickers = seed.stickers
        messagesByConversationID = seed.messages
    }

    func messages(for conversationID: UUID) -> [Message] {
        messagesByConversationID[conversationID, default: []]
    }

    func conversation(id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    func user(id: UUID) -> User? {
        users.first { $0.id == id }
    }

    func group(id: UUID) -> HSGroup? {
        groups.first { $0.id == id }
    }

    func sendText(_ text: String, in conversationID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        append(
            Message(
                conversationID: conversationID,
                sender: currentUser,
                body: trimmed,
                sentAt: Date(),
                isOutgoing: true,
                deliveryState: .read
            ),
            to: conversationID
        )
    }

    func sendAttachment(_ attachment: Attachment, caption: String, in conversationID: UUID) {
        let kind: MessageKind
        switch attachment.kind {
        case .image:
            kind = .image
        case .voice:
            kind = .voice
        default:
            kind = .file
        }
        append(
            Message(
                conversationID: conversationID,
                sender: currentUser,
                body: caption,
                kind: kind,
                attachment: attachment,
                sentAt: Date(),
                isOutgoing: true,
                deliveryState: .read
            ),
            to: conversationID
        )
    }

    func sendSticker(_ sticker: HSSticker, in conversationID: UUID) {
        append(
            Message(
                conversationID: conversationID,
                sender: currentUser,
                body: "",
                kind: .sticker,
                sticker: sticker,
                sentAt: Date(),
                isOutgoing: true,
                deliveryState: .read
            ),
            to: conversationID
        )
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
                message.reactions[reactionIndex].reactorInitials.removeAll { $0 == currentUser.initials }
                if message.reactions[reactionIndex].count == 0 {
                    message.reactions.remove(at: reactionIndex)
                }
            } else {
                message.reactions[reactionIndex].count += 1
                message.reactions[reactionIndex].isSelectedByCurrentUser = true
                if !message.reactions[reactionIndex].reactorInitials.contains(currentUser.initials) {
                    message.reactions[reactionIndex].reactorInitials.append(currentUser.initials)
                }
            }
        } else {
            message.reactions.append(
                MessageReaction(
                    emoji: emoji,
                    count: 1,
                    isSelectedByCurrentUser: true,
                    reactorInitials: [currentUser.initials]
                )
            )
        }
        messages[index] = message
        messagesByConversationID[conversationID] = messages
    }

    func pin(_ conversation: Conversation) {
        updateConversation(conversation.id) { $0.isPinned.toggle() }
    }

    func mute(_ conversation: Conversation) {
        updateConversation(conversation.id) { $0.isMuted.toggle() }
    }

    func archive(_ conversation: Conversation) {
        updateConversation(conversation.id) { $0.isArchived.toggle() }
    }

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

    func setChatTheme(_ theme: ChatThemeConfig) {
        themeConfig.apply(chatTheme: theme)
    }

    func refresh() async {
        try? await Task.sleep(nanoseconds: 450_000_000)
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
        var groups: [HSGroup]
        var contacts: [Contact]
        var settings: [SettingsItem]
        var theme: ThemeConfig
        var recentSearches: [String]
        var stickers: [HSSticker]
    }

    static func make() -> Payload {
        let me = makeUser(
            uuid: "10000000-0000-0000-0000-000000000001",
            name: "lyp",
            username: "lyp",
            initials: "L",
            hex: 0xF36D68,
            presence: .online,
            lastSeen: "在线"
        )
        let kk = makeUser(
            uuid: "10000000-0000-0000-0000-000000000002",
            name: "kk",
            username: "kk01",
            initials: "K",
            hex: 0x62D6D8,
            presence: .online,
            lastSeen: "在线"
        )
        let owner = makeUser(
            uuid: "10000000-0000-0000-0000-000000000003",
            name: "群主 01",
            username: "owner01",
            initials: "群",
            hex: 0x56B4F4,
            presence: .recently,
            lastSeen: "最近上线于 05/25/26"
        )
        let test = makeUser(
            uuid: "10000000-0000-0000-0000-000000000004",
            name: "test",
            username: "test",
            initials: "T",
            hex: 0xF0646B,
            presence: .offline,
            lastSeen: "最近上线于 05/20/26"
        )
        let member02 = makeUser(
            uuid: "10000000-0000-0000-0000-000000000005",
            name: "成员 02",
            username: "member02",
            initials: "成",
            hex: 0xC76BEA,
            presence: .offline,
            lastSeen: "最近上线于 05/13/26"
        )
        let admin03 = makeUser(
            uuid: "10000000-0000-0000-0000-000000000006",
            name: "管理 03",
            username: "admin03",
            initials: "管",
            hex: 0xF6775E,
            presence: .offline,
            lastSeen: "最近上线于 05/08/26"
        )
        let carl = makeUser(
            uuid: "10000000-0000-0000-0000-000000000007",
            name: "Carl",
            username: "carl",
            initials: "C",
            hex: 0x6468F1,
            presence: .recently,
            lastSeen: "最近上线于 05/13/26"
        )
        let kkk05 = makeUser(
            uuid: "10000000-0000-0000-0000-000000000008",
            name: "kkk05",
            username: "kkk05",
            initials: "K",
            hex: 0x83D46F,
            presence: .offline,
            lastSeen: "最近上线于 05/05/26"
        )
        let user123 = makeUser(
            uuid: "10000000-0000-0000-0000-000000000009",
            name: "123 123",
            username: "u123",
            initials: "11",
            hex: 0x62B6F0,
            presence: .offline,
            lastSeen: "最近上线于 05/12/26"
        )
        let kkk03 = makeUser(
            uuid: "10000000-0000-0000-0000-000000000010",
            name: "kkkk03",
            username: "kkkk03",
            initials: "K",
            hex: 0xF6BE63,
            presence: .offline,
            lastSeen: "最近上线于 05/18/26"
        )

        let chatSystem = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let chatGroup = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let chatTestSuper = UUID(uuidString: "20000000-0000-0000-0000-000000000003")!
        let chatTest = UUID(uuidString: "20000000-0000-0000-0000-000000000004")!
        let chatOwner = UUID(uuidString: "20000000-0000-0000-0000-000000000005")!
        let groupID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let now = Date()

        let stickers = [
            HSSticker(title: "开心泡泡", symbol: "face.smiling.fill", baseHex: 0xFFD84D, accentHex: 0xF1992D, mood: "开心"),
            HSSticker(title: "睡觉", symbol: "moon.zzz.fill", baseHex: 0x60D887, accentHex: 0xFFD84D, mood: "睡觉"),
            HSSticker(title: "惊讶", symbol: "exclamationmark.bubble.fill", baseHex: 0x64C8F7, accentHex: 0xFFD84D, mood: "惊讶"),
            HSSticker(title: "庆祝", symbol: "party.popper.fill", baseHex: 0xF37AC1, accentHex: 0xFFD84D, mood: "庆祝"),
            HSSticker(title: "喜欢", symbol: "heart.fill", baseHex: 0xFFD84D, accentHex: 0xF05A6B, mood: "喜欢"),
            HSSticker(title: "酷", symbol: "sunglasses.fill", baseHex: 0x8F63CF, accentHex: 0xFFD84D, mood: "酷"),
            HSSticker(title: "火花", symbol: "flame.fill", baseHex: 0xF77759, accentHex: 0x2B2B2E, mood: "火花"),
            HSSticker(title: "检查", symbol: "checkmark.seal.fill", baseHex: 0x8BD96F, accentHex: 0x4D9C52, mood: "检查")
        ]

        let file = Attachment(
            id: UUID(),
            kind: .file,
            title: "HSgram_UI_Spec.pdf",
            subtitle: "2.4 MB PDF",
            previewSystemImage: "doc.text.fill",
            accentHex: 0xFF9F2E
        )

        let groupMessages = [
            Message(
                conversationID: chatGroup,
                sender: kk,
                body: "???",
                sentAt: now.addingTimeInterval(-42_000),
                isOutgoing: false,
                reactions: [MessageReaction(emoji: "🔥", count: 1, reactorInitials: ["K"])]
            ),
            Message(
                conversationID: chatGroup,
                sender: kk,
                body: "ooo",
                sentAt: now.addingTimeInterval(-38_000),
                isOutgoing: false,
                reactions: [
                    MessageReaction(emoji: "😭", count: 1, reactorInitials: ["K"]),
                    MessageReaction(emoji: "😊", count: 1, reactorInitials: ["K"]),
                    MessageReaction(emoji: "😎", count: 1, reactorInitials: ["K"]),
                    MessageReaction(emoji: "😆", count: 1, reactorInitials: ["K"])
                ]
            ),
            Message(
                conversationID: chatGroup,
                sender: me,
                body: "钱钱钱",
                sentAt: now.addingTimeInterval(-34_000),
                isOutgoing: true,
                deliveryState: .read,
                reactions: [
                    MessageReaction(emoji: "😎", count: 2, reactorInitials: ["群"]),
                    MessageReaction(emoji: "♥", count: 1, reactorInitials: ["K"]),
                    MessageReaction(emoji: "😍", count: 1, reactorInitials: ["K"])
                ]
            ),
            Message(
                conversationID: chatGroup,
                sender: me,
                body: "https://hsgram.cloud/+QP56MDQCnnNRs7k7J7PM",
                sentAt: now.addingTimeInterval(-30_000),
                isOutgoing: true,
                deliveryState: .read,
                reactions: [MessageReaction(emoji: "😁", count: 1, reactorInitials: ["K"])]
            ),
            Message(
                conversationID: chatGroup,
                sender: me,
                body: "dd",
                sentAt: now.addingTimeInterval(-24_000),
                isOutgoing: true,
                deliveryState: .read,
                reactions: [
                    MessageReaction(emoji: "😂", count: 1, reactorInitials: ["K"]),
                    MessageReaction(emoji: "👎", count: 1, reactorInitials: ["K"])
                ]
            ),
            Message(
                conversationID: chatGroup,
                sender: me,
                body: "dd",
                sentAt: now.addingTimeInterval(-18_000),
                isOutgoing: true,
                deliveryState: .read
            ),
            Message(
                conversationID: chatGroup,
                sender: me,
                body: "",
                kind: .sticker,
                sticker: stickers[1],
                sentAt: now.addingTimeInterval(-12_000),
                isOutgoing: true,
                deliveryState: .read
            )
        ]

        let systemMessages = [
            Message(
                conversationID: chatSystem,
                sender: owner,
                body: "HSgram 安全提示 为保障每位用户的账号安全与信息隐私，平台特别提醒：近期发现有不法分子冒充客服。",
                sentAt: now.addingTimeInterval(-46_000),
                isOutgoing: false
            )
        ]
        let testSuperMessages = [
            Message(
                conversationID: chatTestSuper,
                sender: me,
                body: "",
                kind: .sticker,
                sticker: stickers[0],
                sentAt: now.addingTimeInterval(-36_000),
                isOutgoing: true,
                deliveryState: .read
            )
        ]
        let testMessages = [
            Message(
                conversationID: chatTest,
                sender: test,
                body: "Codex线上矩阵验证 lyp rejoin send 1779765981",
                sentAt: now.addingTimeInterval(-72_000),
                isOutgoing: false
            ),
            Message(
                conversationID: chatTest,
                sender: me,
                body: "收到，稍后继续排查。",
                kind: .text,
                attachment: file,
                sentAt: now.addingTimeInterval(-70_000),
                isOutgoing: true,
                deliveryState: .read
            )
        ]
        let ownerMessages = [
            Message(
                conversationID: chatOwner,
                sender: owner,
                body: "dd",
                sentAt: now.addingTimeInterval(-96_000),
                isOutgoing: false
            )
        ]

        let group = HSGroup(
            id: groupID,
            title: "测试超级群",
            about: "用于验证群资料、权限、邀请链接、成员和表情回应体验。",
            announcement: "别去用 qieqie 了",
            members: [kk, owner, test, carl, member02, admin03, kkk05, user123, me],
            adminIDs: [kk.id, carl.id, user123.id, me.id],
            ownerID: owner.id,
            avatarInitials: "群",
            avatarHex: 0x56B4F4,
            username: "supergroup-test",
            inviteLinks: [
                GroupInviteLink(
                    id: UUID(),
                    link: "https://hsgram.cloud/+p...bnVluwxyf5eEVN",
                    shortLink: "hsgram.cloud/+p...bnVluwxyf5eEVN",
                    joinedCount: 0,
                    requiresApproval: false
                )
            ],
            removedUsers: [
                RemovedUser(id: UUID(), user: kk, removedBy: "群主 01"),
                RemovedUser(id: UUID(), user: makeUser(uuid: "10000000-0000-0000-0000-000000000011", name: "kk", username: "kk_removed", initials: "K", hex: 0xF0646B, presence: .offline, lastSeen: "被移除"), removedBy: "群主 01"),
                RemovedUser(id: UUID(), user: makeUser(uuid: "10000000-0000-0000-0000-000000000012", name: "k", username: "k_removed", initials: "K", hex: 0xF7BE63, presence: .offline, lastSeen: "被移除"), removedBy: "群主 01")
            ],
            permissions: GroupPermissionState(
                canSendMessages: true,
                canSendMedia: true,
                canAddMembers: false,
                canPinMessages: false,
                canChangeInfo: false,
                canEditOwnTags: false,
                slowModeSeconds: 0
            ),
            reactionsEnabled: true,
            reactionLimit: 11,
            allowedReactions: ""
        )

        let conversations = [
            Conversation(
                id: chatSystem,
                kind: .privateChat,
                title: "HSgram",
                subtitle: "安全提示",
                avatarInitials: "H",
                avatarHex: 0x3478F6,
                participants: [me],
                lastMessage: systemMessages.last,
                updatedAt: now.addingTimeInterval(-46_000),
                unreadCount: 0,
                isPinned: true,
                isMuted: false,
                isArchived: false,
                isVerified: true
            ),
            Conversation(
                id: chatGroup,
                kind: .groupChat,
                title: group.title,
                subtitle: "\(group.memberCount) 位成员",
                avatarInitials: group.avatarInitials,
                avatarHex: group.avatarHex,
                participants: group.members,
                groupID: group.id,
                lastMessage: groupMessages.last,
                updatedAt: now.addingTimeInterval(-12_000),
                unreadCount: 0,
                isPinned: true,
                isMuted: false,
                isArchived: false,
                isVerified: false
            ),
            Conversation(
                id: chatTestSuper,
                kind: .groupChat,
                title: "test 超级群",
                subtitle: "kk 已移除 k 99",
                avatarInitials: "T",
                avatarHex: 0x82D56E,
                participants: [me, kk, test],
                groupID: group.id,
                lastMessage: testSuperMessages.last,
                updatedAt: now.addingTimeInterval(-36_000),
                unreadCount: 0,
                isPinned: false,
                isMuted: false,
                isArchived: false,
                isVerified: false
            ),
            Conversation(
                id: chatTest,
                kind: .privateChat,
                title: "test",
                subtitle: test.presence.label,
                avatarInitials: "T",
                avatarHex: test.accentHex,
                participants: [me, test],
                lastMessage: testMessages.first,
                updatedAt: now.addingTimeInterval(-72_000),
                unreadCount: 0,
                isPinned: false,
                isMuted: false,
                isArchived: false,
                isVerified: false
            ),
            Conversation(
                id: chatOwner,
                kind: .privateChat,
                title: "群主 01",
                subtitle: owner.lastSeenText,
                avatarInitials: owner.initials,
                avatarHex: owner.accentHex,
                participants: [me, owner],
                lastMessage: ownerMessages.last,
                updatedAt: now.addingTimeInterval(-96_000),
                unreadCount: 0,
                isPinned: false,
                isMuted: false,
                isArchived: false,
                isVerified: false
            ),
            Conversation(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000006")!,
                kind: .privateChat,
                title: "kkkk03",
                subtitle: "https://hsgram.cloud/+HPPpf9cyT910iSx6ywRU",
                avatarInitials: kkk03.initials,
                avatarHex: kkk03.accentHex,
                participants: [me, kkk03],
                lastMessage: nil,
                updatedAt: now.addingTimeInterval(-160_000),
                unreadCount: 0,
                isPinned: false,
                isMuted: false,
                isArchived: false,
                isVerified: false
            )
        ]

        let settings = [
            SettingsItem(id: "account", icon: "lock.shield.fill", title: "账号与安全", subtitle: "邮箱、手机号、登录设备和验证码", accentHex: 0x3478F6, destination: .accountSecurity),
            SettingsItem(id: "privacy", icon: "hand.raised.fill", title: "隐私设置", subtitle: "黑名单、最后上线、资料可见性", accentHex: 0x33B7C7, destination: .privacy),
            SettingsItem(id: "notifications", icon: "bell.badge.fill", title: "通知设置", subtitle: "消息预览、声音、免打扰", accentHex: 0xFF9F2E, destination: .notifications),
            SettingsItem(id: "chat", icon: "bubble.left.and.text.bubble.right.fill", title: "聊天设置", subtitle: "输入、贴纸、文件和自动下载", accentHex: 0x8B5FD3, destination: .chat),
            SettingsItem(id: "appearance", icon: "paintpalette.fill", title: "外观设置", subtitle: "默认浅色、聊天主题、壁纸和字体", accentHex: 0x8B5FD3, destination: .appearance),
            SettingsItem(id: "storage", icon: "internaldrive.fill", title: "存储与数据", subtitle: "缓存、流量和自动清理", accentHex: 0x58C75A, destination: .storage),
            SettingsItem(id: "devices", icon: "iphone.gen3", title: "设备管理", subtitle: "在线设备和登录记录", accentHex: 0x6468F1, destination: .devices),
            SettingsItem(id: "about", icon: "info.circle.fill", title: "关于 HSgram", subtitle: "版本、协议和原创资源说明", accentHex: 0x8E8E93, destination: .about)
        ]

        return Payload(
            currentUser: me,
            users: [me, kk, owner, test, member02, admin03, carl, kkk05, user123, kkk03],
            conversations: conversations.sorted {
                $0.isPinned == $1.isPinned ? $0.updatedAt > $1.updatedAt : $0.isPinned
            },
            messages: [
                chatSystem: systemMessages,
                chatGroup: groupMessages,
                chatTestSuper: testSuperMessages,
                chatTest: testMessages,
                chatOwner: ownerMessages
            ],
            groups: [group],
            contacts: [
                Contact(id: kk.id, user: kk, note: "在线", isFavorite: true),
                Contact(id: owner.id, user: owner, note: owner.lastSeenText, isFavorite: true),
                Contact(id: test.id, user: test, note: test.lastSeenText, isFavorite: false),
                Contact(id: member02.id, user: member02, note: member02.lastSeenText, isFavorite: false),
                Contact(id: admin03.id, user: admin03, note: admin03.lastSeenText, isFavorite: false),
                Contact(id: carl.id, user: carl, note: carl.lastSeenText, isFavorite: false)
            ],
            settings: settings,
            theme: .defaultLight,
            recentSearches: ["测试超级群", "邀请链接", "权限"],
            stickers: stickers
        )
    }

    private static func makeUser(
        uuid: String,
        name: String,
        username: String,
        initials: String,
        hex: UInt32,
        presence: UserPresence,
        lastSeen: String
    ) -> User {
        User(
            id: UUID(uuidString: uuid)!,
            displayName: name,
            username: username,
            email: "\(username)@hsgram.local",
            phone: nil,
            bio: "HSgram mock user",
            initials: initials,
            accentHex: hex,
            presence: presence,
            lastSeenText: lastSeen
        )
    }
}
