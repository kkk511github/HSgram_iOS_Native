import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var chats: [HSChat] = []
    @State private var errorMessage: String?
    @State private var isShowingNewGroup = false

    var body: some View {
        NavigationStack {
            List(chats) { chat in
                NavigationLink {
                    ChatThreadView(chat: chat)
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(chat.isCircle ? HSTheme.circle.opacity(0.18) : HSTheme.accent.opacity(0.18))
                            .overlay {
                                Image(systemName: chat.isCircle ? "person.3" : "person")
                                    .foregroundStyle(chat.isCircle ? HSTheme.circle : HSTheme.accent)
                            }
                            .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(chat.title)
                                .font(.headline)
                            Text(chat.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if chat.unreadCount > 0 {
                            Text("\(chat.unreadCount)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 22, minHeight: 22)
                                .background(HSTheme.accent, in: Capsule())
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .overlay {
                if chats.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(errorMessage ?? "No conversations yet.")
                            .font(.footnote)
                            .foregroundStyle(errorMessage == nil ? .secondary : HSTheme.warning)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingNewGroup = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New supergroup")
                }
            }
            .sheet(isPresented: $isShowingNewGroup) {
                NewSupergroupSheet { group in
                    let chat = HSChat(
                        id: group.id,
                        title: group.title,
                        subtitle: group.about.isEmpty ? "\(group.memberCount) members" : group.about,
                        unreadCount: 0,
                        isCircle: true,
                        updatedAt: nil
                    )
                    chats.removeAll { $0.id == chat.id }
                    chats.insert(chat, at: 0)
                }
                .environmentObject(authStore)
            }
            .task {
                await refresh()
            }
            .refreshable {
                await refresh()
            }
        }
    }

    private func refresh() async {
        guard let session = authStore.session else {
            return
        }
        do {
            let loaded = try await authStore.api.dialogs(session: session)
            chats = loaded
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct NewSupergroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore

    let onCreated: (HSSupergroup) -> Void

    @State private var title = ""
    @State private var about = ""
    @State private var contacts: [HSContact] = []
    @State private var selectedIDs: Set<Int64> = []
    @State private var errorMessage: String?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }

                Section("Supergroup") {
                    TextField("Group name", text: $title)
                    TextField("Description", text: $about, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Members") {
                    if contacts.isEmpty {
                        Text("No contacts to invite yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(contacts) { contact in
                        Button {
                            toggle(contact.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(contact.displayName)
                                        .foregroundStyle(.primary)
                                    Text(contact.username.map { "@\($0)" } ?? contact.status)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedIDs.contains(contact.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(HSTheme.accent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Supergroup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "Creating" : "Create") {
                        Task {
                            await create()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
            .task {
                await loadContacts()
            }
        }
    }

    private func toggle(_ id: Int64) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func loadContacts() async {
        guard let session = authStore.session else {
            return
        }
        do {
            contacts = try await authStore.api.contacts(session: session)
                .filter { !$0.status.contains("pending") }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func create() async {
        guard let session = authStore.session else {
            return
        }
        isCreating = true
        defer { isCreating = false }
        do {
            let group = try await authStore.api.createSupergroup(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                about: about.trimmingCharacters(in: .whitespacesAndNewlines),
                memberIDs: Array(selectedIDs),
                session: session
            )
            onCreated(group)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
