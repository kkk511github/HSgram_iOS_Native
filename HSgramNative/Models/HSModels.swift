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

struct HSPasswordRecoveryResponse: Decodable {
    let emailPattern: String
    let codeLength: Int
}

struct HSTermsOfService: Codable, Equatable {
    let id: String
    let text: String
    let minAgeConfirm: Int?
    let isPopup: Bool
}

struct HSLoginPasswordSettings: Codable, Equatable {
    let hasPassword: Bool
    let hasRecovery: Bool
    let hint: String?
    let pendingEmailPattern: String?
    let loginEmailPattern: String?
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

enum HSChatPeerKind: String, Codable, Hashable {
    case user
    case chat
    case channel
}

struct HSDialogReadState: Codable, Hashable {
    let dialogID: Int64
    let readInboxMaxID: Int64
    let readOutboxMaxID: Int64
    let unreadCount: Int
    let isMarkedUnread: Bool

    private enum CodingKeys: String, CodingKey {
        case dialogID = "dialog_id"
        case readInboxMaxID = "read_inbox_max_id"
        case readOutboxMaxID = "read_outbox_max_id"
        case unreadCount = "unread_count"
        case isMarkedUnread = "is_marked_unread"
    }
}

struct HSChat: Codable, Identifiable, Hashable {
    static let archiveFolderID = 1

    let id: Int64
    let title: String
    let subtitle: String
    let unreadCount: Int
    let readInboxMaxID: Int64
    let readOutboxMaxID: Int64
    let topMessageID: Int64?
    let topMessageIsOutgoing: Bool
    let isMarkedUnread: Bool
    let isPinned: Bool
    let folderID: Int?
    let isCircle: Bool
    let peerKind: HSChatPeerKind
    let isBot: Bool
    let isContact: Bool
    let isBroadcast: Bool
    let isMuted: Bool
    let updatedAt: Date?

    var isArchived: Bool {
        folderID == Self.archiveFolderID
    }

    init(
        id: Int64,
        title: String,
        subtitle: String,
        unreadCount: Int,
        readInboxMaxID: Int64 = 0,
        readOutboxMaxID: Int64 = 0,
        topMessageID: Int64? = nil,
        topMessageIsOutgoing: Bool = false,
        isMarkedUnread: Bool = false,
        isPinned: Bool = false,
        folderID: Int? = nil,
        isCircle: Bool,
        peerKind: HSChatPeerKind = .user,
        isBot: Bool = false,
        isContact: Bool = false,
        isBroadcast: Bool = false,
        isMuted: Bool = false,
        updatedAt: Date?
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.unreadCount = unreadCount
        self.readInboxMaxID = readInboxMaxID
        self.readOutboxMaxID = readOutboxMaxID
        self.topMessageID = topMessageID
        self.topMessageIsOutgoing = topMessageIsOutgoing
        self.isMarkedUnread = isMarkedUnread
        self.isPinned = isPinned
        self.folderID = folderID
        self.isCircle = isCircle
        self.peerKind = peerKind
        self.isBot = isBot
        self.isContact = isContact
        self.isBroadcast = isBroadcast
        self.isMuted = isMuted
        self.updatedAt = updatedAt
    }

    func withFolderID(_ folderID: Int?) -> HSChat {
        HSChat(
            id: id,
            title: title,
            subtitle: subtitle,
            unreadCount: unreadCount,
            readInboxMaxID: readInboxMaxID,
            readOutboxMaxID: readOutboxMaxID,
            topMessageID: topMessageID,
            topMessageIsOutgoing: topMessageIsOutgoing,
            isMarkedUnread: isMarkedUnread,
            isPinned: isPinned,
            folderID: folderID,
            isCircle: isCircle,
            peerKind: peerKind,
            isBot: isBot,
            isContact: isContact,
            isBroadcast: isBroadcast,
            isMuted: isMuted,
            updatedAt: updatedAt
        )
    }

    func withPinned(_ isPinned: Bool) -> HSChat {
        HSChat(
            id: id,
            title: title,
            subtitle: subtitle,
            unreadCount: unreadCount,
            readInboxMaxID: readInboxMaxID,
            readOutboxMaxID: readOutboxMaxID,
            topMessageID: topMessageID,
            topMessageIsOutgoing: topMessageIsOutgoing,
            isMarkedUnread: isMarkedUnread,
            isPinned: isPinned,
            folderID: folderID,
            isCircle: isCircle,
            peerKind: peerKind,
            isBot: isBot,
            isContact: isContact,
            isBroadcast: isBroadcast,
            isMuted: isMuted,
            updatedAt: updatedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case unreadCount = "unread_count"
        case readInboxMaxID = "read_inbox_max_id"
        case readOutboxMaxID = "read_outbox_max_id"
        case topMessageID = "top_message_id"
        case topMessageIsOutgoing = "top_message_is_outgoing"
        case isMarkedUnread = "is_marked_unread"
        case isPinned = "is_pinned"
        case folderID = "folder_id"
        case isCircle = "is_circle"
        case peerKind = "peer_kind"
        case isBot = "is_bot"
        case isContact = "is_contact"
        case isBroadcast = "is_broadcast"
        case isMuted = "is_muted"
        case updatedAt = "updated_at"
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case unreadCount
        case readInboxMaxID
        case readOutboxMaxID
        case topMessageID
        case topMessageIsOutgoing
        case isMarkedUnread
        case isPinned
        case folderID
        case isCircle
        case peerKind
        case isBot
        case isContact
        case isBroadcast
        case isMuted
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount)
            ?? legacyContainer.decodeIfPresent(Int.self, forKey: .unreadCount)
            ?? 0
        readInboxMaxID = try container.decodeIfPresent(Int64.self, forKey: .readInboxMaxID)
            ?? legacyContainer.decodeIfPresent(Int64.self, forKey: .readInboxMaxID)
            ?? 0
        readOutboxMaxID = try container.decodeIfPresent(Int64.self, forKey: .readOutboxMaxID)
            ?? legacyContainer.decodeIfPresent(Int64.self, forKey: .readOutboxMaxID)
            ?? 0
        topMessageID = try container.decodeIfPresent(Int64.self, forKey: .topMessageID)
            ?? legacyContainer.decodeIfPresent(Int64.self, forKey: .topMessageID)
        topMessageIsOutgoing = try container.decodeIfPresent(Bool.self, forKey: .topMessageIsOutgoing)
            ?? legacyContainer.decodeIfPresent(Bool.self, forKey: .topMessageIsOutgoing)
            ?? false
        isMarkedUnread = try container.decodeIfPresent(Bool.self, forKey: .isMarkedUnread)
            ?? legacyContainer.decodeIfPresent(Bool.self, forKey: .isMarkedUnread)
            ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned)
            ?? legacyContainer.decodeIfPresent(Bool.self, forKey: .isPinned)
            ?? false
        folderID = try container.decodeIfPresent(Int.self, forKey: .folderID)
            ?? legacyContainer.decodeIfPresent(Int.self, forKey: .folderID)
        isCircle = try container.decodeIfPresent(Bool.self, forKey: .isCircle)
            ?? legacyContainer.decodeIfPresent(Bool.self, forKey: .isCircle)
            ?? false
        peerKind = try container.decodeIfPresent(HSChatPeerKind.self, forKey: .peerKind)
            ?? legacyContainer.decodeIfPresent(HSChatPeerKind.self, forKey: .peerKind)
            ?? (isCircle ? .chat : .user)
        isBot = try container.decodeIfPresent(Bool.self, forKey: .isBot)
            ?? legacyContainer.decodeIfPresent(Bool.self, forKey: .isBot)
            ?? false
        isContact = try container.decodeIfPresent(Bool.self, forKey: .isContact)
            ?? legacyContainer.decodeIfPresent(Bool.self, forKey: .isContact)
            ?? false
        isBroadcast = try container.decodeIfPresent(Bool.self, forKey: .isBroadcast)
            ?? legacyContainer.decodeIfPresent(Bool.self, forKey: .isBroadcast)
            ?? false
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted)
            ?? legacyContainer.decodeIfPresent(Bool.self, forKey: .isMuted)
            ?? false
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
            ?? legacyContainer.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(unreadCount, forKey: .unreadCount)
        try container.encode(readInboxMaxID, forKey: .readInboxMaxID)
        try container.encode(readOutboxMaxID, forKey: .readOutboxMaxID)
        try container.encodeIfPresent(topMessageID, forKey: .topMessageID)
        try container.encode(topMessageIsOutgoing, forKey: .topMessageIsOutgoing)
        try container.encode(isMarkedUnread, forKey: .isMarkedUnread)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encodeIfPresent(folderID, forKey: .folderID)
        try container.encode(isCircle, forKey: .isCircle)
        try container.encode(peerKind, forKey: .peerKind)
        try container.encode(isBot, forKey: .isBot)
        try container.encode(isContact, forKey: .isContact)
        try container.encode(isBroadcast, forKey: .isBroadcast)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct HSChatListFilterPeerCategories: OptionSet, Codable, Hashable {
    let rawValue: Int32

    static let contacts = HSChatListFilterPeerCategories(rawValue: 1 << 0)
    static let nonContacts = HSChatListFilterPeerCategories(rawValue: 1 << 1)
    static let groups = HSChatListFilterPeerCategories(rawValue: 1 << 2)
    static let channels = HSChatListFilterPeerCategories(rawValue: 1 << 3)
    static let bots = HSChatListFilterPeerCategories(rawValue: 1 << 4)

    static let all: HSChatListFilterPeerCategories = [
        .contacts,
        .nonContacts,
        .groups,
        .channels,
        .bots
    ]

    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
}

struct HSChatListFilterPeer: Codable, Hashable, Identifiable {
    enum PeerKind: String, Codable, Hashable {
        case user
        case chat
        case channel
    }

