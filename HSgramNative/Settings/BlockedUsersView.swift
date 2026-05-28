import SwiftUI

struct BlockedUsersView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var contacts: [HSContact] = []
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isLoading = false
    @State private var activeUserID: Int64?

    var body: some View {
        List {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }
            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HSTheme.trust)
            }

            Section("已屏蔽用户") {
                if isLoading && contacts.isEmpty {
                    ProgressView()
                } else if contacts.isEmpty {
                    Text("没有已屏蔽用户。")
                        .foregroundStyle(HSTheme.secondaryText)
                } else {
                    ForEach(contacts) { contact in
                        NavigationLink {
                            ContactProfileView(contact: contact) { updated in
                                applyProfileChange(updated, originalID: contact.id)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                ContactRow(contact: contact)
                                if activeUserID == contact.id {
                                    ProgressView()
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await unblock(contact)
                                }
                            } label: {
                                Label("解除屏蔽", systemImage: "hand.raised.slash")
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("已屏蔽用户")
        .task {
            await refresh()
        }
        .refreshable {
            await refresh()
        }
    }

    private func refresh() async {
        guard let session = authStore.session else {
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            contacts = try await authStore.api.blockedContacts(session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unblock(_ contact: HSContact) async {
        guard let session = authStore.session else {
            return
        }
        activeUserID = contact.id
        defer { activeUserID = nil }
        do {
            _ = try await authStore.api.unblockContact(userID: contact.id, session: session)
            contacts.removeAll { $0.id == contact.id }
            statusMessage = "\(contact.displayName) 已解除屏蔽。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyProfileChange(_ contact: HSContact?, originalID: Int64) {
        guard let contact, contact.status == "blocked" else {
            contacts.removeAll { $0.id == originalID }
            return
        }
        contacts.removeAll { $0.id == originalID || $0.id == contact.id }
        contacts.insert(contact, at: 0)
    }
}
