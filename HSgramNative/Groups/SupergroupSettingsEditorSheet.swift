import SwiftUI

struct SupergroupSettingsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onUpdate: (HSSupergroupSettings) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("慢速模式") {
                    ForEach(SlowModeOption.allCases) { option in
                        Button {
                            onUpdate(.slowMode(option.seconds))
                        } label: {
                            Label(option.title, systemImage: option.systemImage)
                        }
                    }
                }

                Section("谁可以发消息") {
                    Button {
                        onUpdate(.joinToSend(false))
                    } label: {
                        Label("所有人", systemImage: "person.2")
                    }
                    Button {
                        onUpdate(.joinToSend(true))
                    } label: {
                        Label("仅成员", systemImage: "person.2.fill")
                    }
                }

                Section("加入请求") {
                    Button {
                        onUpdate(.joinRequest(false))
                    } label: {
                        Label("允许直接加入", systemImage: "person.badge.plus")
                    }
                    Button {
                        onUpdate(.joinRequest(true))
                    } label: {
                        Label("需要批准", systemImage: "checkmark.shield")
                    }
                }

                Section("历史记录") {
                    Button {
                        onUpdate(.preHistoryHidden(false))
                    } label: {
                        Label("显示之前的历史", systemImage: "clock.arrow.circlepath")
                    }
                    Button {
                        onUpdate(.preHistoryHidden(true))
                    } label: {
                        Label("隐藏之前的历史", systemImage: "eye.slash")
                    }
                }

                Section("成员") {
                    Button {
                        onUpdate(.participantsHidden(false))
                    } label: {
                        Label("显示成员列表", systemImage: "list.bullet")
                    }
                    Button {
                        onUpdate(.participantsHidden(true))
                    } label: {
                        Label("隐藏成员列表", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(HSTheme.grouped)
            .navigationTitle("群设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private enum SlowModeOption: Int, CaseIterable, Identifiable {
    case off
    case tenSeconds
    case thirtySeconds
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
    case oneHour

    var id: Int {
        rawValue
    }

    var seconds: Int {
        switch self {
        case .off:
            return 0
        case .tenSeconds:
            return 10
        case .thirtySeconds:
            return 30
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 5 * 60
        case .fifteenMinutes:
            return 15 * 60
        case .oneHour:
            return 60 * 60
        }
    }

    var title: String {
        switch self {
        case .off:
            return "关闭"
        case .tenSeconds:
            return "10 秒"
        case .thirtySeconds:
            return "30 秒"
        case .oneMinute:
            return "1 分钟"
        case .fiveMinutes:
            return "5 分钟"
        case .fifteenMinutes:
            return "15 分钟"
        case .oneHour:
            return "1 小时"
        }
    }

    var systemImage: String {
        seconds == 0 ? "timer" : "timer.circle"
    }
}

private extension HSSupergroupSettings {
    static func slowMode(_ seconds: Int) -> HSSupergroupSettings {
        var settings = HSSupergroupSettings()
        settings.slowModeSeconds = seconds
        return settings
    }

    static func participantsHidden(_ value: Bool) -> HSSupergroupSettings {
        var settings = HSSupergroupSettings()
        settings.participantsHidden = value
        return settings
    }

    static func preHistoryHidden(_ value: Bool) -> HSSupergroupSettings {
        var settings = HSSupergroupSettings()
        settings.preHistoryHidden = value
        return settings
    }

    static func joinToSend(_ value: Bool) -> HSSupergroupSettings {
        var settings = HSSupergroupSettings()
        settings.joinToSend = value
        return settings
    }

    static func joinRequest(_ value: Bool) -> HSSupergroupSettings {
        var settings = HSSupergroupSettings()
        settings.joinRequest = value
        return settings
    }
}
