import Foundation

protocol HSServerTransport {
    func sendEmailCode(email: String) async throws -> HSEmailStartResponse
    func verifyEmailCode(email: String, code: String, transactionID: String, displayName: String) async throws -> HSUserSession
    func signUp(email: String, transactionID: String, displayName: String, inviteCode: String) async throws -> HSUserSession
    func uploadProfilePhoto(data: Data, session: HSUserSession) async throws
    func removeProfilePhoto(session: HSUserSession) async throws
    func verifyLoginPassword(email: String, password: String) async throws -> HSUserSession
    func requestPasswordRecovery(email: String) async throws -> HSPasswordRecoveryResponse
    func recoverPassword(email: String, code: String) async throws -> HSUserSession
    func loginPasswordSettings(session: HSUserSession) async throws -> HSLoginPasswordSettings
    func updateLoginPassword(
        currentPassword: String?,
        newPassword: String?,
        hint: String?,
        recoveryEmail: String?,
        session: HSUserSession
    ) async throws -> HSLoginPasswordSettings
    func confirmLoginPasswordEmail(code: String, session: HSUserSession) async throws -> HSLoginPasswordSettings
    func resendLoginPasswordEmail(session: HSUserSession) async throws -> HSLoginPasswordSettings
    func cancelLoginPasswordEmail(session: HSUserSession) async throws -> HSLoginPasswordSettings
    func webPagePreview(text: String, session: HSUserSession) async throws -> HSWebPagePreview?
    func sendMedia(
        dialogID: Int64,
        fileName: String,
        mimeType: String,
        data: Data,
        mediaKind: String,
        caption: String,
        replyToMessageID: Int64?,
        duration: Double?,
        waveform: Data?,
        session: HSUserSession,
        progress: ((HSMediaTransferProgress) -> Void)?
    ) async throws -> HSMessage
    func downloadMedia(_ media: HSMessageMedia, session: HSUserSession) async throws -> Data
    func downloadMedia(
        _ media: HSMessageMedia,
        session: HSUserSession,
        progress: ((HSMediaTransferProgress) -> Void)?
    ) async throws -> Data
    func sharedMedia(
        dialogID: Int64,
        filter: HSSharedMediaFilter,
        offsetID: Int64?,
        limit: Int,
        session: HSUserSession
    ) async throws -> [HSMessage]
    func sharedMediaCounters(
        dialogID: Int64,
        filters: [HSSharedMediaFilter],
        session: HSUserSession
    ) async throws -> [HSSharedMediaCounter]
    func sharedMediaCalendar(
        dialogID: Int64,
        filter: HSSharedMediaFilter,
        offsetID: Int64?,
        offsetDate: Date?,
        session: HSUserSession
    ) async throws -> HSSharedMediaCalendar
    func sharedMediaPositions(
        dialogID: Int64,
        filter: HSSharedMediaFilter,
        offsetID: Int64?,
        limit: Int,
        session: HSUserSession
    ) async throws -> HSSharedMediaPositions
    func syncState(session: HSUserSession) async throws -> HSSyncState
    func syncDifference(since state: HSSyncState, session: HSUserSession) async throws -> HSSyncDifference
    func dialogReadState(dialogID: Int64, session: HSUserSession) async throws -> HSDialogReadState

    func request<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        body: Body?,
        session: HSUserSession?
    ) async throws -> Response
}

final class HSDeployedServerTransport: HSServerTransport {
    private let nativeTransport: HSNativeServerTransport

    init() {
        self.nativeTransport = HSNativeServerTransport()
    }

    func sendEmailCode(email: String) async throws -> HSEmailStartResponse {
        try await nativeTransport.sendEmailCode(email: email)
    }

    func verifyEmailCode(email: String, code: String, transactionID: String, displayName: String) async throws -> HSUserSession {
        try await nativeTransport.verifyEmailCode(
            email: email,
            code: code,
            transactionID: transactionID,
            displayName: displayName
        )
    }

    func signUp(email: String, transactionID: String, displayName: String, inviteCode: String) async throws -> HSUserSession {
        try await nativeTransport.signUp(
            email: email,
            transactionID: transactionID,
            displayName: displayName,
            inviteCode: inviteCode
        )
    }

    func uploadProfilePhoto(data: Data, session: HSUserSession) async throws {
        try await nativeTransport.uploadProfilePhoto(data: data, session: session)
    }

    func removeProfilePhoto(session: HSUserSession) async throws {
        try await nativeTransport.removeProfilePhoto(session: session)
    }

    func verifyLoginPassword(email: String, password: String) async throws -> HSUserSession {
        try await nativeTransport.verifyLoginPassword(email: email, password: password)
    }

    func requestPasswordRecovery(email: String) async throws -> HSPasswordRecoveryResponse {
        try await nativeTransport.requestPasswordRecovery(email: email)
    }

    func recoverPassword(email: String, code: String) async throws -> HSUserSession {
        try await nativeTransport.recoverPassword(email: email, code: code)
    }

    func loginPasswordSettings(session: HSUserSession) async throws -> HSLoginPasswordSettings {
        try await nativeTransport.loginPasswordSettings(session: session)
    }

