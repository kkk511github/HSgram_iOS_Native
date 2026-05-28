import SwiftUI

struct ChannelsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var channels: [HSChannel] = []
    @State private var errorMessage: String?
    @State private var isShowingNewChannel = false

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }
                if channels.isEmpty && errorMessage == nil {
                    Text("暂无频道。")
                        .foregroundStyle(HSTheme.secondaryText)
                }
                ForEach(channels) { channel in
                    NavigationLink {
                        ChatThreadView(chat: chat(for: channel), mode: .channel)
                    } label: {
                        HStack(spacing: 12) {
                            HSClassicAvatar(title: channel.title, icon: "megaphone.fill", tint: HSTheme.accent, size: 52)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(channel.title)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(HSTheme.primaryText)
                                Text(channel.about.isEmpty ? "\(channel.memberCount) subscribers" : channel.about)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(HSTheme.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(HSTheme.Chat.listBackground)
            .navigationTitle("频道")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingNewChannel = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新建频道")
                }
            }
            .sheet(isPresented: $isShowingNewChannel) {
                NewChannelSheet { channel in
                    channels.removeAll { $0.id == channel.id }
                    channels.insert(channel, at: 0)
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
            channels = try await authStore.api.channels(session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func chat(for channel: HSChannel) -> HSChat {
        HSChat(
            id: channel.id,
            title: channel.title,
            subtitle: channel.about.isEmpty ? "\(channel.memberCount) subscribers" : channel.about,
            unreadCount: 0,
            isCircle: false,
            peerKind: .channel,
            isBroadcast: true,
            updatedAt: nil
        )
    }
}

private struct NewChannelSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore

    let onCreated: (HSChannel) -> Void

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
                Section("频道") {
                    TextField("频道名称", text: $title)
                    TextField("简介", text: $about, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("订阅者") {
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
            .navigationTitle("新建频道")
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
            let channel = try await authStore.api.createChannel(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                about: about.trimmingCharacters(in: .whitespacesAndNewlines),
                memberIDs: Array(selectedIDs),
                session: session
            )
            onCreated(channel)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
