import SwiftUI

enum AdminRightsEditorMode {
    case supergroup
    case channel
}

struct AdminRightsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let member: HSSupergroupMember
    let mode: AdminRightsEditorMode
    let onSave: (HSSupergroupAdminRights, String?) -> Void

    @State private var rights: HSSupergroupAdminRights
    @State private var rank: String

    init(
        member: HSSupergroupMember,
        mode: AdminRightsEditorMode,
        initialRights: HSSupergroupAdminRights? = nil,
        initialRank: String? = nil,
        onSave: @escaping (HSSupergroupAdminRights, String?) -> Void
    ) {
        self.member = member
        self.mode = mode
        self.onSave = onSave
        _rights = State(initialValue: initialRights ?? HSSupergroupAdminRights.defaultRights(for: mode))
        _rank = State(initialValue: initialRank ?? member.rank ?? "Admin")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("管理员") {
                    LabeledContent("成员", value: member.displayName)
                    if let username = member.username {
                        LabeledContent("用户名", value: "@\(username)")
                    }
                    TextField("头衔", text: $rank)
                        .textInputAutocapitalization(.words)
                }

                Section("权限") {
                    Toggle("更改资料", isOn: $rights.changeInfo)
                    if mode == .channel {
                        Toggle("发布消息", isOn: $rights.postMessages)
                        Toggle("编辑消息", isOn: $rights.editMessages)
                    }
                    Toggle("删除消息", isOn: $rights.deleteMessages)
                    if mode == .supergroup {
                        Toggle("封禁用户", isOn: $rights.banUsers)
                    }
                    Toggle("邀请用户", isOn: $rights.inviteUsers)
                    if mode == .supergroup {
                        Toggle("置顶消息", isOn: $rights.pinMessages)
                        Toggle("管理话题", isOn: $rights.manageTopics)
                    }
                    Toggle("添加管理员", isOn: $rights.addAdmins)
                    Toggle("匿名管理员", isOn: $rights.anonymous)
                    Toggle("管理通话", isOn: $rights.manageCall)
                    Toggle("管理头衔", isOn: $rights.manageRanks)
                }

                if mode == .channel {
                    Section("故事") {
                        Toggle("发布故事", isOn: $rights.postStories)
                        Toggle("编辑故事", isOn: $rights.editStories)
                        Toggle("删除故事", isOn: $rights.deleteStories)
                        Toggle("管理私信", isOn: $rights.manageDirectMessages)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        rights = HSSupergroupAdminRights()
                        rank = ""
                    } label: {
                        Label("清除管理员权限", systemImage: "person.crop.circle.badge.xmark")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(HSTheme.grouped)
            .navigationTitle("管理员权限")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let trimmedRank = rank.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(rights, trimmedRank.isEmpty ? nil : trimmedRank)
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension HSSupergroupAdminRights {
    static func defaultRights(for mode: AdminRightsEditorMode) -> HSSupergroupAdminRights {
        var rights = HSSupergroupAdminRights()
        rights.changeInfo = true
        rights.deleteMessages = true
        rights.inviteUsers = true
        rights.addAdmins = true
        switch mode {
        case .supergroup:
            rights.banUsers = true
            rights.pinMessages = true
            rights.manageTopics = true
        case .channel:
            rights.postMessages = true
            rights.editMessages = true
        }
        return rights
    }
}
