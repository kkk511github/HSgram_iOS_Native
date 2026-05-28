import Foundation
import SwiftUI

@MainActor
protocol HSChatDataProviding: ObservableObject {
    var currentUser: User { get }
    var users: [User] { get }
    var conversations: [Conversation] { get }
    var contacts: [Contact] { get }
    var groups: [HSGroup] { get }
    var settingsItems: [SettingsItem] { get }
    var themeConfig: ThemeConfig { get set }
    var recentSearches: [String] { get set }

    func messages(for conversationID: UUID) -> [Message]
    func conversation(id: UUID) -> Conversation?
    func user(id: UUID) -> User?
    func group(id: UUID) -> HSGroup?
    func sendText(_ text: String, in conversationID: UUID)
    func sendAttachment(_ attachment: Attachment, caption: String, in conversationID: UUID)
    func toggleReaction(_ emoji: String, for messageID: UUID, in conversationID: UUID)
    func pin(_ conversation: Conversation)
    func mute(_ conversation: Conversation)
    func archive(_ conversation: Conversation)
    func delete(_ conversation: Conversation)
    func deleteMessage(_ messageID: UUID, in conversationID: UUID)
    func refresh() async
}

enum HSRemoteChatAPIError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        "真实 API 连接尚未配置。"
    }
}

enum HSRemoteChatEndpoint: Hashable {
    case startEmailAuth
    case verifyEmailAuth
    case dialogs
    case messages(dialogID: UUID)
    case media(dialogID: UUID)
    case reactions(dialogID: UUID, messageID: UUID)
    case search
    case privacySettings
    case notificationSettings

    var path: String {
        switch self {
        case .startEmailAuth:
            return "v1/auth/email/start"
        case .verifyEmailAuth:
            return "v1/auth/email/verify"
        case .dialogs:
            return "v1/dialogs"
        case .messages(let dialogID):
            return "v1/dialogs/\(dialogID.uuidString)/messages"
        case .media(let dialogID):
            return "v1/dialogs/\(dialogID.uuidString)/media"
        case .reactions(let dialogID, let messageID):
            return "v1/dialogs/\(dialogID.uuidString)/messages/\(messageID.uuidString)/reactions"
        case .search:
            return "v1/search"
        case .privacySettings:
            return "v1/settings/privacy"
        case .notificationSettings:
            return "v1/settings/notifications"
        }
    }
}

struct HSRemoteChatAPI {
    var baseURL: URL

    func url(for endpoint: HSRemoteChatEndpoint) -> URL {
        baseURL.appendingPathComponent(endpoint.path)
    }

    func loadConversations(token: String) async throws -> [Conversation] {
        throw HSRemoteChatAPIError.notConfigured
    }

    func loadMessages(conversationID: UUID, token: String) async throws -> [Message] {
        throw HSRemoteChatAPIError.notConfigured
    }

    func sendMessage(_ message: Message, token: String) async throws -> Message {
        throw HSRemoteChatAPIError.notConfigured
    }
}
