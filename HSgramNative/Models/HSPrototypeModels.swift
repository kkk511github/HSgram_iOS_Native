import Foundation
import SwiftUI

struct HSThemeColor: Codable, Hashable {
    var hex: UInt32
    var alpha: Double

    init(_ hex: UInt32, alpha: Double = 1.0) {
        self.hex = hex
        self.alpha = alpha
    }

    var color: Color {
        Color(hex: hex, alpha: alpha)
    }
}

enum ThemeInterfaceMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

enum ChatWallpaperType: String, Codable, CaseIterable, Identifiable, Hashable {
    case defaultLight
    case solidColor
    case gradient
    case image
    case imageWithOverlay
    case gradientPattern
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .defaultLight: return "默认浅色"
        case .solidColor: return "纯色"
        case .gradient: return "渐变"
        case .image: return "图片"
        case .imageWithOverlay: return "图片蒙层"
        case .gradientPattern: return "渐变线稿"
        case .dark: return "暗色"
        }
    }
}

struct ChatThemeConfig: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var incomingBubbleColor: HSThemeColor
    var outgoingBubbleColor: HSThemeColor
    var incomingTextColor: HSThemeColor
    var outgoingTextColor: HSThemeColor
    var chatWallpaperType: ChatWallpaperType
    var chatWallpaperColor: HSThemeColor
    var chatWallpaperGradient: [HSThemeColor]
    var chatWallpaperImage: String?
    var chatWallpaperOverlayColor: HSThemeColor
    var chatPatternOpacity: Double
    var chatPatternInkColor: HSThemeColor = HSThemeColor(0x7894A8, alpha: 0.52)
    var chatWallpaperSecondaryColor: HSThemeColor = HSThemeColor(0xCDE9F9)
    var chatWallpaperHighlightColor: HSThemeColor = HSThemeColor(0xFFFFFF, alpha: 0.22)
    var reactionPillColor: HSThemeColor
    var reactionAvatarColor: HSThemeColor
    var inputBarBackgroundColor: HSThemeColor
    var inputFieldBackgroundColor: HSThemeColor
    var dateDividerColor: HSThemeColor
    var pinnedBannerColor: HSThemeColor

    static let defaultLight = ChatThemeConfig(
        id: "default-light",
        name: "默认浅色",
        incomingBubbleColor: HSThemeColor(0xFFFFFF),
        outgoingBubbleColor: HSThemeColor(0xE1FFC7),
        incomingTextColor: HSThemeColor(0x101014),
        outgoingTextColor: HSThemeColor(0x101014),
        chatWallpaperType: .defaultLight,
        chatWallpaperColor: HSThemeColor(0xDCE8F3),
        chatWallpaperGradient: [HSThemeColor(0xEAF3FB), HSThemeColor(0xD9E8F4)],
        chatWallpaperImage: nil,
        chatWallpaperOverlayColor: HSThemeColor(0xFFFFFF, alpha: 0.0),
        chatPatternOpacity: 0.12,
        chatPatternInkColor: HSThemeColor(0x7894A8, alpha: 0.52),
        chatWallpaperSecondaryColor: HSThemeColor(0xCDE9F9),
        chatWallpaperHighlightColor: HSThemeColor(0xFFFFFF, alpha: 0.22),
        reactionPillColor: HSThemeColor(0xE9F1FA),
        reactionAvatarColor: HSThemeColor(0x58C7D0),
        inputBarBackgroundColor: HSThemeColor(0xF7F7F7, alpha: 0.86),
        inputFieldBackgroundColor: HSThemeColor(0xFFFFFF, alpha: 0.92),
        dateDividerColor: HSThemeColor(0x6C7B89, alpha: 0.52),
        pinnedBannerColor: HSThemeColor(0xFFFFFF, alpha: 0.82)
    )

    static let blushPattern = ChatThemeConfig(
        id: "blush-pattern",
        name: "粉紫线稿",
        incomingBubbleColor: HSThemeColor(0xFFFFFF),
        outgoingBubbleColor: HSThemeColor(0xEEDFFF),
        incomingTextColor: HSThemeColor(0x111014),
        outgoingTextColor: HSThemeColor(0x171019),
        chatWallpaperType: .gradientPattern,
        chatWallpaperColor: HSThemeColor(0xF3C1E7),
        chatWallpaperGradient: [
            HSThemeColor(0xD45DC2),
            HSThemeColor(0xF3A9C5),
            HSThemeColor(0xF7C29A),
            HSThemeColor(0xB9A7EF)
        ],
        chatWallpaperImage: nil,
        chatWallpaperOverlayColor: HSThemeColor(0xFFFFFF, alpha: 0.10),
        chatPatternOpacity: 0.22,
        chatPatternInkColor: HSThemeColor(0x7F346C, alpha: 0.85),
        chatWallpaperSecondaryColor: HSThemeColor(0xF6C2A2),
        chatWallpaperHighlightColor: HSThemeColor(0xFFFFFF, alpha: 0.22),
        reactionPillColor: HSThemeColor(0x8F63CF, alpha: 0.90),
        reactionAvatarColor: HSThemeColor(0x68D6DD),
        inputBarBackgroundColor: HSThemeColor(0xF8DCF4, alpha: 0.74),
        inputFieldBackgroundColor: HSThemeColor(0xFFF4FF, alpha: 0.82),
        dateDividerColor: HSThemeColor(0xC85E95, alpha: 0.78),
        pinnedBannerColor: HSThemeColor(0xFFF4EA, alpha: 0.82)
    )

    static let dark = ChatThemeConfig(
        id: "dark",
        name: "暗色",
        incomingBubbleColor: HSThemeColor(0x22252E),
        outgoingBubbleColor: HSThemeColor(0x155A7A),
        incomingTextColor: HSThemeColor(0xF4F6F8),
        outgoingTextColor: HSThemeColor(0xF4F6F8),
        chatWallpaperType: .dark,
        chatWallpaperColor: HSThemeColor(0x10141B),
        chatWallpaperGradient: [HSThemeColor(0x111827), HSThemeColor(0x070A10)],
        chatWallpaperImage: nil,
        chatWallpaperOverlayColor: HSThemeColor(0x000000, alpha: 0.18),
        chatPatternOpacity: 0.10,
        chatPatternInkColor: HSThemeColor(0xFFFFFF, alpha: 0.28),
        chatWallpaperSecondaryColor: HSThemeColor(0x070A10),
        chatWallpaperHighlightColor: HSThemeColor(0xFFFFFF, alpha: 0.12),
        reactionPillColor: HSThemeColor(0x263447),
        reactionAvatarColor: HSThemeColor(0x58C7D0),
        inputBarBackgroundColor: HSThemeColor(0x161A21, alpha: 0.86),
        inputFieldBackgroundColor: HSThemeColor(0x242A34, alpha: 0.92),
        dateDividerColor: HSThemeColor(0x324054, alpha: 0.78),
        pinnedBannerColor: HSThemeColor(0x202631, alpha: 0.82)
    )
}