    var id: String {
        "\(kind.rawValue):\(peerID)"
    }

    let kind: PeerKind
    let peerID: Int64
    let dialogID: Int64
    let accessHash: Int64?
}

extension HSChat {
    private static let channelDialogPrefix: Int64 = -1_000_000_000_000

    var chatListFilterPeer: HSChatListFilterPeer {
        let kind: HSChatListFilterPeer.PeerKind
        let peerID: Int64
        switch peerKind {
        case .user:
            kind = .user
            peerID = id
        case .chat:
            kind = .chat
            peerID = id < 0 ? -id : id
        case .channel:
            kind = .channel
            peerID = id < Self.channelDialogPrefix ? Self.channelDialogPrefix - id : id
        }
        return HSChatListFilterPeer(kind: kind, peerID: peerID, dialogID: id, accessHash: nil)
    }
}

struct HSChatListFilter: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let emoticon: String?
    let color: Int?
    let isDefault: Bool
    let isShared: Bool
    let hasSharedLinks: Bool
    let categories: HSChatListFilterPeerCategories
    let excludeMuted: Bool
    let excludeRead: Bool
    let excludeArchived: Bool
    let includePeers: [HSChatListFilterPeer]
    let pinnedPeers: [HSChatListFilterPeer]
    let excludePeers: [HSChatListFilterPeer]
    let titleAnimationsEnabled: Bool

    var displayTitle: String {
        if isDefault {
            return "全部"
        }
        return title.isEmpty ? "文件夹 \(id)" : title
    }

    var isEditable: Bool {
        !isDefault && !isShared
    }
}

struct HSChatListFiltersState: Codable, Hashable {
    let tagsEnabled: Bool
    let filters: [HSChatListFilter]
}

struct HSChatListSharedPeer: Codable, Hashable, Identifiable {
    var id: String {
        peer.id
    }

    let peer: HSChatListFilterPeer
    let title: String
}

struct HSChatListSharedInvite: Codable, Hashable, Identifiable {
    var id: String {
        slug
    }

    let title: String
    let url: String
    let slug: String
    let peers: [HSChatListSharedPeer]
}

struct HSChatListExportedInviteResult: Codable, Hashable {
    let filter: HSChatListFilter
    let invite: HSChatListSharedInvite
}

struct HSChatListExportedInvitesPage: Codable, Hashable {
    let invites: [HSChatListSharedInvite]
}

struct HSChatListInvitePreview: Codable, Hashable {
    let title: String
    let emoticon: String?
    let filterID: Int?
    let isAlreadyJoined: Bool
    let peers: [HSChatListSharedPeer]
    let missingPeers: [HSChatListSharedPeer]
    let alreadyPeers: [HSChatListSharedPeer]

    enum CodingKeys: String, CodingKey {
        case title
        case emoticon
        case filterID = "filter_id"
        case isAlreadyJoined = "is_already_joined"
        case peers
        case missingPeers = "missing_peers"
        case alreadyPeers = "already_peers"
    }
}

struct HSChatListUpdates: Codable, Hashable {
    let missingPeers: [HSChatListSharedPeer]

    enum CodingKeys: String, CodingKey {
        case missingPeers = "missing_peers"
    }
}

struct HSMessageMediaLocation: Codable, Hashable {
    enum LocationKind: String, Codable, Hashable {
        case photo
        case document
    }

    let kind: LocationKind
    let id: Int64
    let accessHash: Int64
    let fileReference: Data
    let dcID: Int?
    let thumbnailSize: String
}

struct HSPollAnswerInput: Codable, Hashable {
    let text: String
    let option: Data?

    init(text: String, option: Data? = nil) {
        self.text = text
        self.option = option
    }
}

struct HSPollAnswer: Codable, Hashable {
    let text: String
    let option: Data
}

struct HSPoll: Codable, Hashable {
    let id: Int64
    let question: String
    let answers: [HSPollAnswer]
    let isClosed: Bool
    let isPublic: Bool
    let isMultipleChoice: Bool
    let isQuiz: Bool
    let closePeriod: Int?
    let closeDate: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case question
        case answers
        case isClosed = "is_closed"
        case isPublic = "is_public"
        case isMultipleChoice = "is_multiple_choice"
        case isQuiz = "is_quiz"
        case closePeriod = "close_period"
        case closeDate = "close_date"
    }
}

struct HSPollAnswerVoters: Codable, Hashable {
    let option: Data
    let voters: Int
    let isChosen: Bool
    let isCorrect: Bool

    private enum CodingKeys: String, CodingKey {
        case option
        case voters
        case isChosen = "is_chosen"
        case isCorrect = "is_correct"
    }
}

struct HSPollResults: Codable, Hashable {
    let totalVoters: Int?
    let answers: [HSPollAnswerVoters]
    let recentVoterIDs: [Int64]
    let solution: String?
    let isMin: Bool

    private enum CodingKeys: String, CodingKey {
        case totalVoters = "total_voters"
        case answers
        case recentVoterIDs = "recent_voter_ids"
        case solution
        case isMin = "is_min"
    }
}

struct HSPollState: Codable, Hashable {
    let poll: HSPoll
    let results: HSPollResults
}

struct HSPollVote: Codable, Hashable {
    let peerID: Int64
    let dialogID: Int64
    let options: [Data]
    let date: Date

    private enum CodingKeys: String, CodingKey {
        case peerID = "peer_id"
        case dialogID = "dialog_id"
        case options
        case date
    }
}

struct HSPollVotesPage: Codable, Hashable {
    let count: Int
    let votes: [HSPollVote]
    let nextOffset: String?

    private enum CodingKeys: String, CodingKey {
        case count
        case votes
        case nextOffset = "next_offset"
    }
}

struct HSTodoItem: Codable, Hashable, Identifiable {
    let id: Int
    let title: String
}

struct HSTodoList: Codable, Hashable {
    let title: String
    let items: [HSTodoItem]
    let othersCanAppend: Bool
    let othersCanComplete: Bool

