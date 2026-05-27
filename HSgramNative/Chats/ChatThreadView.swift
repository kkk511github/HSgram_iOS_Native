import SwiftUI
import UIKit

enum HSChatThreadMode {
    case automatic
    case channel
}

struct ChatThreadView: View {
    @EnvironmentObject private var authStore: AuthStore
    let chat: HSChat
    let mode: HSChatThreadMode = .automatic

    @State private var messages: [HSMessage] = []
    @State private var draft = ""
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var editingMessage: HSMessage?
    @State private var editText = ""
    @State private var forwardingMessage: HSMessage?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if let errorMessage {
                            HSErrorBanner(message: errorMessage)
                        }
                        if let statusMessage {
                            Label(statusMessage, systemImage: "checkmark.circle")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(HSTheme.trust)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(HSTheme.trust.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                isGroup: chat.isCircle,
                                onEdit: { beginEdit(message) },
                                onDelete: { Task { await delete(message) } },
                                onForward: { forwardingMessage = message },
                                onReact: { reaction in Task { await react(message, reaction: reaction) } },
                                onPin: { Task { await pin(message) } },
                                onCopyLink: { Task { await copyLink(message) } }
                            )
                                .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .refreshable {
                    await refresh()
                }
            }

            HStack(spacing: 10) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))

                Button {
                    Task {
                        await send()
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(.regularMaterial)
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if mode == .channel {
                    NavigationLink {
                        ChannelManageView(chat: chat)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                } else if chat.isCircle {
                    NavigationLink {
                        SupergroupManageView(chat: chat)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
                Button {
                    Task {
                        await refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .alert("Edit Message", isPresented: Binding(
            get: { editingMessage != nil },
            set: { isPresented in
                if !isPresented {
                    editingMessage = nil
                    editText = ""
                }
            }
        )) {
            TextField("Message", text: $editText)
            Button("Save") {
                Task {
                    await saveEdit()
                }
            }
            Button("Cancel", role: .cancel) {
                editingMessage = nil
                editText = ""
            }
        }
        .sheet(item: $forwardingMessage) { message in
            ForwardDialogSheet(currentDialogID: chat.id) { target in
                Task {
                    await forward(message, to: target)
                }
            }
            .environmentObject(authStore)
        }
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        guard let session = authStore.session else {
            return
        }
        do {
            let loaded = try await authStore.api.messages(dialogID: chat.id, session: session)
            messages = loaded
            errorMessage = nil
            await markRead(messages: loaded)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func send() async {
        guard let session = authStore.session else {
            return
        }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }
        draft = ""
        do {
            let sent = try await authStore.api.sendMessage(dialogID: chat.id, text: text, session: session)
            messages.append(sent)
            errorMessage = nil
            await markRead(messages: messages)
        } catch {
            draft = text
            errorMessage = error.localizedDescription
        }
    }

    private func markRead(messages: [HSMessage]) async {
        guard let session = authStore.session, let last = messages.last else {
            return
        }
        _ = try? await authStore.api.markDialogRead(dialogID: chat.id, maxMessageID: last.id, session: session)
    }

    private func beginEdit(_ message: HSMessage) {
        editingMessage = message
        editText = message.text
    }

    private func saveEdit() async {
        guard let session = authStore.session, let message = editingMessage else {
            return
        }
        let text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }
        do {
            let edited = try await authStore.api.editMessage(dialogID: chat.id, messageID: message.id, text: text, session: session)
            replace(messageID: message.id, with: edited)
            editingMessage = nil
            editText = ""
            statusMessage = "Message updated."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ message: HSMessage) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.deleteMessage(dialogID: chat.id, messageID: message.id, session: session)
            messages.removeAll { $0.id == message.id }
            statusMessage = "Message deleted."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func forward(_ message: HSMessage, to target: HSChat) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.forwardMessage(dialogID: chat.id, messageID: message.id, toDialogID: target.id, session: session)
            forwardingMessage = nil
            statusMessage = "Forwarded to \(target.title)."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func react(_ message: HSMessage, reaction: String) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.sendReaction(dialogID: chat.id, messageID: message.id, reaction: reaction, session: session)
            statusMessage = "Reaction sent."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pin(_ message: HSMessage) async {
        guard let session = authStore.session else {
            return
        }
        do {
            let serviceMessage = try await authStore.api.pinSupergroupMessage(dialogID: chat.id, messageID: message.id, session: session)
            messages.append(serviceMessage)
            statusMessage = "Message pinned."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyLink(_ message: HSMessage) async {
        guard let session = authStore.session else {
            return
        }
        do {
            let link = try await authStore.api.supergroupMessageLink(dialogID: chat.id, messageID: message.id, session: session)
            UIPasteboard.general.string = link.link
            statusMessage = "Message link copied."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replace(messageID: Int64, with message: HSMessage) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }
        messages[index] = message
    }
}

private struct MessageBubble: View {
    let message: HSMessage
    let isGroup: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onForward: () -> Void
    let onReact: (String) -> Void
    let onPin: () -> Void
    let onCopyLink: () -> Void

    var body: some View {
        HStack {
            if message.isOutgoing {
                Spacer(minLength: 40)
            }
            VStack(alignment: .leading, spacing: 4) {
                if !message.isOutgoing {
                    Text(message.authorName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if message.kind == "media" {
                    Label(message.text.isEmpty ? "Media" : message.text, systemImage: "photo")
                        .font(.body)
                } else if message.kind == "service" {
                    Label(message.text.isEmpty ? "Service update" : message.text, systemImage: "info.circle")
                        .font(.footnote.weight(.semibold))
                } else {
                    Text(message.text)
                        .font(.body)
                }
            }
            .padding(12)
            .background(message.isOutgoing ? HSTheme.accent : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(message.isOutgoing ? .white : .primary)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.text
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                Button {
                    onReact("👍")
                } label: {
                    Label("React", systemImage: "hand.thumbsup")
                }

                Button {
                    onForward()
                } label: {
                    Label("Forward", systemImage: "arrowshape.turn.up.right")
                }

                if message.isOutgoing && message.kind != "service" {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }

                if isGroup {
                    Button {
                        onPin()
                    } label: {
                        Label("Pin", systemImage: "pin")
                    }
                    Button {
                        onCopyLink()
                    } label: {
                        Label("Copy Link", systemImage: "link")
                    }
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            if !message.isOutgoing {
                Spacer(minLength: 40)
            }
        }
    }
}

private struct ForwardDialogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore

    let currentDialogID: Int64
    let onSelect: (HSChat) -> Void

    @State private var chats: [HSChat] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }
                ForEach(chats.filter { $0.id != currentDialogID }) { chat in
                    Button {
                        onSelect(chat)
                        dismiss()
                    } label: {
                        Label(chat.title, systemImage: chat.isCircle ? "person.3" : "person")
                    }
                }
            }
            .navigationTitle("Forward To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
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
            chats = try await authStore.api.dialogs(session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SupergroupManageView: View {
    @EnvironmentObject private var authStore: AuthStore
    let chat: HSChat

    @State private var group: HSSupergroup?
    @State private var members: [HSSupergroupMember] = []
    @State private var adminEvents: [HSSupergroupAdminLogEvent] = []
    @State private var inviteLink: String?
    @State private var errorMessage: String?
    @State private var statusMessage: String?

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

            Section("Overview") {
                LabeledContent("Title", value: group?.title ?? chat.title)
                LabeledContent("Members", value: String(group?.memberCount ?? members.count))
                if let about = group?.about, !about.isEmpty {
                    Text(about)
                        .foregroundStyle(.secondary)
                }
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
            }

            Section("Group Settings") {
                Button("Enable Slow Mode 10s") {
                    Task {
                        await updateSettings { $0.slowModeSeconds = 10 }
                    }
                }
                Button("Disable Slow Mode") {
                    Task {
                        await updateSettings { $0.slowModeSeconds = 0 }
                    }
                }
                Button("Require Join Requests") {
                    Task {
                        await updateSettings { $0.joinRequest = true }
                    }
                }
                Button("Show Previous History To New Members") {
                    Task {
                        await updateSettings { $0.preHistoryHidden = false }
                    }
                }
                Button("Hide Participant List") {
                    Task {
                        await updateSettings { $0.participantsHidden = true }
                    }
                }
            }

            Section("Members") {
                if members.isEmpty {
                    Text("No members loaded.")
                        .foregroundStyle(.secondary)
                }
                ForEach(members) { member in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(member.displayName)
                                .font(.headline)
                            Spacer()
                            Text(member.role)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        if let username = member.username {
                            Text("@\(username)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                await remove(member)
                            }
                        } label: {
                            Label("Remove", systemImage: "person.crop.circle.badge.minus")
                        }
                        Button {
                            Task {
                                await restrict(member)
                            }
                        } label: {
                            Label("Mute", systemImage: "speaker.slash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            Task {
                                await promote(member)
                            }
                        } label: {
                            Label("Admin", systemImage: "star")
                        }
                        .tint(HSTheme.accent)
                    }
                }
            }

            Section("Admin Log") {
                if adminEvents.isEmpty {
                    Text("No recent admin events.")
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
        }
        .navigationTitle("Group Info")
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
            async let loadedGroup = authStore.api.supergroup(dialogID: chat.id, session: session)
            async let loadedMembers = authStore.api.supergroupMembers(dialogID: chat.id, limit: 100, session: session)
            async let loadedEvents = authStore.api.supergroupAdminLog(dialogID: chat.id, limit: 30, session: session)
            group = try await loadedGroup
            members = try await loadedMembers
            adminEvents = try await loadedEvents
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
            let invite = try await authStore.api.exportSupergroupInvite(dialogID: chat.id, title: "HSgram Invite", session: session)
            inviteLink = invite.link
            UIPasteboard.general.string = invite.link
            statusMessage = "Invite link generated and copied."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateSettings(_ configure: (inout HSSupergroupSettings) -> Void) async {
        guard let session = authStore.session else {
            return
        }
        var settings = HSSupergroupSettings()
        configure(&settings)
        do {
            group = try await authStore.api.updateSupergroupSettings(dialogID: chat.id, settings: settings, session: session)
            statusMessage = "Group settings updated."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func promote(_ member: HSSupergroupMember) async {
        guard let session = authStore.session else {
            return
        }
        var rights = HSSupergroupAdminRights()
        rights.changeInfo = true
        rights.deleteMessages = true
        rights.banUsers = true
        rights.inviteUsers = true
        rights.pinMessages = true
        rights.manageTopics = true
        do {
            _ = try await authStore.api.editSupergroupAdmin(dialogID: chat.id, userID: member.id, rights: rights, rank: "Admin", session: session)
            statusMessage = "\(member.displayName) is now an admin."
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restrict(_ member: HSSupergroupMember) async {
        guard let session = authStore.session else {
            return
        }
        var rights = HSSupergroupBannedRights()
        rights.sendMessages = true
        rights.sendMedia = true
        rights.sendPlain = true
        do {
            _ = try await authStore.api.editSupergroupRestrictions(dialogID: chat.id, userID: member.id, rights: rights, session: session)
            statusMessage = "\(member.displayName) was muted."
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ member: HSSupergroupMember) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.removeSupergroupMember(dialogID: chat.id, userID: member.id, revokeHistory: false, session: session)
            members.removeAll { $0.id == member.id }
            statusMessage = "\(member.displayName) was removed."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