struct ThemeConfig: Identifiable, Codable, Hashable {
    var id: UUID
    var interfaceMode: ThemeInterfaceMode
    var fontScale: Double
    var appBackgroundColor: HSThemeColor
    var groupedBackgroundColor: HSThemeColor
    var cardBackgroundColor: HSThemeColor
    var navigationBarBackground: HSThemeColor
    var primaryAccentColor: HSThemeColor
    var secondaryAccentColor: HSThemeColor
    var incomingBubbleColor: HSThemeColor
    var outgoingBubbleColor: HSThemeColor
    var incomingTextColor: HSThemeColor
    var outgoingTextColor: HSThemeColor
    var chatWallpaperType: ChatWallpaperType
    var chatWallpaperColor: HSThemeColor
    var chatWallpaperGradient: [HSThemeColor]
    var chatWallpaperImage: String?
    var chatPatternOpacity: Double
    var reactionPillColor: HSThemeColor
    var reactionAvatarColor: HSThemeColor
    var inputBarBackgroundColor: HSThemeColor
    var inputFieldBackgroundColor: HSThemeColor
    var tabBarBackgroundColor: HSThemeColor
    var separatorColor: HSThemeColor
    var primaryTextColor: HSThemeColor
    var secondaryTextColor: HSThemeColor
    var mutedTextColor: HSThemeColor
    var successColor: HSThemeColor
    var destructiveColor: HSThemeColor
    var warningColor: HSThemeColor
    var sheetBackgroundColor: HSThemeColor
    var inverseTextColor: HSThemeColor
    var glassStrokeColor: HSThemeColor
    var shadowColor: HSThemeColor
    var subtleOverlayColor: HSThemeColor
    var bubbleStrokeColor: HSThemeColor
    var avatarOnlineRingColor: HSThemeColor
    var profileHeaderBlendColor: HSThemeColor
    var cameraTileColor: HSThemeColor
    var stickerInkColor: HSThemeColor
    var activeChatTheme: ChatThemeConfig
    var availableChatThemes: [ChatThemeConfig]