    private enum CodingKeys: String, CodingKey {
        case title
        case items
        case othersCanAppend = "others_can_append"
        case othersCanComplete = "others_can_complete"
    }
}

struct HSTodoCompletion: Codable, Hashable {
    let itemID: Int
    let completedByPeerID: Int64
    let completedByDialogID: Int64
    let completedAt: Date

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case completedByPeerID = "completed_by_peer_id"
        case completedByDialogID = "completed_by_dialog_id"
        case completedAt = "completed_at"
    }
}

struct HSTodoState: Codable, Hashable {
    let todo: HSTodoList
    let completions: [HSTodoCompletion]
}

struct HSMediaTransferProgress: Equatable {
    let completedBytes: Int64
    let totalBytes: Int64?

    var fractionCompleted: Double? {
        guard let totalBytes, totalBytes > 0 else {
            return nil
        }
        return min(1, max(0, Double(completedBytes) / Double(totalBytes)))
    }
}

struct HSMessageMedia: Codable, Hashable {
    enum MediaKind: String, Codable, Hashable {
        case photo
        case video
        case file
        case gif
        case audio
        case voice
        case sticker
        case webpage
        case unknown
    }

    let kind: MediaKind
    let fileName: String?
    let mimeType: String?
    let size: Int64?
    let width: Int?
    let height: Int?
    let duration: Double?
    let waveform: Data?
    let webPage: HSWebPagePreview?
    let location: HSMessageMediaLocation?
    let poll: HSPollState?
    let todo: HSTodoState?

    init(
        kind: MediaKind,
        fileName: String?,
        mimeType: String?,
        size: Int64?,
        width: Int?,
        height: Int?,
        duration: Double?,
        waveform: Data? = nil,
        webPage: HSWebPagePreview? = nil,
        location: HSMessageMediaLocation? = nil,
        poll: HSPollState? = nil,
        todo: HSTodoState? = nil
    ) {
        self.kind = kind
        self.fileName = fileName
        self.mimeType = mimeType
        self.size = size
        self.width = width
        self.height = height
        self.duration = duration
        self.waveform = waveform
        self.webPage = webPage
        self.location = location
        self.poll = poll
        self.todo = todo
    }
}

struct HSWebPagePreview: Codable, Hashable {
    let id: Int64?
    let url: String?
    let displayURL: String?
    let type: String?
    let siteName: String?
    let title: String?
    let description: String?
    let author: String?
    let duration: Double?
    let embedURL: String?
    let embedType: String?
    let embedWidth: Int?
    let embedHeight: Int?
    let photo: HSWebPagePreviewMedia?
    let document: HSWebPagePreviewMedia?
    let isPending: Bool
}

struct HSWebPagePreviewMedia: Codable, Hashable {
    let kind: HSMessageMedia.MediaKind
    let mimeType: String?
    let size: Int64?
    let width: Int?
    let height: Int?
    let duration: Double?
    let location: HSMessageMediaLocation?
}

enum HSVoiceWaveformCodec {
    static func encode(levels: [Double], sampleCount: Int = 64) -> Data? {
        guard !levels.isEmpty, sampleCount > 0 else {
            return nil
        }
        let bucketSize = Double(levels.count) / Double(sampleCount)
        var values: [UInt8] = []
        values.reserveCapacity(sampleCount)

        for index in 0..<sampleCount {
            let start = Int((Double(index) * bucketSize).rounded(.down))
            let end = min(levels.count, max(start + 1, Int((Double(index + 1) * bucketSize).rounded(.up))))
            let slice = levels[start..<end]
            let level = min(1, max(0, slice.max() ?? 0))
            values.append(UInt8(clamping: Int((level * 31).rounded())))
        }

        guard values.contains(where: { $0 > 0 }) else {
            return nil
        }
        return packFiveBitSamples(values)
    }

    static func decode(_ data: Data?, fallbackCount: Int = 36) -> [Double] {
        guard let data, !data.isEmpty else {
            return fallback(count: fallbackCount)
        }
        let values = unpackFiveBitSamples(data).prefix(96)
        guard values.contains(where: { $0 > 0 }) else {
            return fallback(count: fallbackCount)
        }
        return values.map { max(0.08, Double($0) / 31.0) }
    }

    private static func packFiveBitSamples(_ samples: [UInt8]) -> Data {
        var bytes: [UInt8] = []
        var buffer = 0
        var bitCount = 0
        for sample in samples {
            buffer |= Int(sample & 0x1f) << bitCount
            bitCount += 5
            while bitCount >= 8 {
                bytes.append(UInt8(buffer & 0xff))
                buffer >>= 8
                bitCount -= 8
            }
        }
        if bitCount > 0 {
            bytes.append(UInt8(buffer & 0xff))
        }
        return Data(bytes)
    }

    private static func unpackFiveBitSamples(_ data: Data) -> [UInt8] {
        var samples: [UInt8] = []
        var buffer = 0
        var bitCount = 0
        for byte in data {
            buffer |= Int(byte) << bitCount
            bitCount += 8
            while bitCount >= 5 {
                samples.append(UInt8(buffer & 0x1f))
                buffer >>= 5
                bitCount -= 5
            }
        }
        return samples
    }

    private static func fallback(count: Int) -> [Double] {
        let pattern: [Double] = [0.28, 0.45, 0.7, 0.52, 0.36, 0.82, 0.48, 0.62, 0.34, 0.56, 0.74, 0.42]
        return (0..<max(1, count)).map { pattern[$0 % pattern.count] }
    }
}

enum HSSharedMediaFilter: String, Codable, CaseIterable, Identifiable, Hashable {
    case media
    case files
    case links
    case gifs
    case voice
    case music

    var id: String {
        rawValue
    }
}

struct HSSharedMediaCounter: Codable, Identifiable, Hashable {
    let filter: HSSharedMediaFilter
    let count: Int

    var id: HSSharedMediaFilter {
        filter
    }
}

struct HSSharedMediaCalendarPeriod: Codable, Identifiable, Hashable {
    let date: Date
    let minMessageID: Int64
    let maxMessageID: Int64
    let count: Int
    let message: HSMessage?

    var id: Int64 {
        Int64(date.timeIntervalSince1970)
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case minMessageID = "min_message_id"
        case maxMessageID = "max_message_id"
        case count
        case message
    }
}

struct HSSharedMediaCalendar: Codable, Hashable {
    let count: Int
    let minDate: Date?
    let minMessageID: Int64?
    let offsetIDOffset: Int?
    let periods: [HSSharedMediaCalendarPeriod]
    let messages: [HSMessage]
    let inexact: Bool

    private enum CodingKeys: String, CodingKey {
        case count
        case minDate = "min_date"
        case minMessageID = "min_message_id"
        case offsetIDOffset = "offset_id_offset"
        case periods
        case messages
        case inexact
    }
}

struct HSSharedMediaPosition: Codable, Identifiable, Hashable {
    let messageID: Int64
    let date: Date
    let offset: Int

    var id: Int64 {
        messageID
    }

    private enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case date
        case offset
    }
}

struct HSSharedMediaPositions: Codable, Hashable {
    let count: Int
    let positions: [HSSharedMediaPosition]
}

struct HSMessageReaction: Codable, Identifiable, Hashable {
    let value: String
    let count: Int
    let isSelected: Bool
    let chosenOrder: Int?

    var id: String {
        value
    }
}

struct HSMessageCounters: Codable, Hashable {
    let viewCount: Int?
    let forwardCount: Int?
    let replyCount: Int

    init(viewCount: Int? = nil, forwardCount: Int? = nil, replyCount: Int = 0) {
        self.viewCount = viewCount
        self.forwardCount = forwardCount
        self.replyCount = replyCount
    }
}

struct HSMessage: Codable, Identifiable, Hashable {
    enum DeliveryState: String, Codable, Hashable {
        case sending
        case sent
        case read
        case failed
    }

