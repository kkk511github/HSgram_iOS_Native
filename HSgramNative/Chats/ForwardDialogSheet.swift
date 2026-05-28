import SwiftUI

struct ForwardDialogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore

    let currentDialogID: Int64
    let onSelect: (HSChat) -> Void

    @State private var chats: [HSChat] = []
    @State private var errorMessage: String?

    private var savedMessagesChat: HSChat? {
        guard let session = authStore.session else {
            return nil
        }
        return HSChat(
            id: session.userID,
            title: "Saved Messages",
            subtitle: "已保存消息",
            unreadCount: 0,
            isCircle: false,
            updatedAt: nil
        )
    }

    private var displayChats: [HSChat] {
        guard let savedMessagesChat else {
            return chats.filter { $0.id != currentDialogID }
        }
        var result = savedMessagesChat.id == currentDialogID ? [] : [savedMessagesChat]
        result.append(contentsOf: chats.filter { $0.id != currentDialogID && $0.id != savedMessagesChat.id })
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }
                ForEach(displayChats) { chat in
                    Button {
                        onSelect(chat)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            HSClassicAvatar(title: chat.title, icon: chat.id == savedMessagesChat?.id ? "bookmark.fill" : (chat.isCircle ? "person.3.fill" : "person.fill"), tint: chat.isCircle ? HSTheme.circle : HSTheme.accent, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(chat.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(HSTheme.primaryText)
                                Text(chat.subtitle)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(HSTheme.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(HSTheme.Chat.listBackground)
            .navigationTitle("转发到")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .task {
                await refresh()
            }
        }
    }

    private func refresh() async {
        guard let session = authStore.session else {
            return
        }
        do {
            chats = try await authStore.api.dialogs(session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
