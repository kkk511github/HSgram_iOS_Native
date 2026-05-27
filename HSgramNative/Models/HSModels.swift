import Foundation

struct HSAPIResponse<Value: Decodable>: Decodable {
    let ok: Bool
    let data: Value?
    let code: String?
    let message: String?
}

struct HSUserSession: Codable, Equatable {
    let token: String
    let userID: Int64
    let displayName: String
    let email: String
}

struct HSEmailStartResponse: Decodable {
    let transactionID: String
    let emailPattern: String
    let codeLength: Int
}

struct HSWorkspaceCounts: Codable, Equatable {
    let joinRequests: Int64
    let ruleAcks: Int64
    let trustEvents: Int64
    let contactRequests: Int64

    enum CodingKeys: String, CodingKey {
        case joinRequests = "join_requests"
        case ruleAcks = "rule_acks"
        case trustEvents = "trust_events"
        case contactRequests = "contact_requests"
    }
}

struct HSWorkspaceAction: Codable, Identifiable, Hashable {
    let id: String
    let kind: String
    let title: String
    let subtitle: String
    let badge: String?
    let count: Int64
    let route: String
    let groupID: Int64?
    let peerID: Int64?
    let peerNamespace: String?

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case subtitle
        case badge
        case count
        case route
        case groupID = "group_id"
        case peerID = "peer_id"
        case peerNamespace = "peer_namespace"
    }
}

struct HSWorkspaceSummary: Codable, Equatable {
    let userID: Int64
    let source: String
    let generatedAt: Int64
    let counts: HSWorkspaceCounts
    let actions: [HSWorkspaceAction]

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case source
        case generatedAt = "generated_at"
        case counts
        case actions
    }
}

struct HSChat: Codable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let subtitle: String
    let unreadCount: Int
    let isCircle: Bool
    let updatedAt: Date?
}

struct HSMessage: Codable, Identifiable, Hashable {
    let id: Int64
    let dialogID: Int64
    let authorID: Int64
    let authorName: String
    let text: String
    let kind: String?
    let sentAt: Date
    let isOutgoing: Bool
}

struct HSMessageAction: Codable, Hashable {
    let ok: Bool
    let messageID: Int64?
    let dialogID: Int64?
    let pts: Int?
    let ptsCount: Int?
}

struct HSCircle: Codable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let memberCount: Int
    let pendingRequests: Int
    let role: String
}

struct HSSupergroup: Codable, Identifiable, Hashable {
    let id: Int64
    let channelID: Int64
    let title: String
    let about: String
    let memberCount: Int
    let pendingRequests: Int
    let role: String
    let isMegagroup: Bool
    let isBroadcast: Bool
}

typealias HSChannel = HSSupergroup

struct HSSupergroupMember: Codable, Identifiable, Hashable {
    let id: Int64
    let displayName: String
    let username: String?
    let role: String
    let rank: String?
    let joinedAt: Date?
    let isSelf: Bool
}

struct HSSupergroupAdminRights: Codable, Hashable {
    var changeInfo = false
    var postMessages = false
    var editMessages = false
    var deleteMessages = false
    var banUsers = false
    var inviteUsers = false
    var pinMessages = false
    var addAdmins = false
    var anonymous = false
    var manageCall = false
    var other = false
    var manageTopics = false
    var postStories = false
    var editStories = false
    var deleteStories = false
    var manageDirectMessages = false
    var manageRanks = false
}

struct HSSupergroupBannedRights: Codable, Hashable {
    var viewMessages = false
    var sendMessages = false
    var sendMedia = false
    var sendStickers = false
    var sendGifs = false
    var sendGames = false
    var sendInline = false
    var embedLinks = false
    var sendPolls = false
    var changeInfo = false
    var inviteUsers = false
    var pinMessages = false
    var manageTopics = false
    var sendPhotos = false
    var sendVideos = false
    var sendRoundvideos = false
    var sendAudios = false
    var sendVoices = false
    var sendDocs = false
    var sendPlain = false
    var editRank = false
    var untilDate: Int = 0
}

struct HSSupergroupSettings: Codable, Hashable {
    var slowModeSeconds: Int?
    var participantsHidden: Bool?
    var preHistoryHidden: Bool?
    var joinToSend: Bool?
    var joinRequest: Bool?
}

struct HSSupergroupAdminLogEvent: Codable, Identifiable, Hashable {
    let id: Int64
    let date: Date
    let actorID: Int64
    let actorName: String
    let action: String
    let description: String
}

struct HSExportedMessageLink: Codable, Hashable {
    let link: String
    let html: String
}

struct HSExportedInvite: Codable, Hashable {
    let link: String
    let title: String?
    let adminID: Int64
    let date: Date
    let expireDate: Int?
    let usageLimit: Int?
    let usage: Int?
    let requested: Int?
    let revoked: Bool
    let permanent: Bool
    let requestNeeded: Bool
}

struct HSContact: Codable, Identifiable, Hashable {
    let id: Int64
    let displayName: String
    let username: String?
    let status: String
}

struct HSTrustItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let severity: String
}

struct HSDeviceSession: Codable, Identifiable, Hashable {
    let id: Int64
    let current: Bool
    let deviceModel: String
    let platform: String
    let systemVersion: String
    let appName: String
    let appVersion: String
    let ip: String
    let country: String
    let region: String
    let dateActive: Date?
}

struct HSEntitlement: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let state: String
    let included: Bool
}

struct HSAdminTool: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let route: String
    let status: String
    let requiresOwner: Bool?
}

struct HSStickerSet: Codable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let shortName: String
    let count: Int
    let installed: Bool
    let featured: Bool
    let official: Bool
    let premium: Bool
    let animated: Bool
    let videos: Bool
    let thumbDocument: Int64?
}

struct HSReaction: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let premium: Bool
    let inactive: Bool
}

struct HSAssetCatalog: Codable, Hashable {
    let installedStickers: [HSStickerSet]
    let featuredStickers: [HSStickerSet]
    let reactions: [HSReaction]
}

struct HSAccountProfile: Codable, Equatable {
    let userID: Int64
    let displayName: String
    let firstName: String
    let lastName: String
    let username: String?
    let about: String
    let email: String
}

struct HSSettingsItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let value: String
    let status: String
}

struct HSPrivacySettings: Codable, Hashable {
    let items: [HSSettingsItem]
}

struct HSNotifyScopeSettings: Codable, Hashable {
    var enabled: Bool
    var showPreviews: Bool
    var silent: Bool
    var muteUntil: Int?

    static let enabledDefault = HSNotifyScopeSettings(enabled: true, showPreviews: true, silent: false, muteUntil: nil)
}

struct HSNotificationSettings: Codable, Hashable {
    var privateChats: HSNotifyScopeSettings
    var groups: HSNotifyScopeSettings
    var channels: HSNotifyScopeSettings
}

struct HSStorageSettings: Codable, Hashable {
    let mediaBytes: Int64
    let documentBytes: Int64
    let cacheBytes: Int64
    let otherBytes: Int64
    let installedStickerSets: Int
    let featuredStickerSets: Int
    let availableReactions: Int
    let autoDownloadWiFi: Bool
    let autoDownloadCellular: Bool
}
