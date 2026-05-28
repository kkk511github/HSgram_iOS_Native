import Foundation

enum HSAPIError: LocalizedError {
    case invalidURL
    case missingSession
    case signUpRequired(termsOfService: HSTermsOfService?)
    case server(code: String?, message: String)
    case emptyResponse
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server URL is invalid."
        case .missingSession:
            return "Please sign in again."
        case .signUpRequired:
            return "该邮箱需要创建账号。"
        case .server(_, let message):
            return message
        case .emptyResponse:
            return "The server returned an empty response."
        case .transport(let error):
            return error.localizedDescription
        }
    }

    var serverCode: String? {
        if case .signUpRequired = self {
            return "SIGN_UP_REQUIRED"
        }
        if case let .server(code, _) = self {
            return code
        }
        return nil
    }

    var signUpTermsOfService: HSTermsOfService? {
        if case let .signUpRequired(termsOfService) = self {
            return termsOfService
        }
        return nil
    }
}

enum HSNativeFacadeMode: Equatable {
    case deployedServerProtocol
    case localRESTBridge
}

struct HSBackendConfiguration: Equatable {
    let baseURL: URL
    let nativeFacadeMode: HSNativeFacadeMode

    static let deployedServer = HSBackendConfiguration(
        baseURL: URL(string: "https://hsgram.cloud")!,
        nativeFacadeMode: .deployedServerProtocol
    )

    static var current: HSBackendConfiguration {
        let environment = ProcessInfo.processInfo.environment
        guard environment["HS_NATIVE_REST_BRIDGE"] == "1" else {
            return .deployedServer
        }
        let bridgeURL = environment["HS_NATIVE_REST_BRIDGE_URL"]
            .flatMap(URL.init(string:)) ?? URL(string: "https://hsgram.cloud")!
        return HSBackendConfiguration(baseURL: bridgeURL, nativeFacadeMode: .localRESTBridge)
    }

    var allowsNativeRESTFacade: Bool {
        nativeFacadeMode == .localRESTBridge
    }
}

final class HSAPIClient {
    static let shared = HSAPIClient()

    private let configuration: HSBackendConfiguration
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let serverTransport: HSServerTransport

    init(
        configuration: HSBackendConfiguration = .current,
        session: URLSession = .shared,
        serverTransport: HSServerTransport = HSDeployedServerTransport()
    ) {
        self.configuration = configuration
        self.baseURL = configuration.baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .secondsSince1970
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .secondsSince1970
        self.serverTransport = serverTransport
    }

    convenience init(baseURL: URL, session: URLSession = .shared) {
        self.init(
            configuration: HSBackendConfiguration(baseURL: baseURL, nativeFacadeMode: .localRESTBridge),
            session: session
        )
    }

