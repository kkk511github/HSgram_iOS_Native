import SwiftUI

struct MemberRestrictionsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let member: HSSupergroupMember
    let onSave: (HSSupergroupBannedRights) -> Void

    @State private var rights: HSSupergroupBannedRights
    @State private var duration: RestrictionDuration

    init(
        member: HSSupergroupMember,
        initialRights: HSSupergroupBannedRights = HSSupergroupBannedRights.muteDefaults(),
        onSave: @escaping (HSSupergroupBannedRights) -> Void
    ) {
        self.member = member
        self.onSave = onSave
        _rights = State(initialValue: initialRights)
        _duration = State(initialValue: RestrictionDuration.matching(untilDate: initialRights.untilDate))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("成员") {
                    LabeledContent("名称", value: member.displayName)
                    if let username = member.username {
                        LabeledContent("用户名", value: "@\(username)")
                    }
                    Picker("时长", selection: $duration) {
                        ForEach(RestrictionDuration.allCases) { duration in
                            Text(duration.title).tag(duration)
                        }
                    }
                }

                Section("消息") {
                    Toggle("读取消息", isOn: allowedBinding(\.viewMessages))
                    Toggle("发送文字", isOn: textAllowedBinding)
                    Toggle("发送媒体", isOn: mediaAllowedBinding)
                    Toggle("嵌入链接", isOn: allowedBinding(\.embedLinks))
                    Toggle("发送投票", isOn: allowedBinding(\.sendPolls))
                }

                Section("媒体类型") {
                    Toggle("图片", isOn: allowedBinding(\.sendPhotos))
                    Toggle("视频", isOn: allowedBinding(\.sendVideos))
                    Toggle("圆形视频", isOn: allowedBinding(\.sendRoundvideos))
                    Toggle("音频", isOn: allowedBinding(\.sendAudios))
                    Toggle("语音消息", isOn: allowedBinding(\.sendVoices))
                    Toggle("文件", isOn: allowedBinding(\.sendDocs))
                    Toggle("贴纸", isOn: allowedBinding(\.sendStickers))
                    Toggle("GIFs", isOn: allowedBinding(\.sendGifs))
                    Toggle("游戏", isOn: allowedBinding(\.sendGames))
                    Toggle("内联机器人", isOn: allowedBinding(\.sendInline))
                }

                Section("群组") {
                    Toggle("更改资料", isOn: allowedBinding(\.changeInfo))
                    Toggle("邀请用户", isOn: allowedBinding(\.inviteUsers))
                    Toggle("置顶消息", isOn: allowedBinding(\.pinMessages))
                    Toggle("管理话题", isOn: allowedBinding(\.manageTopics))
                    Toggle("编辑头衔", isOn: allowedBinding(\.editRank))
                }

                Section {
                    Button(role: .destructive) {
                        rights = HSSupergroupBannedRights()
                        duration = .forever
                    } label: {
                        Label("清除限制", systemImage: "checkmark.shield")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(HSTheme.grouped)
            .navigationTitle("权限")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var updatedRights = rights
                        updatedRights.untilDate = duration.untilDate()
                        onSave(updatedRights)
                        dismiss()
                    }
                }
            }
        }
    }

    private var textAllowedBinding: Binding<Bool> {
        Binding {
            !rights.sendMessages && !rights.sendPlain
        } set: { isAllowed in
            rights.sendMessages = !isAllowed
            rights.sendPlain = !isAllowed
        }
    }

    private var mediaAllowedBinding: Binding<Bool> {
        Binding {
            mediaRestrictionKeyPaths.allSatisfy { !rights[keyPath: $0] }
        } set: { isAllowed in
            for keyPath in mediaRestrictionKeyPaths {
                rights[keyPath: keyPath] = !isAllowed
            }
        }
    }

    private func allowedBinding(_ keyPath: WritableKeyPath<HSSupergroupBannedRights, Bool>) -> Binding<Bool> {
        Binding {
            !rights[keyPath: keyPath]
        } set: { isAllowed in
            rights[keyPath: keyPath] = !isAllowed
        }
    }

    private var mediaRestrictionKeyPaths: [WritableKeyPath<HSSupergroupBannedRights, Bool>] {
        [
            \.sendMedia,
            \.sendPhotos,
            \.sendVideos,
            \.sendRoundvideos,
            \.sendAudios,
            \.sendVoices,
            \.sendDocs,
            \.sendStickers,
            \.sendGifs,
            \.sendGames,
            \.sendInline
        ]
    }
}

private enum RestrictionDuration: String, CaseIterable, Identifiable {
    case forever
    case oneHour
    case oneDay
    case oneWeek
    case oneMonth

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .forever:
            return "永久"
        case .oneHour:
            return "1 小时"
        case .oneDay:
            return "1 天"
        case .oneWeek:
            return "1 周"
        case .oneMonth:
            return "1 个月"
        }
    }

    func untilDate(now: Date = Date()) -> Int {
        switch self {
        case .forever:
            return 0
        case .oneHour:
            return Int(now.addingTimeInterval(60 * 60).timeIntervalSince1970)
        case .oneDay:
            return Int(now.addingTimeInterval(24 * 60 * 60).timeIntervalSince1970)
        case .oneWeek:
            return Int(now.addingTimeInterval(7 * 24 * 60 * 60).timeIntervalSince1970)
        case .oneMonth:
            return Int(now.addingTimeInterval(30 * 24 * 60 * 60).timeIntervalSince1970)
        }
    }

    static func matching(untilDate: Int) -> RestrictionDuration {
        guard untilDate > 0 else {
            return .forever
        }
        let remaining = untilDate - Int(Date().timeIntervalSince1970)
        switch remaining {
        case ..<(2 * 60 * 60):
            return .oneHour
        case ..<(2 * 24 * 60 * 60):
            return .oneDay
        case ..<(14 * 24 * 60 * 60):
            return .oneWeek
        default:
            return .oneMonth
        }
    }
}

private extension HSSupergroupBannedRights {
    static func muteDefaults() -> HSSupergroupBannedRights {
        var rights = HSSupergroupBannedRights()
        rights.sendMessages = true
        rights.sendPlain = true
        rights.sendMedia = true
        return rights
    }
}
