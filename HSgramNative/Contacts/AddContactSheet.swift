import SwiftUI

struct AddContactSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore

    let onRequested: (HSContact) -> Void

    @State private var query = ""
    @State private var results: [HSContact] = []
    @State private var errorMessage: String?
    @State private var isSearching = false
    @State private var requestingID: Int64?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }

                Section("搜索") {
                    TextField("姓名、用户名或邮箱", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task {
                                await search()
                            }
                        }
                    Button(isSearching ? "搜索中" : "搜索") {
                        Task {
                            await search()
                        }
                    }
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                }

                Section("结果") {
                    if results.isEmpty {
                        Text("搜索 HSgram 用户并添加到联系人。")
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                    ForEach(results) { contact in
                        HStack(spacing: 12) {
                            ContactRow(contact: contact)
                            Spacer()
                            Button(requestingID == contact.id ? "添加中" : actionTitle(for: contact)) {
                                Task {
                                    await add(contact)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canRequest(contact) || requestingID != nil)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(HSTheme.grouped)
            .navigationTitle("添加联系人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func search() async {
        guard let session = authStore.session else {
            return
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await authStore.api.searchContacts(query: trimmed, session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func add(_ contact: HSContact) async {
        guard let session = authStore.session, canRequest(contact) else {
            return
        }
        requestingID = contact.id
        defer { requestingID = nil }
        do {
            _ = try await authStore.api.addContact(
                userID: contact.id,
                firstName: firstName(from: contact.displayName),
                lastName: lastName(from: contact.displayName),
                session: session
            )
            let added = HSContact(id: contact.id, displayName: contact.displayName, username: contact.username, status: "contact")
            results.removeAll { $0.id == contact.id }
            results.insert(added, at: 0)
            onRequested(added)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func canRequest(_ contact: HSContact) -> Bool {
        contact.status == "global" || contact.status == "none"
    }

    private func actionTitle(for contact: HSContact) -> String {
        switch contact.status {
        case "contact", "mutual":
            return "已添加"
        case "pending_sent":
            return "待通过"
        case "pending_received":
            return "待处理"
        case "blocked":
            return "已屏蔽"
        default:
            return "添加"
        }
    }

    private func firstName(from displayName: String) -> String {
        let parts = displayName.split(separator: " ", maxSplits: 1).map(String.init)
        return parts.first ?? displayName
    }

    private func lastName(from displayName: String) -> String {
        let parts = displayName.split(separator: " ", maxSplits: 1).map(String.init)
        return parts.count > 1 ? parts[1] : ""
    }
}