    let id: Int64
    let dialogID: Int64
    let authorID: Int64
    let authorName: String
    let text: String
    let kind: String?
    let sentAt: Date
    let isOutgoing: Bool
    let deliveryState: DeliveryState
    let replyToMessageID: Int64?
    let media: HSMessageMedia?
    let reactions: [HSMessageReaction]
    let counters: HSMessageCounters
    let editDate: Date?
    let authorSignature: String?

    init(
        id: Int64,
        dialogID: Int64,
        authorID: Int64,
        authorName: String,
        text: String,
        kind: String?,
        sentAt: Date,
        isOutgoing: Bool,
        deliveryState: DeliveryState = .sent,
        replyToMessageID: Int64?,
        media: HSMessageMedia? = nil,
        reactions: [HSMessageReaction] = [],
        counters: HSMessageCounters = HSMessageCounters(),
        editDate: Date? = nil,
        authorSignature: String? = nil
    ) {
        self.id = id
        self.dialogID = dialogID
        self.authorID = authorID
        self.authorName = authorName
        self.text = text
        self.kind = kind
        self.sentAt = sentAt
        self.isOutgoing = isOutgoing
        self.deliveryState = deliveryState
        self.replyToMessageID = replyToMessageID
        self.media = media
        self.reactions = reactions
        self.counters = counters
        self.editDate = editDate
        self.authorSignature = authorSignature
    }

    func withDeliveryState(_ deliveryState: DeliveryState) -> HSMessage {
        HSMessage(
            id: id,
            dialogID: dialogID,
            authorID: authorID,
            authorName: authorName,
            text: text,
            kind: kind,
            sentAt: sentAt,
            isOutgoing: isOutgoing,
            deliveryState: deliveryState,
            replyToMessageID: replyToMessageID,
            media: media,
            reactions: reactions,
            counters: counters,
            editDate: editDate,
            authorSignature: authorSignature
        )
    }

    func withUpdatedReaction(_ value: String) -> HSMessage {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanValue.isEmpty else {
            return self
        }
        var updated = reactions.map { reaction in
            HSMessageReaction(
                value: reaction.value,
                count: max(0, reaction.count - (reaction.isSelected ? 1 : 0)),
                isSelected: false,
                chosenOrder: reaction.chosenOrder
            )
        }.filter { $0.count > 0 || $0.value == cleanValue }

        if let index = updated.firstIndex(where: { $0.value == cleanValue }) {
            let reaction = updated[index]
            updated[index] = HSMessageReaction(
                value: reaction.value,
                count: max(1, reaction.count + 1),
                isSelected: true,
                chosenOrder: reaction.chosenOrder ?? 0
            )
        } else {
            updated.append(HSMessageReaction(value: cleanValue, count: 1, isSelected: true, chosenOrder: 0))
        }

        updated.sort { lhs, rhs in
            switch (lhs.chosenOrder, rhs.chosenOrder) {
            case let (left?, right?) where left != right:
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.value < rhs.value
            }
        }

        return HSMessage(
            id: id,
            dialogID: dialogID,
            authorID: authorID,
            authorName: authorName,
            text: text,
            kind: kind,
            sentAt: sentAt,
            isOutgoing: isOutgoing,
            deliveryState: deliveryState,
            replyToMessageID: replyToMessageID,
            media: media,
            reactions: updated,
            counters: counters,
            editDate: editDate,
            authorSignature: authorSignature
        )
    }

    func withCounters(_ counters: HSMessageCounters) -> HSMessage {
        HSMessage(
            id: id,
            dialogID: dialogID,
            authorID: authorID,
            authorName: authorName,
            text: text,
            kind: kind,
            sentAt: sentAt,
            isOutgoing: isOutgoing,
            deliveryState: deliveryState,
            replyToMessageID: replyToMessageID,
            media: media,
            reactions: reactions,
            counters: counters,
            editDate: editDate,
            authorSignature: authorSignature
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case dialogID = "dialog_id"
        case authorID = "author_id"
        case authorName = "author_name"
        case text
        case kind
        case sentAt = "sent_at"
        case isOutgoing = "is_outgoing"
        case deliveryState = "delivery_state"
        case replyToMessageID = "reply_to_message_id"
        case media
        case reactions
        case counters
        case editDate = "edit_date"
        case authorSignature = "author_signature"
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case id
        case dialogID
        case authorID
        case authorName
        case text
        case kind
        case sentAt
        case isOutgoing
        case deliveryState
        case replyToMessageID
        case media
        case reactions
        case counters
        case editDate
        case authorSignature
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        dialogID = try container.decodeIfPresent(Int64.self, forKey: .dialogID)
            ?? legacyContainer.decode(Int64.self, forKey: .dialogID)
        authorID = try container.decodeIfPresent(Int64.self, forKey: .authorID)
            ?? legacyContainer.decode(Int64.self, forKey: .authorID)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
            ?? legacyContainer.decode(String.self, forKey: .authorName)
        text = try container.decode(String.self, forKey: .text)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        sentAt = try container.decodeIfPresent(Date.self, forKey: .sentAt)
            ?? legacyContainer.decode(Date.self, forKey: .sentAt)
        isOutgoing = try container.decodeIfPresent(Bool.self, forKey: .isOutgoing)
            ?? legacyContainer.decode(Bool.self, forKey: .isOutgoing)
        deliveryState = try container.decodeIfPresent(DeliveryState.self, forKey: .deliveryState)
            ?? legacyContainer.decodeIfPresent(DeliveryState.self, forKey: .deliveryState)
            ?? .sent
        replyToMessageID = try container.decodeIfPresent(Int64.self, forKey: .replyToMessageID)
            ?? legacyContainer.decodeIfPresent(Int64.self, forKey: .replyToMessageID)
        media = try container.decodeIfPresent(HSMessageMedia.self, forKey: .media)
            ?? legacyContainer.decodeIfPresent(HSMessageMedia.self, forKey: .media)
        reactions = try container.decodeIfPresent([HSMessageReaction].self, forKey: .reactions)
            ?? legacyContainer.decodeIfPresent([HSMessageReaction].self, forKey: .reactions)
            ?? []
        counters = try container.decodeIfPresent(HSMessageCounters.self, forKey: .counters)
            ?? legacyContainer.decodeIfPresent(HSMessageCounters.self, forKey: .counters)
            ?? HSMessageCounters()
        editDate = try container.decodeIfPresent(Date.self, forKey: .editDate)
            ?? legacyContainer.decodeIfPresent(Date.self, forKey: .editDate)
        authorSignature = try container.decodeIfPresent(String.self, forKey: .authorSignature)
            ?? legacyContainer.decodeIfPresent(String.self, forKey: .authorSignature)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dialogID, forKey: .dialogID)
        try container.encode(authorID, forKey: .authorID)
        try container.encode(authorName, forKey: .authorName)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encode(sentAt, forKey: .sentAt)
        try container.encode(isOutgoing, forKey: .isOutgoing)
        try container.encode(deliveryState, forKey: .deliveryState)
        try container.encodeIfPresent(replyToMessageID, forKey: .replyToMessageID)
        try container.encodeIfPresent(media, forKey: .media)
        try container.encode(reactions, forKey: .reactions)
        try container.encode(counters, forKey: .counters)
        try container.encodeIfPresent(editDate, forKey: .editDate)
        try container.encodeIfPresent(authorSignature, forKey: .authorSignature)
    }
}

struct HSMessageAction: Codable, Hashable {
    let ok: Bool
    let messageID: Int64?
    let dialogID: Int64?
    let pts: Int?
    let ptsCount: Int?
}

struct HSDiscussionMessage: Codable, Hashable {
    let rootMessage: HSMessage?
    let messages: [HSMessage]
    let maxMessageID: Int64?
    let readInboxMaxID: Int64?
    let readOutboxMaxID: Int64?
    let unreadCount: Int

