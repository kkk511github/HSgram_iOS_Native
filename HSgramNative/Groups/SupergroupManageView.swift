import SwiftUI
import UIKit

struct SupergroupManageView: View {
    @EnvironmentObject private var authStore: AuthStore
    let chat: HSChat

    @State private var group: HSSupergroup?
    @State private var members: [HSSupergroupMember] = []
    @State private var adminEvents: [HSSupergroupAdminLogEvent] = []
    @State private var editTitle = ""
    @State private var editAbout = ""
    @State private var inviteLink: String?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isSavingInfo = false
    @State private var isShowingInvite = false
    @State private var isShowingInviteOptions = false
    @State private var isShowingSettings = false
    @State private var memberSearchQuery = ""
    @State private var adminRightsMember: HSSupergroupMember?
    @State private var restrictionsMember: HSSupergroupMember?

    private var filteredMembers: [HSSupergroupMember] {
        members.filter { $0.matchesMemberSearch(memberSearchQuery) }
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

            Section("群组") {
                TextField("群名称", text: $editTitle)
                TextField("简介", text: $editAbout, axis: .vertical)
                    .lineLimit(2...4)
                LabeledContent("成员", value: String(group?.memberCount ?? members.count))
                LabeledContent("身份", value: group?.role ?? "member")
                Button(isSavingInfo ? "保存中" : "保存群资料") {
                    Task {
                        await saveInfo()
                    }
                }
                .disabled(isSavingInfo || editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

            Section("群设置") {
                Button {
                    isShowingSettings = true
                } label: {
                    Label("编辑群设置", systemImage: "slider.horizontal.3")
                }
                LabeledContent("待处理请求", value: String(group?.pendingRequests ?? 0))
            }

            Section("成员") {
                if members.isEmpty {
                    Text("暂无成员。")
                        .foregroundStyle(HSTheme.secondaryText)
                } else if filteredMembers.isEmpty {
                    Label("没有匹配的成员", systemImage: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(HSTheme.secondaryText)
                }
                ForEach(filteredMembers) { member in
                    HStack(spacing: 12) {
                        HSClassicAvatar(title: member.displayName, icon: "person.fill", tint: HSTheme.accent, size: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(member.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(HSTheme.primaryText)
                                Spacer()
                                Text(member.role)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(HSTheme.secondaryText)
                            }
                            if let username = member.username {
                                Text("@\(username)")
                                    .font(.footnote)
                                    .foregroundStyle(HSTheme.secondaryText)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                await remove(member)
                            }
                        } label: {
                            Label("移除", systemImage: "person.crop.circle.badge.minus")
                        }
                        Button(role: .destructive) {
                            Task {
                                await deleteHistory(member)
                            }
                        } label: {
                            Label("清历史", systemImage: "trash")
                        }
                        Button {
                            restrictionsMember = member
                        } label: {
                            Label("限制", systemImage: "hand.raised.slash")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            adminRightsMember = member
                        } label: {
                            Label("管理员", systemImage: "star")
                        }
                        .tint(HSTheme.accent)
                    }
                }
            }

            Section("管理日志") {
                if adminEvents.isEmpty {
                    Text("暂无管理日志。")
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
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("群信息")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $memberSearchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索成员")
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
        .sheet(isPresented: $isShowingInvite) {
            ContactInvitePickerSheet(title: "邀请联系人", existingIDs: Set(members.map(\.id))) { userIDs in
                Task {
                    await invite(userIDs)
                }
            }
            .environmentObject(authStore)
        }
        .sheet(isPresented: $isShowingInviteOptions) {
            InviteLinkOptionsSheet(defaultTitle: "HSgram 邀请") { title, expireDate, usageLimit, requestNeeded in
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
        .sheet(isPresented: $isShowingSettings) {
            SupergroupSettingsEditorSheet { settings in
                Task {
                    await updateSettings(settings)
                }
            }
        }
        .sheet(item: $adminRightsMember) { member in
            AdminRightsEditorSheet(member: member, mode: .supergroup) { rights, rank in
                Task {
                    await saveAdminRights(member, rights: rights, rank: rank)
                }
            }
        }
        .sheet(item: $restrictionsMember) { member in
            MemberRestrictionsEditorSheet(member: member) { rights in
                Task {
                    await saveRestrictions(member, rights: rights)
                }
            }
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
            let currentGroup = try await loadedGroup
            group = currentGroup
            editTitle = currentGroup.title
            editAbout = currentGroup.about
            members = try await loadedMembers
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
            errorMessage = "请输入群名称。"
            return
        }
        isSavingInfo = true
        defer { isSavingInfo = false }
        do {
            group = try await authStore.api.updateSupergroup(
                dialogID: chat.id,
                title: title,
                about: editAbout.trimmingCharacters(in: .whitespacesAndNewlines),
                session: session
            )
            statusMessage = "群资料已更新。"
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
            let invite = try await authStore.api.exportSupergroupInvite(
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
            _ = try await authStore.api.inviteSupergroupMembers(dialogID: chat.id, userIDs: userIDs, session: session)
            statusMessage = "已邀请联系人。"
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateSettings(_ settings: HSSupergroupSettings) async {
        guard let session = authStore.session else {
            return
        }
        do {
            group = try await authStore.api.updateSupergroupSettings(dialogID: chat.id, settings: settings, session: session)
            statusMessage = "群设置已更新。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveAdminRights(_ member: HSSupergroupMember, rights: HSSupergroupAdminRights, rank: String?) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.editSupergroupAdmin(dialogID: chat.id, userID: member.id, rights: rights, rank: rank, session: session)
            statusMessage = "\(member.displayName) 的管理员权限已更新。"
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveRestrictions(_ member: HSSupergroupMember, rights: HSSupergroupBannedRights) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.editSupergroupRestrictions(dialogID: chat.id, userID: member.id, rights: rights, session: session)
            statusMessage = "\(member.displayName) 的限制已更新。"
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteHistory(_ member: HSSupergroupMember) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.deleteSupergroupMemberHistory(dialogID: chat.id, userID: member.id, session: session)
            statusMessage = "\(member.displayName) 的历史消息已删除。"
            errorMessage = nil
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
            statusMessage = "\(member.displayName) 已移除。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
