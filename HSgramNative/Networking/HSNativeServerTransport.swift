import Foundation

final class HSNativeServerTransport: HSServerTransport {
    private let contract = HSNativeServerContract()
    private let mtProtoClient: HSNativeMTProtoClient
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(mtProtoClient: HSNativeMTProtoClient = .shared) {
        self.mtProtoClient = mtProtoClient
    }

    func sendEmailCode(email: String) async throws -> HSEmailStartResponse {
        do {
            return try await mtProtoClient.sendEmailCode(email: email)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func verifyEmailCode(email: String, code: String, transactionID: String, displayName: String) async throws -> HSUserSession {
        do {
            return try await mtProtoClient.verifyEmailCode(
                email: email,
                code: code,
                transactionID: transactionID,
                displayName: displayName
            )
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func signUp(email: String, transactionID: String, displayName: String, inviteCode: String) async throws -> HSUserSession {
        do {
            return try await mtProtoClient.signUp(
                email: email,
                transactionID: transactionID,
                displayName: displayName,
                inviteCode: inviteCode
            )
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func uploadProfilePhoto(data: Data, session: HSUserSession) async throws {
        do {
            try await mtProtoClient.uploadProfilePhoto(data: data, session: session)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func removeProfilePhoto(session: HSUserSession) async throws {
        do {
            try await mtProtoClient.removeProfilePhoto(session: session)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func verifyLoginPassword(email: String, password: String) async throws -> HSUserSession {
        do {
            return try await mtProtoClient.verifyPassword(email: email, password: password)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func requestPasswordRecovery(email: String) async throws -> HSPasswordRecoveryResponse {
        do {
            return try await mtProtoClient.requestPasswordRecovery(email: email)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func recoverPassword(email: String, code: String) async throws -> HSUserSession {
        do {
            return try await mtProtoClient.recoverPassword(email: email, code: code)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func loginPasswordSettings(session: HSUserSession) async throws -> HSLoginPasswordSettings {
        do {
            return try await mtProtoClient.loginPasswordSettings(session: session)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func updateLoginPassword(
        currentPassword: String?,
        newPassword: String?,
        hint: String?,
        recoveryEmail: String?,
        session: HSUserSession
    ) async throws -> HSLoginPasswordSettings {
        do {
            return try await mtProtoClient.updateLoginPassword(
                currentPassword: currentPassword,
                newPassword: newPassword,
                hint: hint,
                recoveryEmail: recoveryEmail,
                session: session
            )
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func confirmLoginPasswordEmail(code: String, session: HSUserSession) async throws -> HSLoginPasswordSettings {
        do {
            return try await mtProtoClient.confirmLoginPasswordEmail(code: code, session: session)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func resendLoginPasswordEmail(session: HSUserSession) async throws -> HSLoginPasswordSettings {
        do {
            return try await mtProtoClient.resendLoginPasswordEmail(session: session)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func cancelLoginPasswordEmail(session: HSUserSession) async throws -> HSLoginPasswordSettings {
        do {
            return try await mtProtoClient.cancelLoginPasswordEmail(session: session)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func webPagePreview(text: String, session: HSUserSession) async throws -> HSWebPagePreview? {
        do {
            return try await mtProtoClient.webPagePreview(text: text, session: session)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
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
        do {
            return try await mtProtoClient.sendMediaMessage(
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
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func downloadMedia(_ media: HSMessageMedia, session: HSUserSession) async throws -> Data {
        try await downloadMedia(media, session: session, progress: nil)
    }

    func downloadMedia(
        _ media: HSMessageMedia,
        session: HSUserSession,
        progress: ((HSMediaTransferProgress) -> Void)?
    ) async throws -> Data {
        do {
            return try await mtProtoClient.downloadMedia(media, session: session, progress: progress)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func sharedMedia(
        dialogID: Int64,
        filter: HSSharedMediaFilter,
        offsetID: Int64?,
        limit: Int,
        session: HSUserSession
    ) async throws -> [HSMessage] {
        do {
            return try await mtProtoClient.sharedMedia(
                dialogID: dialogID,
                filter: filter,
                offsetID: offsetID,
                limit: limit,
                session: session
            )
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func sharedMediaCounters(
        dialogID: Int64,
        filters: [HSSharedMediaFilter],
        session: HSUserSession
    ) async throws -> [HSSharedMediaCounter] {
        do {
            return try await mtProtoClient.sharedMediaCounters(
                dialogID: dialogID,
                filters: filters,
                session: session
            )
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func sharedMediaCalendar(
        dialogID: Int64,
        filter: HSSharedMediaFilter,
        offsetID: Int64?,
        offsetDate: Date?,
        session: HSUserSession
    ) async throws -> HSSharedMediaCalendar {
        do {
            return try await mtProtoClient.sharedMediaCalendar(
                dialogID: dialogID,
                filter: filter,
                offsetID: offsetID,
                offsetDate: offsetDate,
                session: session
            )
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func sharedMediaPositions(
        dialogID: Int64,
        filter: HSSharedMediaFilter,
        offsetID: Int64?,
        limit: Int,
        session: HSUserSession
    ) async throws -> HSSharedMediaPositions {
        do {
            return try await mtProtoClient.sharedMediaPositions(
                dialogID: dialogID,
                filter: filter,
                offsetID: offsetID,
                limit: limit,
                session: session
            )
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func syncState(session: HSUserSession) async throws -> HSSyncState {
        do {
            return try await mtProtoClient.syncState(session: session)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func syncDifference(since state: HSSyncState, session: HSUserSession) async throws -> HSSyncDifference {
        do {
            return try await mtProtoClient.syncDifference(since: state, session: session)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func dialogReadState(dialogID: Int64, session: HSUserSession) async throws -> HSDialogReadState {
        do {
            return try await mtProtoClient.dialogReadState(dialogID: dialogID, session: session)
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    func request<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        body: Body?,
        session: HSUserSession?
    ) async throws -> Response {
        let operation = contract.operation(for: path, method: method)
        let route = HSNativeRoute(path: path)
        if operation == .circlesDisabled {
            throw HSAPIError.server(code: operation.errorCode, message: "圈子模块已按当前产品范围暂停，不会迁移到原生端。")
        }
        do {
            switch operation {
            case .workspaceSummary:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.workspaceSummary(session: session))
            case .messagesGetDialogs:
                let session = try requireSession(session)
                if route.parts.indices.contains(1), route.parts[1] == "channels" {
                    let groups = try await mtProtoClient.groups(limit: route.intQuery("limit") ?? 80, broadcastOnly: true, session: session)
                    return try typed(groups)
                }
                if route.parts.indices.contains(1), route.parts[1] == "supergroups" {
                    let groups = try await mtProtoClient.groups(limit: route.intQuery("limit") ?? 80, broadcastOnly: false, session: session)
                    return try typed(groups)
                }
                let dialogs = try await mtProtoClient.dialogs(
                    limit: route.intQuery("limit") ?? 80,
                    folderID: route.intQuery("folder_id"),
                    session: session
                )
                return try typed(dialogs)
            case .messagesGetDialogFilters:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.dialogFilters(session: session))
            case .messagesUpdateDialogFilter:
                let session = try requireSession(session)
                let request: HSNativeDialogFilterBody = try decodeBody(body)
                return try typed(try await mtProtoClient.updateDialogFilter(request.filter, session: session))
            case .messagesDeleteDialogFilter:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.deleteDialogFilter(id: try route.intPart(at: 2), session: session))
            case .messagesUpdateDialogFiltersOrder:
                let session = try requireSession(session)
                let request: HSNativeDialogFilterOrderBody = try decodeBody(body)
                return try typed(try await mtProtoClient.reorderDialogFilters(ids: request.ids, session: session))
            case .messagesToggleDialogFilterTags:
                let session = try requireSession(session)
                let request: HSNativeDialogFilterTagsBody = try decodeBody(body)
                return try typed(try await mtProtoClient.toggleDialogFilterTags(enabled: request.enabled, session: session))
            case .chatlistsExportChatlistInvite:
                let session = try requireSession(session)
                let request: HSNativeChatListSharedInviteBody = try decodeBody(body)
                return try typed(try await mtProtoClient.exportChatListInvite(
                    filterID: try route.intPart(at: 2),
                    title: request.title ?? "",
                    peers: request.peers ?? [],
                    session: session
                ))
            case .chatlistsDeleteExportedInvite:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.deleteChatListInvite(
                    filterID: try route.intPart(at: 2),
                    slug: try route.stringPart(at: 4),
                    session: session
                ))
            case .chatlistsEditExportedInvite:
                let session = try requireSession(session)
                let request: HSNativeChatListSharedInviteBody = try decodeBody(body)
                return try typed(try await mtProtoClient.editChatListInvite(
                    filterID: try route.intPart(at: 2),
                    slug: try route.stringPart(at: 4),
                    title: request.title,
                    peers: request.peers,
                    session: session
                ))
            case .chatlistsGetExportedInvites:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.chatListSharedInvites(
                    filterID: try route.intPart(at: 2),
                    session: session
                ))
            case .chatlistsCheckChatlistInvite:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.checkChatListInvite(
                    slug: try route.stringPart(at: 2),
                    session: session
                ))
            case .chatlistsJoinChatlistInvite:
                let session = try requireSession(session)
                let request: HSNativeChatListJoinInviteBody = try decodeBody(body)
                return try typed(try await mtProtoClient.joinChatListInvite(
                    slug: try route.stringPart(at: 2),
                    peers: request.peers,
                    session: session
                ))
            case .chatlistsGetChatlistUpdates:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.chatListUpdates(
                    filterID: try route.intPart(at: 2),
                    session: session
                ))
            case .chatlistsJoinChatlistUpdates:
                let session = try requireSession(session)
                let request: HSNativeChatListJoinInviteBody = try decodeBody(body)
                return try typed(try await mtProtoClient.joinChatListUpdates(
                    filterID: try route.intPart(at: 2),
                    peers: request.peers,
                    session: session
                ))
            case .chatlistsHideChatlistUpdates:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.hideChatListUpdates(
                    filterID: try route.intPart(at: 2),
                    session: session
                ))
            case .chatlistsGetLeaveChatlistSuggestions:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.leaveChatListSuggestions(
                    filterID: try route.intPart(at: 2),
                    session: session
                ))
            case .chatlistsLeaveChatlist:
                let session = try requireSession(session)
                let request: HSNativeChatListJoinInviteBody = try decodeBody(body)
                return try typed(try await mtProtoClient.leaveChatList(
                    filterID: try route.intPart(at: 2),
                    peers: request.peers,
                    session: session
                ))
            case .channelsGetFullChannel:
                let session = try requireSession(session)
                let group = try await mtProtoClient.group(dialogID: try route.int64Part(at: 2), session: session)
                return try typed(group)
            case .messagesGetHistory:
                let session = try requireSession(session)
                let messages = try await mtProtoClient.messages(
                    dialogID: try route.int64Part(at: 2),
                    beforeID: route.int64Query("before_id"),
                    limit: route.intQuery("limit") ?? 50,
                    session: session
                )
                return try typed(messages)
            case .messagesSendMessage:
                let session = try requireSession(session)
                let request: HSNativeSendMessageBody = try decodeBody(body)
                let message = try await mtProtoClient.sendTextMessage(
                    dialogID: try route.int64Part(at: 2),
                    text: request.text,
                    replyToMessageID: request.replyToMessageID,
                    noWebpage: request.noWebpage ?? false,
                    session: session
                )
                return try typed(message)
            case .messagesSendMedia:
                let session = try requireSession(session)
                let request: HSNativeMediaMessageBody = try decodeBody(body)
                let message = try await mtProtoClient.sendMediaMessage(
                    dialogID: try route.int64Part(at: 2),
                    fileName: request.fileName,
                    mimeType: request.mimeType,
                    data: request.data,
                    mediaKind: request.mediaKind,
                    caption: request.caption,
                    replyToMessageID: request.replyToMessageID,
                    duration: request.duration,
                    waveform: request.waveform,
                    session: session
                )
                return try typed(message)
            case .messagesSendPoll:
                let session = try requireSession(session)
                let request: HSNativePollMessageBody = try decodeBody(body)
                return try typed(try await mtProtoClient.sendPollMessage(
                    dialogID: try route.int64Part(at: 2),
                    question: request.question,
                    answers: request.answers,
                    isMultipleChoice: request.isMultipleChoice,
                    isQuiz: request.isQuiz,
                    isAnonymous: request.isAnonymous,
                    correctAnswerOptions: request.correctAnswerOptions,
                    solution: request.solution,
                    closePeriod: request.closePeriod,
                    replyToMessageID: request.replyToMessageID,
                    session: session
                ))
            case .messagesSendTodo:
                let session = try requireSession(session)
                let request: HSNativeTodoMessageBody = try decodeBody(body)
                return try typed(try await mtProtoClient.sendTodoMessage(
                    dialogID: try route.int64Part(at: 2),
                    title: request.title,
                    items: request.items,
                    othersCanAppend: request.othersCanAppend,
                    othersCanComplete: request.othersCanComplete,
                    replyToMessageID: request.replyToMessageID,
                    session: session
                ))
            case .messagesSetTyping:
                let session = try requireSession(session)
                let request: HSNativeTypingActivityBody = try decodeBody(body)
                let action = try await mtProtoClient.setTyping(
                    dialogID: try route.int64Part(at: 2),
                    activity: request.activity,
                    progress: request.progress,
                    session: session
                )
                return try typed(action)
            case .messagesSaveDraft:
                let session = try requireSession(session)
                let request: HSNativeDraftBody = try decodeBody(body)
                let action = try await mtProtoClient.saveDraft(
                    dialogID: try route.int64Part(at: 2),
                    text: request.text,
                    replyToMessageID: request.replyToMessageID,
                    noWebpage: request.noWebpage ?? false,
                    session: session
                )
                return try typed(action)
            case .messagesReadHistory:
                let session = try requireSession(session)
                let action = try await mtProtoClient.markRead(
                    dialogID: try route.int64Part(at: 2),
                    maxMessageID: route.int64Query("max_id"),
                    session: session
                )
                return try typed(action)
            case .messagesMarkDialogUnread:
                let session = try requireSession(session)
                let request: HSNativeMarkUnreadBody = try decodeBody(body)
                let action = try await mtProtoClient.markUnread(
                    dialogID: try route.int64Part(at: 2),
                    unread: request.unread,
                    session: session
                )
                return try typed(action)
            case .messagesToggleDialogPin:
                let session = try requireSession(session)
                let request: HSNativeDialogPinBody = try decodeBody(body)
                let action = try await mtProtoClient.toggleDialogPin(
                    dialogID: try route.int64Part(at: 2),
                    pinned: request.pinned,
                    session: session
                )
                return try typed(action)
            case .messagesReorderPinnedDialogs:
                let session = try requireSession(session)
                let request: HSNativeDialogPinOrderBody = try decodeBody(body)
                let action = try await mtProtoClient.reorderPinnedDialogs(
                    dialogIDs: request.dialogIDs,
                    folderID: request.folderID,
                    session: session
                )
                return try typed(action)
            case .foldersEditPeerFolders:
                let session = try requireSession(session)
                let request: HSNativeDialogFolderBody = try decodeBody(body)
                let action = try await mtProtoClient.editPeerFolder(
                    dialogID: try route.int64Part(at: 2),
                    folderID: request.folderID,
                    session: session
                )
                return try typed(action)
            case .messagesEditMessage:
                let session = try requireSession(session)
                let request: HSNativeEditMessageBody = try decodeBody(body)
                let message = try await mtProtoClient.editMessage(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    text: request.text,
                    session: session
                )
                return try typed(message)
            case .messagesDeleteMessages:
                let session = try requireSession(session)
                let action = try await mtProtoClient.deleteMessage(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    revoke: route.boolQuery("revoke") ?? true,
                    session: session
                )
                return try typed(action)
            case .messagesDeleteHistory:
                let session = try requireSession(session)
                let action = try await mtProtoClient.deleteDialogHistory(
                    dialogID: try route.int64Part(at: 2),
                    justClear: route.boolQuery("just_clear") ?? true,
                    revoke: route.boolQuery("revoke") ?? false,
                    maxMessageID: route.int64Query("max_id"),
                    session: session
                )
                return try typed(action)
            case .messagesForwardMessages:
                let session = try requireSession(session)
                let request: HSNativeForwardMessageBody = try decodeBody(body)
                let message = try await mtProtoClient.forwardMessage(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    toDialogID: request.toDialogID,
                    session: session
                )
                return try typed(message)
            case .messagesSendReaction:
                let session = try requireSession(session)
                let request: HSNativeReactionBody = try decodeBody(body)
                let action = try await mtProtoClient.sendReaction(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    reaction: request.reaction,
                    big: request.big,
                    session: session
                )
                return try typed(action)
            case .messagesSendVote:
                let session = try requireSession(session)
                let request: HSNativePollVoteBody = try decodeBody(body)
                return try typed(try await mtProtoClient.votePoll(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    options: request.options,
                    session: session
                ))
            case .messagesGetPollResults:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.refreshPoll(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    session: session
                ))
            case .messagesGetPollVotes:
                let session = try requireSession(session)
                let option = route.stringQuery("option").flatMap { Data(base64Encoded: $0) }
                return try typed(try await mtProtoClient.pollVotes(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    option: option,
                    offset: route.stringQuery("offset"),
                    limit: route.intQuery("limit") ?? 50,
                    session: session
                ))
            case .messagesToggleTodoCompleted:
                let session = try requireSession(session)
                let request: HSNativeTodoToggleBody = try decodeBody(body)
                return try typed(try await mtProtoClient.toggleTodoCompleted(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    completedIDs: request.completedIDs,
                    incompletedIDs: request.incompletedIDs,
                    session: session
                ))
            case .messagesAppendTodoList:
                let session = try requireSession(session)
                let request: HSNativeTodoItemsBody = try decodeBody(body)
                return try typed(try await mtProtoClient.appendTodoItems(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    items: request.items,
                    session: session
                ))
            case .messagesGetDiscussionMessage:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.discussionMessage(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    session: session
                ))
            case .messagesReadDiscussion:
                let session = try requireSession(session)
                let readMaxID: Int64
                if let queryReadMaxID = route.int64Query("read_max_id") {
                    readMaxID = queryReadMaxID
                } else {
                    readMaxID = try route.int64Part(at: 4)
                }
                return try typed(try await mtProtoClient.readDiscussion(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    readMaxID: readMaxID,
                    session: session
                ))
            case .messagesReadMessageContents:
                let session = try requireSession(session)
                let request: HSNativeMessageIDsBody = try decodeBody(body)
                return try typed(try await mtProtoClient.readMessageContents(
                    dialogID: try route.int64Part(at: 2),
                    messageIDs: request.messageIDs,
                    session: session
                ))
            case .messagesGetMessagesViews:
                let session = try requireSession(session)
                let request: HSNativeMessageIDsBody = try decodeBody(body)
                return try typed(try await mtProtoClient.messageViews(
                    dialogID: try route.int64Part(at: 2),
                    messageIDs: request.messageIDs,
                    increment: route.boolQuery("increment") ?? true,
                    session: session
                ))
            case .messagesGetMessageReadParticipants:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.messageReadParticipants(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    session: session
                ))
            case .messagesGetMessageReactionsList:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.messageReactions(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    reaction: route.stringQuery("reaction"),
                    offset: route.stringQuery("offset"),
                    limit: route.intQuery("limit") ?? 50,
                    session: session
                ))
            case .messagesSearchGlobal:
                let session = try requireSession(session)
                let results = try await mtProtoClient.search(
                    query: route.stringQuery("q") ?? "",
                    limit: route.intQuery("limit") ?? 20,
                    session: session
                )
                return try typed(results)
            case .messagesSearch:
                let session = try requireSession(session)
                if route.parts.indices.contains(3), route.parts[3] == "search" {
                    let messages = try await mtProtoClient.searchMessages(
                        dialogID: try route.int64Part(at: 2),
                        query: route.stringQuery("q") ?? "",
                        offsetID: route.int64Query("offset_id"),
                        limit: route.intQuery("limit") ?? 100,
                        session: session
                    )
                    return try typed(messages)
                }
                let filter = HSSharedMediaFilter(rawValue: route.stringQuery("filter") ?? "") ?? .media
                let messages = try await mtProtoClient.sharedMedia(
                    dialogID: try route.int64Part(at: 2),
                    filter: filter,
                    offsetID: route.int64Query("offset_id"),
                    limit: route.intQuery("limit") ?? 50,
                    session: session
                )
                return try typed(messages)
            case .messagesGetSearchCounters:
                let session = try requireSession(session)
                let filters = route.stringQuery("filters")?
                    .split(separator: ",")
                    .compactMap { HSSharedMediaFilter(rawValue: String($0)) }
                let counters = try await mtProtoClient.sharedMediaCounters(
                    dialogID: try route.int64Part(at: 2),
                    filters: filters?.isEmpty == false ? filters! : HSSharedMediaFilter.allCases,
                    session: session
                )
                return try typed(counters)
            case .messagesGetSearchResultsCalendar:
                let session = try requireSession(session)
                let filter = HSSharedMediaFilter(rawValue: route.stringQuery("filter") ?? "") ?? .media
                let offsetDate = route.int64Query("offset_date")
                    .map { Date(timeIntervalSince1970: TimeInterval($0)) }
                return try typed(try await mtProtoClient.sharedMediaCalendar(
                    dialogID: try route.int64Part(at: 2),
                    filter: filter,
                    offsetID: route.int64Query("offset_id"),
                    offsetDate: offsetDate,
                    session: session
                ))
            case .messagesGetSearchResultsPositions:
                let session = try requireSession(session)
                let filter = HSSharedMediaFilter(rawValue: route.stringQuery("filter") ?? "") ?? .media
                return try typed(try await mtProtoClient.sharedMediaPositions(
                    dialogID: try route.int64Part(at: 2),
                    filter: filter,
                    offsetID: route.int64Query("offset_id"),
                    limit: route.intQuery("limit") ?? 1000,
                    session: session
                ))
            case .messagesGetAllDrafts:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.drafts(session: session))
            case .contactsGetContacts:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.contacts(session: session))
            case .contactsGetBlocked:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.blockedContacts(
                    offset: route.intQuery("offset") ?? 0,
                    limit: route.intQuery("limit") ?? 100,
                    session: session
                ))
            case .contactsResolve:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.resolveContact(
                    identifier: route.stringQuery("identifier") ?? "",
                    session: session
                ))
            case .contactsSearch:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.searchContacts(
                    query: route.stringQuery("q") ?? "",
                    limit: route.intQuery("limit") ?? 20,
                    session: session
                ))
            case .contactsImportContacts:
                let session = try requireSession(session)
                let request: HSNativeImportContactsBody = try decodeBody(body)
                return try typed(try await mtProtoClient.importContacts(request.contacts, session: session))
            case .contactsDeleteByPhones:
                let session = try requireSession(session)
                let request: HSNativeContactPhonesBody = try decodeBody(body)
                return try typed(try await mtProtoClient.deleteImportedContactsByPhones(request.phones, session: session))
            case .contactsExportContactToken:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.exportContactToken(session: session))
            case .contactsImportContactToken:
                let session = try requireSession(session)
                let request: HSNativeImportContactTokenBody = try decodeBody(body)
                return try typed(try await mtProtoClient.importContactToken(request.token, session: session))
            case .contactsAddContact:
                let session = try requireSession(session)
                let request: HSNativeContactRequestBody = try decodeBody(body)
                return try typed(try await mtProtoClient.addContact(
                    userID: request.userID,
                    firstName: request.firstName,
                    lastName: request.lastName,
                    phone: request.phone,
                    note: request.note,
                    addPhonePrivacyException: request.addPhonePrivacyException ?? false,
                    session: session
                ))
            case .contactsUpdateContactNote:
                let session = try requireSession(session)
                let request: HSNativeContactNoteBody = try decodeBody(body)
                return try typed(try await mtProtoClient.updateContactNote(
                    userID: try route.int64Part(at: 2),
                    note: request.note,
                    session: session
                ))
            case .contactsRequestContact:
                let session = try requireSession(session)
                let request: HSNativeContactRequestBody = try decodeBody(body)
                return try typed(try await mtProtoClient.requestContact(
                    userID: request.userID,
                    firstName: request.firstName,
                    lastName: request.lastName,
                    phone: request.phone,
                    session: session
                ))
            case .contactsAcceptContact:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.acceptContact(userID: try route.int64Part(at: 2), session: session))
            case .contactsDeclineContact:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.declineContact(userID: try route.int64Part(at: 2), session: session))
            case .contactsDeleteContacts:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.deleteContact(userID: try route.int64Part(at: 2), session: session))
            case .contactsBlock:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.blockContact(userID: try route.int64Part(at: 2), session: session))
            case .contactsUnblock:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.unblockContact(userID: try route.int64Part(at: 2), session: session))
            case .channelsCreateMegagroup:
                let session = try requireSession(session)
                let request: HSNativeSupergroupCreateBody = try decodeBody(body)
                return try typed(try await mtProtoClient.createGroup(
                    title: request.title,
                    about: request.about,
                    memberIDs: request.memberIDs,
                    isBroadcast: false,
                    session: session
                ))
            case .channelsCreateBroadcast:
                let session = try requireSession(session)
                let request: HSNativeSupergroupCreateBody = try decodeBody(body)
                return try typed(try await mtProtoClient.createGroup(
                    title: request.title,
                    about: request.about,
                    memberIDs: request.memberIDs,
                    isBroadcast: true,
                    session: session
                ))
            case .channelsEditAboutOrTitle:
                let session = try requireSession(session)
                let request: HSNativeSupergroupUpdateBody = try decodeBody(body)
                return try typed(try await mtProtoClient.updateGroup(
                    dialogID: try route.int64Part(at: 2),
                    title: request.title,
                    about: request.about,
                    session: session
                ))
            case .channelsLeaveChannel:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.leaveGroup(dialogID: try route.int64Part(at: 2), session: session))
            case .channelsGetParticipants:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.groupMembers(
                    dialogID: try route.int64Part(at: 2),
                    filter: route.memberFilterQuery(),
                    query: route.stringQuery("q"),
                    limit: route.intQuery("limit") ?? 50,
                    offset: route.intQuery("offset") ?? 0,
                    session: session
                ))
            case .channelsInviteToChannel:
                let session = try requireSession(session)
                let request: HSNativeMembersBody = try decodeBody(body)
                return try typed(try await mtProtoClient.inviteGroupMembers(
                    dialogID: try route.int64Part(at: 2),
                    userIDs: request.userIDs,
                    session: session
                ))
            case .channelsEditAdmin:
                let session = try requireSession(session)
                let request: HSNativeSupergroupAdminBody = try decodeBody(body)
                return try typed(try await mtProtoClient.editGroupAdmin(
                    dialogID: try route.int64Part(at: 2),
                    userID: try route.int64Part(at: 4),
                    rights: request.rights,
                    rank: request.rank,
                    session: session
                ))
            case .channelsEditBanned:
                let session = try requireSession(session)
                if route.parts.indices.contains(5), route.parts[5] == "restrictions" {
                    let request: HSNativeSupergroupRestrictionBody = try decodeBody(body)
                    return try typed(try await mtProtoClient.editGroupRestrictions(
                        dialogID: try route.int64Part(at: 2),
                        userID: try route.int64Part(at: 4),
                        rights: request.rights,
                        session: session
                    ))
                }
                return try typed(try await mtProtoClient.removeGroupMember(
                    dialogID: try route.int64Part(at: 2),
                    userID: try route.int64Part(at: 4),
                    session: session
                ))
            case .channelsDeleteParticipantHistory:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.deleteGroupMemberHistory(
                    dialogID: try route.int64Part(at: 2),
                    userID: try route.int64Part(at: 4),
                    session: session
                ))
            case .channelsUpdateSettings:
                let session = try requireSession(session)
                let settings: HSSupergroupSettings = try decodeBody(body)
                return try typed(try await mtProtoClient.updateGroupSettings(
                    dialogID: try route.int64Part(at: 2),
                    settings: settings,
                    session: session
                ))
            case .channelsGetGroupsForDiscussion:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.discussionGroups(session: session))
            case .channelsSetDiscussionGroup:
                let session = try requireSession(session)
                let request: HSNativeDiscussionGroupBody = try decodeBody(body)
                return try typed(try await mtProtoClient.updateChannelDiscussionGroup(
                    channelDialogID: try route.int64Part(at: 2),
                    groupDialogID: request.groupDialogID,
                    session: session
                ))
            case .channelsCheckUsername:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.checkChannelUsername(
                    dialogID: try route.int64Part(at: 2),
                    username: route.stringQuery("username") ?? "",
                    session: session
                ))
            case .channelsUpdateUsername:
                let session = try requireSession(session)
                let request: HSNativeUsernameBody = try decodeBody(body)
                return try typed(try await mtProtoClient.updateChannelUsername(
                    dialogID: try route.int64Part(at: 2),
                    username: request.username,
                    session: session
                ))
            case .messagesUpdatePinnedMessage:
                let session = try requireSession(session)
                let request: HSNativePinMessageBody = try decodeBody(body)
                return try typed(try await mtProtoClient.pinGroupMessage(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    silent: request.silent,
                    unpin: request.unpin,
                    session: session
                ))
            case .messagesExportMessageLink:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.groupMessageLink(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    session: session
                ))
            case .messagesExportChatInvite:
                let session = try requireSession(session)
                let request: HSNativeExportInviteBody = try decodeBody(body)
                return try typed(try await mtProtoClient.exportInvite(
                    dialogID: try route.int64Part(at: 2),
                    title: request.title,
                    expireDate: request.expireDate,
                    usageLimit: request.usageLimit,
                    requestNeeded: request.requestNeeded,
                    session: session
                ))
            case .messagesGetExportedChatInvites:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.exportedInvites(
                    dialogID: try route.int64Part(at: 2),
                    revoked: route.boolQuery("revoked") ?? false,
                    adminID: route.int64Query("admin_id"),
                    offsetDate: route.intQuery("offset_date"),
                    offsetLink: route.stringQuery("offset_link"),
                    limit: route.intQuery("limit") ?? 50,
                    session: session
                ))
            case .messagesEditExportedChatInvite:
                let session = try requireSession(session)
                let request: HSNativeEditInviteBody = try decodeBody(body)
                return try typed(try await mtProtoClient.editInvite(
                    dialogID: try route.int64Part(at: 2),
                    link: request.link,
                    title: request.title,
                    expireDate: request.expireDate,
                    usageLimit: request.usageLimit,
                    requestNeeded: request.requestNeeded,
                    revoked: request.revoked,
                    session: session
                ))
            case .messagesDeleteExportedChatInvite:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.deleteInvite(
                    dialogID: try route.int64Part(at: 2),
                    link: route.stringQuery("link") ?? "",
                    session: session
                ))
            case .messagesGetChatInviteImporters:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.inviteImporters(
                    dialogID: try route.int64Part(at: 2),
                    requested: route.boolQuery("requested") ?? false,
                    link: route.stringQuery("link"),
                    query: route.stringQuery("q"),
                    offsetDate: route.intQuery("offset_date") ?? 0,
                    offsetUserID: route.int64Query("offset_user_id"),
                    limit: route.intQuery("limit") ?? 50,
                    session: session
                ))
            case .messagesHideChatJoinRequest:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.updateJoinRequest(
                    dialogID: try route.int64Part(at: 2),
                    userID: try route.int64Part(at: 4),
                    approve: route.parts.last == "approve",
                    session: session
                ))
            case .messagesHideAllChatJoinRequests:
                let session = try requireSession(session)
                let request: HSNativeJoinRequestsBody = try decodeBody(body)
                return try typed(try await mtProtoClient.updateAllJoinRequests(
                    dialogID: try route.int64Part(at: 2),
                    link: request.link,
                    approve: route.parts.last == "approve-all",
                    session: session
                ))
            case .channelsGetAdminLog:
                let session = try requireSession(session)
                let adminIDs = route.stringQuery("admins")?
                    .split(separator: ",")
                    .compactMap { Int64($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? []
                return try typed(try await mtProtoClient.groupAdminLog(
                    dialogID: try route.int64Part(at: 2),
                    query: route.stringQuery("q"),
                    adminIDs: adminIDs,
                    limit: route.intQuery("limit") ?? 50,
                    session: session
                ))
            case .channelsReadMessageContents:
                let session = try requireSession(session)
                let request: HSNativeMessageIDsBody = try decodeBody(body)
                return try typed(try await mtProtoClient.readChannelMessageContents(
                    dialogID: try route.int64Part(at: 2),
                    messageIDs: request.messageIDs,
                    session: session
                ))
            case .channelsReportAntiSpamFalsePositive:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.reportAntiSpamFalsePositive(
                    dialogID: try route.int64Part(at: 2),
                    messageID: try route.int64Part(at: 4),
                    session: session
                ))
            case .accountGetProfile:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.accountProfile(session: session))
            case .accountUpdateProfile:
                let session = try requireSession(session)
                let request: HSNativeAccountProfileBody = try decodeBody(body)
                return try typed(try await mtProtoClient.updateAccountProfile(
                    displayName: request.displayName,
                    username: request.username,
                    about: request.about,
                    session: session
                ))
            case .accountDeleteAccount:
                let session = try requireSession(session)
                let request: HSNativeDeleteAccountBody = try decodeBody(body)
                return try typed(try await mtProtoClient.deleteAccount(
                    reason: request.reason,
                    password: request.password,
                    session: session
                ))
            case .accountGetPrivacy:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.privacySettings(session: session))
            case .accountSetPrivacy:
                let session = try requireSession(session)
                let request: HSNativePrivacyRuleUpdateBody = try decodeBody(body)
                return try typed(try await mtProtoClient.updatePrivacySetting(
                    id: request.id,
                    value: request.value,
                    exceptions: request.exceptions,
                    session: session
                ))
            case .accountGetNotifySettings:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.notificationSettings(session: session))
            case .accountUpdateNotifySettings:
                let session = try requireSession(session)
                let settings: HSNotificationSettings = try decodeBody(body)
                return try typed(try await mtProtoClient.updateNotificationSettings(settings, session: session))
            case .accountUpdatePeerNotifySettings:
                let session = try requireSession(session)
                let request: HSNativePeerNotificationSettingsBody = try decodeBody(body)
                return try typed(try await mtProtoClient.updatePeerNotificationSettings(
                    dialogID: try route.int64Part(at: 2),
                    muteInterval: request.muteInterval,
                    showPreviews: request.showPreviews,
                    silent: request.silent,
                    sound: request.sound,
                    session: session
                ))
            case .accountGetNotifyExceptions:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.notificationExceptions(
                    scope: route.stringQuery("scope").flatMap(HSNotificationException.Scope.init(rawValue:)),
                    compareSound: route.boolQuery("compare_sound") ?? true,
                    session: session
                ))
            case .accountResetNotifySettings:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.resetNotificationSettings(session: session))
            case .accountGetSavedRingtones:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.savedRingtones(
                    hash: route.int64Query("hash") ?? 0,
                    session: session
                ))
            case .accountSaveRingtone:
                let session = try requireSession(session)
                let request: HSNativeDocumentActionBody = try decodeBody(body)
                return try typed(try await mtProtoClient.saveRingtone(
                    id: try route.int64Part(at: 3),
                    accessHash: request.accessHash,
                    fileReference: request.fileReference,
                    unsave: method == "DELETE",
                    session: session
                ))
            case .accountUploadRingtone:
                let session = try requireSession(session)
                let request: HSNativeRingtoneUploadBody = try decodeBody(body)
                return try typed(try await mtProtoClient.uploadRingtone(
                    fileName: request.fileName,
                    mimeType: request.mimeType,
                    data: request.data,
                    session: session
                ))
            case .accountReportPeer:
                let session = try requireSession(session)
                let request: HSNativeReportPeerBody = try decodeBody(body)
                return try typed(try await mtProtoClient.reportPeer(
                    dialogID: try route.int64Part(at: 2),
                    reason: request.reason,
                    message: request.message,
                    session: session
                ))
            case .accountReportProfilePhoto:
                let session = try requireSession(session)
                let request: HSNativeReportPeerBody = try decodeBody(body)
                return try typed(try await mtProtoClient.reportPeerPhoto(
                    dialogID: try route.int64Part(at: 2),
                    reason: request.reason,
                    message: request.message,
                    session: session
                ))
            case .messagesReport:
                let session = try requireSession(session)
                let request: HSNativeReportMessagesBody = try decodeBody(body)
                return try typed(try await mtProtoClient.reportMessages(
                    dialogID: try route.int64Part(at: 2),
                    messageIDs: request.messageIDs,
                    option: request.option,
                    message: request.message,
                    session: session
                ))
            case .accountGetStorageStats:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.storageSettings(session: session))
            case .accountGetAuthorizations:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.devices(session: session))
            case .accountResetAuthorization:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.resetDevice(id: try route.int64Part(at: 2), session: session))
            case .accountRegisterDevice:
                let session = try requireSession(session)
                let request: HSNativePushTokenBody = try decodeBody(body)
                return try typed(try await mtProtoClient.registerPushToken(
                    token: request.token,
                    tokenType: request.tokenType,
                    sandbox: request.sandbox,
                    otherUserIDs: request.otherUserIDs,
                    session: session
                ))
            case .accountUnregisterDevice:
                let session = try requireSession(session)
                let request: HSNativePushTokenBody = try decodeBody(body)
                return try typed(try await mtProtoClient.unregisterPushToken(
                    token: request.token,
                    tokenType: request.tokenType,
                    otherUserIDs: request.otherUserIDs,
                    session: session
                ))
            case .messagesGetStickerAndReactionState:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.assetCatalog(session: session))
            case .messagesInstallStickerSet:
                let session = try requireSession(session)
                let request: HSNativeStickerSetActionBody = try decodeBody(body)
                return try typed(try await mtProtoClient.installStickerSet(
                    id: try route.int64Part(at: 3),
                    accessHash: request.accessHash,
                    archived: request.archived ?? false,
                    session: session
                ))
            case .messagesUninstallStickerSet:
                let session = try requireSession(session)
                let request: HSNativeStickerSetActionBody = try decodeBody(body)
                return try typed(try await mtProtoClient.uninstallStickerSet(
                    id: try route.int64Part(at: 3),
                    accessHash: request.accessHash,
                    session: session
                ))
            case .messagesReadFeaturedStickers:
                let session = try requireSession(session)
                let request: HSNativeFeaturedStickerSetsReadBody = try decodeBody(body)
                return try typed(try await mtProtoClient.readFeaturedStickerSets(request.ids, session: session))
            case .messagesGetStickerSet:
                let session = try requireSession(session)
                if route.parts.indices.contains(3), route.parts[3] == "by-short-name" {
                    return try typed(try await mtProtoClient.stickerSetDetails(
                        shortName: try route.stringPart(at: 4),
                        hash: route.intQuery("hash") ?? 0,
                        session: session
                    ))
                }
                return try typed(try await mtProtoClient.stickerSetDetails(
                    id: try route.int64Part(at: 3),
                    accessHash: route.int64Query("access_hash") ?? 0,
                    hash: route.intQuery("hash") ?? 0,
                    session: session
                ))
            case .messagesGetStickers:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.stickersForEmoji(
                    route.stringQuery("emoji") ?? "",
                    hash: route.int64Query("hash") ?? 0,
                    session: session
                ))
            case .messagesGetCustomEmojiDocuments:
                let session = try requireSession(session)
                let ids = route.stringQuery("ids")?
                    .split(separator: ",")
                    .compactMap { Int64(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) } ?? []
                return try typed(try await mtProtoClient.customEmojiDocuments(ids: ids, session: session))
            case .messagesGetEmojiStickers:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.customEmojiStickerSets(
                    hash: route.int64Query("hash") ?? 0,
                    session: session
                ))
            case .messagesSearchCustomEmoji:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.searchCustomEmoji(
                    route.stringQuery("emoji") ?? "",
                    hash: route.int64Query("hash") ?? 0,
                    session: session
                ))
            case .messagesGetEmojiKeywords:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.emojiKeywords(
                    langCode: route.stringQuery("lang_code") ?? "en",
                    session: session
                ))
            case .messagesGetEmojiKeywordsDifference:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.emojiKeywordsDifference(
                    langCode: route.stringQuery("lang_code") ?? "en",
                    fromVersion: route.intQuery("from_version") ?? 0,
                    session: session
                ))
            case .messagesGetEmojiKeywordsLanguages:
                let session = try requireSession(session)
                let langCodes = route.stringQuery("lang_codes")?
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } ?? []
                return try typed(try await mtProtoClient.emojiKeywordLanguages(langCodes, session: session))
            case .langpackGetLanguages:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.localizationLanguages(
                    langPack: route.stringQuery("lang_pack") ?? "",
                    session: session
                ))
            case .langpackGetLanguage:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.localizationLanguage(
                    langPack: route.stringQuery("lang_pack") ?? "",
                    langCode: try route.stringPart(at: 3),
                    session: session
                ))
            case .langpackGetLangPack:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.localizationPack(
                    langPack: route.stringQuery("lang_pack") ?? "",
                    langCode: try route.stringPart(at: 3),
                    session: session
                ))
            case .langpackGetStrings:
                let session = try requireSession(session)
                let keys = route.stringQuery("keys")?
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } ?? []
                return try typed(try await mtProtoClient.localizationStrings(
                    langPack: route.stringQuery("lang_pack") ?? "",
                    langCode: route.stringQuery("lang_code") ?? "en",
                    keys: keys,
                    session: session
                ))
            case .langpackGetDifference:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.localizationPackDifference(
                    langPack: route.stringQuery("lang_pack") ?? "",
                    langCode: try route.stringPart(at: 3),
                    fromVersion: route.intQuery("from_version") ?? 0,
                    session: session
                ))
            case .messagesGetArchivedStickers:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.archivedStickerSets(
                    kind: route.stringQuery("kind") ?? "stickers",
                    offsetID: route.int64Query("offset_id") ?? 0,
                    limit: route.intQuery("limit") ?? 200,
                    session: session
                ))
            case .messagesGetRecentStickers:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.recentStickers(
                    attached: route.boolQuery("attached") ?? false,
                    hash: route.int64Query("hash") ?? 0,
                    session: session
                ))
            case .messagesSaveRecentSticker:
                let session = try requireSession(session)
                let request: HSNativeStickerDocumentActionBody = try decodeBody(body)
                return try typed(try await mtProtoClient.saveRecentSticker(
                    id: try route.int64Part(at: 3),
                    accessHash: request.accessHash,
                    fileReference: request.fileReference,
                    attached: request.attached,
                    unsave: method == "DELETE",
                    session: session
                ))
            case .messagesClearRecentStickers:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.clearRecentStickers(
                    attached: route.boolQuery("attached") ?? false,
                    session: session
                ))
            case .messagesGetFavedStickers:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.favedStickers(
                    hash: route.int64Query("hash") ?? 0,
                    session: session
                ))
            case .messagesGetSavedGifs:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.savedGifs(
                    hash: route.int64Query("hash") ?? 0,
                    session: session
                ))
            case .messagesSaveGif:
                let session = try requireSession(session)
                let request: HSNativeDocumentActionBody = try decodeBody(body)
                return try typed(try await mtProtoClient.saveGif(
                    id: try route.int64Part(at: 3),
                    accessHash: request.accessHash,
                    fileReference: request.fileReference,
                    unsave: method == "DELETE",
                    session: session
                ))
            case .accountGetWallPapers:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.wallpapers(
                    hash: route.int64Query("hash") ?? 0,
                    session: session
                ))
            case .accountGetWallPaper:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.wallpaper(
                    slug: try route.stringPart(at: 2),
                    session: session
                ))
            case .accountSaveWallPaper:
                let session = try requireSession(session)
                let request: HSNativeWallpaperActionBody = try decodeBody(body)
                return try typed(try await mtProtoClient.saveWallpaper(
                    slug: try route.stringPart(at: 2),
                    settings: request.settings,
                    unsave: method == "DELETE",
                    session: session
                ))
            case .accountInstallWallPaper:
                let session = try requireSession(session)
                let request: HSNativeWallpaperActionBody = try decodeBody(body)
                if route.parts.indices.contains(2), route.parts[2] == "no-file" {
                    return try typed(try await mtProtoClient.installWallpaperNoFile(
                        id: try route.int64Part(at: 3),
                        settings: request.settings,
                        session: session
                    ))
                }
                return try typed(try await mtProtoClient.installWallpaper(
                    slug: try route.stringPart(at: 2),
                    id: request.id ?? 0,
                    accessHash: request.accessHash ?? 0,
                    settings: request.settings,
                    session: session
                ))
            case .accountResetWallPapers:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.resetWallpapers(session: session))
            case .messagesGetRecentReactions:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.recentReactions(
                    limit: route.intQuery("limit") ?? 100,
                    hash: route.int64Query("hash") ?? 0,
                    session: session
                ))
            case .messagesGetTopReactions:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.topReactions(
                    limit: route.intQuery("limit") ?? 32,
                    hash: route.int64Query("hash") ?? 0,
                    session: session
                ))
            case .helpGetConfigDefaultReaction:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.defaultReaction(session: session))
            case .messagesSetDefaultReaction:
                let session = try requireSession(session)
                let request: HSNativeDefaultReactionBody = try decodeBody(body)
                return try typed(try await mtProtoClient.setDefaultReaction(request.reaction, session: session))
            case .messagesClearRecentReactions:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.clearRecentReactions(session: session))
            case .trustReadState:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.trustItems(session: session))
            case .entitlementsReadState:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.entitlements(session: session))
            case .adminToolsReadState:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.adminTools(session: session))
            default:
                throw HSAPIError.server(
                    code: "HS_NATIVE_MTPROTO_RPC_PENDING",
                    message: "默认构建已路由到 HSgram 自有 MTProto 入口；\(operation.rawValue) 仍在按旧版 HSgram-ios schema 逐项迁移。详情：\(path)。"
                )
            }
        } catch let error as HSNativeMTProtoError {
            throw apiError(from: error)
        }
    }

    private func apiError(from error: HSNativeMTProtoError) -> HSAPIError {
        .server(code: error.serverCode, message: error.localizedDescription)
    }

    private func requireSession(_ session: HSUserSession?) throws -> HSUserSession {
        guard let session else {
            throw HSAPIError.missingSession
        }
        return session
    }

    private func decodeBody<Value: Decodable, Body: Encodable>(_ body: Body?) throws -> Value {
        guard let body else {
            throw HSAPIError.server(code: "MISSING_BODY", message: "请求缺少必要参数。")
        }
        let data = try encoder.encode(body)
        return try decoder.decode(Value.self, from: data)
    }

    private func typed<Response: Decodable>(_ value: Any) throws -> Response {
        guard let response = value as? Response else {
            throw HSAPIError.server(
                code: "NATIVE_RESPONSE_TYPE_MISMATCH",
                message: "原生 MTProto 适配返回类型和当前 UI 期望不一致。"
            )
        }
        return response
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

private struct HSNativeMediaMessageBody: Decodable {
    let fileName: String
    let mimeType: String
    let data: Data
    let mediaKind: String
    let caption: String
    let replyToMessageID: Int64?
    let duration: Double?
    let waveform: Data?
}

private struct HSNativePollMessageBody: Decodable {
    let question: String
    let answers: [HSPollAnswerInput]
    let isMultipleChoice: Bool
    let isQuiz: Bool
    let isAnonymous: Bool
    let correctAnswerOptions: [Data]?
    let solution: String?
    let closePeriod: Int?
    let replyToMessageID: Int64?

    private enum CodingKeys: String, CodingKey {
        case question
        case answers
        case isMultipleChoice = "is_multiple_choice"
        case isQuiz = "is_quiz"
        case isAnonymous = "is_anonymous"
        case correctAnswerOptions = "correct_answer_options"
        case solution
        case closePeriod = "close_period"
        case replyToMessageID
    }
}

private struct HSNativePollVoteBody: Decodable {
    let options: [Data]
}

private struct HSNativeTodoMessageBody: Decodable {
    let title: String
    let items: [HSTodoItem]
    let othersCanAppend: Bool
    let othersCanComplete: Bool
    let replyToMessageID: Int64?

    private enum CodingKeys: String, CodingKey {
        case title
        case items
        case othersCanAppend = "others_can_append"
        case othersCanComplete = "others_can_complete"
        case replyToMessageID
    }
}

private struct HSNativeTodoToggleBody: Decodable {
    let completedIDs: [Int]
    let incompletedIDs: [Int]

    private enum CodingKeys: String, CodingKey {
        case completedIDs = "completed_ids"
        case incompletedIDs = "incompleted_ids"
    }
}

private struct HSNativeTodoItemsBody: Decodable {
    let items: [HSTodoItem]
}

private struct HSNativeTypingActivityBody: Decodable {
    let activity: HSInputActivityKind
    let progress: Int?
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

private struct HSNativeDialogFilterBody: Decodable {
    let filter: HSChatListFilter
}

private struct HSNativeDialogFilterOrderBody: Decodable {
    let ids: [Int]
}

private struct HSNativeDialogFilterTagsBody: Decodable {
    let enabled: Bool
}

private struct HSNativeChatListSharedInviteBody: Decodable {
    let title: String?
    let peers: [HSChatListFilterPeer]?
}

private struct HSNativeChatListJoinInviteBody: Decodable {
    let peers: [HSChatListFilterPeer]
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
    let dropAuthor: Bool
    let dropMediaCaptions: Bool
}

private struct HSNativeReactionBody: Decodable {
    let reaction: String
    let big: Bool
}

private struct HSNativeDefaultReactionBody: Decodable {
    let reaction: String
}

private struct HSNativeStickerSetActionBody: Decodable {
    let accessHash: Int64
    let archived: Bool?

    private enum CodingKeys: String, CodingKey {
        case accessHash = "access_hash"
        case archived
    }
}

private struct HSNativeFeaturedStickerSetsReadBody: Decodable {
    let ids: [Int64]
}

private struct HSNativeStickerDocumentActionBody: Decodable {
    let accessHash: Int64
    let fileReference: Data
    let attached: Bool

    private enum CodingKeys: String, CodingKey {
        case accessHash = "access_hash"
        case fileReference = "file_reference"
        case attached
    }
}

private struct HSNativeDocumentActionBody: Decodable {
    let accessHash: Int64
    let fileReference: Data

    private enum CodingKeys: String, CodingKey {
        case accessHash = "access_hash"
        case fileReference = "file_reference"
    }
}

private struct HSNativeWallpaperActionBody: Decodable {
    let id: Int64?
    let accessHash: Int64?
    let settings: HSWallpaperSettings

    private enum CodingKeys: String, CodingKey {
        case id
        case accessHash = "access_hash"
        case settings
    }
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

private struct HSNativeContactPhonesBody: Decodable {
    let phones: [String]
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
    let legacyRevokePermanent: Bool
}

private struct HSNativeEditInviteBody: Decodable {
    let link: String
    let title: String?
    let expireDate: Int?
    let usageLimit: Int?
    let requestNeeded: Bool?
    let revoked: Bool
}

private struct HSNativeJoinRequestsBody: Decodable {
    let link: String?
}

private struct HSNativeUsernameBody: Decodable {
    let username: String?
}

private struct HSNativeDiscussionGroupBody: Decodable {
    let groupDialogID: Int64?

    enum CodingKeys: String, CodingKey {
        case groupDialogID = "group_dialog_id"
    }
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

private struct HSNativePeerNotificationSettingsBody: Decodable {
    let muteInterval: Int?
    let showPreviews: Bool
    let silent: Bool
    let sound: HSNotificationSound?

    enum CodingKeys: String, CodingKey {
        case muteInterval = "mute_interval"
        case showPreviews = "show_previews"
        case silent
        case sound
    }
}

private struct HSNativeRingtoneUploadBody: Decodable {
    let fileName: String
    let mimeType: String
    let data: Data

    enum CodingKeys: String, CodingKey {
        case fileName = "file_name"
        case mimeType = "mime_type"
        case data
    }
}

private struct HSNativeReportPeerBody: Decodable {
    let reason: HSReportReason
    let message: String
}

private struct HSNativeReportMessagesBody: Decodable {
    let messageIDs: [Int64]
    let option: Data?
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case messageIDs = "message_ids"
        case option
        case message
    }
}

private struct HSNativeMessageIDsBody: Decodable {
    let messageIDs: [Int64]

    private enum CodingKeys: String, CodingKey {
        case messageIDs = "message_ids"
    }
}

private struct HSNativePushTokenBody: Decodable {
    let token: String
    let tokenType: Int
    let sandbox: Bool
    let otherUserIDs: [Int64]
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

    func intQuery(_ name: String) -> Int? {
        queryItems[name].flatMap(Int.init)
    }

    func stringQuery(_ name: String) -> String? {
        queryItems[name]
    }

    func int64Query(_ name: String) -> Int64? {
        queryItems[name].flatMap(Int64.init)
    }

    func boolQuery(_ name: String) -> Bool? {
        queryItems[name].flatMap(Bool.init)
    }

    func rawStringPart(at index: Int) throws -> String {
        guard parts.indices.contains(index) else {
            throw HSAPIError.server(code: "BAD_ROUTE", message: "鍘熺敓鍗忚閫傞厤鏃犳硶瑙ｆ瀽璺緞鍙傛暟锛歕(parts.joined(separator: "/"))")
        }
        return parts[index]
    }

    func memberFilterQuery() -> HSSupergroupMemberFilter {
        queryItems["filter"].flatMap(HSSupergroupMemberFilter.init(rawValue:)) ?? .recent
    }

    func int64Part(at index: Int) throws -> Int64 {
        guard parts.indices.contains(index), let value = Int64(parts[index]) else {
            throw HSAPIError.server(code: "BAD_ROUTE", message: "原生协议适配无法解析路径参数：\(parts.joined(separator: "/"))")
        }
        return value
    }

    func intPart(at index: Int) throws -> Int {
        guard parts.indices.contains(index), let value = Int(parts[index]) else {
            throw HSAPIError.server(code: "BAD_ROUTE", message: "原生协议适配无法解析路径参数：\(parts.joined(separator: "/"))")
        }
        return value
    }

    func stringPart(at index: Int) throws -> String {
        guard parts.indices.contains(index) else {
            throw HSAPIError.server(code: "BAD_ROUTE", message: "Native route is missing a path parameter.")
        }
        return parts[index].removingPercentEncoding ?? parts[index]
    }
}