    func updateLoginPassword(
        currentPassword: String?,
        newPassword: String?,
        hint: String?,
        recoveryEmail: String?,
        session: HSUserSession
    ) async throws -> HSLoginPasswordSettings {
        try await nativeTransport.updateLoginPassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
            hint: hint,
            recoveryEmail: recoveryEmail,
            session: session
        )
    }

    func confirmLoginPasswordEmail(code: String, session: HSUserSession) async throws -> HSLoginPasswordSettings {
        try await nativeTransport.confirmLoginPasswordEmail(code: code, session: session)
    }

    func resendLoginPasswordEmail(session: HSUserSession) async throws -> HSLoginPasswordSettings {
        try await nativeTransport.resendLoginPasswordEmail(session: session)
    }

    func cancelLoginPasswordEmail(session: HSUserSession) async throws -> HSLoginPasswordSettings {
        try await nativeTransport.cancelLoginPasswordEmail(session: session)
    }

    func webPagePreview(text: String, session: HSUserSession) async throws -> HSWebPagePreview? {
        try await nativeTransport.webPagePreview(text: text, session: session)
    }

    func sendMedia(
        dialogID: Int64,
        fileName: String,
        mimeType: String,
        data: Data,
        mediaKind: String,
        caption: String,
        replyToMessageID: Int64?,
        duration: Double?,
        waveform: Data?,
        session: HSUserSession,
        progress: ((HSMediaTransferProgress) -> Void)?
    ) async throws -> HSMessage {
        try await nativeTransport.sendMedia(
            dialogID: dialogID,
            fileName: fileName,
            mimeType: mimeType,
            data: data,
            mediaKind: mediaKind,
            caption: caption,
            replyToMessageID: replyToMessageID,
            duration: duration,
            waveform: waveform,
            session: session,
            progress: progress
        )
    }

    func downloadMedia(_ media: HSMessageMedia, session: HSUserSession) async throws -> Data {
        try await nativeTransport.downloadMedia(media, session: session)
    }

    func downloadMedia(
        _ media: HSMessageMedia,
        session: HSUserSession,
        progress: ((HSMediaTransferProgress) -> Void)?
    ) async throws -> Data {
        try await nativeTransport.downloadMedia(media, session: session, progress: progress)
    }

    func sharedMedia(
        dialogID: Int64,
        filter: HSSharedMediaFilter,
        offsetID: Int64?,
        limit: Int,
        session: HSUserSession
    ) async throws -> [HSMessage] {
        try await nativeTransport.sharedMedia(
            dialogID: dialogID,
            filter: filter,
            offsetID: offsetID,
            limit: limit,
            session: session
        )
    }

    func sharedMediaCounters(
        dialogID: Int64,
        filters: [HSSharedMediaFilter],
        session: HSUserSession
    ) async throws -> [HSSharedMediaCounter] {
        try await nativeTransport.sharedMediaCounters(
            dialogID: dialogID,
            filters: filters,
            session: session
        )
    }

    func sharedMediaCalendar(
        dialogID: Int64,
        filter: HSSharedMediaFilter,
        offsetID: Int64?,
        offsetDate: Date?,
        session: HSUserSession
    ) async throws -> HSSharedMediaCalendar {
        try await nativeTransport.sharedMediaCalendar(
            dialogID: dialogID,
            filter: filter,
            offsetID: offsetID,
            offsetDate: offsetDate,
            session: session
        )
    }

    func sharedMediaPositions(
        dialogID: Int64,
        filter: HSSharedMediaFilter,
        offsetID: Int64?,
        limit: Int,
        session: HSUserSession
    ) async throws -> HSSharedMediaPositions {
        try await nativeTransport.sharedMediaPositions(
            dialogID: dialogID,
            filter: filter,
            offsetID: offsetID,
            limit: limit,
            session: session
        )
    }

    func syncState(session: HSUserSession) async throws -> HSSyncState {
        try await nativeTransport.syncState(session: session)
    }

    func syncDifference(since state: HSSyncState, session: HSUserSession) async throws -> HSSyncDifference {
        try await nativeTransport.syncDifference(since: state, session: session)
    }

    func dialogReadState(dialogID: Int64, session: HSUserSession) async throws -> HSDialogReadState {
        try await nativeTransport.dialogReadState(dialogID: dialogID, session: session)
    }

    func request<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        body: Body?,
        session: HSUserSession?
    ) async throws -> Response {
        try await nativeTransport.request(path, method: method, body: body, session: session)
    }
}

private struct HSNativeRoute {
    let parts: [String]
    private let queryItems: [String: String]

    init(path: String) {
        let split = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        self.parts = split.first.map { $0.split(separator: "/").map(String.init) } ?? []
        if split.count > 1 {
            var components = URLComponents()
            components.percentEncodedQuery = String(split[1])
            self.queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                guard let value = item.value else {
                    return nil
                }
                return (item.name, value)
            })
        } else {
            self.queryItems = [:]
        }
    }

    func stringQuery(_ name: String) -> String? {
        queryItems[name]
    }

    func intQuery(_ name: String) -> Int? {
        queryItems[name].flatMap(Int.init)
    }

    func int64Query(_ name: String) -> Int64? {
        queryItems[name].flatMap(Int64.init)
    }

    func boolQuery(_ name: String) -> Bool? {
        queryItems[name].flatMap(Bool.init)
    }

    func int64Part(at index: Int) throws -> Int64 {
        guard parts.indices.contains(index), let value = Int64(parts[index]) else {
            throw HSAPIError.server(code: "BAD_ROUTE", message: "原生路由适配无法解析路径参数：\(parts.joined(separator: "/"))")
        }
        return value
    }
}

private struct HSNativeSendMessageBody: Decodable {
    let text: String
    let replyToMessageID: Int64?
    let noWebpage: Bool?

    private enum CodingKeys: String, CodingKey {
        case text
        case replyToMessageID
        case noWebpage = "no_webpage"
    }
}

private struct HSNativeSendMediaBody: Decodable {
    let fileName: String
    let mimeType: String
    let data: Data
    let mediaKind: String
    let caption: String
    let replyToMessageID: Int64?
    let duration: Double?
}

private struct HSNativeMarkUnreadBody: Decodable {
    let unread: Bool
}

private struct HSNativeDialogPinBody: Decodable {
    let pinned: Bool
}

private struct HSNativeDialogPinOrderBody: Decodable {
    let dialogIDs: [Int64]
    let folderID: Int

    enum CodingKeys: String, CodingKey {
        case dialogIDs = "dialog_ids"
        case folderID = "folder_id"
    }
}

private struct HSNativeDialogFolderBody: Decodable {
    let folderID: Int

    enum CodingKeys: String, CodingKey {
        case folderID = "folder_id"
    }
}

private struct HSNativeDraftBody: Decodable {
    let text: String
    let replyToMessageID: Int64?
    let noWebpage: Bool?

    private enum CodingKeys: String, CodingKey {
        case text
        case replyToMessageID
        case noWebpage = "no_webpage"
    }
}

private struct HSNativeEditMessageBody: Decodable {
    let text: String
}