    init(
        id: UUID = UUID(),
        interfaceMode: ThemeInterfaceMode = .light,
        fontScale: Double = 1.0,
        appBackgroundColor: HSThemeColor = HSThemeColor(0xFFFFFF),
        groupedBackgroundColor: HSThemeColor = HSThemeColor(0xF2F3F7),
        cardBackgroundColor: HSThemeColor = HSThemeColor(0xFFFFFF),
        navigationBarBackground: HSThemeColor = HSThemeColor(0xFFFFFF, alpha: 0.82),
        primaryAccentColor: HSThemeColor = HSThemeColor(0x8B5FD3),
        secondaryAccentColor: HSThemeColor = HSThemeColor(0x48A8F5),
        incomingBubbleColor: HSThemeColor = ChatThemeConfig.defaultLight.incomingBubbleColor,
        outgoingBubbleColor: HSThemeColor = ChatThemeConfig.defaultLight.outgoingBubbleColor,
        incomingTextColor: HSThemeColor = ChatThemeConfig.defaultLight.incomingTextColor,
        outgoingTextColor: HSThemeColor = ChatThemeConfig.defaultLight.outgoingTextColor,
        chatWallpaperType: ChatWallpaperType = ChatThemeConfig.defaultLight.chatWallpaperType,
        chatWallpaperColor: HSThemeColor = ChatThemeConfig.defaultLight.chatWallpaperColor,
        chatWallpaperGradient: [HSThemeColor] = ChatThemeConfig.defaultLight.chatWallpaperGradient,
        chatWallpaperImage: String? = nil,
        chatPatternOpacity: Double = ChatThemeConfig.defaultLight.chatPatternOpacity,
        reactionPillColor: HSThemeColor = ChatThemeConfig.defaultLight.reactionPillColor,
        reactionAvatarColor: HSThemeColor = ChatThemeConfig.defaultLight.reactionAvatarColor,
        inputBarBackgroundColor: HSThemeColor = ChatThemeConfig.defaultLight.inputBarBackgroundColor,
        inputFieldBackgroundColor: HSThemeColor = ChatThemeConfig.defaultLight.inputFieldBackgroundColor,
        tabBarBackgroundColor: HSThemeColor = HSThemeColor(0xFFFFFF, alpha: 0.84),
        separatorColor: HSThemeColor = HSThemeColor(0xDADDE3),
        primaryTextColor: HSThemeColor = HSThemeColor(0x050505),
        secondaryTextColor: HSThemeColor = HSThemeColor(0x8E8E93),
        mutedTextColor: HSThemeColor = HSThemeColor(0xC6C7CD),
        successColor: HSThemeColor = HSThemeColor(0x58C75A),
        destructiveColor: HSThemeColor = HSThemeColor(0xF04B41),
        warningColor: HSThemeColor = HSThemeColor(0xF5A12A),
        sheetBackgroundColor: HSThemeColor = HSThemeColor(0xF8F8FA, alpha: 0.94),
        inverseTextColor: HSThemeColor = HSThemeColor(0xFFFFFF),
        glassStrokeColor: HSThemeColor = HSThemeColor(0xFFFFFF, alpha: 0.52),
        shadowColor: HSThemeColor = HSThemeColor(0x000000, alpha: 0.12),
        subtleOverlayColor: HSThemeColor = HSThemeColor(0x000000, alpha: 0.05),
        bubbleStrokeColor: HSThemeColor = HSThemeColor(0x000000, alpha: 0.10),
        avatarOnlineRingColor: HSThemeColor = HSThemeColor(0xFFFFFF),
        profileHeaderBlendColor: HSThemeColor = HSThemeColor(0xC8D6E7),
        cameraTileColor: HSThemeColor = HSThemeColor(0x462214),
        stickerInkColor: HSThemeColor = HSThemeColor(0x1E1E22),
        activeChatTheme: ChatThemeConfig = .defaultLight,
        availableChatThemes: [ChatThemeConfig] = [.defaultLight, .blushPattern, .dark]
    ) {
        self.id = id
        self.interfaceMode = interfaceMode
        self.fontScale = fontScale
        self.appBackgroundColor = appBackgroundColor
        self.groupedBackgroundColor = groupedBackgroundColor
        self.cardBackgroundColor = cardBackgroundColor
        self.navigationBarBackground = navigationBarBackground
        self.primaryAccentColor = primaryAccentColor
        self.secondaryAccentColor = secondaryAccentColor
        self.incomingBubbleColor = incomingBubbleColor
        self.outgoingBubbleColor = outgoingBubbleColor
        self.incomingTextColor = incomingTextColor
        self.outgoingTextColor = outgoingTextColor
        self.chatWallpaperType = chatWallpaperType
        self.chatWallpaperColor = chatWallpaperColor
        self.chatWallpaperGradient = chatWallpaperGradient
        self.chatWallpaperImage = chatWallpaperImage
        self.chatPatternOpacity = chatPatternOpacity
        self.reactionPillColor = reactionPillColor
        self.reactionAvatarColor = reactionAvatarColor
        self.inputBarBackgroundColor = inputBarBackgroundColor
        self.inputFieldBackgroundColor = inputFieldBackgroundColor
        self.tabBarBackgroundColor = tabBarBackgroundColor
        self.separatorColor = separatorColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.mutedTextColor = mutedTextColor
        self.successColor = successColor
        self.destructiveColor = destructiveColor
        self.warningColor = warningColor
        self.sheetBackgroundColor = sheetBackgroundColor
        self.inverseTextColor = inverseTextColor
        self.glassStrokeColor = glassStrokeColor
        self.shadowColor = shadowColor
        self.subtleOverlayColor = subtleOverlayColor
        self.bubbleStrokeColor = bubbleStrokeColor
        self.avatarOnlineRingColor = avatarOnlineRingColor
        self.profileHeaderBlendColor = profileHeaderBlendColor
        self.cameraTileColor = cameraTileColor
        self.stickerInkColor = stickerInkColor
        self.activeChatTheme = activeChatTheme
        self.availableChatThemes = availableChatThemes
    }

