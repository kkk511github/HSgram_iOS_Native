import SwiftUI
import UIKit

struct HSGroupProfileView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService
    @Environment(\.dismiss) private var dismiss
    let groupID: UUID
    @State private var selectedTab = "成员"
    @State private var headerMode: HSGroupProfileHeader.Mode = .large
    @State private var showMore = false

    private var group: HSGroup {
        data.group(id: groupID) ?? data.groups[0]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HSGroupProfileHeader(group: group, mode: headerMode, onBack: { dismiss() }, onEdit: {
                    router.open(.groupSettings(groupID))
                }, onAction: handleHeaderAction)

                VStack(spacing: 16) {
                    HSSettingsRow(
                        icon: "slider.horizontal.3",
                        title: "群组设置",
                        accent: data.themeConfig.warningColor.color,
                        action: { router.open(.groupSettings(groupID)) }
                    )
                    .background(data.themeConfig.cardBackgroundColor.color, in: Capsule())

                    HSCapsuleSegmentedControl(selection: $selectedTab, items: ["成员", "媒体", "文件", "链接"])
                        .frame(maxWidth: 286)

                    if selectedTab == "成员" {
                        membersContent
                    } else {
                        mediaPlaceholder
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 22)
            }
        }
        .background(data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("更多", isPresented: $showMore, titleVisibility: .hidden) {
            Button("更改壁纸") { data.setChatTheme(.blushPattern) }
            Button("启用自动删除") {}
            Button("禁用分享") {}
            Button("清除消息") {}
            Button("屏蔽此用户", role: .destructive) {}
        }
    }

    private var membersContent: some View {
        VStack(spacing: 0) {
            Button {
                router.open(.groupMembers(groupID))
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                        .frame(width: 48, height: 48)
                    Text("添加成员")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)

            ForEach(Array(group.members.prefix(6).enumerated()), id: \.element.id) { index, user in
                HSMemberRow(
                    user: user,
                    role: group.role(for: user),
                    showSeparator: index != min(group.members.count, 6) - 1
                )
            }
        }
        .background(data.themeConfig.cardBackgroundColor.color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var mediaPlaceholder: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(0..<9, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                data.themeConfig.primaryAccentColor.color.opacity(0.20 + Double(index % 3) * 0.08),
                                data.themeConfig.secondaryAccentColor.color.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: selectedTab == "媒体" ? "photo" : selectedTab == "文件" ? "doc.text" : "link")
                            .foregroundStyle(.white.opacity(0.90))
                    }
            }
        }
    }

    private func handleHeaderAction(_ action: String) {
        switch action {
        case "搜索":
            router.open(.media(groupID))
        case "更多":
            showMore = true
        default:
            break
        }
    }
}