private struct HSNativeForwardMessageBody: Decodable {
    let toDialogID: Int64
}

private struct HSNativeReactionBody: Decodable {
    let reaction: String
    let big: Bool
}

private struct HSNativeContactRequestBody: Decodable {
    let userID: Int64
    let firstName: String
    let lastName: String
    let phone: String
    let note: String?
    let addPhonePrivacyException: Bool?
}

private struct HSNativeContactNoteBody: Decodable {
    let note: String
}

private struct HSNativeImportContactTokenBody: Decodable {
    let token: String
}

private struct HSNativeImportContactsBody: Decodable {
    let contacts: [HSDeviceContactImport]
}

private struct HSNativeSupergroupCreateBody: Decodable {
    let title: String
    let about: String
    let memberIDs: [Int64]
}

private struct HSNativeSupergroupUpdateBody: Decodable {
    let title: String?
    let about: String?
}

private struct HSNativeMembersBody: Decodable {
    let userIDs: [Int64]
}

private struct HSNativeSupergroupAdminBody: Decodable {
    let rights: HSSupergroupAdminRights
    let rank: String?
}

private struct HSNativeSupergroupRestrictionBody: Decodable {
    let rights: HSSupergroupBannedRights
}

private struct HSNativePinMessageBody: Decodable {
    let silent: Bool
    let unpin: Bool
}

private struct HSNativeExportInviteBody: Decodable {
    let title: String?
    let expireDate: Int?
    let usageLimit: Int?
    let requestNeeded: Bool
}

private struct HSNativeAccountProfileBody: Decodable {
    let displayName: String?
    let username: String?
    let about: String?
}

private struct HSNativeDeleteAccountBody: Decodable {
    let reason: String
    let password: String?
}

private struct HSNativePrivacyRuleUpdateBody: Decodable {
    let id: String
    let value: HSPrivacyRuleValue
    let exceptions: HSPrivacyRuleExceptions
}

