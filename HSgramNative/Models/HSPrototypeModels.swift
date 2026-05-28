import Foundation

enum UserPresence: String, Codable, Hashable {
    case online
    case offline
    case typing
    case recently

    var label: String {
        switch self {
        case .online:
            return "在线"
        case .offline:
            return "离线"
        case .typing:
            return "正在输入..."
        case .recently:
            return "最近在线"
        }
    }
}

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var username: String
    var email: String
    var phone: String?
    var bio: String
    var initials: String
    var accentHex: UInt32
    var presence: UserPresence

    var isOnline: Bool {
        presence == .online || presence == .typing
    }
}

enum ConversationKind: String, Codable, Hashable {
    case privateChat
    case groupChat
}

enum AttachmentKind: String, Codable, Hashable {
    case image
    case file
    case voice
    case link
}

struct Attachment: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: AttachmentKind
    var title: String
    var subtitle: String
    var previewSystemImage: String
    var accentHex: UInt32
}

struct MessageReaction: Identifiable, Codable, Hashable {
    let id: UUID
    var emoji: String
    var count: Int
    var isSelectedByCurrentUser: Bool

    init(id: UUID = UUID(), emoji: String, count: Int, isSelectedByCurrentUser: Bool = false) {
        self.id = id
        self.emoji = emoji
        self.count = count
        self.isSelectedByCurrentUser = isSelectedByCurrentUser
    }
}

enum MessageDeliveryState: String, Codable, Hashable {
    case sending
    case sent
    case delivered
    case read
}

enum MessageKind: String, Codable, Hashable {
    case text
    case image
    case file
    case voice
}

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    var conversationID: UUID
    var sender: User
    var body: String
    var kind: MessageKind
    var attachment: Attachment?
    var sentAt: Date
    var isOutgoing: Bool
    var deliveryState: MessageDeliveryState
    var reactions: [MessageReaction]
    var replyPreview: String?
    var mentions: [String]
    var senderRole: String?

    init(
        id: UUID = UUID(),
        conversationID: UUID,
        sender: User,
        body: String,
        kind: MessageKind = .text,
        attachment: Attachment? = nil,
        sentAt: Date = Date(),
        isOutgoing: Bool,
        deliveryState: MessageDeliveryState = .sent,
        reactions: [MessageReaction] = [],
        replyPreview: String? = nil,
        mentions: [String] = [],
        senderRole: String? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.sender = sender
        self.body = body
        self.kind = kind
        self.attachment = attachment
        self.sentAt = sentAt
        self.isOutgoing = isOutgoing
        self.deliveryState = deliveryState
        self.reactions = reactions
        self.replyPreview = replyPreview
        self.mentions = mentions
        self.senderRole = senderRole
    }
}

struct Conversation: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: ConversationKind
    var title: String
    var subtitle: String
    var avatarInitials: String
    var avatarHex: UInt32
    var participants: [User]
    var groupID: UUID?
    var lastMessage: Message?
    var updatedAt: Date
    var unreadCount: Int
    var isPinned: Bool
    var isMuted: Bool
    var isArchived: Bool

    var isGroup: Bool {
        kind == .groupChat
    }
}

struct Group: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var about: String
    var announcement: String
    var members: [User]
    var adminIDs: Set<UUID>
    var avatarHex: UInt32

    var memberCount: Int {
        members.count
    }

    func role(for user: User) -> String? {
        adminIDs.contains(user.id) ? "管理员" : nil
    }
}

struct Contact: Identifiable, Codable, Hashable {
    let id: UUID
    var user: User
    var note: String
    var isFavorite: Bool

    var sectionTitle: String {
        String(user.displayName.prefix(1)).uppercased()
    }
}

enum SettingsDestination: String, Codable, Hashable {
    case profile
    case accountSecurity
    case privacy
    case notifications
    case chat
    case appearance
    case storage
    case devices
    case about
    case logout
}

struct SettingsItem: Identifiable, Codable, Hashable {
    let id: String
    var icon: String
    var title: String
    var subtitle: String
    var accentHex: UInt32
    var destination: SettingsDestination
}

enum ThemeInterfaceMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:
            return "跟随系统"
        case .light:
            return "浅色"
        case .dark:
            return "深色"
        }
    }
}

enum ChatBubbleStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case soft
    case compact
    case glass

    var id: String { rawValue }

    var label: String {
        switch self {
        case .soft:
            return "柔和"
        case .compact:
            return "紧凑"
        case .glass:
            return "通透"
        }
    }
}

enum ChatBackgroundStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case clean
    case pattern
    case mist

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clean:
            return "纯净"
        case .pattern:
            return "细纹"
        case .mist:
            return "薄雾"
        }
    }
}

struct ThemeConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var interfaceMode: ThemeInterfaceMode
    var bubbleStyle: ChatBubbleStyle
    var fontScale: Double
    var accentHex: UInt32
    var chatBackground: ChatBackgroundStyle

    init(
        id: UUID = UUID(),
        interfaceMode: ThemeInterfaceMode = .system,
        bubbleStyle: ChatBubbleStyle = .soft,
        fontScale: Double = 1.0,
        accentHex: UInt32 = 0x168BFF,
        chatBackground: ChatBackgroundStyle = .pattern
    ) {
        self.id = id
        self.interfaceMode = interfaceMode
        self.bubbleStyle = bubbleStyle
        self.fontScale = fontScale
        self.accentHex = accentHex
        self.chatBackground = chatBackground
    }
}

enum HSDateText {
    static func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "M/d"
        return formatter.string(from: date)
    }

    static func chatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