    private enum CodingKeys: String, CodingKey {
        case rootMessage = "root_message"
        case messages
        case maxMessageID = "max_message_id"
        case readInboxMaxID = "read_inbox_max_id"
        case readOutboxMaxID = "read_outbox_max_id"
        case unreadCount = "unread_count"
    }
}

struct HSMessageViewState: Codable, Identifiable, Hashable {
    let messageID: Int64
    let counters: HSMessageCounters

    var id: Int64 {
        messageID
    }

    private enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case counters
    }
}

struct HSMessageReadParticipant: Codable, Identifiable, Hashable {
    let userID: Int64
    let readAt: Date?

    var id: Int64 {
        userID
    }

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case readAt = "read_at"
    }
}

struct HSMessageReactionPeer: Codable, Identifiable, Hashable {
    let peerID: Int64
    let dialogID: Int64
    let reaction: String
    let date: Date
    let big: Bool
    let unread: Bool
    let isSelectedByCurrentUser: Bool

    var id: String {
        "\(dialogID):\(peerID):\(reaction):\(Int(date.timeIntervalSince1970))"
    }

    private enum CodingKeys: String, CodingKey {
        case peerID = "peer_id"
        case dialogID = "dialog_id"
        case reaction
        case date
        case big
        case unread
        case isSelectedByCurrentUser = "is_selected_by_current_user"
    }
}

struct HSMessageReactionsPage: Codable, Hashable {
    let totalCount: Int
    let reactions: [HSMessageReactionPeer]
    let nextOffset: String?

    private enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case reactions
        case nextOffset = "next_offset"
    }
}

enum HSInputActivityKind: String, Codable, Hashable {
    case cancel
    case typing
    case recordingVoice = "recording_voice"
    case recordingVideo = "recording_video"
    case uploadingFile = "uploading_file"
    case uploadingPhoto = "uploading_photo"
    case uploadingVideo = "uploading_video"
    case uploadingVoice = "uploading_voice"
    case uploadingInstantVideo = "uploading_instant_video"
    case choosingSticker = "choosing_sticker"
}

struct HSInputActivity: Codable, Hashable {
    let dialogID: Int64
    let userID: Int64
    let kind: HSInputActivityKind
    let progress: Int?
    let expiresAt: Date

    private enum CodingKeys: String, CodingKey {
        case dialogID = "dialog_id"
        case userID = "user_id"
        case kind
        case progress
        case expiresAt = "expires_at"
    }
}

struct HSSyncState: Codable, Hashable {
    let pts: Int
    let qts: Int
    let date: Int
    let seq: Int
    let unreadCount: Int
}

struct HSSyncDifference: Codable, Hashable {
    let state: HSSyncState
    let messages: [HSMessage]
    let changedDialogIDs: [Int64]
    let readOutboxMaxIDsByDialogID: [Int64: Int64]
    let inputActivities: [HSInputActivity]
    let affectsAllDialogs: Bool
    let isTooLong: Bool
    let isSlice: Bool

    var requiresRefresh: Bool {
        isTooLong || affectsAllDialogs || !messages.isEmpty || !changedDialogIDs.isEmpty || !readOutboxMaxIDsByDialogID.isEmpty || !inputActivities.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case state
        case messages
        case changedDialogIDs = "changed_dialog_ids"
        case readOutboxMaxIDsByDialogID = "read_outbox_max_ids_by_dialog_id"
        case inputActivities = "input_activities"
        case affectsAllDialogs = "affects_all_dialogs"
        case isTooLong = "is_too_long"
        case isSlice = "is_slice"
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case state
        case messages
        case changedDialogIDs
        case readOutboxMaxIDsByDialogID
        case inputActivities
        case affectsAllDialogs
        case isTooLong
        case isSlice
    }

    init(
        state: HSSyncState,
        messages: [HSMessage],
        changedDialogIDs: [Int64],
        readOutboxMaxIDsByDialogID: [Int64: Int64] = [:],
        inputActivities: [HSInputActivity] = [],
        affectsAllDialogs: Bool,
        isTooLong: Bool,
        isSlice: Bool
    ) {
        self.state = state
        self.messages = messages
        self.changedDialogIDs = changedDialogIDs
        self.readOutboxMaxIDsByDialogID = readOutboxMaxIDsByDialogID
        self.inputActivities = inputActivities
        self.affectsAllDialogs = affectsAllDialogs
        self.isTooLong = isTooLong
        self.isSlice = isSlice
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        state = try container.decodeIfPresent(HSSyncState.self, forKey: .state)
            ?? legacyContainer.decode(HSSyncState.self, forKey: .state)
        messages = try container.decodeIfPresent([HSMessage].self, forKey: .messages)
            ?? legacyContainer.decodeIfPresent([HSMessage].self, forKey: .messages)
            ?? []
        changedDialogIDs = try container.decodeIfPresent([Int64].self, forKey: .changedDialogIDs)
            ?? legacyContainer.decodeIfPresent([Int64].self, forKey: .changedDialogIDs)
            ?? []
        readOutboxMaxIDsByDialogID = Self.decodeReadOutboxMaxIDs(from: container, key: .readOutboxMaxIDsByDialogID)
            ?? Self.decodeReadOutboxMaxIDs(from: legacyContainer, key: .readOutboxMaxIDsByDialogID)
            ?? [:]
        inputActivities = try container.decodeIfPresent([HSInputActivity].self, forKey: .inputActivities)
            ?? legacyContainer.decodeIfPresent([HSInputActivity].self, forKey: .inputActivities)
            ?? []
        affectsAllDialogs = try container.decodeIfPresent(Bool.self, forKey: .affectsAllDialogs)
            ?? legacyContainer.decodeIfPresent(Bool.self, forKey: .affectsAllDialogs)
            ?? false
        isTooLong = try container.decodeIfPresent(Bool.self, forKey: .isTooLong)
            ?? legacyContainer.decodeIfPresent(Bool.self, forKey: .isTooLong)
            ?? false
        isSlice = try container.decodeIfPresent(Bool.self, forKey: .isSlice)
            ?? legacyContainer.decodeIfPresent(Bool.self, forKey: .isSlice)
            ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(state, forKey: .state)
        try container.encode(messages, forKey: .messages)
        try container.encode(changedDialogIDs, forKey: .changedDialogIDs)
        try container.encode(Self.stringKeyedReadOutboxMaxIDs(from: readOutboxMaxIDsByDialogID), forKey: .readOutboxMaxIDsByDialogID)
        try container.encode(inputActivities, forKey: .inputActivities)
        try container.encode(affectsAllDialogs, forKey: .affectsAllDialogs)
        try container.encode(isTooLong, forKey: .isTooLong)
        try container.encode(isSlice, forKey: .isSlice)
    }

    private static func decodeReadOutboxMaxIDs<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        key: Key
    ) -> [Int64: Int64]? {
        if let stringMap = try? container.decodeIfPresent([String: Int64].self, forKey: key) {
            return intKeyedReadOutboxMaxIDs(from: stringMap)
        }
        if let intMap = try? container.decodeIfPresent([Int64: Int64].self, forKey: key) {
            return intMap
        }
        return nil
    }

    private static func intKeyedReadOutboxMaxIDs(from stringMap: [String: Int64]) -> [Int64: Int64] {
        var result: [Int64: Int64] = [:]
        for (key, value) in stringMap {
            guard let dialogID = Int64(key) else {
                continue
            }
            result[dialogID] = value
        }
        return result
    }

    private static func stringKeyedReadOutboxMaxIDs(from intMap: [Int64: Int64]) -> [String: Int64] {
        Dictionary(uniqueKeysWithValues: intMap.map { (String($0.key), $0.value) })
    }

    func withState(_ state: HSSyncState) -> HSSyncDifference {
        HSSyncDifference(
            state: state,
            messages: messages,
            changedDialogIDs: changedDialogIDs,
            readOutboxMaxIDsByDialogID: readOutboxMaxIDsByDialogID,
            inputActivities: inputActivities,
            affectsAllDialogs: affectsAllDialogs,
            isTooLong: isTooLong,
            isSlice: isSlice
        )
    }
}