struct HSGroupSettingsView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService
    @Environment(\.dismiss) private var dismiss
    let groupID: UUID
    @State private var titleText = ""
    @State private var aboutText = ""
    @State private var forbidPrivateChat = true
    @State private var historyVisible = true

    private var group: HSGroup {
        data.group(id: groupID) ?? data.groups[0]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HSSimplePageHeader(title: "群组设置", leadingTitle: "取消", trailingTitle: "完成", onLeading: { dismiss() }, onTrailing: { dismiss() })

                VStack(spacing: 12) {
                    HSAvatarView(initials: group.avatarInitials, colorHex: group.avatarHex, size: 88, isGroup: true)
                        .opacity(0.32)
                    Text("设置新头像")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                }

                HSGroupedSettingsCard {
                    VStack(spacing: 0) {
                        TextField("群名称", text: $titleText)
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                        Rectangle().fill(data.themeConfig.separatorColor.color).frame(height: 1 / UIScreen.main.scale).padding(.leading, 14)
                        TextField("简介", text: $aboutText, axis: .vertical)
                            .font(.system(size: 17))
                            .lineLimit(2...4)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 58)
                    }
                }

                settingsSection([
                    row("person.3.fill", "群组类型", "私密", 0x3478F6) { router.open(.groupInviteLinks(groupID)) },
                    row("speaker.slash.fill", "禁止私聊", nil, 0x111111, toggle: $forbidPrivateChat),
                    row("bubble.left.fill", "聊天记录", "可见", 0x58C75A, toggle: $historyVisible)
                ])

                settingsSection([
                    row("link", "邀请链接", "\(group.inviteLinks.count)", 0xF5A12A) { router.open(.groupInviteLinks(groupID)) },
                    row("heart.fill", "表情回应", "所有回应", 0xF04B6A) { router.open(.groupReactionSettings(groupID)) },
                    row("paintbrush.fill", "外观", nil, 0xF5A12A) { router.open(.appearance) }
                ])

                settingsSection([
                    row("rectangle.3.group.bubble.left.fill", "圈子工具", nil, 0x111111),
                    row("person.3.fill", "成员", "\(group.memberCount)", 0x48A8F5) { router.open(.groupMembers(groupID)) },
                    row("key.fill", "权限", "10/14", 0x8E8E93) { router.open(.groupPermissions(groupID)) },
                    row("shield.lefthalf.filled", "管理员", "\(group.adminIDs.count)", 0x58C75A),
                    row("minus.circle.fill", "被移除的用户", "\(group.removedUsers.count)", 0xF04B41) { router.open(.groupRemovedUsers(groupID)) },
                    row("eye.fill", "近期操作", nil, 0xF5A12A) { router.open(.groupRecentActions(groupID)) }
                ])
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
        .background(data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            titleText = group.title
            aboutText = group.about
        }
    }

    private func settingsSection(_ rows: [HSSettingsRow]) -> some View {
        HSGroupedSettingsCard {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                row
                if index != rows.count - 1 {
                    Rectangle()
                        .fill(data.themeConfig.separatorColor.color)
                        .frame(height: 1 / UIScreen.main.scale)
                        .padding(.leading, 56)
                }
            }
        }
    }

    private func row(
        _ icon: String,
        _ title: String,
        _ value: String?,
        _ hex: UInt32,
        toggle: Binding<Bool>? = nil,
        action: (() -> Void)? = nil
    ) -> HSSettingsRow {
        HSSettingsRow(
            icon: icon,
            title: title,
            value: value,
            accent: Color(hex: hex),
            showsDisclosure: toggle == nil,
            toggle: toggle,
            action: action
        )
    }
}

