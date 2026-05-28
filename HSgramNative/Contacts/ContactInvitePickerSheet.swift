import SwiftUI

struct ContactInvitePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore

    let title: String
    let existingIDs: Set<Int64>
    let onInvite: ([Int64]) -> Void

    @State private var contacts: [HSContact] = []
    @State private var selectedIDs: Set<Int64> = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }
                ForEach(contacts.filter { !existingIDs.contains($0.id) }) { contact in
                    Button {
                        if selectedIDs.contains(contact.id) {
                            selectedIDs.remove(contact.id)
                        } else {
                            selectedIDs.insert(contact.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            HSClassicAvatar(title: contact.displayName, icon: "person.fill", tint: HSTheme.accent, size: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(HSTheme.primaryText)
                                if let username = contact.username {
                                    Text("@\(username)")
                                        .font(.footnote)
                                        .foregroundStyle(HSTheme.secondaryText)
                                }
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
            .scrollContentBackground(.hidden)
            .background(HSTheme.Chat.listBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("邀请") {
                        onInvite(Array(selectedIDs))
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
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
            contacts = try await authStore.api.contacts(session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
