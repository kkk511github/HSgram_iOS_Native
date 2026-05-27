import SwiftUI

struct ContactsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var contacts: [HSContact] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }
                Section("Requests") {
                    ForEach(contacts.filter { $0.status.contains("pending") }) { contact in
                        ContactRow(contact: contact)
                    }
                    if contacts.filter({ $0.status.contains("pending") }).isEmpty {
                        Text("No pending requests.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("People") {
                    ForEach(contacts.filter { !$0.status.contains("pending") }) { contact in
                        NavigationLink {
                            ChatThreadView(chat: privateChat(for: contact))
                        } label: {
                            ContactRow(contact: contact)
                        }
                    }
                    if contacts.filter({ !$0.status.contains("pending") }).isEmpty {
                        Text("No contacts yet.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                Button {
                } label: {
                    Image(systemName: "person.badge.plus")
                }
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
            let loaded = try await authStore.api.contacts(session: session)
            contacts = loaded
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func privateChat(for contact: HSContact) -> HSChat {
        HSChat(
            id: contact.id,
            title: contact.displayName,
            subtitle: contact.username.map { "@\($0)" } ?? contact.status,
            unreadCount: 0,
            isCircle: false,
            updatedAt: nil
        )
    }
}

private struct ContactRow: View {
    let contact: HSContact

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(HSTheme.accent.opacity(0.16))
                .overlay {
                    Text(String(contact.displayName.prefix(1)))
                        .font(.headline)
                        .foregroundStyle(HSTheme.accent)
                }
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.displayName)
                    .font(.headline)
                Text(contact.username.map { "@\($0)" } ?? contact.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if contact.status.contains("pending") {
                Text("Pending")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HSTheme.circle)
            }
        }
    }
}
