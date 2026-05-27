import Foundation

enum HSAPIError: LocalizedError {
    case invalidURL
    case missingSession
    case server(String)
    case emptyResponse
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server URL is invalid."
        case .missingSession:
            return "Please sign in again."
        case .server(let message):
            return message
        case .emptyResponse:
            return "The server returned an empty response."
        case .transport(let error):
            return error.localizedDescription
        }
    }
}

final class HSAPIClient {
    static let shared = HSAPIClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL = URL(string: "https://hsgram.cloud")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .secondsSince1970
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .secondsSince1970
    }

    func sendEmailCode(email: String) async throws -> HSEmailStartResponse {
        try await request(
            "v1/auth/email/start",
            method: "POST",
            body: ["email": email, "purpose": "sign_in_or_register"],
            session: nil
        )
    }

    func verifyEmailCode(email: String, code: String, transactionID: String, displayName: String) async throws -> HSUserSession {
        try await request(
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

    func workspaceSummary(session: HSUserSession) async throws -> HSWorkspaceSummary {
        try await request("workspace/summary", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func dialogs(session: HSUserSession) async throws -> [HSChat] {
        try await request("v1/dialogs", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func messages(dialogID: Int64, session: HSUserSession) async throws -> [HSMessage] {
        try await request("v1/dialogs/\(dialogID)/messages", method: "GET", body: Optional<EmptyBody>.none, session: session)
    }

    func sendMessage(dialogID: Int64, text: String, session: HSUserSession) async throws -> HSMessage {
        try await request(
            "v1/dialogs/\(dialogID)/messages",
            method: "POST",
            body: ["text": text],
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

    func privacySettings(session: HSUserSession) async throws -> HSPrivacySettings {
        try await request("v1/settings/privacy", method: "GET", body: Optional<EmptyBody>.none, session: session)
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

    private func request<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        body: Body?,
        session userSession: HSUserSession?
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw HSAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
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
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                throw HSAPIError.server(message)
            }
            let wrapped = try decoder.decode(HSAPIResponse<Response>.self, from: data)
            if wrapped.ok, let value = wrapped.data {
                return value
            }
            throw HSAPIError.server(wrapped.message ?? wrapped.code ?? "Request failed.")
        } catch let error as HSAPIError {
            throw error
        } catch {
            throw HSAPIError.transport(error)
        }
    }
}

private struct EmptyBody: Encodable {}

private struct ForwardMessageBody: Encodable {
    let toDialogID: Int64
    let dropAuthor: Bool
    let dropMediaCaptions: Bool
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