struct HSGroupMembersView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService
    @Environment(\.dismiss) private var dismiss
    let groupID: UUID
    @State private var hideMembers = true
    @State private var hideMemberCount = false

    private var group: HSGroup {
        data.group(id: groupID) ?? data.groups[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HSSimplePageHeader(title: "成员", leadingTitle: nil, trailingTitle: "编辑", onLeading: { dismiss() }, onTrailing: {})

                HSGroupedSettingsCard {
                    HSPermissionRow(title: "隐藏成员", isOn: $hideMembers)
                    Rectangle().fill(data.themeConfig.separatorColor.color).frame(height: 1 / UIScreen.main.scale).padding(.leading, 18)
                    HSPermissionRow(title: "隐藏群成员数", isOn: $hideMemberCount)
                }
                Text("禁用以显示本群所有成员")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                    .padding(.leading, 18)
                    .padding(.top, -12)

                HSGroupedSettingsCard {
                    HSSettingsRow(icon: "person.badge.plus", title: "添加成员", accent: data.themeConfig.primaryAccentColor.color, showsDisclosure: false)
                    Rectangle().fill(data.themeConfig.separatorColor.color).frame(height: 1 / UIScreen.main.scale).padding(.leading, 72)
                    HSSettingsRow(icon: "link", title: "通过链接邀请", accent: data.themeConfig.primaryAccentColor.color, showsDisclosure: false) {
                        router.open(.groupInviteLinks(groupID))
                    }
                }

                sectionTitle("此群组内的联系人")
                HSGroupedSettingsCard {
                    ForEach(Array(group.members.enumerated()), id: \.element.id) { index, user in
                        HSMemberRow(
                            user: user,
                            role: group.role(for: user),
                            showSeparator: index != group.members.count - 1
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(data.themeConfig.secondaryTextColor.color)
            .padding(.leading, 18)
            .padding(.bottom, -10)
    }
}

struct HSGroupPermissionsView: View {
    @EnvironmentObject private var data: HSMockChatService
    @Environment(\.dismiss) private var dismiss
    let groupID: UUID

    @State private var canSendMessages = true
    @State private var canSendMedia = true
    @State private var canAddMembers = false
    @State private var canPinMessages = false
    @State private var canChangeInfo = false
    @State private var canEditTags = false
    @State private var slowMode: Double = 0

    private var group: HSGroup {
        data.group(id: groupID) ?? data.groups[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HSSimplePageHeader(title: "权限", leadingTitle: nil, trailingTitle: nil, onLeading: { dismiss() }, onTrailing: {})

                sectionTitle("本群组成员有何权限？")
                HSGroupedSettingsCard {
                    permissionRows
                }

                sectionTitle("慢速模式")
                VStack(spacing: 10) {
                    HSSliderControl(
                        value: $slowMode,
                        bounds: 0...6,
                        step: 1,
                        labels: ["关", "1 小时"],
                        centerTitle: slowModeTitle
                    )
                    Text("选择每个成员必须等多长时间才能发送下一条消息。")
                        .font(.system(size: 16))
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                }

                HSGroupedSettingsCard {
                    HSSettingsRow(icon: "minus.circle.fill", title: "被移除的用户", value: "\(group.removedUsers.count)", accent: data.themeConfig.destructiveColor.color)
                }

                sectionTitle("例外")
                HSGroupedSettingsCard {
                    HSSettingsRow(icon: "person.badge.plus", title: "添加例外", accent: data.themeConfig.primaryAccentColor.color, showsDisclosure: false)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            let p = group.permissions
            canSendMessages = p.canSendMessages
            canSendMedia = p.canSendMedia
            canAddMembers = p.canAddMembers
            canPinMessages = p.canPinMessages
            canChangeInfo = p.canChangeInfo
            canEditTags = p.canEditOwnTags
            slowMode = p.slowModeSeconds
        }
    }

    private var permissionRows: some View {
        VStack(spacing: 0) {
            HSPermissionRow(title: "发送消息", isOn: $canSendMessages)
            divider
            HSPermissionRow(title: "发送媒体文件", detail: "9/9", isOn: $canSendMedia)
            divider
            HSPermissionRow(title: "添加成员", isOn: $canAddMembers)
            divider
            HSPermissionRow(title: "置顶消息", isOn: $canPinMessages)
            divider
            HSPermissionRow(title: "修改群组信息", isOn: $canChangeInfo)
            divider
            HSPermissionRow(title: "编辑自己的标签", isOn: $canEditTags)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(data.themeConfig.separatorColor.color)
            .frame(height: 1 / UIScreen.main.scale)
            .padding(.leading, 18)
    }

    private var slowModeTitle: String {
        switch Int(slowMode) {
        case 0: return "关"
        case 1: return "5 秒"
        case 2: return "10 秒"
        case 3: return "30 秒"
        case 4: return "1 分钟"
        case 5: return "5 分钟"
        default: return "15 分钟"
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(data.themeConfig.secondaryTextColor.color)
            .padding(.leading, 18)
            .padding(.bottom, -10)
    }
}

struct HSInviteLinksView: View {
    @EnvironmentObject private var data: HSMockChatService
    @Environment(\.dismiss) private var dismiss
    let groupID: UUID
    @State private var restrictSaving = false

    private var group: HSGroup {
        data.group(id: groupID) ?? data.groups[0]
    }

    private var invite: GroupInviteLink {
        group.inviteLinks.first ?? GroupInviteLink(
            id: UUID(),
            link: "https://hsgram.cloud/+p...bnVluwxyf5eEVN",
            shortLink: "hsgram.cloud/+p...bnVluwxyf5eEVN",
            joinedCount: 0,
            requiresApproval: false
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HSSimplePageHeader(title: "邀请链接", leadingTitle: "返回", trailingTitle: nil, onLeading: { dismiss() }, onTrailing: {})

                VStack(spacing: 18) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 70, weight: .thin))
                        .foregroundStyle(.white)
                        .frame(height: 86)
                    Text("HSgram 上的任何人都可以通过此链接加入您的群组。")
                        .font(.system(size: 16))
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                sectionTitle("邀请链接")
                HSGroupedSettingsCard {
                    VStack(spacing: 18) {
                        HStack {
                            Text(invite.shortLink)
                                .font(.system(size: 17, weight: .semibold))
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "ellipsis")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(data.themeConfig.mutedTextColor.color, in: Circle())
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(data.themeConfig.groupedBackgroundColor.color, in: Capsule())

                        HStack(spacing: 10) {
                            inviteButton("拷贝") {
                                UIPasteboard.general.string = invite.link
                            }
                            inviteButton("分享") {}
                        }

                        Text(invite.joinedCount == 0 ? "无人加入" : "\(invite.joinedCount) 人加入")
                            .font(.system(size: 17))
                            .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                            .padding(.bottom, 4)
                    }
                    .padding(14)
                }

                sectionTitle("其他链接")
                HSGroupedSettingsCard {
                    HSSettingsRow(icon: "plus", title: "新建链接", accent: data.themeConfig.primaryAccentColor.color, showsDisclosure: false)
                }
                Text("你可以建立限制时间、用户数量或需要付费订阅的附加邀请链接。")
                    .font(.system(size: 14))
                    .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                    .padding(.horizontal, 18)
                    .padding(.top, -18)

                sectionTitle("从该群组转发消息")
                HSGroupedSettingsCard {
                    HSPermissionRow(title: "限制保存内容", isOn: $restrictSaving)
                }
                Text("成员将可以拷贝、保存及转发此群组中的内容。")
                    .font(.system(size: 14))
                    .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                    .padding(.horizontal, 18)
                    .padding(.top, -18)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
        .background(data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func inviteButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(data.themeConfig.primaryAccentColor.color, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(data.themeConfig.secondaryTextColor.color)
            .padding(.leading, 18)
            .padding(.bottom, -18)
    }
}

struct HSReactionSettingsView: View {
    @EnvironmentObject private var data: HSMockChatService
    @Environment(\.dismiss) private var dismiss
    let groupID: UUID
    @State private var enabled = true
    @State private var allowed = ""
    @State private var limit: Double = 11

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HSSimplePageHeader(title: "表情回应", leadingTitle: nil, trailingTitle: nil, onLeading: { dismiss() }, onTrailing: {})

                    HSGroupedSettingsCard {
                        HSPermissionRow(title: "启用表情回应", isOn: $enabled)
                    }
                    Text("您可以添加任意表情包中的表情作为回应。")
                        .font(.system(size: 14))
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                        .padding(.horizontal, 18)
                        .padding(.top, -18)

                    sectionTitle("可选表情回应")
                    HSGroupedSettingsCard {
                        TextField("添加表情回应...", text: $allowed)
                            .font(.system(size: 17))
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                    }
                    Text("您也可以 创建自己的 表情包并使用它们。")
                        .font(.system(size: 14))
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                        .padding(.horizontal, 18)
                        .padding(.top, -18)

                    sectionTitle("每个帖子的回应数量上限")
                    HSSliderControl(
                        value: $limit,
                        bounds: 1...11,
                        step: 1,
                        labels: ["1", "11"],
                        centerTitle: "\(Int(limit)) 反应"
                    )
                    Text("限制可以加入到帖子中的表情回应类型数量，包括已发布的帖子。")
                        .font(.system(size: 14))
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                        .padding(.horizontal, 18)
                        .padding(.top, -18)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 96)
            }

            Button {
                dismiss()
            } label: {
                Text("更新表情回应")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(data.themeConfig.primaryAccentColor.color, in: Capsule())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)
            }
            .buttonStyle(.plain)
        }
        .background(data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(data.themeConfig.secondaryTextColor.color)
            .padding(.leading, 18)
            .padding(.bottom, -18)
    }
}

struct HSRemovedUsersView: View {
    @EnvironmentObject private var data: HSMockChatService
    @Environment(\.dismiss) private var dismiss
    let groupID: UUID

    private var group: HSGroup {
        data.group(id: groupID) ?? data.groups[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HSSimplePageHeader(title: "被移除的用户", leadingTitle: nil, trailingTitle: "编辑", onLeading: { dismiss() }, onTrailing: {})

                HSGroupedSettingsCard {
                    HSSettingsRow(icon: "minus", title: "移除用户", accent: data.themeConfig.primaryAccentColor.color, showsDisclosure: false)
                }
                Text("被管理员移除的用户不能通过邀请链接再次加入群组。")
                    .font(.system(size: 14))
                    .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                    .padding(.horizontal, 18)
                    .padding(.top, -14)

                sectionTitle("被移除的用户")
                HSGroupedSettingsCard {
                    ForEach(Array(group.removedUsers.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 11) {
                            HSAvatarView(initials: item.user.initials, colorHex: item.user.accentHex, size: 48)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.user.displayName)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                                Text("被 \(item.removedBy) 移除")
                                    .font(.system(size: 14))
                                    .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        if index != group.removedUsers.count - 1 {
                            Rectangle()
                                .fill(data.themeConfig.separatorColor.color)
                                .frame(height: 1 / UIScreen.main.scale)
                                .padding(.leading, 70)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
        .background(data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(data.themeConfig.secondaryTextColor.color)
            .padding(.leading, 18)
            .padding(.bottom, -14)
    }
}

struct HSRecentActionsView: View {
    @EnvironmentObject private var data: HSMockChatService
    @Environment(\.dismiss) private var dismiss
    let groupID: UUID

    private var group: HSGroup {
        data.group(id: groupID) ?? data.groups[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text(group.title)
                        .font(.headline.weight(.bold))
                    Text("所有操作")
                        .font(.subheadline)
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                }

                Spacer()
                Color.clear.frame(width: 52, height: 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(data.themeConfig.navigationBarBackground.color)

            ZStack {
                HSChatWallpaperView(theme: .blushPattern)
                VStack(spacing: 18) {
                    Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("暂无近期操作记录")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                    Text("在过去的 48 小时内，群组成员/管理员没有执行任何操作。")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .background(data.themeConfig.activeChatTheme.reactionPillColor.color.opacity(0.66), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 44)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

struct HSSimplePageHeader: View {
    @EnvironmentObject private var data: HSMockChatService
    let title: String
    let leadingTitle: String?
    let trailingTitle: String?
    var onLeading: () -> Void
    var onTrailing: () -> Void

    var body: some View {
        HStack {
            Button(action: onLeading) {
                if let leadingTitle {
                    Text(leadingTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(data.themeConfig.primaryTextColor.color)
                        .padding(.horizontal, 15)
                        .frame(height: 48)
                        .background(.ultraThinMaterial, in: Capsule())
                } else {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(data.themeConfig.primaryTextColor.color)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(data.themeConfig.primaryTextColor.color)

            Spacer()

            if let trailingTitle {
                Button(trailingTitle, action: onTrailing)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                    .padding(.horizontal, 15)
                    .frame(height: 48)
                    .background(.ultraThinMaterial, in: Capsule())
                    .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 48, height: 48)
            }
        }
        .padding(.top, 7)
    }
}
