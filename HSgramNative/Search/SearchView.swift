import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var query = ""
    @State private var results = HSSearchResults(query: "", dialogs: [], contacts: [], messages: [])
    @State private var errorMessage: String?
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Label("搜索聊天、消息、联系人和频道。", systemImage: "magnifyingglass")
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                } else if isSearching {
                    Section {
                        HStack {
                            ProgressView()
                            Text("搜索中")
                                .foregroundStyle(HSTheme.secondaryText)
                        }
                    }
                } else if results.dialogs.isEmpty && results.contacts.isEmpty && results.messages.isEmpty && errorMessage == nil {
                    Section {
                        Text("没有找到结果。")
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                }

                if !results.dialogs.isEmpty {
                    Section("聊天") {
                        ForEach(results.dialogs) { chat in
                            NavigationLink {
                                ChatThreadView(chat: chat)
                            } label: {
                                SearchChatRow(chat: chat)
                            }
                        }
                    }
                }

                if !results.contacts.isEmpty {
                    Section("联系人") {
                        ForEach(results.contacts) { contact in
                            NavigationLink {
                                ContactProfileView(contact: contact) { updated in
                                    applyContactChange(updated, originalID: contact.id)
                                }
                            } label: {
                                SearchContactRow(contact: contact)
                            }
                        }
                    }
                }

                if !results.messages.isEmpty {
                    Section("消息") {
                        ForEach(results.messages, id: \.searchID) { message in
                            NavigationLink {
                                ChatThreadView(chat: chat(for: message), mode: message.isChannel ? .channel : .automatic)
                            } label: {
                                SearchMessageRow(message: message)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(HSTheme.Chat.listBackground)
            .navigationTitle("搜索")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索 HSgram")
            .onSubmit(of: .search) {
                Task {
                    await performSearch()
                }
            }
            .onChange(of: query) { _ in
                Task {
                    await debouncedSearch()
                }
            }
            .refreshable {
                await performSearch()
            }
        }
    }

    private func debouncedSearch() async {
        let current = query
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard current == query else {
            return
        }
        await performSearch()
    }

    private func performSearch() async {
        guard let session = authStore.session else {
            return
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = HSSearchResults(query: "", dialogs: [], contacts: [], messages: [])
            errorMessage = nil
            return
        }

        isSearching = true
        defer { isSearching = false }
        do {
            results = try await authStore.api.search(query: trimmed, session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyContactChange(_ contact: HSContact?, originalID: Int64) {
        var contacts = results.contacts
        if let contact {
            contacts.removeAll { $0.id == contact.id }
            contacts.insert(contact, at: 0)
        } else {
            contacts.removeAll { $0.id == originalID }
        }
        results = HSSearchResults(query: results.query, dialogs: results.dialogs, contacts: contacts, messages: results.messages)
    }

    private func chat(for message: HSSearchMessage) -> HSChat {
        HSChat(
            id: message.dialogID,
            title: message.dialogTitle,
            subtitle: message.authorName,
            unreadCount: 0,
            isCircle: message.isGroup,
            peerKind: message.isGroup ? .chat : .user,
            updatedAt: message.sentAt
        )
    }
}

private struct SearchChatRow: View {
    let chat: HSChat

    var body: some View {
        HStack(spacing: 12) {
            HSClassicAvatar(title: chat.title, icon: chat.isCircle ? "person.3.fill" : "bubble.left.fill", tint: chat.isCircle ? HSTheme.circle : HSTheme.accent, size: 44)
            VStack(alignment: .leading, spacing: 4) {
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

private struct SearchContactRow: View {
    let contact: HSContact

    var body: some View {
        HStack(spacing: 12) {
            HSClassicAvatar(title: contact.displayName, icon: "person.fill", tint: HSTheme.accent, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(HSTheme.primaryText)
                Text(contact.username.map { "@\($0)" } ?? contact.status)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HSTheme.secondaryText)
            }
        }
    }
}

private struct SearchMessageRow: View {
    let message: HSSearchMessage

    var body: some View {
        HStack(spacing: 12) {
            HSClassicAvatar(title: message.dialogTitle, icon: message.isChannel ? "megaphone.fill" : (message.isGroup ? "person.3.fill" : "text.bubble.fill"), tint: message.isChannel ? HSTheme.accent : HSTheme.circle, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.dialogTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(HSTheme.primaryText)
                    Spacer()
                    Text(message.sentAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(HSTheme.secondaryText)
                }
                Text(message.text.isEmpty ? message.authorName : message.text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HSTheme.secondaryText)
                    .lineLimit(2)
            }
        }
    }
}