    static let defaultLight = ThemeConfig()

    static let blushExample: ThemeConfig = {
        var config = ThemeConfig()
        config.apply(chatTheme: .blushPattern)
        return config
    }()

    mutating func apply(chatTheme: ChatThemeConfig) {
        activeChatTheme = chatTheme
        incomingBubbleColor = chatTheme.incomingBubbleColor
        outgoingBubbleColor = chatTheme.outgoingBubbleColor
        incomingTextColor = chatTheme.incomingTextColor
        outgoingTextColor = chatTheme.outgoingTextColor
        chatWallpaperType = chatTheme.chatWallpaperType
        chatWallpaperColor = chatTheme.chatWallpaperColor
        chatWallpaperGradient = chatTheme.chatWallpaperGradient
        chatWallpaperImage = chatTheme.chatWallpaperImage
        chatPatternOpacity = chatTheme.chatPatternOpacity
        reactionPillColor = chatTheme.reactionPillColor
        reactionAvatarColor = chatTheme.reactionAvatarColor
        inputBarBackgroundColor = chatTheme.inputBarBackgroundColor
        inputFieldBackgroundColor = chatTheme.inputFieldBackgroundColor
    }
}

enum UserPresence: String, Codable, Hashable {
    case online
    case offline
    case typing
    case recently