struct HSDraft: Codable, Identifiable, Hashable {
    var id: Int64 { dialogID }

    let dialogID: Int64
    let text: String
    let replyToMessageID: Int64?
    let updatedAt: Date?
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
    let noForwards: Bool
    let disableSocialActions: Bool
    let participantsCountHidden: Bool
    let signaturesEnabled: Bool
    let signatureProfilesEnabled: Bool
    let antiSpamEnabled: Bool
    let linkedDiscussionGroupID: Int64?

    init(
        id: Int64,
        channelID: Int64,
        title: String,
        about: String,
        memberCount: Int,
        pendingRequests: Int,
        role: String,
        isMegagroup: Bool,
        isBroadcast: Bool,
        noForwards: Bool = false,
        disableSocialActions: Bool = false,
        participantsCountHidden: Bool = false,
        signaturesEnabled: Bool = false,
        signatureProfilesEnabled: Bool = false,
        antiSpamEnabled: Bool = false,
        linkedDiscussionGroupID: Int64? = nil
    ) {
        self.id = id
        self.channelID = channelID
        self.title = title
        self.about = about
        self.memberCount = memberCount
        self.pendingRequests = pendingRequests
        self.role = role
        self.isMegagroup = isMegagroup
        self.isBroadcast = isBroadcast
        self.noForwards = noForwards
        self.disableSocialActions = disableSocialActions
        self.participantsCountHidden = participantsCountHidden
        self.signaturesEnabled = signaturesEnabled
        self.signatureProfilesEnabled = signatureProfilesEnabled
        self.antiSpamEnabled = antiSpamEnabled
        self.linkedDiscussionGroupID = linkedDiscussionGroupID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case channelID
        case title
        case about
        case memberCount
        case pendingRequests
        case role
        case isMegagroup
        case isBroadcast
        case noForwards
        case disableSocialActions
        case participantsCountHidden
        case signaturesEnabled
        case signatureProfilesEnabled
        case antiSpamEnabled
        case linkedDiscussionGroupID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        channelID = try container.decode(Int64.self, forKey: .channelID)
        title = try container.decode(String.self, forKey: .title)
        about = try container.decode(String.self, forKey: .about)
        memberCount = try container.decode(Int.self, forKey: .memberCount)
        pendingRequests = try container.decode(Int.self, forKey: .pendingRequests)
        role = try container.decode(String.self, forKey: .role)
        isMegagroup = try container.decode(Bool.self, forKey: .isMegagroup)
        isBroadcast = try container.decode(Bool.self, forKey: .isBroadcast)
        noForwards = try container.decodeIfPresent(Bool.self, forKey: .noForwards) ?? false
        disableSocialActions = try container.decodeIfPresent(Bool.self, forKey: .disableSocialActions) ?? false
        participantsCountHidden = try container.decodeIfPresent(Bool.self, forKey: .participantsCountHidden) ?? false
        signaturesEnabled = try container.decodeIfPresent(Bool.self, forKey: .signaturesEnabled) ?? false
        signatureProfilesEnabled = try container.decodeIfPresent(Bool.self, forKey: .signatureProfilesEnabled) ?? false
        antiSpamEnabled = try container.decodeIfPresent(Bool.self, forKey: .antiSpamEnabled) ?? false
        linkedDiscussionGroupID = try container.decodeIfPresent(Int64.self, forKey: .linkedDiscussionGroupID)
    }

    func withNoForwards(_ value: Bool) -> HSSupergroup {
        withFeatureOverrides(noForwards: value)
    }

    func withFeatureOverrides(
        noForwards: Bool? = nil,
        disableSocialActions: Bool? = nil,
        participantsCountHidden: Bool? = nil,
        signaturesEnabled: Bool? = nil,
        signatureProfilesEnabled: Bool? = nil,
        antiSpamEnabled: Bool? = nil
    ) -> HSSupergroup {
        HSSupergroup(
            id: id,
            channelID: channelID,
            title: title,
            about: about,
            memberCount: memberCount,
            pendingRequests: pendingRequests,
            role: role,
            isMegagroup: isMegagroup,
            isBroadcast: isBroadcast,
            noForwards: noForwards ?? self.noForwards,
            disableSocialActions: disableSocialActions ?? self.disableSocialActions,
            participantsCountHidden: participantsCountHidden ?? self.participantsCountHidden,
            signaturesEnabled: signaturesEnabled ?? self.signaturesEnabled,
            signatureProfilesEnabled: signatureProfilesEnabled ?? self.signatureProfilesEnabled,
            antiSpamEnabled: antiSpamEnabled ?? self.antiSpamEnabled,
            linkedDiscussionGroupID: linkedDiscussionGroupID
        )
    }
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

enum HSSupergroupMemberFilter: String, Codable, Hashable {
    case recent
    case search
    case admins
    case contacts
    case bots
    case restricted
    case banned
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
    var noForwards: Bool?
    var disableSocialActions: Bool?
    var participantsCountHidden: Bool?
    var signaturesEnabled: Bool?
    var signatureProfilesEnabled: Bool?
    var antiSpamEnabled: Bool?
}

enum HSAddressNameAvailability: String, Codable, Hashable {
    case available
    case taken
    case invalid
    case purchaseAvailable = "purchase_available"
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

struct HSExportedContactToken: Codable, Hashable {
    let url: String
    let expires: Int
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

struct HSExportedInvitesPage: Codable, Hashable {
    let totalCount: Int
    let invites: [HSExportedInvite]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case invites
    }
}

struct HSInviteImporter: Codable, Identifiable, Hashable {
    let userID: Int64
    let displayName: String
    let username: String?
    let date: Date
    let about: String?
    let approvedBy: Int64?
    let requested: Bool
    let joinedViaFolderLink: Bool

    var id: Int64 {
        userID
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case username
        case date
        case about
        case approvedBy = "approved_by"
        case requested
        case joinedViaFolderLink = "joined_via_folder_link"
    }
}

struct HSInviteImportersPage: Codable, Hashable {
    let totalCount: Int
    let importers: [HSInviteImporter]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case importers
    }
}

struct HSContact: Codable, Identifiable, Hashable {
    let id: Int64
    let displayName: String
    let username: String?
    let status: String
}

struct HSDeviceContactImport: Codable, Identifiable, Hashable {
    let clientID: Int64
    let phone: String
    let firstName: String
    let lastName: String
    let note: String?

    init(clientID: Int64, phone: String, firstName: String, lastName: String, note: String? = nil) {
        self.clientID = clientID
        self.phone = phone
        self.firstName = firstName
        self.lastName = lastName
        self.note = note
    }

    var id: Int64 {
        clientID
    }

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case phone
        case firstName = "first_name"
        case lastName = "last_name"
        case note
    }
}

struct HSImportedContactsSummary: Codable, Hashable {
    let importedContacts: [HSContact]
    let importedCount: Int
    let popularInviteCount: Int
    let retryContactIDs: [Int64]

    enum CodingKeys: String, CodingKey {
        case importedContacts = "imported_contacts"
        case importedCount = "imported_count"
        case popularInviteCount = "popular_invite_count"
        case retryContactIDs = "retry_contact_ids"
    }
}

enum HSReportReason: String, Codable, CaseIterable, Identifiable, Hashable {
    case spam
    case fake
    case violence
    case pornography
    case childAbuse = "child_abuse"
    case copyright
    case geoIrrelevant = "geo_irrelevant"
    case illegalDrugs = "illegal_drugs"
    case personalDetails = "personal_details"
    case other

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .spam:
            return "Spam"
        case .fake:
            return "Fake Account"
        case .violence:
            return "Violence"
        case .pornography:
            return "Pornography"
        case .childAbuse:
            return "Child Abuse"
        case .copyright:
            return "Copyright"
        case .geoIrrelevant:
            return "Irrelevant Location"
        case .illegalDrugs:
            return "Illegal Drugs"
        case .personalDetails:
            return "Personal Details"
        case .other:
            return "Other"
        }
    }
}

