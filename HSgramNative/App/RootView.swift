import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        Group {
            if authStore.session == nil {
                AuthView()
            } else {
                MainTabsView()
            }
        }
        .tint(HSTheme.accent)
    }
}

private struct MainTabsView: View {
    var body: some View {
        TabView {
            WorkspaceView()
                .tabItem {
                    Label("Today", systemImage: "tray.full")
                }

            ChatListView()
                .tabItem {
                    Label("Chats", systemImage: "bubble.left.and.bubble.right")
                }

            ChannelsView()
                .tabItem {
                    Label("Channels", systemImage: "megaphone")
                }

            CirclesView()
                .tabItem {
                    Label("Circles", systemImage: "person.3")
                }

            ContactsView()
                .tabItem {
                    Label("Contacts", systemImage: "person.crop.circle")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

private struct ChannelsView: View {
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
                    Text("No channels yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(channels) { channel in
                    NavigationLink {
                        ChatThreadView(chat: chat(for: channel), mode: .channel)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(HSTheme.accent.opacity(0.16))
                                .overlay {
                                    Image(systemName: "megaphone")
                                        .foregroundStyle(HSTheme.accent)
                                }
                                .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(channel.title)
                                    .font(.headline)
                                Text(channel.about.isEmpty ? "\(channel.memberCount) subscribers" : channel.about)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Channels")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingNewChannel = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New channel")
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
    @State private var errorMessage: String?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }
                Section("Channel") {
                    TextField("Channel name", text: $title)
                    TextField("Description", text: $about, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Channel")
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
                session: session
            )
            onCreated(channel)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ChannelManageView: View {
    @EnvironmentObject private var authStore: AuthStore
    let chat: HSChat

    @State private var channel: HSChannel?
    @State private var subscribers: [HSSupergroupMember] = []
    @State private var adminEvents: [HSSupergroupAdminLogEvent] = []
    @State private var editTitle = ""
    @State private var editAbout = ""
    @State private var inviteLink: String?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isSaving = false
    @State private var isShowingInvite = false

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

            Section("Channel") {
                TextField("Channel name", text: $editTitle)
                TextField("Description", text: $editAbout, axis: .vertical)
                    .lineLimit(2...4)
                LabeledContent("Subscribers", value: String(channel?.memberCount ?? subscribers.count))
                LabeledContent("Role", value: channel?.role ?? "member")
                Button(isSaving ? "Saving" : "Save Channel Info") {
                    Task {
                        await saveInfo()
                    }
                }
                .disabled(isSaving || editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Invite Link") {
                if let inviteLink {
                    Text(inviteLink)
                        .font(.footnote)
                        .textSelection(.enabled)
                    Button("Copy Invite Link") {
                        UIPasteboard.general.string = inviteLink
                        statusMessage = "Invite link copied."
                    }
                }
                Button("Generate Invite Link") {
                    Task {
                        await generateInvite()
                    }
                }
                Button("Invite Contacts") {
                    isShowingInvite = true
                }
            }

            Section("Subscribers") {
                if subscribers.isEmpty {
                    Text("No subscribers loaded.")
                        .foregroundStyle(.secondary)
                }
                ForEach(subscribers) { subscriber in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(subscriber.displayName)
                                .font(.headline)
                            Spacer()
                            Text(subscriber.role)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        if let username = subscriber.username {
                            Text("@\(username)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !subscriber.isSelf {
                            Button(role: .destructive) {
                                Task {
                                    await remove(subscriber)
                                }
                            } label: {
                                Label("Remove", systemImage: "person.crop.circle.badge.minus")
                            }
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if !subscriber.isSelf {
                            Button {
                                Task {
                                    await promote(subscriber)
                                }
                            } label: {
                                Label("Admin", systemImage: "star")
                            }
                            .tint(HSTheme.accent)
                        }
                    }
                }
            }

            Section("Admin Log") {
                if adminEvents.isEmpty {
                    Text("No recent channel events.")
                        .foregroundStyle(.secondary)
                }
                ForEach(adminEvents) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.description)
                            .font(.subheadline.weight(.semibold))
                        Text("\(event.actorName) · \(event.action)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        await leave()
                    }
                } label: {
                    Text("Leave Channel")
                }
            }
        }
        .navigationTitle("Channel Info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                Task {
                    await refresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
        .sheet(isPresented: $isShowingInvite) {
            ChannelInviteSubscribersSheet(existingIDs: Set(subscribers.map(\.id))) { userIDs in
                Task {
                    await invite(userIDs)
                }
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

    private func refresh() async {
        guard let session = authStore.session else {
            return
        }
        do {
            async let loadedChannel = authStore.api.channel(dialogID: chat.id, session: session)
            async let loadedSubscribers = authStore.api.channelSubscribers(dialogID: chat.id, limit: 100, session: session)
            async let loadedEvents = authStore.api.channelAdminLog(dialogID: chat.id, limit: 30, session: session)
            let channel = try await loadedChannel
            self.channel = channel
            editTitle = channel.title
            editAbout = channel.about
            subscribers = try await loadedSubscribers
            adminEvents = try await loadedEvents
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveInfo() async {
        guard let session = authStore.session else {
            return
        }
        let title = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            errorMessage = "Channel name is required."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            channel = try await authStore.api.updateChannel(
                dialogID: chat.id,
                title: title,
                about: editAbout.trimmingCharacters(in: .whitespacesAndNewlines),
                session: session
            )
            statusMessage = "Channel info updated."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generateInvite() async {
        guard let session = authStore.session else {
            return
        }
        do {
            let invite = try await authStore.api.exportChannelInvite(dialogID: chat.id, title: "HSgram Channel", session: session)
            inviteLink = invite.link
            UIPasteboard.general.string = invite.link
            statusMessage = "Invite link generated and copied."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func invite(_ userIDs: [Int64]) async {
        guard let session = authStore.session, !userIDs.isEmpty else {
            return
        }
        do {
            _ = try await authStore.api.inviteChannelSubscribers(dialogID: chat.id, userIDs: userIDs, session: session)
            statusMessage = "Contacts invited."
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ subscriber: HSSupergroupMember) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.removeChannelSubscriber(dialogID: chat.id, userID: subscriber.id, session: session)
            subscribers.removeAll { $0.id == subscriber.id }
            statusMessage = "\(subscriber.displayName) was removed."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func promote(_ subscriber: HSSupergroupMember) async {
        guard let session = authStore.session else {
            return
        }
        var rights = HSSupergroupAdminRights()
        rights.changeInfo = true
        rights.postMessages = true
        rights.editMessages = true
        rights.deleteMessages = true
        rights.inviteUsers = true
        do {
            _ = try await authStore.api.editChannelAdmin(dialogID: chat.id, userID: subscriber.id, rights: rights, rank: "Admin", session: session)
            statusMessage = "\(subscriber.displayName) is now a channel admin."
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func leave() async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.leaveChannel(dialogID: chat.id, session: session)
            statusMessage = "Left channel."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ChannelInviteSubscribersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore

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
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.displayName)
                                if let username = contact.username {
                                    Text("@\(username)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
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
            .navigationTitle("Invite Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Invite") {
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