struct HSNativeServerContract {
    func operation(for path: String, method: String) -> HSNativeServerOperation {
        let route = path.split(separator: "?").first.map(String.init) ?? path
        let parts = route.split(separator: "/").map(String.init)

        guard parts.first == "v1" else {
            return .workspaceSummary
        }

        if parts.count == 2, parts[1] == "dialogs" {
            return .messagesGetDialogs
        }
        if parts.count == 3, parts[1] == "workspace", parts[2] == "summary" {
            return .workspaceSummary
        }
        if parts.count == 4, parts[1] == "dialog-filters", parts[3] == "shared-links" {
            return method == "GET" ? .chatlistsGetExportedInvites : .chatlistsExportChatlistInvite
        }
        if parts.count == 5, parts[1] == "dialog-filters", parts[3] == "shared-links" {
            if method == "DELETE" {
                return .chatlistsDeleteExportedInvite
            }
            return .chatlistsEditExportedInvite
        }
        if parts.count == 3, parts[1] == "chatlist-invites", method == "GET" {
            return .chatlistsCheckChatlistInvite
        }
        if parts.count == 4, parts[1] == "chatlist-invites", parts[3] == "join", method == "POST" {
            return .chatlistsJoinChatlistInvite
        }
        if parts.count == 4, parts[1] == "dialog-filters", parts[3] == "chatlist-updates" {
            if method == "GET" {
                return .chatlistsGetChatlistUpdates
            }
            if method == "DELETE" {
                return .chatlistsHideChatlistUpdates
            }
            return .chatlistsJoinChatlistUpdates
        }
        if parts.count == 4, parts[1] == "dialog-filters", parts[3] == "leave-suggestions", method == "GET" {
            return .chatlistsGetLeaveChatlistSuggestions
        }
        if parts.count == 4, parts[1] == "dialog-filters", parts[3] == "leave", method == "POST" {
            return .chatlistsLeaveChatlist
        }
        if parts.count == 2, parts[1] == "dialog-filters" {
            if method == "GET" {
                return .messagesGetDialogFilters
            }
            if method == "PUT" {
                return .messagesUpdateDialogFiltersOrder
            }
        }
        if parts.count == 3, parts[1] == "dialog-filters", parts[2] == "tags" {
            return .messagesToggleDialogFilterTags
        }
        if parts.count == 3, parts[1] == "dialog-filters" {
            return method == "DELETE" ? .messagesDeleteDialogFilter : .messagesUpdateDialogFilter
        }
        if parts.count == 4, parts[1] == "dialogs", parts[2] == "pins", parts[3] == "order" {
            return .messagesReorderPinnedDialogs
        }
        if parts.count == 2, parts[1] == "drafts" {
            return .messagesGetAllDrafts
        }
        if parts.count >= 4, parts[1] == "dialogs", parts[3] == "messages" {
            if parts.count == 4, method == "GET" {
                return .messagesGetHistory
            }
            if parts.count == 4, method == "POST" {
                return .messagesSendMessage
            }
            if parts.count == 5, method == "PATCH" {
                return .messagesEditMessage
            }
            if parts.count == 5, method == "DELETE" {
                return .messagesDeleteMessages
            }
            if parts.count == 5, parts[4] == "views", method == "POST" {
                return .messagesGetMessagesViews
            }
            if parts.count == 6, parts[5] == "forward" {
                return .messagesForwardMessages
            }
            if parts.count == 6, parts[5] == "reactions" {
                return .messagesSendReaction
            }
            if parts.count == 7, parts[5] == "reactions", parts[6] == "list", method == "GET" {
                return .messagesGetMessageReactionsList
            }
            if parts.count == 7, parts[5] == "poll", parts[6] == "vote", method == "POST" {
                return .messagesSendVote
            }
            if parts.count == 7, parts[5] == "poll", parts[6] == "refresh", method == "POST" {
                return .messagesGetPollResults
            }
            if parts.count == 7, parts[5] == "poll", parts[6] == "votes", method == "GET" {
                return .messagesGetPollVotes
            }
            if parts.count == 7, parts[5] == "todo", parts[6] == "toggle", method == "POST" {
                return .messagesToggleTodoCompleted
            }
            if parts.count == 7, parts[5] == "todo", parts[6] == "items", method == "POST" {
                return .messagesAppendTodoList
            }
            if parts.count == 6, parts[5] == "read-participants", method == "GET" {
                return .messagesGetMessageReadParticipants
            }
            if parts.count == 6, parts[5] == "discussion" {
                return .messagesGetDiscussionMessage
            }
            if parts.count == 7, parts[5] == "discussion", parts[6] == "read" {
                return .messagesReadDiscussion
            }
        }
        if parts.count == 5, parts[1] == "dialogs", parts[3] == "messages", parts[4] == "read-contents", method == "POST" {
            return .messagesReadMessageContents
        }
        if parts.count == 4, parts[1] == "dialogs", parts[3] == "history", method == "DELETE" {
            return .messagesDeleteHistory
        }
        if parts.count == 4, parts[1] == "dialogs", parts[3] == "media", method == "POST" {
            return .messagesSendMedia
        }
        if parts.count == 4, parts[1] == "dialogs", parts[3] == "polls", method == "POST" {
            return .messagesSendPoll
        }
        if parts.count == 4, parts[1] == "dialogs", parts[3] == "todos", method == "POST" {
            return .messagesSendTodo
        }
        if parts.count == 4, parts[1] == "dialogs", parts[3] == "typing", method == "POST" {
            return .messagesSetTyping
        }
        if parts.count == 5, parts[1] == "dialogs", parts[3] == "shared-media", parts[4] == "calendar", method == "GET" {
            return .messagesGetSearchResultsCalendar
        }
        if parts.count == 5, parts[1] == "dialogs", parts[3] == "shared-media", parts[4] == "positions", method == "GET" {
            return .messagesGetSearchResultsPositions
        }
        if parts.count == 5, parts[1] == "dialogs", parts[3] == "shared-media", parts[4] == "counters", method == "GET" {
            return .messagesGetSearchCounters
        }
        if parts.count == 4, parts[1] == "dialogs", parts[3] == "search", method == "GET" {
            return .messagesSearch
        }
        if parts.count == 4, parts[1] == "dialogs", parts[3] == "shared-media", method == "GET" {
            return .messagesSearch
        }
        if parts.count >= 4, parts[1] == "dialogs", parts[3] == "draft" {
            return .messagesSaveDraft
        }
        if parts.count >= 4, parts[1] == "dialogs", parts[3] == "read" {
            return .messagesReadHistory
        }
        if parts.count >= 4, parts[1] == "dialogs", parts[3] == "unread" {
            return .messagesMarkDialogUnread
        }
        if parts.count >= 4, parts[1] == "dialogs", parts[3] == "pin" {
            return .messagesToggleDialogPin
        }
        if parts.count >= 4, parts[1] == "dialogs", parts[3] == "folder" {
            return .foldersEditPeerFolders
        }
        if parts.count >= 4, parts[1] == "dialogs", parts[3] == "notifications" {
            return .accountUpdatePeerNotifySettings
        }
        if parts.count >= 4, parts[1] == "dialogs", parts[3] == "report" {
            return .accountReportPeer
        }
        if parts.count >= 5, parts[1] == "dialogs", parts[3] == "photo", parts[4] == "report" {
            return .accountReportProfilePhoto
        }
        if parts.count >= 5, parts[1] == "dialogs", parts[3] == "messages", parts[4] == "report" {
            return .messagesReport
        }
        if parts.count == 2, parts[1] == "search" {
            return .messagesSearchGlobal
        }
        if parts.count == 2, parts[1] == "contacts" {
            return method == "POST" ? .contactsAddContact : .contactsGetContacts
        }
        if parts.count >= 3, parts[1] == "contacts", parts[2] == "import" {
            if method == "DELETE" {
                return .contactsDeleteByPhones
            }
            if method == "POST" {
                return .contactsImportContacts
            }
        }
        if parts.count == 3, parts[1] == "contacts", parts[2] == "token", method == "POST" {
            return .contactsExportContactToken
        }
        if parts.count == 4, parts[1] == "contacts", parts[2] == "token", parts[3] == "import", method == "POST" {
            return .contactsImportContactToken
        }
        if parts.count >= 3, parts[1] == "contacts", parts[2] == "blocked" {
            return .contactsGetBlocked
        }
        if parts.count >= 3, parts[1] == "contacts", parts[2] == "resolve" {
            return .contactsResolve
        }
        if parts.count >= 3, parts[1] == "contacts", parts[2] == "search" {
            return .contactsSearch
        }
        if parts.count >= 3, parts[1] == "contacts", parts[2] == "requests" {
            return .contactsRequestContact
        }
        if parts.count >= 4, parts[1] == "contacts", parts[3] == "accept" {
            return .contactsAcceptContact
        }
        if parts.count >= 4, parts[1] == "contacts", parts[3] == "decline" {
            return .contactsDeclineContact
        }
        if parts.count >= 4, parts[1] == "contacts", parts[3] == "note", method == "PATCH" {
            return .contactsUpdateContactNote
        }
        if parts.count >= 4, parts[1] == "contacts", parts[3] == "block" {
            return method == "DELETE" ? .contactsUnblock : .contactsBlock
        }
        if parts.count == 3, parts[1] == "contacts", method == "DELETE" {
            return .contactsDeleteContacts
        }
        if parts.count >= 2, parts[1] == "supergroups" {
            return supergroupOperation(parts: parts, method: method)
        }
        if parts.count >= 2, parts[1] == "channels" {
            return channelOperation(parts: parts, method: method)
        }
        if parts.count >= 2, parts[1] == "account", method == "DELETE" {
            return .accountDeleteAccount
        }
        if parts.count >= 2, parts[1] == "account" {
            return method == "PATCH" ? .accountUpdateProfile : .accountGetProfile
        }
        if parts.count >= 3, parts[1] == "settings", parts[2] == "privacy" {
            return method == "PATCH" ? .accountSetPrivacy : .accountGetPrivacy
        }
        if parts.count == 4, parts[1] == "settings", parts[2] == "notifications", parts[3] == "exceptions", method == "GET" {
            return .accountGetNotifyExceptions
        }
        if parts.count == 4, parts[1] == "settings", parts[2] == "notifications", parts[3] == "reset", method == "POST" {
            return .accountResetNotifySettings
        }
        if parts.count == 3, parts[1] == "settings", parts[2] == "notifications" {
            return method == "PATCH" ? .accountUpdateNotifySettings : .accountGetNotifySettings
        }
        if parts.count >= 3, parts[1] == "settings", parts[2] == "storage" {
            return .accountGetStorageStats
        }
        if parts.count >= 2, parts[1] == "devices" {
            return method == "DELETE" ? .accountResetAuthorization : .accountGetAuthorizations
        }
        if parts.count >= 2, parts[1] == "assets" {
            return .messagesGetStickerAndReactionState
        }
        if parts.count >= 2, parts[1] == "custom-emoji" {
            if parts.count == 3, parts[2] == "documents" {
                return method == "GET" ? .messagesGetCustomEmojiDocuments : .unknown
            }
            if parts.count == 3, parts[2] == "sticker-sets" {
                return method == "GET" ? .messagesGetEmojiStickers : .unknown
            }
            if parts.count == 3, parts[2] == "search" {
                return method == "GET" ? .messagesSearchCustomEmoji : .unknown
            }
            return .messagesGetStickerAndReactionState
        }
        if parts.count >= 2, parts[1] == "emoji" {
            if parts.count == 3, parts[2] == "keywords" {
                return method == "GET" ? .messagesGetEmojiKeywords : .unknown
            }
            if parts.count == 4, parts[2] == "keywords", parts[3] == "difference" {
                return method == "GET" ? .messagesGetEmojiKeywordsDifference : .unknown
            }
            if parts.count == 4, parts[2] == "keywords", parts[3] == "languages" {
                return method == "GET" ? .messagesGetEmojiKeywordsLanguages : .unknown
            }
            if parts.count == 3, parts[2] == "keyword-languages" {
                return method == "GET" ? .messagesGetEmojiKeywordsLanguages : .unknown
            }
            return .messagesGetStickerAndReactionState
        }
        if parts.count >= 2, parts[1] == "localization" {
            if parts.count == 3, parts[2] == "languages" {
                return method == "GET" ? .langpackGetLanguages : .unknown
            }
            if parts.count == 4, parts[2] == "languages" {
                return method == "GET" ? .langpackGetLanguage : .unknown
            }
            if parts.count == 3, parts[2] == "strings" {
                return method == "GET" ? .langpackGetStrings : .unknown
            }
            if parts.count == 4, parts[2] == "packs" {
                return method == "GET" ? .langpackGetLangPack : .unknown
            }
            if parts.count == 5, parts[2] == "packs", parts[4] == "difference" {
                return method == "GET" ? .langpackGetDifference : .unknown
            }
            return .unknown
        }
        if parts.count >= 2, parts[1] == "stickers" {
            if parts.count == 3, parts[2] == "search" {
                return method == "GET" ? .messagesGetStickers : .unknown
            }
            if parts.count == 5, parts[2] == "sets", parts[3] == "by-short-name" {
                return method == "GET" ? .messagesGetStickerSet : .unknown
            }
            if parts.count == 5, parts[2] == "sets", parts[4] == "install" {
                if method == "POST" {
                    return .messagesInstallStickerSet
                }
                return method == "DELETE" ? .messagesUninstallStickerSet : .unknown
            }
            if parts.count == 4, parts[2] == "sets" {
                return method == "GET" ? .messagesGetStickerSet : .unknown
            }
            if parts.count == 4, parts[2] == "featured", parts[3] == "read", method == "POST" {
                return .messagesReadFeaturedStickers
            }
            if parts.count == 3, parts[2] == "archived" {
                return method == "GET" ? .messagesGetArchivedStickers : .unknown
            }
            if parts.count == 3, parts[2] == "recent" {
                if method == "GET" {
                    return .messagesGetRecentStickers
                }
                return method == "DELETE" ? .messagesClearRecentStickers : .unknown
            }
            if parts.count == 4, parts[2] == "recent" {
                if method == "POST" || method == "DELETE" {
                    return .messagesSaveRecentSticker
                }
                return .unknown
            }
            if parts.count == 3, parts[2] == "faved" {
                return method == "GET" ? .messagesGetFavedStickers : .unknown
            }
            return .messagesGetStickerAndReactionState
        }
        if parts.count >= 2, parts[1] == "gifs" {
            if parts.count == 3, parts[2] == "saved" {
                return method == "GET" ? .messagesGetSavedGifs : .unknown
            }
            if parts.count == 4, parts[2] == "saved" {
                return method == "POST" || method == "DELETE" ? .messagesSaveGif : .unknown
            }
            return .messagesGetStickerAndReactionState
        }
        if parts.count >= 2, parts[1] == "wallpapers" {
            if parts.count == 2 {
                return method == "GET" ? .accountGetWallPapers : .unknown
            }
            if parts.count == 3, parts[2] == "reset" {
                return method == "POST" ? .accountResetWallPapers : .unknown
            }
            if parts.count == 5, parts[2] == "no-file", parts[4] == "install" {
                return method == "POST" ? .accountInstallWallPaper : .unknown
            }
            if parts.count == 3 {
                return method == "GET" ? .accountGetWallPaper : .unknown
            }
            if parts.count == 4, parts[3] == "saved" {
                return method == "POST" || method == "DELETE" ? .accountSaveWallPaper : .unknown
            }
            if parts.count == 4, parts[3] == "install" {
                return method == "POST" ? .accountInstallWallPaper : .unknown
            }
            return .messagesGetStickerAndReactionState
        }
        if parts.count >= 2, parts[1] == "reactions" {
            if parts.count >= 3, parts[2] == "recent" {
                if method == "DELETE" {
                    return .messagesClearRecentReactions
                }
                return method == "GET" ? .messagesGetRecentReactions : .unknown
            }
            if parts.count >= 3, parts[2] == "top" {
                return method == "GET" ? .messagesGetTopReactions : .unknown
            }
            if parts.count >= 3, parts[2] == "default" {
                if method == "GET" {
                    return .helpGetConfigDefaultReaction
                }
                return method == "PUT" ? .messagesSetDefaultReaction : .unknown
            }
            return .messagesGetStickerAndReactionState
        }
        if parts.count >= 3, parts[1] == "notifications", parts[2] == "push-token" {
            return method == "DELETE" ? .accountUnregisterDevice : .accountRegisterDevice
        }
        if parts.count >= 3, parts[1] == "notifications", parts[2] == "ringtones" {
            if parts.count == 3, method == "GET" {
                return .accountGetSavedRingtones
            }
            if parts.count == 4, parts[3] == "upload", method == "POST" {
                return .accountUploadRingtone
            }
            if parts.count == 4 {
                return .accountSaveRingtone
            }
        }
        if parts.count >= 2, parts[1] == "trust" {
            return .trustReadState
        }
        if parts.count >= 2, parts[1] == "entitlements" {
            return .entitlementsReadState
        }
        if parts.count >= 2, parts[1] == "admin" {
            return .adminToolsReadState
        }
        if parts.count >= 2, parts[1] == "circles" {
            return .circlesDisabled
        }

        return .unknown
    }