struct HSReportOption: Codable, Identifiable, Hashable {
    let text: String
    let option: Data

    var id: String {
        option.base64EncodedString()
    }
}

enum HSReportContentResult: Codable, Hashable {
    case options(title: String, options: [HSReportOption])
    case addComment(optional: Bool, option: Data)
    case reported

    private enum CodingKeys: String, CodingKey {
        case state
        case title
        case options
        case optional
        case option
    }

    private enum State: String, Codable {
        case options
        case addComment = "add_comment"
        case reported
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let state = try container.decode(State.self, forKey: .state)
        switch state {
        case .options:
            self = .options(
                title: try container.decode(String.self, forKey: .title),
                options: try container.decode([HSReportOption].self, forKey: .options)
            )
        case .addComment:
            self = .addComment(
                optional: try container.decode(Bool.self, forKey: .optional),
                option: try container.decode(Data.self, forKey: .option)
            )
        case .reported:
            self = .reported
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .options(title, options):
            try container.encode(State.options, forKey: .state)
            try container.encode(title, forKey: .title)
            try container.encode(options, forKey: .options)
        case let .addComment(optional, option):
            try container.encode(State.addComment, forKey: .state)
            try container.encode(optional, forKey: .optional)
            try container.encode(option, forKey: .option)
        case .reported:
            try container.encode(State.reported, forKey: .state)
        }
    }
}

struct HSSearchMessage: Codable, Identifiable, Hashable {
    let id: Int64
    let dialogID: Int64
    let dialogTitle: String
    let authorID: Int64
    let authorName: String
    let text: String
    let kind: String?
    let sentAt: Date
    let isOutgoing: Bool
    let isGroup: Bool
    let isChannel: Bool

    var searchID: String {
        "\(dialogID)-\(id)"
    }
}

struct HSSearchResults: Codable, Hashable {
    let query: String
    let dialogs: [HSChat]
    let contacts: [HSContact]
    let messages: [HSSearchMessage]
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
    let accessHash: Int64
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

struct HSStickerSetInstallResult: Codable, Hashable {
    let installed: Bool
    let archived: Bool
    let archiveSetIDs: [Int64]

    private enum CodingKeys: String, CodingKey {
        case installed
        case archived
        case archiveSetIDs = "archive_set_ids"
    }
}

enum HSNotificationSound: Codable, Hashable {
    case `default`
    case none
    case local(title: String, data: String)
    case ringtone(id: Int64)

    private enum CodingKeys: String, CodingKey {
        case kind
        case title
        case data
        case id
    }

    private enum Kind: String, Codable {
        case `default`
        case none
        case local
        case ringtone
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .default:
            self = .default
        case .none:
            self = .none
        case .local:
            self = .local(
                title: try container.decode(String.self, forKey: .title),
                data: try container.decode(String.self, forKey: .data)
            )
        case .ringtone:
            self = .ringtone(id: try container.decode(Int64.self, forKey: .id))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .default:
            try container.encode(Kind.default, forKey: .kind)
        case .none:
            try container.encode(Kind.none, forKey: .kind)
        case let .local(title, data):
            try container.encode(Kind.local, forKey: .kind)
            try container.encode(title, forKey: .title)
            try container.encode(data, forKey: .data)
        case let .ringtone(id):
            try container.encode(Kind.ringtone, forKey: .kind)
            try container.encode(id, forKey: .id)
        }
    }
}

struct HSSavedRingtones: Codable, Hashable {
    let hash: Int64
    let ringtones: [HSStickerDocument]
    let notModified: Bool

    private enum CodingKeys: String, CodingKey {
        case hash
        case ringtones
        case notModified = "not_modified"
    }
}

struct HSSavedRingtoneAction: Codable, Hashable {
    let saved: Bool
    let document: HSStickerDocument?
}

struct HSNotificationException: Codable, Identifiable, Hashable {
    enum Scope: String, Codable, Hashable {
        case privateChats = "private_chats"
        case groups
        case channels
        case unknown
    }

    let dialogID: Int64
    let peerID: Int64
    let scope: Scope
    let settings: HSNotifyScopeSettings

    var id: Int64 {
        dialogID
    }

    private enum CodingKeys: String, CodingKey {
        case dialogID = "dialog_id"
        case peerID = "peer_id"
        case scope
        case settings
    }
}

struct HSNotificationExceptions: Codable, Hashable {
    let privateChats: [HSNotificationException]
    let groups: [HSNotificationException]
    let channels: [HSNotificationException]
    let all: [HSNotificationException]

    private enum CodingKeys: String, CodingKey {
        case privateChats = "private_chats"
        case groups
        case channels
        case all
    }
}

struct HSArchivedStickerSetsPage: Codable, Hashable {
    let count: Int
    let sets: [HSStickerSet]
}

struct HSStickerPack: Codable, Hashable {
    let emoticon: String
    let documents: [Int64]
}

struct HSStickerKeyword: Codable, Hashable {
    let documentID: Int64
    let keywords: [String]

    private enum CodingKeys: String, CodingKey {
        case documentID = "document_id"
        case keywords
    }
}

struct HSStickerSetDetails: Codable, Hashable {
    let set: HSStickerSet?
    let packs: [HSStickerPack]
    let keywords: [HSStickerKeyword]
    let documents: [HSStickerDocument]
    let notModified: Bool

    private enum CodingKeys: String, CodingKey {
        case set
        case packs
        case keywords
        case documents
        case notModified = "not_modified"
    }
}

struct HSStickerDocument: Codable, Identifiable, Hashable {
    let id: Int64
    let accessHash: Int64
    let fileReference: Data
    let setID: Int64?
    let alt: String?
    let fileName: String?
    let mimeType: String?
    let size: Int64?
    let width: Int?
    let height: Int?
    let animated: Bool
    let video: Bool
    let date: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case accessHash = "access_hash"
        case fileReference = "file_reference"
        case setID = "set_id"
        case alt
        case fileName = "file_name"
        case mimeType = "mime_type"
        case size
        case width
        case height
        case animated
        case video
        case date
    }
}

struct HSStickerDocumentList: Codable, Hashable {
    let hash: Int64
    let stickers: [HSStickerDocument]
    let notModified: Bool

    private enum CodingKeys: String, CodingKey {
        case hash
        case stickers
        case notModified = "not_modified"
    }
}

struct HSEmojiDocumentList: Codable, Hashable {
    let hash: Int64
    let documentIDs: [Int64]
    let notModified: Bool

    private enum CodingKeys: String, CodingKey {
        case hash
        case documentIDs = "document_ids"
        case notModified = "not_modified"
    }
}

struct HSEmojiKeyword: Codable, Hashable {
    let keyword: String
    let emoticons: [String]
    let deleted: Bool
}

struct HSEmojiKeywordsDifference: Codable, Hashable {
    let langCode: String
    let fromVersion: Int
    let version: Int
    let keywords: [HSEmojiKeyword]

    private enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case fromVersion = "from_version"
        case version
        case keywords
    }
}

struct HSEmojiLanguage: Codable, Identifiable, Hashable {
    let langCode: String

    var id: String {
        langCode
    }

    private enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
    }
}

struct HSLocalizationLanguage: Codable, Identifiable, Hashable {
    let languageCode: String
    let baseLanguageCode: String?
    let pluralCode: String
    let title: String
    let localizedTitle: String
    let totalStringCount: Int
    let translatedStringCount: Int
    let translationsURL: String
    let official: Bool

    var id: String {
        languageCode
    }

    private enum CodingKeys: String, CodingKey {
        case languageCode = "language_code"
        case baseLanguageCode = "base_language_code"
        case pluralCode = "plural_code"
        case title
        case localizedTitle = "localized_title"
        case totalStringCount = "total_string_count"
        case translatedStringCount = "translated_string_count"
        case translationsURL = "translations_url"
        case official
    }
}

