import SwiftUI

struct ContactProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore

    @State private var contact: HSContact
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var activeAction: ProfileAction?

    private let onChanged: (HSContact?) -> Void

    init(contact: HSContact, onChanged: @escaping (HSContact?) -> Void = { _ in }) {
        _contact = State(initialValue: contact)
        self.onChanged = onChanged
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    HSClassicAvatar(title: contact.displayName, icon: "person.fill", tint: HSTheme.accent, size: 96)

                    VStack(spacing: 4) {
                        Text(contact.displayName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(HSTheme.primaryText)
                            .multilineTextAlignment(.center)
                        Text(contact.username.map { "@\($0)" } ?? statusTitle)
                            .font(.subheadline)
                            .foregroundStyle(HSTheme.secondaryText)
                    }

                    statusBadge
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            .listRowBackground(Color.clear)

            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }
            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HSTheme.trust)
            }

            if canMessage {
                Section {
                    NavigationLink {
                        ChatThreadView(chat: privateChat)
                    } label: {
                        Label("发消息", systemImage: "message")
                    }
                }
            }

            Section("资料") {
                LabeledContent("User ID", value: "\(contact.id)")
                if let username = contact.username {
                    LabeledContent("用户名", value: "@\(username)")
                }
                LabeledContent("状态", value: statusTitle)
            }

            Section("联系人") {
                if canRequest {
                    Button {
                        Task {
                            await request()
                        }
                    } label: {
                        actionLabel("添加联系人", systemImage: "person.badge.plus", action: .request)
                    }
                    .disabled(activeAction != nil)
                }

                if isIncomingRequest {
                    Button {
                        Task {
                            await accept()
                        }
                    } label: {
                        actionLabel("接受请求", systemImage: "checkmark.circle", action: .accept)
                    }
                    .disabled(activeAction != nil)

                    Button(role: .destructive) {
                        Task {
                            await decline()
                        }
                    } label: {
                        actionLabel("拒绝请求", systemImage: "xmark.circle", action: .decline)
                    }
                    .disabled(activeAction != nil)
                }

                if canRemove {
                    Button(role: .destructive) {
                        Task {
                            await delete()
                        }
                    } label: {
                        actionLabel("删除联系人", systemImage: "trash", action: .delete)
                    }
                    .disabled(activeAction != nil)
                }

                if isBlocked {
                    Button {
                        Task {
                            await unblock()
                        }
                    } label: {
                        actionLabel("解除屏蔽", systemImage: "hand.raised.slash", action: .unblock)
                    }
                    .disabled(activeAction != nil)
                } else if canBlock {
                    Button(role: .destructive) {
                        Task {
                            await block()
                        }
                    } label: {
                        actionLabel("屏蔽", systemImage: "hand.raised", action: .block)
                    }
                    .disabled(activeAction != nil)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("资料")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch contact.status {
        case "mutual":
            Text("互相关注")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HSTheme.trust)
        case "contact", "accepted":
            Text("联系人")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HSTheme.trust)
        case "pending_received", "pending":
            Text("待处理")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HSTheme.circle)
        case "pending_sent":
            Text("请求已发送")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HSTheme.circle)
        case "blocked":
            Text("已屏蔽")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HSTheme.warning)
        default:
            EmptyView()
        }
    }

    private var statusTitle: String {
        switch contact.status {
        case "mutual":
            return "互相关注"
        case "contact", "accepted":
            return "联系人"
        case "pending_received", "pending":
            return "待处理请求"
        case "pending_sent":
            return "请求已发送"
        case "blocked":
            return "已屏蔽"
        case "global", "none":
            return "未添加"
        default:
            return contact.status
        }
    }

    private var isIncomingRequest: Bool {
        contact.status == "pending_received" || contact.status == "pending"
    }

    private var isBlocked: Bool {
        contact.status == "blocked"
    }

    private var isContactLike: Bool {
        contact.status == "contact" || contact.status == "mutual" || contact.status == "accepted"
    }

    private var canMessage: Bool {
        !isBlocked && contact.status != "pending_received" && contact.status != "pending"
    }

    private var canRequest: Bool {
        contact.status == "global" || contact.status == "none"
    }

    private var canRemove: Bool {
        isContactLike || contact.status == "pending_sent" || isBlocked
    }

    private var canBlock: Bool {
        !canRequest && !isBlocked
    }

    private var privateChat: HSChat {
        HSChat(
            id: contact.id,
            title: contact.displayName,
            subtitle: contact.username.map { "@\($0)" } ?? statusTitle,
            unreadCount: 0,
            isCircle: false,
            peerKind: .user,
            isContact: isContactLike,
            updatedAt: nil
        )
    }

    private func actionLabel(_ title: String, systemImage: String, action: ProfileAction) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            if activeAction == action {
                Spacer()
                ProgressView()
            }
        }
    }

    private func request() async {
        guard let session = authStore.session else {
            return
        }
        await run(.request) {
            _ = try await authStore.api.addContact(
                userID: contact.id,
                firstName: firstName(from: contact.displayName),
                lastName: lastName(from: contact.displayName),
                session: session
            )
            update(HSContact(id: contact.id, displayName: contact.displayName, username: contact.username, status: "contact"), message: "\(contact.displayName) 已添加到联系人。")
        }
    }

    private func accept() async {
        guard let session = authStore.session else {
            return
        }
        await run(.accept) {
            _ = try await authStore.api.acceptContact(userID: contact.id, session: session)
            update(HSContact(id: contact.id, displayName: contact.displayName, username: contact.username, status: "contact"), message: "\(contact.displayName) 已添加到联系人。")
        }
    }

    private func decline() async {
        guard let session = authStore.session else {
            return
        }
        await run(.decline) {
            _ = try await authStore.api.declineContact(userID: contact.id, session: session)
            onChanged(nil)
            statusMessage = "已拒绝联系人请求。"
            errorMessage = nil
            dismiss()
        }
    }

    private func delete() async {
        guard let session = authStore.session else {
            return
        }
        await run(.delete) {
            _ = try await authStore.api.deleteContact(userID: contact.id, session: session)
            onChanged(nil)
            statusMessage = "\(contact.displayName) 已移除。"
            errorMessage = nil
            dismiss()
        }
    }

    private func block() async {
        guard let session = authStore.session else {
            return
        }
        await run(.block) {
            _ = try await authStore.api.blockContact(userID: contact.id, session: session)
            update(HSContact(id: contact.id, displayName: contact.displayName, username: contact.username, status: "blocked"), message: "\(contact.displayName) 已屏蔽。")
        }
    }

    private func unblock() async {
        guard let session = authStore.session else {
            return
        }
        await run(.unblock) {
            _ = try await authStore.api.unblockContact(userID: contact.id, session: session)
            update(HSContact(id: contact.id, displayName: contact.displayName, username: contact.username, status: "contact"), message: "\(contact.displayName) 已解除屏蔽。")
        }
    }

    private func run(_ action: ProfileAction, operation: () async throws -> Void) async {
        activeAction = action
        defer { activeAction = nil }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func update(_ updated: HSContact, message: String) {
        contact = updated
        onChanged(updated)
        statusMessage = message
        errorMessage = nil
    }

    private func firstName(from displayName: String) -> String {
        let parts = displayName.split(separator: " ", maxSplits: 1).map(String.init)
        return parts.first ?? displayName
    }

    private func lastName(from displayName: String) -> String {
        let parts = displayName.split(separator: " ", maxSplits: 1).map(String.init)
        return parts.count > 1 ? parts[1] : ""
    }

    private enum ProfileAction {
        case request
        case accept
        case decline
        case delete
        case block
        case unblock
    }
}
