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
        try await serverTransport.request("v1/workspace/summary", method: "GET", body: Optional<EmptyBody>.none, session: session)
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

    func chatListSharedInvites(filterID: Int, session: HSUserSession) async throws -> HSChatListExportedInvitesPage {
        try await request(
            "v1/dialog-filters/\(filterID)/shared-links",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func exportChatListInvite(
        filterID: Int,
        title: String,
        peers: [HSChatListFilterPeer],
        session: HSUserSession
    ) async throws -> HSChatListExportedInviteResult {
        try await request(
            "v1/dialog-filters/\(filterID)/shared-links",
            method: "POST",
            body: ChatListSharedInviteBody(title: title, peers: peers),
            session: session
        )
    }

    func editChatListInvite(
        filterID: Int,
        slug: String,
        title: String?,
        peers: [HSChatListFilterPeer]?,
        session: HSUserSession
    ) async throws -> HSChatListSharedInvite {
        try await request(
            "v1/dialog-filters/\(filterID)/shared-links/\(pathEncoded(slug))",
            method: "PATCH",
            body: ChatListSharedInviteBody(title: title, peers: peers),
            session: session
        )
    }

    func deleteChatListInvite(filterID: Int, slug: String, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialog-filters/\(filterID)/shared-links/\(pathEncoded(slug))",
            method: "DELETE",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func checkChatListInvite(slug: String, session: HSUserSession) async throws -> HSChatListInvitePreview {
        try await request(
            "v1/chatlist-invites/\(pathEncoded(slug))",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func joinChatListInvite(
        slug: String,
        peers: [HSChatListFilterPeer],
        session: HSUserSession
    ) async throws -> HSMessageAction {
        try await request(
            "v1/chatlist-invites/\(pathEncoded(slug))/join",
            method: "POST",
            body: ChatListSharedInviteJoinBody(peers: peers),
            session: session
        )
    }

    func chatListUpdates(filterID: Int, session: HSUserSession) async throws -> HSChatListUpdates {
        try await request(
            "v1/dialog-filters/\(filterID)/chatlist-updates",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func joinChatListUpdates(
        filterID: Int,
        peers: [HSChatListFilterPeer],
        session: HSUserSession
    ) async throws -> HSMessageAction {
        try await request(
            "v1/dialog-filters/\(filterID)/chatlist-updates",
            method: "POST",
            body: ChatListSharedInviteJoinBody(peers: peers),
            session: session
        )
    }

    func hideChatListUpdates(filterID: Int, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialog-filters/\(filterID)/chatlist-updates",
            method: "DELETE",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func leaveChatListSuggestions(filterID: Int, session: HSUserSession) async throws -> [HSChatListSharedPeer] {
        try await request(
            "v1/dialog-filters/\(filterID)/leave-suggestions",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func leaveChatList(
        filterID: Int,
        peers: [HSChatListFilterPeer],
        session: HSUserSession
    ) async throws -> HSMessageAction {
        try await request(
            "v1/dialog-filters/\(filterID)/leave",
            method: "POST",
            body: ChatListSharedInviteJoinBody(peers: peers),
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

    func sharedMediaCalendar(
        dialogID: Int64,
        filter: HSSharedMediaFilter,
        offsetID: Int64? = nil,
        offsetDate: Date? = nil,
        session: HSUserSession
    ) async throws -> HSSharedMediaCalendar {
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.sharedMediaCalendar(
                dialogID: dialogID,
                filter: filter,
                offsetID: offsetID,
                offsetDate: offsetDate,
                session: session
            )
        }
        var path = "v1/dialogs/\(dialogID)/shared-media/calendar?filter=\(filter.rawValue)"
        if let offsetID {
            path += "&offset_id=\(offsetID)"
        }
        if let offsetDate {
            path += "&offset_date=\(Int64(offsetDate.timeIntervalSince1970))"
        }
        return try await request(path, method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func sharedMediaPositions(
        dialogID: Int64,
        filter: HSSharedMediaFilter,
        offsetID: Int64? = nil,
        limit: Int = 1000,
        session: HSUserSession
    ) async throws -> HSSharedMediaPositions {
        let safeLimit = max(1, min(limit, 1000))
        guard configuration.allowsNativeRESTFacade else {
            return try await serverTransport.sharedMediaPositions(
                dialogID: dialogID,
                filter: filter,
                offsetID: offsetID,
                limit: safeLimit,
                session: session
            )
        }
        var path = "v1/dialogs/\(dialogID)/shared-media/positions?filter=\(filter.rawValue)&limit=\(safeLimit)"
        if let offsetID {
            path += "&offset_id=\(offsetID)"
        }
        return try await request(path, method: "GET", body: Optional<EmptyBody>.none, session: session)
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

    func sendPoll(
        dialogID: Int64,
        question: String,
        answers: [HSPollAnswerInput],
        isMultipleChoice: Bool = false,
        isQuiz: Bool = false,
        isAnonymous: Bool = true,
        correctAnswerOptions: [Data]? = nil,
        solution: String? = nil,
        closePeriod: Int? = nil,
        replyToMessageID: Int64? = nil,
        session: HSUserSession
    ) async throws -> HSMessage {
        let body = PollMessageBody(
            question: question,
            answers: answers,
            isMultipleChoice: isMultipleChoice,
            isQuiz: isQuiz,
            isAnonymous: isAnonymous,
            correctAnswerOptions: correctAnswerOptions,
            solution: solution,
            closePeriod: closePeriod,
            replyToMessageID: replyToMessageID
        )
        return try await request(
            "v1/dialogs/\(dialogID)/polls",
            method: "POST",
            body: body,
            session: session
        )
    }

    func votePoll(dialogID: Int64, messageID: Int64, options: [Data], session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/messages/\(messageID)/poll/vote",
            method: "POST",
            body: PollVoteBody(options: options),
            session: session
        )
    }

    func refreshPoll(dialogID: Int64, messageID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/messages/\(messageID)/poll/refresh",
            method: "POST",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func pollVotes(
        dialogID: Int64,
        messageID: Int64,
        option: Data? = nil,
        offset: String? = nil,
        limit: Int = 50,
        session: HSUserSession
    ) async throws -> HSPollVotesPage {
        var path = "v1/dialogs/\(dialogID)/messages/\(messageID)/poll/votes?limit=\(max(1, min(100, limit)))"
        if let option, !option.isEmpty {
            path += "&option=\(queryEncoded(option.base64EncodedString()))"
        }
        if let offset, !offset.isEmpty {
            path += "&offset=\(queryEncoded(offset))"
        }
        return try await request(path, method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func sendTodo(
        dialogID: Int64,
        title: String,
        items: [HSTodoItem],
        othersCanAppend: Bool = false,
        othersCanComplete: Bool = false,
        replyToMessageID: Int64? = nil,
        session: HSUserSession
    ) async throws -> HSMessage {
        let body = TodoMessageBody(
            title: title,
            items: items,
            othersCanAppend: othersCanAppend,
            othersCanComplete: othersCanComplete,
            replyToMessageID: replyToMessageID
        )
        return try await request(
            "v1/dialogs/\(dialogID)/todos",
            method: "POST",
            body: body,
            session: session
        )
    }

    func toggleTodoCompleted(
        dialogID: Int64,
        messageID: Int64,
        completedIDs: [Int],
        incompletedIDs: [Int],
        session: HSUserSession
    ) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/messages/\(messageID)/todo/toggle",
            method: "POST",
            body: TodoToggleBody(completedIDs: completedIDs, incompletedIDs: incompletedIDs),
            session: session
        )
    }

    func appendTodoItems(dialogID: Int64, messageID: Int64, items: [HSTodoItem], session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/messages/\(messageID)/todo/items",
            method: "POST",
            body: TodoItemsBody(items: items),
            session: session
        )
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

    func markMessageContentsRead(dialogID: Int64, messageIDs: [Int64], session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/messages/read-contents",
            method: "POST",
            body: MessageIDsBody(messageIDs: messageIDs),
            session: session
        )
    }

    func messageViews(dialogID: Int64, messageIDs: [Int64], increment: Bool = true, session: HSUserSession) async throws -> [HSMessageViewState] {
        try await request(
            "v1/dialogs/\(dialogID)/messages/views?increment=\(increment)",
            method: "POST",
            body: MessageIDsBody(messageIDs: messageIDs),
            session: session
        )
    }

    func messageReadParticipants(dialogID: Int64, messageID: Int64, session: HSUserSession) async throws -> [HSMessageReadParticipant] {
        try await request(
            "v1/dialogs/\(dialogID)/messages/\(messageID)/read-participants",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func messageReactions(
        dialogID: Int64,
        messageID: Int64,
        reaction: String? = nil,
        offset: String? = nil,
        limit: Int = 50,
        session: HSUserSession
    ) async throws -> HSMessageReactionsPage {
        try await request(
            messageReactionsPath(scope: "dialogs", dialogID: dialogID, messageID: messageID, reaction: reaction, offset: offset, limit: limit),
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
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

    func discussionMessage(dialogID: Int64, messageID: Int64, session: HSUserSession) async throws -> HSDiscussionMessage {
        try await request(
            "v1/dialogs/\(dialogID)/messages/\(messageID)/discussion",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func markDiscussionRead(dialogID: Int64, messageID: Int64, readMaxID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/messages/\(messageID)/discussion/read?read_max_id=\(readMaxID)",
            method: "POST",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func circles(session: HSUserSession) async throws -> [HSCircle] {
        try await request("v1/circles", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func channels(session: HSUserSession) async throws -> [HSChannel] {
        try await request("v1/channels", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func channelDiscussionGroups(session: HSUserSession) async throws -> [HSSupergroup] {
        try await request("v1/channels/discussion-groups", method: "GET", body: Optional<EmptyBody>.none, session: session)
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

    func updateChannelSettings(dialogID: Int64, settings: HSSupergroupSettings, session: HSUserSession) async throws -> HSChannel {
        try await request(
            "v1/channels/\(dialogID)/settings",
            method: "PATCH",
            body: settings,
            session: session
        )
    }

    func updateChannelDiscussionGroup(dialogID: Int64, groupDialogID: Int64?, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/channels/\(dialogID)/discussion-group",
            method: "PATCH",
            body: DiscussionGroupBody(groupDialogID: groupDialogID),
            session: session
        )
    }

    func checkChannelUsername(dialogID: Int64, username: String, session: HSUserSession) async throws -> HSAddressNameAvailability {
        try await request(
            "v1/channels/\(dialogID)/username/check?username=\(queryEncoded(username))",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func updateChannelUsername(dialogID: Int64, username: String?, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/channels/\(dialogID)/username",
            method: "PATCH",
            body: UsernameBody(username: username),
            session: session
        )
    }

    func leaveChannel(dialogID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request("v1/channels/\(dialogID)/leave", method: "POST", body: Optional<EmptyBody>.none, session: session)
    }

    func channelSubscribers(dialogID: Int64, filter: HSSupergroupMemberFilter = .recent, query: String? = nil, limit: Int = 50, offset: Int = 0, session: HSUserSession) async throws -> [HSSupergroupMember] {
        try await request(memberListPath(scope: "channels", dialogID: dialogID, collection: "subscribers", filter: filter, query: query, limit: limit, offset: offset), method: "GET", body: Optional<EmptyBody>.none, session: session)
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

    func reportChannelAntiSpamFalsePositive(dialogID: Int64, messageID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/channels/\(dialogID)/messages/\(messageID)/anti-spam/false-positive",
            method: "POST",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func markChannelMessageContentsRead(dialogID: Int64, messageIDs: [Int64], session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/channels/\(dialogID)/messages/read-contents",
            method: "POST",
            body: MessageIDsBody(messageIDs: messageIDs),
            session: session
        )
    }

    func channelMessageViews(dialogID: Int64, messageIDs: [Int64], increment: Bool = true, session: HSUserSession) async throws -> [HSMessageViewState] {
        try await request(
            "v1/channels/\(dialogID)/messages/views?increment=\(increment)",
            method: "POST",
            body: MessageIDsBody(messageIDs: messageIDs),
            session: session
        )
    }

    func channelMessageReadParticipants(dialogID: Int64, messageID: Int64, session: HSUserSession) async throws -> [HSMessageReadParticipant] {
        try await request(
            "v1/channels/\(dialogID)/messages/\(messageID)/read-participants",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func channelMessageReactions(
        dialogID: Int64,
        messageID: Int64,
        reaction: String? = nil,
        offset: String? = nil,
        limit: Int = 50,
        session: HSUserSession
    ) async throws -> HSMessageReactionsPage {
        try await request(
            messageReactionsPath(scope: "channels", dialogID: dialogID, messageID: messageID, reaction: reaction, offset: offset, limit: limit),
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

    func channelInvites(dialogID: Int64, revoked: Bool = false, adminID: Int64? = nil, offsetDate: Int? = nil, offsetLink: String? = nil, limit: Int = 50, session: HSUserSession) async throws -> HSExportedInvitesPage {
        try await request(invitesPath(scope: "channels", dialogID: dialogID, revoked: revoked, adminID: adminID, offsetDate: offsetDate, offsetLink: offsetLink, limit: limit), method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func editChannelInvite(dialogID: Int64, link: String, title: String? = nil, expireDate: Int? = nil, usageLimit: Int? = nil, requestNeeded: Bool? = nil, revoked: Bool = false, session: HSUserSession) async throws -> HSExportedInvite {
        try await request(
            "v1/channels/\(dialogID)/invites",
            method: "PATCH",
            body: EditInviteBody(link: link, title: title, expireDate: expireDate, usageLimit: usageLimit, requestNeeded: requestNeeded, revoked: revoked),
            session: session
        )
    }

    func deleteChannelInvite(dialogID: Int64, link: String, session: HSUserSession) async throws -> HSMessageAction {
        let encoded = queryEncoded(link)
        return try await request("v1/channels/\(dialogID)/invites?link=\(encoded)", method: "DELETE", body: Optional<EmptyBody>.none, session: session)
    }

    func channelInviteImporters(dialogID: Int64, requested: Bool = false, link: String? = nil, query: String? = nil, offsetDate: Int = 0, offsetUserID: Int64? = nil, limit: Int = 50, session: HSUserSession) async throws -> HSInviteImportersPage {
        try await request(inviteImportersPath(scope: "channels", dialogID: dialogID, requested: requested, link: link, query: query, offsetDate: offsetDate, offsetUserID: offsetUserID, limit: limit), method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func approveChannelJoinRequest(dialogID: Int64, userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await updateJoinRequest(scope: "channels", dialogID: dialogID, userID: userID, approve: true, session: session)
    }

    func declineChannelJoinRequest(dialogID: Int64, userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await updateJoinRequest(scope: "channels", dialogID: dialogID, userID: userID, approve: false, session: session)
    }

    func approveAllChannelJoinRequests(dialogID: Int64, link: String? = nil, session: HSUserSession) async throws -> HSMessageAction {
        try await updateAllJoinRequests(scope: "channels", dialogID: dialogID, link: link, approve: true, session: session)
    }

    func declineAllChannelJoinRequests(dialogID: Int64, link: String? = nil, session: HSUserSession) async throws -> HSMessageAction {
        try await updateAllJoinRequests(scope: "channels", dialogID: dialogID, link: link, approve: false, session: session)
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

    func supergroupMembers(dialogID: Int64, filter: HSSupergroupMemberFilter = .recent, query: String? = nil, limit: Int = 50, offset: Int = 0, session: HSUserSession) async throws -> [HSSupergroupMember] {
        try await request(memberListPath(scope: "supergroups", dialogID: dialogID, collection: "members", filter: filter, query: query, limit: limit, offset: offset), method: "GET", body: Optional<EmptyBody>.none, session: session)
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

    func checkSupergroupUsername(dialogID: Int64, username: String, session: HSUserSession) async throws -> HSAddressNameAvailability {
        try await request(
            "v1/supergroups/\(dialogID)/username/check?username=\(queryEncoded(username))",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func updateSupergroupUsername(dialogID: Int64, username: String?, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/supergroups/\(dialogID)/username",
            method: "PATCH",
            body: UsernameBody(username: username),
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

    func reportSupergroupAntiSpamFalsePositive(dialogID: Int64, messageID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/supergroups/\(dialogID)/messages/\(messageID)/anti-spam/false-positive",
            method: "POST",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func markSupergroupMessageContentsRead(dialogID: Int64, messageIDs: [Int64], session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/supergroups/\(dialogID)/messages/read-contents",
            method: "POST",
            body: MessageIDsBody(messageIDs: messageIDs),
            session: session
        )
    }

    func supergroupMessageViews(dialogID: Int64, messageIDs: [Int64], increment: Bool = true, session: HSUserSession) async throws -> [HSMessageViewState] {
        try await request(
            "v1/supergroups/\(dialogID)/messages/views?increment=\(increment)",
            method: "POST",
            body: MessageIDsBody(messageIDs: messageIDs),
            session: session
        )
    }

    func supergroupMessageReadParticipants(dialogID: Int64, messageID: Int64, session: HSUserSession) async throws -> [HSMessageReadParticipant] {
        try await request(
            "v1/supergroups/\(dialogID)/messages/\(messageID)/read-participants",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func supergroupMessageReactions(
        dialogID: Int64,
        messageID: Int64,
        reaction: String? = nil,
        offset: String? = nil,
        limit: Int = 50,
        session: HSUserSession
    ) async throws -> HSMessageReactionsPage {
        try await request(
            messageReactionsPath(scope: "supergroups", dialogID: dialogID, messageID: messageID, reaction: reaction, offset: offset, limit: limit),
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

    func supergroupInvites(dialogID: Int64, revoked: Bool = false, adminID: Int64? = nil, offsetDate: Int? = nil, offsetLink: String? = nil, limit: Int = 50, session: HSUserSession) async throws -> HSExportedInvitesPage {
        try await request(invitesPath(scope: "supergroups", dialogID: dialogID, revoked: revoked, adminID: adminID, offsetDate: offsetDate, offsetLink: offsetLink, limit: limit), method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func editSupergroupInvite(dialogID: Int64, link: String, title: String? = nil, expireDate: Int? = nil, usageLimit: Int? = nil, requestNeeded: Bool? = nil, revoked: Bool = false, session: HSUserSession) async throws -> HSExportedInvite {
        try await request(
            "v1/supergroups/\(dialogID)/invites",
            method: "PATCH",
            body: EditInviteBody(link: link, title: title, expireDate: expireDate, usageLimit: usageLimit, requestNeeded: requestNeeded, revoked: revoked),
            session: session
        )
    }

    func deleteSupergroupInvite(dialogID: Int64, link: String, session: HSUserSession) async throws -> HSMessageAction {
        let encoded = queryEncoded(link)
        return try await request("v1/supergroups/\(dialogID)/invites?link=\(encoded)", method: "DELETE", body: Optional<EmptyBody>.none, session: session)
    }

    func supergroupInviteImporters(dialogID: Int64, requested: Bool = false, link: String? = nil, query: String? = nil, offsetDate: Int = 0, offsetUserID: Int64? = nil, limit: Int = 50, session: HSUserSession) async throws -> HSInviteImportersPage {
        try await request(inviteImportersPath(scope: "supergroups", dialogID: dialogID, requested: requested, link: link, query: query, offsetDate: offsetDate, offsetUserID: offsetUserID, limit: limit), method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func approveSupergroupJoinRequest(dialogID: Int64, userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await updateJoinRequest(scope: "supergroups", dialogID: dialogID, userID: userID, approve: true, session: session)
    }

    func declineSupergroupJoinRequest(dialogID: Int64, userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        try await updateJoinRequest(scope: "supergroups", dialogID: dialogID, userID: userID, approve: false, session: session)
    }

    func approveAllSupergroupJoinRequests(dialogID: Int64, link: String? = nil, session: HSUserSession) async throws -> HSMessageAction {
        try await updateAllJoinRequests(scope: "supergroups", dialogID: dialogID, link: link, approve: true, session: session)
    }

    func declineAllSupergroupJoinRequests(dialogID: Int64, link: String? = nil, session: HSUserSession) async throws -> HSMessageAction {
        try await updateAllJoinRequests(scope: "supergroups", dialogID: dialogID, link: link, approve: false, session: session)
    }

    func contacts(session: HSUserSession) async throws -> [HSContact] {
        try await request("v1/contacts", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func importContacts(_ contacts: [HSDeviceContactImport], session: HSUserSession) async throws -> HSImportedContactsSummary {
        try await request(
            "v1/contacts/import",
            method: "POST",
            body: ImportContactsBody(contacts: contacts),
            session: session
        )
    }

    func deleteImportedContactsByPhones(_ phones: [String], session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/contacts/import",
            method: "DELETE",
            body: ContactPhonesBody(phones: phones),
            session: session
        )
    }

    func exportContactToken(session: HSUserSession) async throws -> HSExportedContactToken {
        try await request("v1/contacts/token", method: "POST", body: Optional<EmptyBody>.none, session: session)
    }

    func importContactToken(_ token: String, session: HSUserSession) async throws -> HSContact {
        try await request(
            "v1/contacts/token/import",
            method: "POST",
            body: ImportContactTokenBody(token: token),
            session: session
        )
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

    func addContact(
        userID: Int64,
        firstName: String,
        lastName: String = "",
        phone: String = "",
        note: String? = nil,
        addPhonePrivacyException: Bool = false,
        session: HSUserSession
    ) async throws -> HSMessageAction {
        try await request(
            "v1/contacts",
            method: "POST",
            body: ContactRequestBody(
                userID: userID,
                firstName: firstName,
                lastName: lastName,
                phone: phone,
                note: note,
                addPhonePrivacyException: addPhonePrivacyException
            ),
            session: session
        )
    }

    func updateContactNote(userID: Int64, note: String, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/contacts/\(userID)/note",
            method: "PATCH",
            body: ContactNoteBody(note: note),
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

    func reportPeer(dialogID: Int64, reason: HSReportReason, message: String, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/report",
            method: "POST",
            body: ReportPeerBody(reason: reason, message: message),
            session: session
        )
    }

    func reportPeerPhoto(dialogID: Int64, reason: HSReportReason, message: String, session: HSUserSession) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/photo/report",
            method: "POST",
            body: ReportPeerBody(reason: reason, message: message),
            session: session
        )
    }

    func reportMessages(
        dialogID: Int64,
        messageIDs: [Int64],
        option: Data? = nil,
        message: String? = nil,
        session: HSUserSession
    ) async throws -> HSReportContentResult {
        try await request(
            "v1/dialogs/\(dialogID)/messages/report",
            method: "POST",
            body: ReportMessagesBody(messageIDs: messageIDs, option: option, message: message),
            session: session
        )
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

    func notificationExceptions(scope: HSNotificationException.Scope? = nil, compareSound: Bool = true, session: HSUserSession) async throws -> HSNotificationExceptions {
        var items: [String] = []
        if let scope, scope != .unknown {
            items.append("scope=\(scope.rawValue)")
        }
        if compareSound {
            items.append("compare_sound=true")
        }
        let suffix = items.isEmpty ? "" : "?\(items.joined(separator: "&"))"
        return try await request(
            "v1/settings/notifications/exceptions\(suffix)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func resetNotificationSettings(session: HSUserSession) async throws -> Bool {
        try await request(
            "v1/settings/notifications/reset",
            method: "POST",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func updatePeerNotificationSettings(
        dialogID: Int64,
        muteInterval: Int?,
        showPreviews: Bool = true,
        silent: Bool = false,
        sound: HSNotificationSound? = nil,
        session: HSUserSession
    ) async throws -> HSMessageAction {
        try await request(
            "v1/dialogs/\(dialogID)/notifications",
            method: "PATCH",
            body: PeerNotificationSettingsBody(
                muteInterval: muteInterval,
                showPreviews: showPreviews,
                silent: silent,
                sound: sound
            ),
            session: session
        )
    }

    func storageSettings(session: HSUserSession) async throws -> HSStorageSettings {
        try await request("v1/settings/storage", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func assetCatalog(session: HSUserSession) async throws -> HSAssetCatalog {
        try await request("v1/assets", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func installStickerSet(_ set: HSStickerSet, archived: Bool = false, session: HSUserSession) async throws -> HSStickerSetInstallResult {
        try await installStickerSet(id: set.id, accessHash: set.accessHash, archived: archived, session: session)
    }

    func installStickerSet(id: Int64, accessHash: Int64, archived: Bool = false, session: HSUserSession) async throws -> HSStickerSetInstallResult {
        try await request(
            "v1/stickers/sets/\(id)/install",
            method: "POST",
            body: StickerSetActionBody(accessHash: accessHash, archived: archived),
            session: session
        )
    }

    func uninstallStickerSet(_ set: HSStickerSet, session: HSUserSession) async throws -> Bool {
        try await uninstallStickerSet(id: set.id, accessHash: set.accessHash, session: session)
    }

    func uninstallStickerSet(id: Int64, accessHash: Int64, session: HSUserSession) async throws -> Bool {
        try await request(
            "v1/stickers/sets/\(id)/install",
            method: "DELETE",
            body: StickerSetActionBody(accessHash: accessHash, archived: nil),
            session: session
        )
    }

    func readFeaturedStickerSets(_ ids: [Int64], session: HSUserSession) async throws -> Bool {
        try await request(
            "v1/stickers/featured/read",
            method: "POST",
            body: FeaturedStickerSetsReadBody(ids: ids),
            session: session
        )
    }

    func archivedStickerSets(kind: String = "stickers", offsetID: Int64 = 0, limit: Int = 200, session: HSUserSession) async throws -> HSArchivedStickerSetsPage {
        try await request(
            "v1/stickers/archived?kind=\(queryEncoded(kind))&offset_id=\(offsetID)&limit=\(limit)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func stickerSetDetails(_ set: HSStickerSet, hash: Int = 0, session: HSUserSession) async throws -> HSStickerSetDetails {
        try await stickerSetDetails(id: set.id, accessHash: set.accessHash, hash: hash, session: session)
    }

    func stickerSetDetails(id: Int64, accessHash: Int64, hash: Int = 0, session: HSUserSession) async throws -> HSStickerSetDetails {
        try await request(
            "v1/stickers/sets/\(id)?access_hash=\(accessHash)&hash=\(hash)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func stickerSetDetails(shortName: String, hash: Int = 0, session: HSUserSession) async throws -> HSStickerSetDetails {
        try await request(
            "v1/stickers/sets/by-short-name/\(queryEncoded(shortName))?hash=\(hash)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func stickersForEmoji(_ emoji: String, hash: Int64 = 0, session: HSUserSession) async throws -> HSStickerDocumentList {
        try await request(
            "v1/stickers/search?emoji=\(queryEncoded(emoji))&hash=\(hash)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func customEmojiDocuments(ids: [Int64], session: HSUserSession) async throws -> HSStickerDocumentList {
        let encodedIDs = ids.map(String.init).joined(separator: ",")
        return try await request(
            "v1/custom-emoji/documents?ids=\(queryEncoded(encodedIDs))",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func customEmojiStickerSets(hash: Int64 = 0, session: HSUserSession) async throws -> [HSStickerSet] {
        try await request(
            "v1/custom-emoji/sticker-sets?hash=\(hash)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func searchCustomEmoji(_ emoji: String, hash: Int64 = 0, session: HSUserSession) async throws -> HSEmojiDocumentList {
        try await request(
            "v1/custom-emoji/search?emoji=\(queryEncoded(emoji))&hash=\(hash)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func emojiKeywords(langCode: String, session: HSUserSession) async throws -> HSEmojiKeywordsDifference {
        try await request(
            "v1/emoji/keywords?lang_code=\(queryEncoded(langCode))",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func emojiKeywordsDifference(langCode: String, fromVersion: Int, session: HSUserSession) async throws -> HSEmojiKeywordsDifference {
        try await request(
            "v1/emoji/keywords/difference?lang_code=\(queryEncoded(langCode))&from_version=\(fromVersion)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func emojiKeywordLanguages(langCodes: [String] = [], session: HSUserSession) async throws -> [HSEmojiLanguage] {
        let encoded = langCodes.joined(separator: ",")
        return try await request(
            "v1/emoji/keywords/languages?lang_codes=\(queryEncoded(encoded))",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func localizationLanguages(langPack: String = "", session: HSUserSession) async throws -> [HSLocalizationLanguage] {
        try await request(
            "v1/localization/languages?lang_pack=\(queryEncoded(langPack))",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func localizationLanguage(langCode: String, langPack: String = "", session: HSUserSession) async throws -> HSLocalizationLanguage {
        try await request(
            "v1/localization/languages/\(queryEncoded(langCode))?lang_pack=\(queryEncoded(langPack))",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func localizationPack(langCode: String, langPack: String = "", session: HSUserSession) async throws -> HSLocalizationPack {
        try await request(
            "v1/localization/packs/\(queryEncoded(langCode))?lang_pack=\(queryEncoded(langPack))",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func localizationPackDifference(langCode: String, fromVersion: Int, langPack: String = "", session: HSUserSession) async throws -> HSLocalizationPack {
        try await request(
            "v1/localization/packs/\(queryEncoded(langCode))/difference?lang_pack=\(queryEncoded(langPack))&from_version=\(fromVersion)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func localizationStrings(langCode: String, keys: [String], langPack: String = "", session: HSUserSession) async throws -> [HSLocalizationEntry] {
        try await request(
            "v1/localization/strings?lang_pack=\(queryEncoded(langPack))&lang_code=\(queryEncoded(langCode))&keys=\(queryEncoded(keys.joined(separator: ",")))",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func recentStickers(attached: Bool = false, hash: Int64 = 0, session: HSUserSession) async throws -> HSStickerDocumentList {
        try await request(
            "v1/stickers/recent?attached=\(attached)&hash=\(hash)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func saveRecentSticker(_ sticker: HSStickerDocument, attached: Bool = false, session: HSUserSession) async throws -> Bool {
        try await saveRecentSticker(
            id: sticker.id,
            accessHash: sticker.accessHash,
            fileReference: sticker.fileReference,
            attached: attached,
            session: session
        )
    }

    func saveRecentSticker(id: Int64, accessHash: Int64, fileReference: Data = Data(), attached: Bool = false, session: HSUserSession) async throws -> Bool {
        try await request(
            "v1/stickers/recent/\(id)",
            method: "POST",
            body: StickerDocumentActionBody(accessHash: accessHash, fileReference: fileReference, attached: attached),
            session: session
        )
    }

    func removeRecentSticker(_ sticker: HSStickerDocument, attached: Bool = false, session: HSUserSession) async throws -> Bool {
        try await removeRecentSticker(id: sticker.id, accessHash: sticker.accessHash, attached: attached, session: session)
    }

    func removeRecentSticker(id: Int64, accessHash: Int64, attached: Bool = false, session: HSUserSession) async throws -> Bool {
        try await request(
            "v1/stickers/recent/\(id)",
            method: "DELETE",
            body: StickerDocumentActionBody(accessHash: accessHash, fileReference: Data(), attached: attached),
            session: session
        )
    }

    func clearRecentStickers(attached: Bool = false, session: HSUserSession) async throws -> Bool {
        try await request(
            "v1/stickers/recent?attached=\(attached)",
            method: "DELETE",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func favedStickers(hash: Int64 = 0, session: HSUserSession) async throws -> HSStickerDocumentList {
        try await request(
            "v1/stickers/faved?hash=\(hash)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func savedGifs(hash: Int64 = 0, session: HSUserSession) async throws -> HSStickerDocumentList {
        try await request(
            "v1/gifs/saved?hash=\(hash)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func saveGif(_ gif: HSStickerDocument, session: HSUserSession) async throws -> Bool {
        try await saveGif(id: gif.id, accessHash: gif.accessHash, fileReference: gif.fileReference, session: session)
    }

    func saveGif(id: Int64, accessHash: Int64, fileReference: Data = Data(), session: HSUserSession) async throws -> Bool {
        try await request(
            "v1/gifs/saved/\(id)",
            method: "POST",
            body: DocumentActionBody(accessHash: accessHash, fileReference: fileReference),
            session: session
        )
    }

    func removeSavedGif(_ gif: HSStickerDocument, session: HSUserSession) async throws -> Bool {
        try await removeSavedGif(id: gif.id, accessHash: gif.accessHash, session: session)
    }

    func removeSavedGif(id: Int64, accessHash: Int64, session: HSUserSession) async throws -> Bool {
        try await request(
            "v1/gifs/saved/\(id)",
            method: "DELETE",
            body: DocumentActionBody(accessHash: accessHash, fileReference: Data()),
            session: session
        )
    }

    func savedRingtones(hash: Int64 = 0, session: HSUserSession) async throws -> HSSavedRingtones {
        try await request(
            "v1/notifications/ringtones?hash=\(hash)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func saveRingtone(_ document: HSStickerDocument, session: HSUserSession) async throws -> HSSavedRingtoneAction {
        try await saveRingtone(
            id: document.id,
            accessHash: document.accessHash,
            fileReference: document.fileReference,
            session: session
        )
    }

    func saveRingtone(id: Int64, accessHash: Int64, fileReference: Data = Data(), session: HSUserSession) async throws -> HSSavedRingtoneAction {
        try await request(
            "v1/notifications/ringtones/\(id)",
            method: "POST",
            body: DocumentActionBody(accessHash: accessHash, fileReference: fileReference),
            session: session
        )
    }

    func removeSavedRingtone(_ document: HSStickerDocument, session: HSUserSession) async throws -> HSSavedRingtoneAction {
        try await removeSavedRingtone(id: document.id, accessHash: document.accessHash, session: session)
    }

    func removeSavedRingtone(id: Int64, accessHash: Int64, session: HSUserSession) async throws -> HSSavedRingtoneAction {
        try await request(
            "v1/notifications/ringtones/\(id)",
            method: "DELETE",
            body: DocumentActionBody(accessHash: accessHash, fileReference: Data()),
            session: session
        )
    }

    func uploadRingtone(fileName: String, mimeType: String = "audio/mpeg", data: Data, session: HSUserSession) async throws -> HSStickerDocument {
        try await request(
            "v1/notifications/ringtones/upload",
            method: "POST",
            body: RingtoneUploadBody(fileName: fileName, mimeType: mimeType, data: data),
            session: session
        )
    }

    func wallpapers(hash: Int64 = 0, session: HSUserSession) async throws -> HSWallpaperList {
        try await request(
            "v1/wallpapers?hash=\(hash)",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func wallpaper(slug: String, session: HSUserSession) async throws -> HSWallpaper {
        try await request(
            "v1/wallpapers/\(queryEncoded(slug))",
            method: "GET",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func saveWallpaper(_ wallpaper: HSWallpaper, session: HSUserSession) async throws -> Bool {
        guard let slug = wallpaper.slug, !slug.isEmpty else {
            return true
        }
        return try await saveWallpaper(slug: slug, settings: wallpaper.settings, session: session)
    }

    func saveWallpaper(slug: String, settings: HSWallpaperSettings = HSWallpaperSettings(), session: HSUserSession) async throws -> Bool {
        try await request(
            "v1/wallpapers/\(queryEncoded(slug))/saved",
            method: "POST",
            body: WallpaperActionBody(settings: settings),
            session: session
        )
    }

    func removeSavedWallpaper(_ wallpaper: HSWallpaper, session: HSUserSession) async throws -> Bool {
        guard let slug = wallpaper.slug, !slug.isEmpty else {
            return true
        }
        return try await removeSavedWallpaper(slug: slug, settings: wallpaper.settings, session: session)
    }

    func removeSavedWallpaper(slug: String, settings: HSWallpaperSettings = HSWallpaperSettings(), session: HSUserSession) async throws -> Bool {
        try await request(
            "v1/wallpapers/\(queryEncoded(slug))/saved",
            method: "DELETE",
            body: WallpaperActionBody(settings: settings),
            session: session
        )
    }

    func installWallpaper(_ wallpaper: HSWallpaper, session: HSUserSession) async throws -> Bool {
        guard wallpaper.kind == .file, wallpaper.slug?.isEmpty == false else {
            return try await installNoFileWallpaper(id: wallpaper.id, settings: wallpaper.settings, session: session)
        }
        try await installWallpaper(
            slug: wallpaper.slug ?? "",
            id: wallpaper.id,
            accessHash: wallpaper.accessHash,
            settings: wallpaper.settings,
            session: session
        )
    }

    func installWallpaper(
        slug: String,
        id: Int64 = 0,
        accessHash: Int64 = 0,
        settings: HSWallpaperSettings = HSWallpaperSettings(),
        session: HSUserSession
    ) async throws -> Bool {
        try await request(
            "v1/wallpapers/\(queryEncoded(slug))/install",
            method: "POST",
            body: WallpaperActionBody(id: id, accessHash: accessHash, settings: settings),
            session: session
        )
    }

    func installNoFileWallpaper(id: Int64 = 0, settings: HSWallpaperSettings = HSWallpaperSettings(), session: HSUserSession) async throws -> Bool {
        try await request(
            "v1/wallpapers/no-file/\(id)/install",
            method: "POST",
            body: WallpaperActionBody(settings: settings),
            session: session
        )
    }

    func resetWallpapers(session: HSUserSession) async throws -> Bool {
        try await request(
            "v1/wallpapers/reset",
            method: "POST",
            body: Optional<EmptyBody>.none,
            session: session
        )
    }

    func recentReactions(limit: Int = 100, hash: Int64 = 0, session: HSUserSession) async throws -> HSReactionList {
        try await request("v1/reactions/recent?limit=\(limit)&hash=\(hash)", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func topReactions(limit: Int = 32, hash: Int64 = 0, session: HSUserSession) async throws -> HSReactionList {
        try await request("v1/reactions/top?limit=\(limit)&hash=\(hash)", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func defaultReaction(session: HSUserSession) async throws -> HSDefaultReaction {
        try await request("v1/reactions/default", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func setDefaultReaction(_ reaction: String, session: HSUserSession) async throws -> Bool {
        try await request("v1/reactions/default", method: "PUT", body: DefaultReactionBody(reaction: reaction), session: session)
    }

    func clearRecentReactions(session: HSUserSession) async throws -> Bool {
        try await request("v1/reactions/recent", method: "DELETE", body: Optional<EmptyBody>.none, session: session)
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

    private func invitesPath(scope: String, dialogID: Int64, revoked: Bool, adminID: Int64?, offsetDate: Int?, offsetLink: String?, limit: Int) -> String {
        var items = ["limit=\(limit)"]
        if revoked {
            items.append("revoked=true")
        }
        if let adminID {
            items.append("admin_id=\(adminID)")
        }
        if let offsetDate {
            items.append("offset_date=\(offsetDate)")
        }
        if let offsetLink, !offsetLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("offset_link=\(queryEncoded(offsetLink))")
        }
        return "v1/\(scope)/\(dialogID)/invites?\(items.joined(separator: "&"))"
    }

    private func inviteImportersPath(scope: String, dialogID: Int64, requested: Bool, link: String?, query: String?, offsetDate: Int, offsetUserID: Int64?, limit: Int) -> String {
        var items = ["limit=\(limit)", "offset_date=\(offsetDate)"]
        if requested {
            items.append("requested=true")
        }
        if let link, !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("link=\(queryEncoded(link))")
        }
        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("q=\(queryEncoded(query))")
        }
        if let offsetUserID {
            items.append("offset_user_id=\(offsetUserID)")
        }
        return "v1/\(scope)/\(dialogID)/invite-importers?\(items.joined(separator: "&"))"
    }

    private func memberListPath(scope: String, dialogID: Int64, collection: String, filter: HSSupergroupMemberFilter, query: String?, limit: Int, offset: Int) -> String {
        var items = ["limit=\(limit)", "offset=\(offset)"]
        if filter != .recent {
            items.append("filter=\(filter.rawValue)")
        }
        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("q=\(queryEncoded(query))")
        }
        return "v1/\(scope)/\(dialogID)/\(collection)?\(items.joined(separator: "&"))"
    }

    private func messageReactionsPath(scope: String, dialogID: Int64, messageID: Int64, reaction: String?, offset: String?, limit: Int) -> String {
        var items = ["limit=\(limit)"]
        if let reaction, !reaction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("reaction=\(queryEncoded(reaction))")
        }
        if let offset, !offset.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("offset=\(queryEncoded(offset))")
        }
        return "v1/\(scope)/\(dialogID)/messages/\(messageID)/reactions/list?\(items.joined(separator: "&"))"
    }

    private func updateJoinRequest(scope: String, dialogID: Int64, userID: Int64, approve: Bool, session: HSUserSession) async throws -> HSMessageAction {
        let action = approve ? "approve" : "decline"
        return try await request("v1/\(scope)/\(dialogID)/join-requests/\(userID)/\(action)", method: "POST", body: Optional<EmptyBody>.none, session: session)
    }

    private func updateAllJoinRequests(scope: String, dialogID: Int64, link: String?, approve: Bool, session: HSUserSession) async throws -> HSMessageAction {
        let action = approve ? "approve-all" : "decline-all"
        return try await request(
            "v1/\(scope)/\(dialogID)/join-requests/\(action)",
            method: "POST",
            body: JoinRequestsBody(link: link),
            session: session
        )
    }

    private func queryEncoded(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=?+")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func pathEncoded(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=:")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
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

private struct PollMessageBody: Encodable {
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

private struct PollVoteBody: Encodable {
    let options: [Data]
}

private struct TodoMessageBody: Encodable {
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

private struct TodoToggleBody: Encodable {
    let completedIDs: [Int]
    let incompletedIDs: [Int]

    private enum CodingKeys: String, CodingKey {
        case completedIDs = "completed_ids"
        case incompletedIDs = "incompleted_ids"
    }
}

private struct TodoItemsBody: Encodable {
    let items: [HSTodoItem]
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

private struct ChatListSharedInviteBody: Encodable {
    let title: String?
    let peers: [HSChatListFilterPeer]?
}

private struct ChatListSharedInviteJoinBody: Encodable {
    let peers: [HSChatListFilterPeer]
}

private struct DialogFolderBody: Encodable {
    let folderID: Int

    enum CodingKeys: String, CodingKey {
        case folderID = "folder_id"
    }
}

private struct PeerNotificationSettingsBody: Encodable {
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

private struct ReportPeerBody: Encodable {
    let reason: HSReportReason
    let message: String
}

private struct ReportMessagesBody: Encodable {
    let messageIDs: [Int64]
    let option: Data?
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case messageIDs = "message_ids"
        case option
        case message
    }
}

private struct MessageIDsBody: Encodable {
    let messageIDs: [Int64]

    private enum CodingKeys: String, CodingKey {
        case messageIDs = "message_ids"
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

private struct DefaultReactionBody: Encodable {
    let reaction: String
}

private struct StickerSetActionBody: Encodable {
    let accessHash: Int64
    let archived: Bool?

    private enum CodingKeys: String, CodingKey {
        case accessHash = "access_hash"
        case archived
    }
}

private struct FeaturedStickerSetsReadBody: Encodable {
    let ids: [Int64]
}

private struct StickerDocumentActionBody: Encodable {
    let accessHash: Int64
    let fileReference: Data
    let attached: Bool

    private enum CodingKeys: String, CodingKey {
        case accessHash = "access_hash"
        case fileReference = "file_reference"
        case attached
    }
}

private struct DocumentActionBody: Encodable {
    let accessHash: Int64
    let fileReference: Data

    private enum CodingKeys: String, CodingKey {
        case accessHash = "access_hash"
        case fileReference = "file_reference"
    }
}

private struct RingtoneUploadBody: Encodable {
    let fileName: String
    let mimeType: String
    let data: Data

    private enum CodingKeys: String, CodingKey {
        case fileName = "file_name"
        case mimeType = "mime_type"
        case data
    }
}

private struct WallpaperActionBody: Encodable {
    let id: Int64?
    let accessHash: Int64?
    let settings: HSWallpaperSettings

    init(id: Int64? = nil, accessHash: Int64? = nil, settings: HSWallpaperSettings) {
        self.id = id
        self.accessHash = accessHash
        self.settings = settings
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case accessHash = "access_hash"
        case settings
    }
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
    let note: String? = nil
    let addPhonePrivacyException: Bool = false
}

private struct ContactNoteBody: Encodable {
    let note: String
}

private struct ImportContactsBody: Encodable {
    let contacts: [HSDeviceContactImport]
}

private struct ContactPhonesBody: Encodable {
    let phones: [String]
}

private struct ImportContactTokenBody: Encodable {
    let token: String
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

private struct EditInviteBody: Encodable {
    let link: String
    let title: String?
    let expireDate: Int?
    let usageLimit: Int?
    let requestNeeded: Bool?
    let revoked: Bool
}

private struct JoinRequestsBody: Encodable {
    let link: String?
}

private struct UsernameBody: Encodable {
    let username: String?
}

private struct DiscussionGroupBody: Encodable {
    let groupDialogID: Int64?

    enum CodingKeys: String, CodingKey {
        case groupDialogID = "group_dialog_id"
    }
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
