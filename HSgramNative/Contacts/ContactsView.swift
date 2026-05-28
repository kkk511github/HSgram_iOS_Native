import SwiftUI

struct ContactsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var contacts: [HSContact] = []
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isShowingAddContact = false

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }
                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HSTheme.trust)
                }

                Section("请求") {
                    ForEach(pendingReceived) { contact in
                        NavigationLink {
                            ContactProfileView(contact: contact) { updated in
                                applyProfileChange(updated, originalID: contact.id)
                            }
                        } label: {
                            ContactRow(contact: contact)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await decline(contact)
                                }
                            } label: {
                                Label("拒绝", systemImage: "xmark")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                Task {
                                    await accept(contact)
                                }
                            } label: {
                                Label("接受", systemImage: "checkmark")
                            }
                            .tint(HSTheme.trust)
                        }
                    }
                    if pendingReceived.isEmpty {
                        Text("没有待处理的联系人请求。")
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                }

                Section("联系人") {
                    ForEach(visiblePeople) { contact in
                        NavigationLink {
                            ContactProfileView(contact: contact) { updated in
                                applyProfileChange(updated, originalID: contact.id)
                            }
                        } label: {
                            ContactRow(contact: contact)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await delete(contact)
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            if contact.status == "blocked" {
                                Button {
                                    Task {
                                        await unblock(contact)
                                    }
                                } label: {
                                    Label("解除屏蔽", systemImage: "hand.raised.slash")
                                }
                                .tint(HSTheme.trust)
                            } else {
                                Button(role: .destructive) {
                                    Task {
                                        await block(contact)
                                    }
                                } label: {
                                    Label("屏蔽", systemImage: "hand.raised")
                                }
                            }
                        }
                    }
                    if visiblePeople.isEmpty {
                        Text("暂无联系人。")
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(HSTheme.Chat.listBackground)
            .navigationTitle("联系人")
            .toolbar {
                Button {
                    isShowingAddContact = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .accessibilityLabel("添加联系人")
            }
            .sheet(isPresented: $isShowingAddContact) {
                AddContactSheet { contact in
                    upsert(contact)
                    statusMessage = "\(contact.displayName) 已添加到联系人。"
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

    private var pendingReceived: [HSContact] {
        contacts.filter { $0.status == "pending_received" || $0.status == "pending" }
    }

    private var visiblePeople: [HSContact] {
        contacts.filter { contact in
            contact.status != "pending_received" && contact.status != "pending"
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

    private func accept(_ contact: HSContact) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.acceptContact(userID: contact.id, session: session)
            statusMessage = "\(contact.displayName) 已添加到联系人。"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func decline(_ contact: HSContact) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.declineContact(userID: contact.id, session: session)
            contacts.removeAll { $0.id == contact.id }
            statusMessage = "已拒绝联系人请求。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ contact: HSContact) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.deleteContact(userID: contact.id, session: session)
            contacts.removeAll { $0.id == contact.id }
            statusMessage = "\(contact.displayName) 已移除。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func block(_ contact: HSContact) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.blockContact(userID: contact.id, session: session)
            upsert(HSContact(id: contact.id, displayName: contact.displayName, username: contact.username, status: "blocked"))
            statusMessage = "\(contact.displayName) 已屏蔽。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unblock(_ contact: HSContact) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.unblockContact(userID: contact.id, session: session)
            statusMessage = "\(contact.displayName) 已解除屏蔽。"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsert(_ contact: HSContact) {
        contacts.removeAll { $0.id == contact.id }
        contacts.insert(contact, at: 0)
    }

    private func applyProfileChange(_ contact: HSContact?, originalID: Int64) {
        if let contact {
            upsert(contact)
        } else {
            contacts.removeAll { $0.id == originalID }
        }
    }
}