    func pending(_ operation: HSNativeServerOperation, detail: String) -> HSAPIError {
        let message: String
        if operation == .circlesDisabled {
            message = "圈子模块已按当前产品范围暂停，不会迁移到原生端。"
        } else {
            message = "该功能已从未发布的 /v1 草稿路由切到 HSgram 生产协议适配入口，但原生 target 还需要接入自有服务端传输层。当前操作：\(operation.rawValue)。详情：\(detail)。"
        }
        return .server(code: operation.errorCode, message: message)
    }

    private func supergroupOperation(parts: [String], method: String) -> HSNativeServerOperation {
        if parts.count == 2, method == "POST" {
            return .channelsCreateMegagroup
        }
        if parts.count == 3 {
            return method == "PATCH" ? .channelsEditAboutOrTitle : .channelsGetFullChannel
        }
        if parts.count >= 4, parts[3] == "leave" {
            return .channelsLeaveChannel
        }
        if parts.count >= 4, parts[3] == "members" {
            if parts.count == 4 {
                return method == "POST" ? .channelsInviteToChannel : .channelsGetParticipants
            }
            if parts.count == 6, parts[5] == "history" {
                return .channelsDeleteParticipantHistory
            }
            if parts.count == 6, parts[5] == "restrictions" {
                return .channelsEditBanned
            }
            return .channelsEditBanned
        }
        if parts.count >= 4, parts[3] == "admins" {
            return .channelsEditAdmin
        }
        if parts.count >= 4, parts[3] == "settings" {
            return .channelsUpdateSettings
        }
        if parts.count >= 4, parts[3] == "username" {
            return parts.count >= 5 && parts[4] == "check" ? .channelsCheckUsername : .channelsUpdateUsername
        }
        if parts.count == 5, parts[3] == "messages", parts[4] == "read-contents", method == "POST" {
            return .channelsReadMessageContents
        }
        if parts.count == 5, parts[3] == "messages", parts[4] == "views", method == "POST" {
            return .messagesGetMessagesViews
        }
        if parts.count >= 6, parts[3] == "messages", parts[5] == "read-participants", method == "GET" {
            return .messagesGetMessageReadParticipants
        }
        if parts.count >= 7, parts[3] == "messages", parts[5] == "reactions", parts[6] == "list", method == "GET" {
            return .messagesGetMessageReactionsList
        }
        if parts.count >= 6, parts[3] == "messages", parts[5] == "pin" {
            return .messagesUpdatePinnedMessage
        }
        if parts.count >= 6, parts[3] == "messages", parts[5] == "link" {
            return .messagesExportMessageLink
        }
        if parts.count >= 7, parts[3] == "messages", parts[5] == "anti-spam", parts[6] == "false-positive" {
            return .channelsReportAntiSpamFalsePositive
        }
        if parts.count >= 4, parts[3] == "admin-log" {
            return .channelsGetAdminLog
        }
        if parts.count >= 5, parts[3] == "join-requests" {
            if parts[4] == "approve-all" || parts[4] == "decline-all" {
                return .messagesHideAllChatJoinRequests
            }
            return .messagesHideChatJoinRequest
        }
        if parts.count >= 4, parts[3] == "invite-importers" {
            return .messagesGetChatInviteImporters
        }
        if parts.count >= 4, parts[3] == "invites" {
            if method == "GET" {
                return .messagesGetExportedChatInvites
            }
            if method == "PATCH" {
                return .messagesEditExportedChatInvite
            }
            if method == "DELETE" {
                return .messagesDeleteExportedChatInvite
            }
            return .messagesExportChatInvite
        }
        return .channelsGetFullChannel
    }