    var label: String {
        switch self {
        case .online: return "在线"
        case .offline: return "离线"
        case .typing: return "正在输入..."
        case .recently: return "最近上线"
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
    var lastSeenText: String

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
    case location
    case checklist
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
    var reactorInitials: [String]

    init(
        id: UUID = UUID(),
        emoji: String,
        count: Int,
        isSelectedByCurrentUser: Bool = false,
        reactorInitials: [String] = []
    ) {
        self.id = id
        self.emoji = emoji
        self.count = count
        self.isSelectedByCurrentUser = isSelectedByCurrentUser
        self.reactorInitials = reactorInitials
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
    case sticker
}

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    var conversationID: UUID
    var sender: User
    var body: String
    var kind: MessageKind
    var attachment: Attachment?
    var sticker: HSSticker?
    var sentAt: Date
    var isOutgoing: Bool
    var deliveryState: MessageDeliveryState
    var reactions: [MessageReaction]
    var replyPreview: String?
    var forwardSource: String?
    var mentions: [String]
    var senderRole: String?

    init(
        id: UUID = UUID(),
        conversationID: UUID,
        sender: User,
        body: String,
        kind: MessageKind = .text,
        attachment: Attachment? = nil,
        sticker: HSSticker? = nil,
        sentAt: Date = Date(),
        isOutgoing: Bool,
        deliveryState: MessageDeliveryState = .sent,
        reactions: [MessageReaction] = [],
        replyPreview: String? = nil,
        forwardSource: String? = nil,
        mentions: [String] = [],
        senderRole: String? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.sender = sender
        self.body = body
        self.kind = kind
        self.attachment = attachment
        self.sticker = sticker
        self.sentAt = sentAt
        self.isOutgoing = isOutgoing
        self.deliveryState = deliveryState
        self.reactions = reactions
        self.replyPreview = replyPreview
        self.forwardSource = forwardSource
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
    var isVerified: Bool

    var isGroup: Bool {
        kind == .groupChat
    }
}

struct GroupPermissionState: Codable, Hashable {
    var canSendMessages: Bool
    var canSendMedia: Bool
    var canAddMembers: Bool
    var canPinMessages: Bool
    var canChangeInfo: Bool
    var canEditOwnTags: Bool
    var slowModeSeconds: Double
}

struct RemovedUser: Identifiable, Codable, Hashable {
    let id: UUID
    var user: User
    var removedBy: String
}

struct GroupInviteLink: Identifiable, Codable, Hashable {
    let id: UUID
    var link: String
    var shortLink: String
    var joinedCount: Int
    var requiresApproval: Bool
}

struct HSGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var about: String
    var announcement: String
    var members: [User]
    var adminIDs: Set<UUID>
    var ownerID: UUID
    var avatarInitials: String
    var avatarHex: UInt32
    var username: String
    var inviteLinks: [GroupInviteLink]
    var removedUsers: [RemovedUser]
    var permissions: GroupPermissionState
    var reactionsEnabled: Bool
    var reactionLimit: Double
    var allowedReactions: String

    var memberCount: Int {
        members.count
    }

    func role(for user: User) -> String? {
        if user.id == ownerID { return "所有者" }
        if adminIDs.contains(user.id) { return "管理员" }
        return nil
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

struct HSSticker: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var symbol: String
    var baseHex: UInt32
    var accentHex: UInt32
    var mood: String

    init(
        id: UUID = UUID(),
        title: String,
        symbol: String,
        baseHex: UInt32,
        accentHex: UInt32,
        mood: String
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.baseHex = baseHex
        self.accentHex = accentHex
        self.mood = mood
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

enum HSDateText {
    static func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MM/dd"
        }
        return formatter.string(from: date)
    }

    static func chatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}
