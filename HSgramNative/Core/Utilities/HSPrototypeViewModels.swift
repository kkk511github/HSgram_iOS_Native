import Foundation
import SwiftUI

enum HSAuthMode: Hashable {
    case login
    case register

    var switchPrompt: String {
        self == .login ? "没有账号？注册" : "已有账号？登录"
    }
}

enum HSAuthLoginMethod: Hashable {
    case email
    case phone
}

struct HSAuthViewModel {
    let mode: HSAuthMode
    let loginMethod: HSAuthLoginMethod
    let codeSent: Bool

    var showsNameField: Bool {
        mode == .register
    }

    var usesEmailLogin: Bool {
        loginMethod == .email
    }

    var primaryActionTitle: String {
        guard codeSent else { return "获取验证码" }
        return mode == .login ? "登录 HSgram" : "创建 HSgram 账号"
    }

    var helperText: String {
        "邮箱为主入口，手机号作为辅助登录。当前原型使用 Mock 验证码，后续可接入真实 API。"
    }

    var verificationSeed: String {
        "1024"
    }

    func toggledMode() -> HSAuthMode {
        mode == .login ? .register : .login
    }
}

struct HSChatListViewModel {
    let conversations: [Conversation]
    let query: String

    var visibleConversations: [Conversation] {
        conversations
            .filter { !$0.isArchived }
            .filter { conversation in
                query.isEmpty
                    || conversation.title.localizedCaseInsensitiveContains(query)
                    || (conversation.lastMessage?.body.localizedCaseInsensitiveContains(query) ?? false)
            }
    }

    var isFiltering: Bool {
        !query.isEmpty
    }
}

struct HSChatRoomViewModel {
    let conversationID: UUID
    let conversation: Conversation?
    let messages: [Message]
    let currentUser: User
    let group: Group?
    let themeConfig: ThemeConfig

    var title: String {
        conversation?.title ?? "聊天"
    }

    var subtitle: String? {
        conversation?.subtitle
    }

    var isGroupChat: Bool {
        conversation?.isGroup == true
    }

    var groupAnnouncement: String {
        group?.announcement ?? "暂无公告"
    }

    var profilePeer: User? {
        conversation?.participants.first { $0.id != currentUser.id }
    }

    func replyDraft(for message: Message) -> String {
        "@\(message.sender.username) "
    }

    func forwardText(for message: Message) -> String {
        "转发：\(message.body.isEmpty ? message.attachment?.title ?? "附件" : message.body)"
    }

    func makeAttachment(kind: AttachmentKind) -> Attachment {
        Attachment(
            id: UUID(),
            kind: kind,
            title: kind == .image ? "新图片" : kind == .voice ? "语音消息" : kind == .link ? "hsgram.app" : "设计文档.pdf",
            subtitle: kind == .voice ? "00:08" : kind == .image ? "960 x 720" : "1.8 MB",
            previewSystemImage: kind == .image ? "photo" : kind == .voice ? "waveform" : kind == .link ? "link" : "doc.text.fill",
            accentHex: kind == .voice ? 0x34C759 : kind == .image ? 0x168BFF : 0xFF9500
        )
    }
}

struct HSContactsViewModel {
    let contacts: [Contact]
    let query: String

    var filteredContacts: [Contact] {
        contacts.filter {
            query.isEmpty
                || $0.user.displayName.localizedCaseInsensitiveContains(query)
                || $0.user.username.localizedCaseInsensitiveContains(query)
        }
    }

    var groupedContacts: [(String, [Contact])] {
        Dictionary(grouping: filteredContacts, by: \.sectionTitle)
            .map { ($0.key, $0.value.sorted { $0.user.displayName < $1.user.displayName }) }
            .sorted { $0.0 < $1.0 }
    }
}

struct HSGlobalSearchViewModel {
    let query: String
    let users: [User]
    let currentUser: User
    let groups: [Group]
    let conversations: [Conversation]
    let messages: [Message]
    let recentSearches: [String]

    var userResults: [User] {
        users.filter {
            $0.id != currentUser.id
                && (query.isEmpty
                    || $0.displayName.localizedCaseInsensitiveContains(query)
                    || $0.username.localizedCaseInsensitiveContains(query))
        }
    }

    var groupResults: [Group] {
        groups.filter {
            query.isEmpty
                || $0.title.localizedCaseInsensitiveContains(query)
                || $0.about.localizedCaseInsensitiveContains(query)
        }
    }

    var messageResults: [Message] {
        guard !query.isEmpty else { return [] }
        return messages.filter { $0.body.localizedCaseInsensitiveContains(query) }
    }

    func conversation(for group: Group) -> Conversation? {
        conversations.first { $0.groupID == group.id }
    }
}

struct HSSettingsHomeViewModel {
    let currentUser: User
    let settingsItems: [SettingsItem]
}

struct HSProfileViewModel {
    let user: User
    let conversations: [Conversation]

    func conversationForMessage(currentUser: User) -> Conversation? {
        conversations.first { conversation in
            conversation.participants.contains(user) && conversation.participants.contains(currentUser)
        }
    }
}

struct HSMediaLibraryViewModel {
    let messages: [Message]
    let selectedTab: HSMediaTab

    var items: [Message] {
        messages.filter { message in
            switch selectedTab {
            case .media:
                return message.kind == .image
            case .files:
                return message.kind == .file || message.attachment?.kind == .file
            case .links:
                return message.body.contains("http") || message.attachment?.kind == .link
            }
        }
    }
}

struct HSAppearanceViewModel {
    let themeConfig: ThemeConfig
    let users: [User]
    let currentUser: User

    let accentChoices: [UInt32] = [0x168BFF, 0x30B7C5, 0x34C759, 0xFF9500, 0xAF52DE]

    var incomingPreview: Message {
        Message(
            conversationID: UUID(),
            sender: users.first ?? currentUser,
            body: "这是一条收到的消息预览。",
            sentAt: Date().addingTimeInterval(-120),
            isOutgoing: false
        )
    }

    var outgoingPreview: Message {
        Message(
            conversationID: UUID(),
            sender: currentUser,
            body: "主题色和背景会实时影响界面。",
            sentAt: Date(),
            isOutgoing: true,
            deliveryState: .read,
            reactions: [MessageReaction(emoji: "👍", count: 1, isSelectedByCurrentUser: true)]
        )
    }
}

enum HSMediaTab: String, CaseIterable, Identifiable {
    case media
    case files
    case links

    var id: String { rawValue }

    var title: String {
        switch self {
        case .media: return "媒体"
        case .files: return "文件"
        case .links: return "链接"
        }
    }

    var icon: String {
        switch self {
        case .media: return "photo.on.rectangle"
        case .files: return "doc.text"
        case .links: return "link"
        }
    }
}