enum HSLocalizationEntry: Codable, Hashable {
    case string(key: String, value: String)
    case pluralized(
        key: String,
        zero: String?,
        one: String?,
        two: String?,
        few: String?,
        many: String?,
        other: String
    )
    case deleted(key: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case key
        case value
        case zero
        case one
        case two
        case few
        case many
        case other
    }

    private enum Kind: String, Codable {
        case string
        case pluralized
        case deleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .string:
            self = .string(
                key: try container.decode(String.self, forKey: .key),
                value: try container.decode(String.self, forKey: .value)
            )
        case .pluralized:
            self = .pluralized(
                key: try container.decode(String.self, forKey: .key),
                zero: try container.decodeIfPresent(String.self, forKey: .zero),
                one: try container.decodeIfPresent(String.self, forKey: .one),
                two: try container.decodeIfPresent(String.self, forKey: .two),
                few: try container.decodeIfPresent(String.self, forKey: .few),
                many: try container.decodeIfPresent(String.self, forKey: .many),
                other: try container.decode(String.self, forKey: .other)
            )
        case .deleted:
            self = .deleted(key: try container.decode(String.self, forKey: .key))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .string(key, value):
            try container.encode(Kind.string, forKey: .kind)
            try container.encode(key, forKey: .key)
            try container.encode(value, forKey: .value)
        case let .pluralized(key, zero, one, two, few, many, other):
            try container.encode(Kind.pluralized, forKey: .kind)
            try container.encode(key, forKey: .key)
            try container.encodeIfPresent(zero, forKey: .zero)
            try container.encodeIfPresent(one, forKey: .one)
            try container.encodeIfPresent(two, forKey: .two)
            try container.encodeIfPresent(few, forKey: .few)
            try container.encodeIfPresent(many, forKey: .many)
            try container.encode(other, forKey: .other)
        case let .deleted(key):
            try container.encode(Kind.deleted, forKey: .kind)
            try container.encode(key, forKey: .key)
        }
    }
}

struct HSLocalizationPack: Codable, Hashable {
    let languageCode: String
    let fromVersion: Int
    let version: Int
    let entries: [HSLocalizationEntry]

    private enum CodingKeys: String, CodingKey {
        case languageCode = "language_code"
        case fromVersion = "from_version"
        case version
        case entries
    }
}

struct HSWallpaperSettings: Codable, Hashable {
    var blur: Bool
    var motion: Bool
    var colors: [Int32]
    var intensity: Int32?
    var rotation: Int32?
    var emoticon: String?

    init(
        blur: Bool = false,
        motion: Bool = false,
        colors: [Int32] = [],
        intensity: Int32? = nil,
        rotation: Int32? = nil,
        emoticon: String? = nil
    ) {
        self.blur = blur
        self.motion = motion
        self.colors = colors
        self.intensity = intensity
        self.rotation = rotation
        self.emoticon = emoticon
    }
}

struct HSWallpaper: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, Hashable {
        case file
        case color
        case gradient
        case emoticon
    }

    let id: Int64
    let kind: Kind
    let accessHash: Int64
    let slug: String?
    let document: HSStickerDocument?
    let settings: HSWallpaperSettings
    let isCreator: Bool
    let isDefault: Bool
    let isPattern: Bool
    let isDark: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case accessHash = "access_hash"
        case slug
        case document
        case settings
        case isCreator = "is_creator"
        case isDefault = "is_default"
        case isPattern = "is_pattern"
        case isDark = "is_dark"
    }
}

struct HSWallpaperList: Codable, Hashable {
    let hash: Int64
    let wallpapers: [HSWallpaper]
    let notModified: Bool

    private enum CodingKeys: String, CodingKey {
        case hash
        case wallpapers
        case notModified = "not_modified"
    }
}

struct HSReaction: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let premium: Bool
    let inactive: Bool
}

struct HSDefaultReaction: Codable, Hashable {
    let reaction: String?
}

struct HSReactionList: Codable, Hashable {
    let hash: Int64
    let reactions: [HSReaction]
    let notModified: Bool

    private enum CodingKeys: String, CodingKey {
        case hash
        case reactions
        case notModified = "not_modified"
    }
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
    let selection: String?
    let exceptions: HSPrivacyRuleExceptions?

    init(
        id: String,
        title: String,
        subtitle: String,
        value: String,
        status: String,
        selection: String? = nil,
        exceptions: HSPrivacyRuleExceptions? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.status = status
        self.selection = selection
        self.exceptions = exceptions
    }
}

struct HSPrivacySettings: Codable, Hashable {
    let items: [HSSettingsItem]
}

enum HSPrivacyPeerKind: String, Codable, Hashable {
    case user
    case group
    case channel
}

struct HSPrivacyExceptionPeer: Codable, Identifiable, Hashable {
    let peerID: Int64
    let dialogID: Int64
    let title: String
    let subtitle: String?
    let kind: HSPrivacyPeerKind

    var id: String {
        "\(kind.rawValue):\(peerID)"
    }

    var icon: String {
        switch kind {
        case .user:
            return "person.fill"
        case .group:
            return "person.2.fill"
        case .channel:
            return "megaphone.fill"
        }
    }

    static func user(_ contact: HSContact) -> HSPrivacyExceptionPeer {
        HSPrivacyExceptionPeer(
            peerID: contact.id,
            dialogID: contact.id,
            title: contact.displayName,
            subtitle: contact.username.map { "@\($0)" } ?? contact.status,
            kind: .user
        )
    }

    static func chat(_ chat: HSChat) -> HSPrivacyExceptionPeer? {
        if chat.id > 0 {
            return user(HSContact(id: chat.id, displayName: chat.title, username: nil, status: chat.subtitle))
        }

        let channelDialogPrefix: Int64 = -1_000_000_000_000
        let peerID: Int64
        if chat.id <= channelDialogPrefix {
            peerID = channelDialogPrefix - chat.id
        } else {
            peerID = -chat.id
        }
        guard peerID > 0 else {
            return nil
        }
        return HSPrivacyExceptionPeer(
            peerID: peerID,
            dialogID: chat.id,
            title: chat.title,
            subtitle: chat.subtitle,
            kind: chat.id <= channelDialogPrefix ? .channel : .group
        )
    }
}

struct HSPrivacyRuleExceptions: Codable, Hashable {
    var allow: [HSPrivacyExceptionPeer]
    var disallow: [HSPrivacyExceptionPeer]

    static let empty = HSPrivacyRuleExceptions(allow: [], disallow: [])

    var isEmpty: Bool {
        allow.isEmpty && disallow.isEmpty
    }

    var totalCount: Int {
        allow.count + disallow.count
    }
}

enum HSPrivacyRuleValue: String, Codable, CaseIterable, Identifiable, Hashable {
    case everyone
    case contacts
    case nobody
    case custom
    case serverDefault = "server_default"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .everyone:
            return "所有人"
        case .contacts:
            return "我的联系人"
        case .nobody:
            return "没有人"
        case .custom:
            return "自定义"
        case .serverDefault:
            return "服务端默认"
        }
    }

    var isBaseRule: Bool {
        switch self {
        case .everyone, .contacts, .nobody:
            return true
        case .custom, .serverDefault:
            return false
        }
    }

    static var editableCases: [HSPrivacyRuleValue] {
        [.everyone, .contacts, .nobody]
    }
}

struct HSNotifyScopeSettings: Codable, Hashable {
    var enabled: Bool
    var showPreviews: Bool
    var silent: Bool
    var muteUntil: Int?
    var sound: HSNotificationSound?

    init(
        enabled: Bool,
        showPreviews: Bool,
        silent: Bool,
        muteUntil: Int?,
        sound: HSNotificationSound? = nil
    ) {
        self.enabled = enabled
        self.showPreviews = showPreviews
        self.silent = silent
        self.muteUntil = muteUntil
        self.sound = sound
    }

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
