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
            case .contactsSearch:
                let session = try requireSession(session)
                return try typed(try await mtProtoClient.searchContacts(
                    query: route.stringQuery("q") ?? "",
                    limit: route.intQuery("limit") ?? 20,
                    session: session
                ))
            case .contactsAddContact:
                let session = try requireSession(session)
                let request: HSNativeContactRequestBody = try decodeBody(body)
                return try typed(try await mtProtoClient.addContact(
                    userID: request.userID,
                    firstName: request.firstName,
                    lastName: request.lastName,
                    phone: request.phone,
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

private struct HSNativeContactRequestBody: Decodable {
    let userID: Int64
    let firstName: String
    let lastName: String
    let phone: String
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
}