    private func channelOperation(parts: [String], method: String) -> HSNativeServerOperation {
        if parts.count == 3, parts[2] == "discussion-groups" {
            return .channelsGetGroupsForDiscussion
        }
        if parts.count == 2 {
            return method == "POST" ? .channelsCreateBroadcast : .messagesGetDialogs
        }
        if parts.count == 3 {
            return method == "PATCH" ? .channelsEditAboutOrTitle : .channelsGetFullChannel
        }
        if parts.count >= 4, parts[3] == "leave" {
            return .channelsLeaveChannel
        }
        if parts.count >= 4, parts[3] == "subscribers" {
            if parts.count == 4 {
                return method == "POST" ? .channelsInviteToChannel : .channelsGetParticipants
            }
            return .channelsEditBanned
        }
        if parts.count >= 4, parts[3] == "admins" {
            return .channelsEditAdmin
        }
        if parts.count >= 4, parts[3] == "settings" {
            return .channelsUpdateSettings
        }
        if parts.count >= 4, parts[3] == "discussion-group" {
            return .channelsSetDiscussionGroup
        }
        if parts.count >= 4, parts[3] == "username" {
            return parts.count >= 5 && parts[4] == "check" ? .channelsCheckUsername : .channelsUpdateUsername
        }
        if parts.count == 5, parts[3] == "messages", parts[4] == "read-contents", method == "POST" {
            return .channelsReadMessageContents
        }
        if parts.count == 5, parts[3] == "messages", parts[4] == "views", method == "POST" {
            return .messagesGetMessagesViews
        }
        if parts.count >= 6, parts[3] == "messages", parts[5] == "read-participants", method == "GET" {
            return .messagesGetMessageReadParticipants
        }
        if parts.count >= 7, parts[3] == "messages", parts[5] == "reactions", parts[6] == "list", method == "GET" {
            return .messagesGetMessageReactionsList
        }
        if parts.count >= 4, parts[3] == "admin-log" {
            return .channelsGetAdminLog
        }
        if parts.count >= 7, parts[3] == "messages", parts[5] == "anti-spam", parts[6] == "false-positive" {
            return .channelsReportAntiSpamFalsePositive
        }
        if parts.count >= 5, parts[3] == "join-requests" {
            if parts[4] == "approve-all" || parts[4] == "decline-all" {
                return .messagesHideAllChatJoinRequests
            }
            return .messagesHideChatJoinRequest
        }
        if parts.count >= 4, parts[3] == "invite-importers" {
            return .messagesGetChatInviteImporters
        }
        if parts.count >= 4, parts[3] == "invites" {
            if method == "GET" {
                return .messagesGetExportedChatInvites
            }
            if method == "PATCH" {
                return .messagesEditExportedChatInvite
            }
            if method == "DELETE" {
                return .messagesDeleteExportedChatInvite
            }
            return .messagesExportChatInvite
        }
        return .channelsGetFullChannel
    }
}

