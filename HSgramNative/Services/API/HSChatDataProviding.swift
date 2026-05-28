import Foundation
import SwiftUI

@MainActor
protocol HSChatDataProviding: ObservableObject {
    var currentUser: User { get }
    var users: [User] { get }
    var conversations: [Conversation] { get }
    var contacts: [Contact] { get }
    var groups: [Group] { get }
    var settingsItems: [SettingsItem] { get }
    var themeConfig: ThemeConfig { get set }
    var recentSearches: [String] { get set }

    func messages(for conversationID: UUID) -> [Message]
    func conversation(id: UUID) -> Conversation?
    func user(id: UUID) -> User?
    func group(id: UUID) -> Group?
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

struct HSRemoteChatAPI {
    var baseURL: URL

    // Align these endpoint slots with the current native client/server adapter:
    // POST v1/auth/email/start, POST v1/auth/email/verify, GET v1/dialogs,
    // GET/POST v1/dialogs/{dialogID}/messages, POST v1/dialogs/{dialogID}/media,
    // POST v1/dialogs/{dialogID}/messages/{messageID}/reactions, GET v1/search,
    // GET/PATCH v1/settings/privacy and v1/settings/notifications.
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
