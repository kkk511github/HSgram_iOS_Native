import SwiftUI

struct NewSupergroupSheet: View {
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

                Section("超级群") {
                    TextField("群名称", text: $title)
                    TextField("简介", text: $about, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("成员") {
                    if contacts.isEmpty {
                        Text("暂无可邀请联系人。")
                            .foregroundStyle(HSTheme.secondaryText)
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
            .scrollContentBackground(.hidden)
            .background(HSTheme.grouped)
            .navigationTitle("新建超级群")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "创建中" : "创建") {
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