    func sendEmailCode(email: String) async throws -> HSEmailStartResponse {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.sendEmailCode(email: email)
        }
        return try await request(
            "v1/auth/email/start",
            method: "POST",
            body: ["email": email, "purpose": "sign_in_or_register"],
            session: nil
        )
    }

    func verifyEmailCode(email: String, code: String, transactionID: String, displayName: String) async throws -> HSUserSession {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.verifyEmailCode(email: email, code: code, transactionID: transactionID, displayName: displayName)
        }
        return try await request(
            "v1/auth/email/verify",
            method: "POST",
            body: [
                "email": email,
                "code": code,
                "transaction_id": transactionID,
                "display_name": displayName
            ],
            session: nil
        )
    }

    func signUp(email: String, transactionID: String, displayName: String, inviteCode: String) async throws -> HSUserSession {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.signUp(
                email: email,
                transactionID: transactionID,
                displayName: displayName,
                inviteCode: inviteCode
            )
        }
        throw HSAPIError.server(
            code: "NATIVE_REST_FACADE_NOT_DEPLOYED",
            message: "显式注册必须走现有 MTProto auth.signUp；本地 /v1 测试桥没有这个线上协议。"
        )
    }

    func uploadProfilePhoto(data: Data, session: HSUserSession) async throws {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.uploadProfilePhoto(data: data, session: session)
        }
        throw HSAPIError.server(
            code: "NATIVE_REST_FACADE_NOT_DEPLOYED",
            message: "头像上传必须走现有 MTProto photos.uploadProfilePhoto；本地 /v1 测试桥没有这个线上协议。"
        )
    }

    func removeProfilePhoto(session: HSUserSession) async throws {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.removeProfilePhoto(session: session)
        }
        throw HSAPIError.server(
            code: "NATIVE_REST_FACADE_NOT_DEPLOYED",
            message: "头像移除必须走现有 MTProto photos.updateProfilePhoto；本地 /v1 测试桥没有这个线上协议。"
        )
    }

    func verifyLoginPassword(email: String, password: String) async throws -> HSUserSession {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.verifyLoginPassword(email: email, password: password)
        }
        return try await request(
            "v1/auth/password/verify",
            method: "POST",
            body: [
                "email": email,
                "password": password
            ],
            session: nil
        )
    }

    func requestPasswordRecovery(email: String) async throws -> HSPasswordRecoveryResponse {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.requestPasswordRecovery(email: email)
        }
        throw HSAPIError.server(
            code: "NATIVE_REST_FACADE_NOT_DEPLOYED",
            message: "密码恢复必须走现有 MTProto auth.requestPasswordRecovery；本地 /v1 测试桥没有这个线上协议。"
        )
    }

    func recoverPassword(email: String, code: String) async throws -> HSUserSession {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.recoverPassword(email: email, code: code)
        }
        throw HSAPIError.server(
            code: "NATIVE_REST_FACADE_NOT_DEPLOYED",
            message: "密码恢复必须走现有 MTProto auth.recoverPassword；本地 /v1 测试桥没有这个线上协议。"
        )
    }

    func loginPasswordSettings(session: HSUserSession) async throws -> HSLoginPasswordSettings {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.loginPasswordSettings(session: session)
        }
        throw HSAPIError.server(
            code: "NATIVE_REST_FACADE_NOT_DEPLOYED",
            message: "登录密码设置必须走现有 MTProto account.getPassword；本地 /v1 测试桥没有这个线上协议。"
        )
    }

    func updateLoginPassword(
        currentPassword: String?,
        newPassword: String?,
        hint: String?,
        recoveryEmail: String?,
        session: HSUserSession
    ) async throws -> HSLoginPasswordSettings {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.updateLoginPassword(
                currentPassword: currentPassword,
                newPassword: newPassword,
                hint: hint,
                recoveryEmail: recoveryEmail,
                session: session
            )
        }
        throw HSAPIError.server(
            code: "NATIVE_REST_FACADE_NOT_DEPLOYED",
            message: "登录密码设置必须走现有 MTProto account.updatePasswordSettings；本地 /v1 测试桥没有这个线上协议。"
        )
    }

    func confirmLoginPasswordEmail(code: String, session: HSUserSession) async throws -> HSLoginPasswordSettings {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.confirmLoginPasswordEmail(code: code, session: session)
        }
        throw HSAPIError.server(
            code: "NATIVE_REST_FACADE_NOT_DEPLOYED",
            message: "登录密码恢复邮箱确认必须走现有 MTProto account.confirmPasswordEmail。"
        )
    }

    func resendLoginPasswordEmail(session: HSUserSession) async throws -> HSLoginPasswordSettings {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.resendLoginPasswordEmail(session: session)
        }
        throw HSAPIError.server(
            code: "NATIVE_REST_FACADE_NOT_DEPLOYED",
            message: "登录密码恢复邮箱确认必须走现有 MTProto account.resendPasswordEmail。"
        )
    }

    func cancelLoginPasswordEmail(session: HSUserSession) async throws -> HSLoginPasswordSettings {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.cancelLoginPasswordEmail(session: session)
        }
        throw HSAPIError.server(
            code: "NATIVE_REST_FACADE_NOT_DEPLOYED",
            message: "登录密码恢复邮箱确认必须走现有 MTProto account.cancelPasswordEmail。"
        )
    }

    func workspaceSummary(session: HSUserSession) async throws -> HSWorkspaceSummary {
        try await request("workspace/summary", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func dialogs(folderID: Int? = nil, session: HSUserSession) async throws -> [HSChat] {
        var path = "v1/dialogs"
        if let folderID {
            path += "?folder_id=\(folderID)"
        }
        return try await request(path, method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func dialogFilters(session: HSUserSession) async throws -> HSChatListFiltersState {
        try await request("v1/dialog-filters", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func updateDialogFilter(_ filter: HSChatListFilter, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialog-filters/\(filter.id)",
            method: "PUT",
            body: DialogFilterBody(filter: filter),
            session: session
        )
    }

    func deleteDialogFilter(id: Int, session: HSUserSession) async throws -> HSMessageAction {
        try await request("v1/dialog-filters/\(id)", method: "DELETE", body: Optional<EmptyBody>.none, session: session)
    }

    func reorderDialogFilters(ids: [Int], session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialog-filters",
            method: "PUT",
            body: DialogFilterOrderBody(ids: ids),
            session: session
        )
    }

    func setDialogFilterTagsEnabled(_ enabled: Bool, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialog-filters/tags",
            method: "PUT",
            body: DialogFilterTagsBody(enabled: enabled),
            session: session
        )
    }

    func drafts(session: HSUserSession) async throws -> [HSDraft] {
        try await request("v1/drafts", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func search(query: String, limit: Int = 20, session: HSUserSession) async throws -> HSSearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return HSSearchResults(query: "", dialogs: [], contacts: [], messages: [])
        }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return try await request("v1/search?q=\(encoded)&limit=\(limit)", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func searchMessages(
        dialogID: Int64,
        query: String,
        offsetID: Int64? = nil,
        limit: Int = 100,
        session: HSUserSession
    ) async throws -> [HSSearchMessage] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }
        let safeLimit = max(1, min(limit, 100))
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        var path = "v1/dialogs/\(dialogID)/search?q=\(encoded)&limit=\(safeLimit)"
        if let offsetID {
            path += "&offset_id=\(offsetID)"
        }
        return try await request(path, method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func messages(dialogID: Int64, beforeID: Int64? = nil, limit: Int = 50, session: HSUserSession) async throws -> [HSMessage] {
        var path = "v1/dialogs/\(dialogID)/messages?limit=\(limit)"
        if let beforeID {
            path += "&before_id=\(beforeID)"
        }
        return try await request(path, method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func sharedMedia(
        dialogID: Int64,
        filter: HSSharedMediaFilter,
        offsetID: Int64? = nil,
        limit: Int = 50,
        session: HSUserSession
    ) async throws -> [HSMessage] {
        let safeLimit = max(1, min(limit, 50))
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.sharedMedia(
                dialogID: dialogID,
                filter: filter,
                offsetID: offsetID,
                limit: safeLimit,
                session: session
            )
        }
        var path = "v1/dialogs/\(dialogID)/shared-media?filter=\(filter.rawValue)&limit=\(safeLimit)"
        if let offsetID {
            path += "&offset_id=\(offsetID)"
        }
        return try await request(path, method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func sharedMediaCounters(
        dialogID: Int64,
        filters: [HSSharedMediaFilter] = HSSharedMediaFilter.allCases,
        session: HSUserSession
    ) async throws -> [HSSharedMediaCounter] {
        let requestedFilters = filters.isEmpty ? HSSharedMediaFilter.allCases : filters
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.sharedMediaCounters(
                dialogID: dialogID,
                filters: requestedFilters,
                session: session
            )
        }
        let filterQuery = requestedFilters.map(\.rawValue).joined(separator: ",")
        return try await request(
            "v1/dialogs/\(dialogID)/shared-media/counters?filters=\(filterQuery)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func sendMessage(dialogID: Int64, text: String, replyToMessageID: Int64? = nil, session: HSUserSession) async throws -> HSMessage {
        try await sendMessage(
            dialogID: dialogID,
            text: text,
            replyToMessageID: replyToMessageID,
            disableWebPagePreview: false,
            session: session
        )
    }

    func sendMessage(
        dialogID: Int64,
        text: String,
        replyToMessageID: Int64? = nil,
        disableWebPagePreview: Bool,
        session: HSUserSession
    ) async throws -> HSMessage {
        try await request(
            "v1/dialogs/\(dialogID)/messages",
            method: "POST",
            body: SendMessageBody(text: text, replyToMessageID: replyToMessageID, noWebpage: disableWebPagePreview),
            session: session
        )
    }

    func webPagePreview(text: String, session: HSUserSession) async throws -> HSWebPagePreview? {
        try await serverTransport.webPagePreview(text: text, session: session)
    }

    func sendMedia(
        dialogID: Int64,
        fileName: String,
        mimeType: String,
        data: Data,
        mediaKind: String,
        caption: String = "",
        replyToMessageID: Int64? = nil,
        duration: Double? = nil,
        waveform: Data? = nil,
        session: HSUserSession,
        progress: ((HSMediaTransferProgress) -> Void)? = nil
    ) async throws -> HSMessage {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.sendMedia(
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
        progress?(HSMediaTransferProgress(completedBytes: 0, totalBytes: Int64(data.count)))
        let message: HSMessage = try await request(
            "v1/dialogs/\(dialogID)/media",
            method: "POST",
            body: MediaMessageBody(
                fileName: fileName,
                mimeType: mimeType,
                data: data,
                mediaKind: mediaKind,
                caption: caption,
                replyToMessageID: replyToMessageID,
                duration: duration,
                waveform: waveform
            ),
            session: session
        )
        progress?(HSMediaTransferProgress(completedBytes: Int64(data.count), totalBytes: Int64(data.count)))
        return message
    }

    func setTyping(
        dialogID: Int64,
        activity: HSInputActivityKind,
        progress: Int? = nil,
        session: HSUserSession
    ) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/typing",
            method: "POST",
            body: TypingActivityBody(activity: activity, progress: progress),
            session: session
        )
    }

    func downloadMedia(_ media: HSMessageMedia, session: HSUserSession) async throws -> Data {
        try await downloadMedia(media, session: session, progress: nil)
    }

    func downloadMedia(
        _ media: HSMessageMedia,
        session: HSUserSession,
        progress: ((HSMediaTransferProgress) -> Void)?
    ) async throws -> Data {
        try await serverTransport.downloadMedia(media, session: session, progress: progress)
    }

    func saveDraft(
        dialogID: Int64,
        text: String,
        replyToMessageID: Int64? = nil,
        disableWebPagePreview: Bool = false,
        session: HSUserSession
    ) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/draft",
            method: "PUT",
            body: DraftBody(text: text, replyToMessageID: replyToMessageID, noWebpage: disableWebPagePreview),
            session: session
        )
    }

    func markDialogRead(dialogID: Int64, maxMessageID: Int64? = nil, session: HSUserSession) async throws -> HSMessageAction {
        var path = "v1/dialogs/\(dialogID)/read"
        if let maxMessageID {
            path += "?max_id=\(maxMessageID)"
        }
        return try await request(path, method: "POST", body: Optional<EmptyBody>.none, session: session)
    }

    func markDialogUnread(dialogID: Int64, unread: Bool = true, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/unread",
            method: "POST",
            body: MarkUnreadBody(unread: unread),
            session: session
        )
    }

    func setDialogPinned(dialogID: Int64, pinned: Bool, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/pin",
            method: "POST",
            body: DialogPinBody(pinned: pinned),
            session: session
        )
    }

    func reorderPinnedDialogs(dialogIDs: [Int64], folderID: Int, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/pins/order",
            method: "PUT",
            body: DialogPinOrderBody(dialogIDs: dialogIDs, folderID: folderID),
            session: session
        )
    }

    func setDialogFolder(dialogID: Int64, folderID: Int, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/folder",
            method: "PUT",
            body: DialogFolderBody(folderID: folderID),
            session: session
        )
    }

    func editMessage(dialogID: Int64, messageID: Int64, text: String, session: HSUserSession) async throws -> HSMessage {
        try await request(
            "v1/dialogs/\(dialogID)/messages/\(messageID)",
            method: "PATCH",
            body: ["text": text],
            session: session
        )
    }

    func deleteMessage(dialogID: Int64, messageID: Int64, revoke: Bool = true, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/messages/\(messageID)?revoke=\(revoke)",
            method: "DELETE",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func deleteDialogHistory(
        dialogID: Int64,
        justClear: Bool,
        revoke: Bool,
        maxMessageID: Int64?,
        session: HSUserSession
    ) async throws -> HSMessageAction {
        var queryItems = [
            "just_clear=\(justClear)",
            "revoke=\(revoke)"
        ]
        if let maxMessageID {
            queryItems.append("max_id=\(maxMessageID)")
        }
        return try await request(
            "v1/dialogs/\(dialogID)/history?\(queryItems.joined(separator: "&"))",
            method: "DELETE",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func forwardMessage(dialogID: Int64, messageID: Int64, toDialogID: Int64, session: HSUserSession) async throws -> HSMessage {
        try await request(
            "v1/dialogs/\(dialogID)/messages/\(messageID)/forward",
            method: "POST",
            body: ForwardMessageBody(toDialogID: toDialogID, dropAuthor: false, dropMediaCaptions: false),
            session: session
        )
    }

    func sendReaction(dialogID: Int64, messageID: Int64, reaction: String, big: Bool = false, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/messages/\(messageID)/reactions",
            method: "POST",
            body: ReactionBody(reaction: reaction, big: big),
            session: session
        )
    }

    func circles(session: HSUserSession) async throws -> [HSCircle] {
        try await request("v1/circles", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func channels(session: HSUserSession) async throws -> [HSChannel] {
        try await request("v1/channels", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func createChannel(title: String, about: String = "", memberIDs: [Int64] = [], session: HSUserSession) async throws -> HSChannel {
        try await request(
            "v1/channels",
            method: "POST",
            body: SupergroupCreateBody(title: title, about: about, memberIDs: memberIDs),
            session: session
        )
    }

    func channel(dialogID: Int64, session: HSUserSession) async throws -> HSChannel {
        try await request("v1/channels/\(dialogID)", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func updateChannel(dialogID: Int64, title: String? = nil, about: String? = nil, session: HSUserSession) async throws -> HSChannel {
        try await request(
            "v1/channels/\(dialogID)",
            method: "PATCH",
            body: SupergroupUpdateBody(title: title, about: about),
            session: session
        )
    }

    func leaveChannel(dialogID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request("v1/channels/\(dialogID)/leave", method: "POST", body: Optional<EmptyBody>.none, session: session)
    }

    func channelSubscribers(dialogID: Int64, limit: Int = 50, offset: Int = 0, session: HSUserSession) async throws -> [HSSupergroupMember] {
        try await request("v1/channels/\(dialogID)/subscribers?limit=\(limit)&offset=\(offset)", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func inviteChannelSubscribers(dialogID: Int64, userIDs: [Int64], session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/channels/\(dialogID)/subscribers",
            method: "POST",
            body: SupergroupMembersBody(userIDs: userIDs),
            session: session
        )
    }

    func removeChannelSubscriber(dialogID: Int64, userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/channels/\(dialogID)/subscribers/\(userID)",
            method: "DELETE",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func editChannelAdmin(dialogID: Int64, userID: Int64, rights: HSSupergroupAdminRights, rank: String? = nil, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/channels/\(dialogID)/admins/\(userID)",
            method: "PATCH",
            body: SupergroupAdminBody(rights: rights, rank: rank),
            session: session
        )
    }

    func channelAdminLog(dialogID: Int64, query: String? = nil, adminIDs: [Int64] = [], limit: Int = 50, session: HSUserSession) async throws -> [HSSupergroupAdminLogEvent] {
        var items = ["limit=\(limit)"]
        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            items.append("q=\(encoded)")
        }
        if !adminIDs.isEmpty {
            items.append("admins=\(adminIDs.map { String($0) }.joined(separator: ","))")
        }
        return try await request(
            "v1/channels/\(dialogID)/admin-log?\(items.joined(separator: "&"))",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func exportChannelInvite(dialogID: Int64, title: String? = nil, expireDate: Int? = nil, usageLimit: Int? = nil, requestNeeded: Bool = false, session: HSUserSession) async throws -> HSExportedInvite {
        try await request(
            "v1/channels/\(dialogID)/invites",
            method: "POST",
            body: ExportInviteBody(title: title, expireDate: expireDate, usageLimit: usageLimit, requestNeeded: requestNeeded, legacyRevokePermanent: false),
            session: session
        )
    }

    func createSupergroup(title: String, about: String = "", memberIDs: [Int64] = [], session: HSUserSession) async throws -> HSSupergroup {
        try await request(
            "v1/supergroups",
            method: "POST",
            body: SupergroupCreateBody(title: title, about: about, memberIDs: memberIDs),
            session: session
        )
    }

    func supergroup(dialogID: Int64, session: HSUserSession) async throws -> HSSupergroup {
        try await request("v1/supergroups/\(dialogID)", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func updateSupergroup(dialogID: Int64, title: String? = nil, about: String? = nil, session: HSUserSession) async throws -> HSSupergroup {
        try await request(
            "v1/supergroups/\(dialogID)",
            method: "PATCH",
            body: SupergroupUpdateBody(title: title, about: about),
            session: session
        )
    }

    func leaveSupergroup(dialogID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request("v1/supergroups/\(dialogID)/leave", method: "POST", body: Optional<EmptyBody>.none, session: session)
    }

    func supergroupMembers(dialogID: Int64, limit: Int = 50, offset: Int = 0, session: HSUserSession) async throws -> [HSSupergroupMember] {
        try await request("v1/supergroups/\(dialogID)/members?limit=\(limit)&offset=\(offset)", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func inviteSupergroupMembers(dialogID: Int64, userIDs: [Int64], session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/supergroups/\(dialogID)/members",
            method: "POST",
            body: SupergroupMembersBody(userIDs: userIDs),
            session: session
        )
    }

    func removeSupergroupMember(dialogID: Int64, userID: Int64, revokeHistory: Bool = false, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/supergroups/\(dialogID)/members/\(userID)?revoke_history=\(revokeHistory)",
            method: "DELETE",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func deleteSupergroupMemberHistory(dialogID: Int64, userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/supergroups/\(dialogID)/members/\(userID)/history",
            method: "DELETE",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func editSupergroupAdmin(dialogID: Int64, userID: Int64, rights: HSSupergroupAdminRights, rank: String? = nil, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/supergroups/\(dialogID)/admins/\(userID)",
            method: "PATCH",
            body: SupergroupAdminBody(rights: rights, rank: rank),
            session: session
        )
    }

    func editSupergroupRestrictions(dialogID: Int64, userID: Int64, rights: HSSupergroupBannedRights, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/supergroups/\(dialogID)/members/\(userID)/restrictions",
            method: "PATCH",
            body: SupergroupRestrictionBody(rights: rights),
            session: session
        )
    }

    func updateSupergroupSettings(dialogID: Int64, settings: HSSupergroupSettings, session: HSUserSession) async throws -> HSSupergroup {
        try await request(
            "v1/supergroups/\(dialogID)/settings",
            method: "PATCH",
            body: settings,
            session: session
        )
    }

    func pinSupergroupMessage(dialogID: Int64, messageID: Int64, silent: Bool = false, unpin: Bool = false, session: HSUserSession) async throws -> HSMessage {
        try await request(
            "v1/supergroups/\(dialogID)/messages/\(messageID)/pin",
            method: "POST",
            body: PinMessageBody(silent: silent, unpin: unpin),
            session: session
        )
    }

    func supergroupMessageLink(dialogID: Int64, messageID: Int64, session: HSUserSession) async throws -> HSExportedMessageLink {
        try await request(
            "v1/supergroups/\(dialogID)/messages/\(messageID)/link",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func supergroupAdminLog(dialogID: Int64, query: String? = nil, adminIDs: [Int64] = [], limit: Int = 50, session: HSUserSession) async throws -> [HSSupergroupAdminLogEvent] {
        var items = ["limit=\(limit)"]
        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            items.append("q=\(encoded)")
        }
        if !adminIDs.isEmpty {
            items.append("admins=\(adminIDs.map { String($0) }.joined(separator: ","))")
        }
        return try await request(
            "v1/supergroups/\(dialogID)/admin-log?\(items.joined(separator: "&"))",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func exportSupergroupInvite(dialogID: Int64, title: String? = nil, expireDate: Int? = nil, usageLimit: Int? = nil, requestNeeded: Bool = false, session: HSUserSession) async throws -> HSExportedInvite {
        try await request(
            "v1/supergroups/\(dialogID)/invites",
            method: "POST",
            body: ExportInviteBody(title: title, expireDate: expireDate, usageLimit: usageLimit, requestNeeded: requestNeeded, legacyRevokePermanent: false),
            session: session
        )
    }

    func contacts(session: HSUserSession) async throws -> [HSContact] {
        try await request("v1/contacts", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func blockedContacts(offset: Int = 0, limit: Int = 100, session: HSUserSession) async throws -> [HSContact] {
        try await request("v1/contacts/blocked?offset=\(offset)&limit=\(limit)", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func searchContacts(query: String, limit: Int = 20, session: HSUserSession) async throws -> [HSContact] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return try await request("v1/contacts/search?q=\(encoded)&limit=\(limit)", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func resolveContact(identifier: String, session: HSUserSession) async throws -> HSContact {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HSAPIError.server(code: "EMPTY_IDENTIFIER", message: "Please enter a username, phone number, or HSgram link.")
        }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return try await request("v1/contacts/resolve?identifier=\(encoded)", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func addContact(userID: Int64, firstName: String, lastName: String = "", phone: String = "", session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/contacts",
            method: "POST",
            body: ContactRequestBody(userID: userID, firstName: firstName, lastName: lastName, phone: phone),
            session: session
        )
    }

    func requestContact(userID: Int64, firstName: String, lastName: String = "", phone: String = "", session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/contacts/requests",
            method: "POST",
            body: ContactRequestBody(userID: userID, firstName: firstName, lastName: lastName, phone: phone),
            session: session
        )
    }

    func acceptContact(userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request("v1/contacts/\(userID)/accept", method: "POST", body: Optional<EmptyBody>.none, session: session)
    }

    func declineContact(userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request("v1/contacts/\(userID)/decline", method: "POST", body: Optional<EmptyBody>.none, session: session)
    }

    func deleteContact(userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request("v1/contacts/\(userID)", method: "DELETE", body: Optional<EmptyBody>.none, session: session)
    }

    func blockContact(userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request("v1/contacts/\(userID)/block", method: "POST", body: Optional<EmptyBody>.none, session: session)
    }

    func unblockContact(userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request("v1/contacts/\(userID)/block", method: "DELETE", body: Optional<EmptyBody>.none, session: session)
    }

    func trustItems(session: HSUserSession) async throws -> [HSTrustItem] {
        try await request("v1/trust/items", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func devices(session: HSUserSession) async throws -> [HSDeviceSession] {
        try await request("v1/devices", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func resetDevice(id: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request("v1/devices/\(id)", method: "DELETE", body: Optional<EmptyBody>.none, session: session)
    }

    func accountProfile(session: HSUserSession) async throws -> HSAccountProfile {
        try await request("v1/account/profile", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func updateAccountProfile(displayName: String? = nil, username: String? = nil, about: String? = nil, session: HSUserSession) async throws -> HSAccountProfile {
        try await request(
            "v1/account/profile",
            method: "PATCH",
            body: AccountProfileBody(displayName: displayName, username: username, about: about),
            session: session
        )
    }

    func deleteAccount(reason: String, password: String?, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/account",
            method: "DELETE",
            body: AccountDeleteBody(reason: reason, password: password),
            session: session
        )
    }

    func privacySettings(session: HSUserSession) async throws -> HSPrivacySettings {
        try await request("v1/settings/privacy", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func updatePrivacySetting(
        id: String,
        value: HSPrivacyRuleValue,
        exceptions: HSPrivacyRuleExceptions = .empty,
        session: HSUserSession
    ) async throws -> HSSettingsItem {
        try await request(
            "v1/settings/privacy",
            method: "PATCH",
            body: PrivacyRuleUpdateBody(id: id, value: value, exceptions: exceptions),
            session: session
        )
    }

    func notificationSettings(session: HSUserSession) async throws -> HSNotificationSettings {
        try await request("v1/settings/notifications", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func updateNotificationSettings(_ settings: HSNotificationSettings, session: HSUserSession) async throws -> HSNotificationSettings {
        try await request("v1/settings/notifications", method: "PATCH", body: settings, session: session)
    }

    func storageSettings(session: HSUserSession) async throws -> HSStorageSettings {
        try await request("v1/settings/storage", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func assetCatalog(session: HSUserSession) async throws -> HSAssetCatalog {
        try await request("v1/assets", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func entitlements(session: HSUserSession) async throws -> [HSEntitlement] {
        try await request("v1/entitlements", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func adminTools(session: HSUserSession) async throws -> [HSAdminTool] {
        try await request("v1/admin/tools", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func registerPushToken(
        token: String,
        tokenType: Int,
        sandbox: Bool,
        otherUserIDs: [Int64],
        session: HSUserSession
    ) async throws -> HSMessageAction {
        try await serverTransport.request(
            "v1/notifications/push-token",
            method: "POST",
            body: PushTokenBody(
                token: token,
                tokenType: tokenType,
                sandbox: sandbox,
                otherUserIDs: otherUserIDs
            ),
            session: session
        )
    }

    func unregisterPushToken(
        token: String,
        tokenType: Int,
        otherUserIDs: [Int64],
        session: HSUserSession
    ) async throws -> HSMessageAction {
        try await serverTransport.request(
            "v1/notifications/push-token",
            method: "DELETE",
            body: PushTokenBody(
                token: token,
                tokenType: tokenType,
                sandbox: false,
                otherUserIDs: otherUserIDs
            ),
            session: session
        )
    }

    func syncState(session: HSUserSession) async throws -> HSSyncState {
        try await serverTransport.syncState(session: session)
    }

    func syncDifference(since state: HSSyncState, session: HSUserSession) async throws -> HSSyncDifference {
        try await serverTransport.syncDifference(since: state, session: session)
    }

    func dialogReadState(dialogID: Int64, session: HSUserSession) async throws -> HSDialogReadState {
        try await serverTransport.dialogReadState(dialogID: dialogID, session: session)
    }

    private func request<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        body: Body?,
        session userSession: HSUserSession?
    ) async throws -> Response {
        if path.hasPrefix("v1/"), !configuration.allowsNativeRESTFacade {
            return try await serverTransport.request(path, method: method, body: body, session: userSession)
        }

        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw HSAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("HSgramNative-iOS", forHTTPHeaderField: "X-HSgram-Client")

        if let userSession {
            request.setValue("Bearer \(userSession.token)", forHTTPHeaderField: "Authorization")
            request.setValue(String(userSession.userID), forHTTPHeaderField: "X-HSgram-User-ID")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                if let wrapped = try? decoder.decode(HSAPIErrorEnvelope.self, from: data) {
                    let code = firstNonEmpty(wrapped.code, wrapped.error, "HTTP_\(http.statusCode)")
                    let message = firstNonEmpty(wrapped.message, wrapped.error, wrapped.code, httpFallbackMessage(statusCode: http.statusCode))
                    throw HSAPIError.server(code: code, message: message)
                }
                let bodyMessage = String(data: data, encoding: .utf8)
                throw HSAPIError.server(
                    code: "HTTP_\(http.statusCode)",
                    message: firstNonEmpty(bodyMessage, httpFallbackMessage(statusCode: http.statusCode))
                )
            }
            let wrapped = try decoder.decode(HSAPIResponse<Response>.self, from: data)
            if wrapped.ok, let value = wrapped.data {
                return value
            }
            throw HSAPIError.server(code: wrapped.code, message: wrapped.message ?? wrapped.code ?? "Request failed.")
        } catch let error as HSAPIError {
            throw error
        } catch {
            throw HSAPIError.transport(error)
        }
    }

    private func firstNonEmpty(_ values: String?...) -> String {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return "Request failed."
    }

    private func httpFallbackMessage(statusCode: Int) -> String {
        let reason = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        return "HTTP \(statusCode): \(reason)"
    }
}

private struct EmptyBody: Encodable {}

private struct HSAPIErrorEnvelope: Decodable {
    let ok: Bool?
    let code: String?
    let message: String?
    let error: String?
}

private struct ForwardMessageBody: Encodable {
    let toDialogID: Int64
    let dropAuthor: Bool
    let dropMediaCaptions: Bool
}

private struct SendMessageBody: Encodable {
    let text: String
    let replyToMessageID: Int64?
    let noWebpage: Bool

    private enum CodingKeys: String, CodingKey {
        case text
        case replyToMessageID
        case noWebpage = "no_webpage"
    }
}

private struct MediaMessageBody: Encodable {
    let fileName: String
    let mimeType: String
    let data: Data
    let mediaKind: String
    let caption: String
    let replyToMessageID: Int64?
    let duration: Double?
    let waveform: Data?
}

private struct TypingActivityBody: Encodable {
    let activity: HSInputActivityKind
    let progress: Int?
}

private struct MarkUnreadBody: Encodable {
    let unread: Bool
}

private struct DialogPinBody: Encodable {
    let pinned: Bool
}

private struct DialogPinOrderBody: Encodable {
    let dialogIDs: [Int64]
    let folderID: Int

    enum CodingKeys: String, CodingKey {
        case dialogIDs = "dialog_ids"
        case folderID = "folder_id"
    }
}

private struct DialogFilterBody: Encodable {
    let filter: HSChatListFilter
}

private struct DialogFilterOrderBody: Encodable {
    let ids: [Int]
}

private struct DialogFilterTagsBody: Encodable {
    let enabled: Bool
}

private struct DialogFolderBody: Encodable {
    let folderID: Int

    enum CodingKeys: String, CodingKey {
        case folderID = "folder_id"
    }
}

private struct DraftBody: Encodable {
    let text: String
    let replyToMessageID: Int64?
    let noWebpage: Bool

    private enum CodingKeys: String, CodingKey {
        case text
        case replyToMessageID
        case noWebpage = "no_webpage"
    }
}

private struct ReactionBody: Encodable {
    let reaction: String
    let big: Bool
}

private struct SupergroupCreateBody: Encodable {
    let title: String
    let about: String
    let memberIDs: [Int64]
}

private struct SupergroupUpdateBody: Encodable {
    let title: String?
    let about: String?
}

private struct SupergroupMembersBody: Encodable {
    let userIDs: [Int64]
}

private struct SupergroupAdminBody: Encodable {
    let rights: HSSupergroupAdminRights
    let rank: String?
}

private struct SupergroupRestrictionBody: Encodable {
    let rights: HSSupergroupBannedRights
}

private struct ContactRequestBody: Encodable {
    let userID: Int64
    let firstName: String
    let lastName: String
    let phone: String
}

private struct PinMessageBody: Encodable {
    let silent: Bool
    let unpin: Bool
}

private struct ExportInviteBody: Encodable {
    let title: String?
    let expireDate: Int?
    let usageLimit: Int?
    let requestNeeded: Bool
    let legacyRevokePermanent: Bool
}

private struct AccountProfileBody: Encodable {
    let displayName: String?
    let username: String?
    let about: String?
}

private struct AccountDeleteBody: Encodable {
    let reason: String
    let password: String?
}

private struct PrivacyRuleUpdateBody: Encodable {
    let id: String
    let value: HSPrivacyRuleValue
    let exceptions: HSPrivacyRuleExceptions
}

private struct PushTokenBody: Encodable {
    let token: String
    let tokenType: Int
    let sandbox: Bool
    let otherUserIDs: [Int64]
}