enum HSNativeServerOperation: String, Equatable {
    case authSendCode = "auth.sendCode"
    case authSignInOrSignUp = "auth.signIn/auth.signUp"
    case workspaceSummary = "workspace.summary"
    case messagesGetDialogs = "messages.getDialogs"
    case messagesGetDialogFilters = "messages.getDialogFilters"
    case messagesUpdateDialogFilter = "messages.updateDialogFilter"
    case messagesDeleteDialogFilter = "messages.updateDialogFilter(delete)"
    case messagesUpdateDialogFiltersOrder = "messages.updateDialogFiltersOrder"
    case messagesToggleDialogFilterTags = "messages.toggleDialogFilterTags"
    case chatlistsExportChatlistInvite = "chatlists.exportChatlistInvite"
    case chatlistsDeleteExportedInvite = "chatlists.deleteExportedInvite"
    case chatlistsEditExportedInvite = "chatlists.editExportedInvite"
    case chatlistsGetExportedInvites = "chatlists.getExportedInvites"
    case chatlistsCheckChatlistInvite = "chatlists.checkChatlistInvite"
    case chatlistsJoinChatlistInvite = "chatlists.joinChatlistInvite"
    case chatlistsGetChatlistUpdates = "chatlists.getChatlistUpdates"
    case chatlistsJoinChatlistUpdates = "chatlists.joinChatlistUpdates"
    case chatlistsHideChatlistUpdates = "chatlists.hideChatlistUpdates"
    case chatlistsGetLeaveChatlistSuggestions = "chatlists.getLeaveChatlistSuggestions"
    case chatlistsLeaveChatlist = "chatlists.leaveChatlist"
    case messagesGetAllDrafts = "messages.getAllDrafts"
    case messagesGetHistory = "messages.getHistory"
    case messagesSendMessage = "messages.sendMessage"
    case messagesSendMedia = "messages.sendMedia"
    case messagesSendPoll = "messages.sendMedia(inputMediaPoll)"
    case messagesSendTodo = "messages.sendMedia(inputMediaTodo)"
    case messagesSendVote = "messages.sendVote"
    case messagesGetPollResults = "messages.getPollResults"
    case messagesGetPollVotes = "messages.getPollVotes"
    case messagesToggleTodoCompleted = "messages.toggleTodoCompleted"
    case messagesAppendTodoList = "messages.appendTodoList"
    case messagesSetTyping = "messages.setTyping"
    case messagesSaveDraft = "messages.saveDraft"
    case messagesReadHistory = "messages.readHistory"
    case messagesMarkDialogUnread = "messages.markDialogUnread"
    case messagesToggleDialogPin = "messages.toggleDialogPin"
    case messagesReorderPinnedDialogs = "messages.reorderPinnedDialogs"
    case foldersEditPeerFolders = "folders.editPeerFolders"
    case messagesEditMessage = "messages.editMessage"
    case messagesDeleteMessages = "messages.deleteMessages"
    case messagesDeleteHistory = "messages.deleteHistory"
    case messagesForwardMessages = "messages.forwardMessages"
    case messagesSendReaction = "messages.sendReaction"
    case messagesGetDiscussionMessage = "messages.getDiscussionMessage"
    case messagesReadDiscussion = "messages.readDiscussion"
    case messagesReadMessageContents = "messages.readMessageContents"
    case messagesGetMessagesViews = "messages.getMessagesViews"
    case messagesGetMessageReadParticipants = "messages.getMessageReadParticipants"
    case messagesGetMessageReactionsList = "messages.getMessageReactionsList"
    case messagesSearch = "messages.search"
    case messagesGetSearchCounters = "messages.getSearchCounters"
    case messagesGetSearchResultsCalendar = "messages.getSearchResultsCalendar"
    case messagesGetSearchResultsPositions = "messages.getSearchResultsPositions"
    case messagesSearchGlobal = "messages.searchGlobal"
    case messagesUpdatePinnedMessage = "messages.updatePinnedMessage"
    case messagesExportMessageLink = "messages.exportMessageLink"
    case messagesExportChatInvite = "messages.exportChatInvite"
    case messagesGetExportedChatInvites = "messages.getExportedChatInvites"
    case messagesEditExportedChatInvite = "messages.editExportedChatInvite"
    case messagesDeleteExportedChatInvite = "messages.deleteExportedChatInvite"
    case messagesGetChatInviteImporters = "messages.getChatInviteImporters"
    case messagesHideChatJoinRequest = "messages.hideChatJoinRequest"
    case messagesHideAllChatJoinRequests = "messages.hideAllChatJoinRequests"
    case messagesGetStickerAndReactionState = "messages/stickers/reactions state"
    case messagesInstallStickerSet = "messages.installStickerSet"
    case messagesUninstallStickerSet = "messages.uninstallStickerSet"
    case messagesReadFeaturedStickers = "messages.readFeaturedStickers"
    case messagesGetStickerSet = "messages.getStickerSet"
    case messagesGetStickers = "messages.getStickers"
    case messagesGetCustomEmojiDocuments = "messages.getCustomEmojiDocuments"
    case messagesGetEmojiStickers = "messages.getEmojiStickers"
    case messagesSearchCustomEmoji = "messages.searchCustomEmoji"
    case messagesGetEmojiKeywords = "messages.getEmojiKeywords"
    case messagesGetEmojiKeywordsDifference = "messages.getEmojiKeywordsDifference"
    case messagesGetEmojiKeywordsLanguages = "messages.getEmojiKeywordsLanguages"
    case langpackGetLanguages = "langpack.getLanguages"
    case langpackGetLanguage = "langpack.getLanguage"
    case langpackGetLangPack = "langpack.getLangPack"
    case langpackGetStrings = "langpack.getStrings"
    case langpackGetDifference = "langpack.getDifference"
    case messagesGetArchivedStickers = "messages.getArchivedStickers"
    case messagesGetRecentStickers = "messages.getRecentStickers"
    case messagesSaveRecentSticker = "messages.saveRecentSticker"
    case messagesClearRecentStickers = "messages.clearRecentStickers"
    case messagesGetFavedStickers = "messages.getFavedStickers"
    case messagesGetSavedGifs = "messages.getSavedGifs"
    case messagesSaveGif = "messages.saveGif"
    case accountGetWallPapers = "account.getWallPapers"
    case accountGetWallPaper = "account.getWallPaper"
    case accountSaveWallPaper = "account.saveWallPaper"
    case accountInstallWallPaper = "account.installWallPaper"
    case accountResetWallPapers = "account.resetWallPapers"
    case messagesGetRecentReactions = "messages.getRecentReactions"
    case messagesGetTopReactions = "messages.getTopReactions"
    case helpGetConfigDefaultReaction = "help.getConfig(reactions_default)"
    case messagesSetDefaultReaction = "messages.setDefaultReaction"
    case messagesClearRecentReactions = "messages.clearRecentReactions"
    case contactsGetContacts = "contacts.getContacts"
    case contactsGetBlocked = "contacts.getBlocked"
    case contactsResolve = "contacts.resolve"
    case contactsSearch = "contacts.search"
    case contactsImportContacts = "contacts.importContacts"
    case contactsDeleteByPhones = "contacts.deleteByPhones"
    case contactsExportContactToken = "contacts.exportContactToken"
    case contactsImportContactToken = "contacts.importContactToken"
    case contactsAddContact = "contacts.addContact"
    case contactsUpdateContactNote = "contacts.updateContactNote"
    case contactsRequestContact = "contacts.requestContact"
    case contactsAcceptContact = "contacts.acceptContact"
    case contactsDeclineContact = "contacts.declineContact"
    case contactsDeleteContacts = "contacts.deleteContacts"
    case contactsBlock = "contacts.block"
    case contactsUnblock = "contacts.unblock"
    case channelsCreateMegagroup = "channels.createChannel(megagroup)"
    case channelsCreateBroadcast = "channels.createChannel(broadcast)"
    case channelsGetFullChannel = "channels.getFullChannel"
    case channelsEditAboutOrTitle = "channels.editTitle/channels.editAbout"
    case channelsLeaveChannel = "channels.leaveChannel"
    case channelsGetParticipants = "channels.getParticipants"
    case channelsInviteToChannel = "channels.inviteToChannel"
    case channelsEditAdmin = "channels.editAdmin"
    case channelsEditBanned = "channels.editBanned"
    case channelsDeleteParticipantHistory = "channels.deleteParticipantHistory"
    case channelsUpdateSettings = "channels.updateSettings"
    case channelsCheckUsername = "channels.checkUsername"
    case channelsUpdateUsername = "channels.updateUsername"
    case channelsGetGroupsForDiscussion = "channels.getGroupsForDiscussion"
    case channelsSetDiscussionGroup = "channels.setDiscussionGroup"
    case channelsGetAdminLog = "channels.getAdminLog"
    case channelsReadMessageContents = "channels.readMessageContents"
    case channelsReportAntiSpamFalsePositive = "channels.reportAntiSpamFalsePositive"
    case accountGetProfile = "users.getFullUser/account.getProfile"
    case accountUpdateProfile = "account.updateProfile/account.updateUsername"
    case accountDeleteAccount = "account.deleteAccount"
    case accountGetPrivacy = "account.getPrivacy"
    case accountSetPrivacy = "account.setPrivacy"
    case accountGetNotifySettings = "account.getNotifySettings"
    case accountUpdateNotifySettings = "account.updateNotifySettings"
    case accountUpdatePeerNotifySettings = "account.updateNotifySettings(peer)"
    case accountGetNotifyExceptions = "account.getNotifyExceptions"
    case accountResetNotifySettings = "account.resetNotifySettings"
    case accountGetSavedRingtones = "account.getSavedRingtones"
    case accountSaveRingtone = "account.saveRingtone"
    case accountUploadRingtone = "account.uploadRingtone"
    case accountReportPeer = "account.reportPeer"
    case accountReportProfilePhoto = "account.reportProfilePhoto"
    case messagesReport = "messages.report"
    case accountGetStorageStats = "storage/settings local+remote state"
    case accountGetAuthorizations = "account.getAuthorizations"
    case accountResetAuthorization = "account.resetAuthorization"
    case accountRegisterDevice = "account.registerDevice"
    case accountUnregisterDevice = "account.unregisterDevice"
    case trustReadState = "trust/moderation state"
    case entitlementsReadState = "entitlements state"
    case adminToolsReadState = "admin tools state"
    case circlesDisabled = "circles disabled"
    case unknown = "unknown native route operation"

    var errorCode: String {
        switch self {
        case .circlesDisabled:
            return "CIRCLES_DISABLED"
        case .unknown:
            return "LEGACY_OPERATION_UNMAPPED"
        default:
            return "LEGACY_TRANSPORT_PENDING"
        }
    }
}
