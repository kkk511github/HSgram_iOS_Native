import SwiftUI
import UIKit

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
    @State private var isShowingInviteOptions = false
    @State private var subscriberSearchQuery = ""
    @State private var adminRightsSubscriber: HSSupergroupMember?

    private var filteredSubscribers: [HSSupergroupMember] {
        subscribers.filter { $0.matchesMemberSearch(subscriberSearchQuery) }
    }

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

            Section("频道") {
                TextField("频道名称", text: $editTitle)
                TextField("简介", text: $editAbout, axis: .vertical)
                    .lineLimit(2...4)
                LabeledContent("订阅者", value: String(channel?.memberCount ?? subscribers.count))
                LabeledContent("身份", value: channel?.role ?? "member")
                Button(isSaving ? "保存中" : "保存频道资料") {
                    Task {
                        await saveInfo()
                    }
                }
                .disabled(isSaving || editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("邀请链接") {
                if let inviteLink {
                    Text(inviteLink)
                        .font(.footnote)
                        .textSelection(.enabled)
                    Button("复制邀请链接") {
                        UIPasteboard.general.string = inviteLink
                        statusMessage = "邀请链接已复制。"
                    }
                }
                Button {
                    isShowingInviteOptions = true
                } label: {
                    Label("创建邀请链接", systemImage: "link.badge.plus")
                }
                Button("邀请联系人") {
                    isShowingInvite = true
                }
            }

            Section("订阅者") {
                if subscribers.isEmpty {
                    Text("暂无订阅者。")
                        .foregroundStyle(HSTheme.secondaryText)
                } else if filteredSubscribers.isEmpty {
                    Label("没有匹配的订阅者", systemImage: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(HSTheme.secondaryText)
                }
                ForEach(filteredSubscribers) { subscriber in
                    HStack(spacing: 12) {
                        HSClassicAvatar(title: subscriber.displayName, icon: "person.fill", tint: HSTheme.accent, size: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(subscriber.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(HSTheme.primaryText)
                                Spacer()
                                Text(subscriber.role)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(HSTheme.secondaryText)
                            }
                            if let username = subscriber.username {
                                Text("@\(username)")
                                    .font(.footnote)
                                    .foregroundStyle(HSTheme.secondaryText)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !subscriber.isSelf {
                            Button(role: .destructive) {
                                Task {
                                    await remove(subscriber)
                                }
                            } label: {
                                Label("移除", systemImage: "person.crop.circle.badge.minus")
                            }
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if !subscriber.isSelf {
                            Button {
                                adminRightsSubscriber = subscriber
                            } label: {
                                Label("管理员", systemImage: "star")
                            }
                            .tint(HSTheme.accent)
                        }
                    }
                }
            }

            Section("管理日志") {
                if adminEvents.isEmpty {
                    Text("暂无频道事件。")
                        .foregroundStyle(HSTheme.secondaryText)
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
                    Text("退出频道")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("频道信息")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $subscriberSearchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索订阅者")
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
            ContactInvitePickerSheet(title: "邀请联系人", existingIDs: Set(subscribers.map(\.id))) { userIDs in
                Task {
                    await invite(userIDs)
                }
            }
            .environmentObject(authStore)
        }
        .sheet(isPresented: $isShowingInviteOptions) {
            InviteLinkOptionsSheet(defaultTitle: "HSgram 频道") { title, expireDate, usageLimit, requestNeeded in
                Task {
                    await generateInvite(
                        title: title,
                        expireDate: expireDate,
                        usageLimit: usageLimit,
                        requestNeeded: requestNeeded
                    )
                }
            }
        }
        .sheet(item: $adminRightsSubscriber) { subscriber in
            AdminRightsEditorSheet(member: subscriber, mode: .channel) { rights, rank in
                Task {
                    await saveAdminRights(subscriber, rights: rights, rank: rank)
                }
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
            errorMessage = "请输入频道名称。"
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
            statusMessage = "频道资料已更新。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generateInvite(title: String?, expireDate: Int?, usageLimit: Int?, requestNeeded: Bool) async {
        guard let session = authStore.session else {
            return
        }
        do {
            let invite = try await authStore.api.exportChannelInvite(
                dialogID: chat.id,
                title: title,
                expireDate: expireDate,
                usageLimit: usageLimit,
                requestNeeded: requestNeeded,
                session: session
            )
            inviteLink = invite.link
            UIPasteboard.general.string = invite.link
            statusMessage = "邀请链接已创建并复制。"
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
            statusMessage = "已邀请联系人。"
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
            statusMessage = "\(subscriber.displayName) 已移除。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveAdminRights(_ subscriber: HSSupergroupMember, rights: HSSupergroupAdminRights, rank: String?) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.editChannelAdmin(dialogID: chat.id, userID: subscriber.id, rights: rights, rank: rank, session: session)
            statusMessage = "\(subscriber.displayName) 的管理员权限已更新。"
            errorMessage = nil
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
            statusMessage = "已退出频道。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
