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

    var showsNameField: Bool { mode == .register }
    var usesEmailLogin: Bool { loginMethod == .email }

    var primaryActionTitle: String {
        guard codeSent else { return "获取验证码" }
        return mode == .login ? "登录 HSgram" : "创建 HSgram 账号"
    }

    var helperText: String {
        "邮箱为主入口，手机号作为辅助登录。当前原型使用 Mock 验证码，后续可接入真实 API。"
    }

    var verificationSeed: String { "1024" }

    var switchPrompt: String {
        mode.switchPrompt
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
                query.isEmpty ||
                    conversation.title.localizedCaseInsensitiveContains(query) ||
                    conversation.subtitle.localizedCaseInsensitiveContains(query) ||
                    (conversation.lastMessage?.body.localizedCaseInsensitiveContains(query) ?? false)
            }
    }

    var isFiltering: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct HSChatRoomViewModel {
    let conversationID: UUID
    let conversation: Conversation?
    let messages: [Message]
    let currentUser: User
    let group: HSGroup?
    let themeConfig: ThemeConfig

    var title: String {
        conversation?.title ?? "聊天"
    }

    var subtitle: String? {
        if let group {
            return "\(group.memberCount) 位成员"
        }
        return conversation?.subtitle
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
        let content = message.body.isEmpty ? message.attachment?.title ?? message.sticker?.title ?? "附件" : message.body
        return "转发：\(content)"
    }

    func makeAttachment(kind: AttachmentKind) -> Attachment {
        switch kind {
        case .image:
            return Attachment(
                id: UUID(),
                kind: .image,
                title: "新图片",
                subtitle: "960 x 720",
                previewSystemImage: "photo",
                accentHex: 0x48A8F5
            )
        case .file:
            return Attachment(
                id: UUID(),
                kind: .file,
                title: "设计文件.pdf",
                subtitle: "1.8 MB",
                previewSystemImage: "doc.text.fill",
                accentHex: 0xF5A12A
            )
        case .voice:
            return Attachment(
                id: UUID(),
                kind: .voice,
                title: "语音消息",
                subtitle: "00:08",
                previewSystemImage: "waveform",
                accentHex: 0x58C75A
            )
        case .link:
            return Attachment(
                id: UUID(),
                kind: .link,
                title: "hsgram.cloud",
                subtitle: "邀请链接",
                previewSystemImage: "link",
                accentHex: 0x8B5FD3
            )
        case .location:
            return Attachment(
                id: UUID(),
                kind: .location,
                title: "当前位置",
                subtitle: "附近 40 米",
                previewSystemImage: "mappin.circle.fill",
                accentHex: 0xF04B41
            )
        case .checklist:
            return Attachment(
                id: UUID(),
                kind: .checklist,
                title: "核对清单",
                subtitle: "3 个项目",
                previewSystemImage: "checklist.checked",
                accentHex: 0x58C75A
            )
        }
    }
}

struct HSContactsViewModel {
    let contacts: [Contact]
    let query: String

    var filteredContacts: [Contact] {
        contacts.filter {
            query.isEmpty ||
                $0.user.displayName.localizedCaseInsensitiveContains(query) ||
                $0.user.username.localizedCaseInsensitiveContains(query)
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
    let groups: [HSGroup]
    let conversations: [Conversation]
    let messages: [Message]
    let recentSearches: [String]

    var userResults: [User] {
        users.filter {
            $0.id != currentUser.id &&
                (query.isEmpty ||
                    $0.displayName.localizedCaseInsensitiveContains(query) ||
                    $0.username.localizedCaseInsensitiveContains(query))
        }
    }

    var groupResults: [HSGroup] {
        groups.filter {
            query.isEmpty ||
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.about.localizedCaseInsensitiveContains(query)
        }
    }

    var messageResults: [Message] {
        guard !query.isEmpty else { return [] }
        return messages.filter { $0.body.localizedCaseInsensitiveContains(query) }
    }

    func conversation(for group: HSGroup) -> Conversation? {
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
                return message.kind == .image || message.kind == .sticker
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

    let accentChoices: [UInt32] = [0x8B5FD3, 0x48A8F5, 0x58C75A, 0xF5A12A, 0xF04B41]

    var incomingPreview: Message {
        Message(
            conversationID: UUID(),
            sender: users.first ?? currentUser,
            body: "这是默认浅色聊天主题的收到消息预览。",
            sentAt: Date().addingTimeInterval(-120),
            isOutgoing: false,
            reactions: [MessageReaction(emoji: "👍", count: 1, reactorInitials: ["K"])]
        )
    }

    var outgoingPreview: Message {
        Message(
            conversationID: UUID(),
            sender: currentUser,
            body: "粉紫线稿只是一个可切换聊天主题，不是整站默认色。",
            sentAt: Date(),
            isOutgoing: true,
            deliveryState: .read,
            reactions: [MessageReaction(emoji: "♥", count: 1, isSelectedByCurrentUser: true, reactorInitials: ["L"])]
        )
    }
}
