import SwiftUI

struct InviteLinkOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let defaultTitle: String
    let onCreate: (String?, Int?, Int?, Bool) -> Void

    @State private var title: String
    @State private var expiration: InviteLinkExpiration = .never
    @State private var usageLimit: InviteLinkUsageLimit = .unlimited
    @State private var requestNeeded = false

    init(defaultTitle: String, onCreate: @escaping (String?, Int?, Int?, Bool) -> Void) {
        self.defaultTitle = defaultTitle
        self.onCreate = onCreate
        _title = State(initialValue: defaultTitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("邀请链接") {
                    TextField("名称", text: $title)
                        .textInputAutocapitalization(.words)
                }

                Section("有效期") {
                    Picker("过期时间", selection: $expiration) {
                        ForEach(InviteLinkExpiration.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section("使用次数") {
                    Picker("限制", selection: $usageLimit) {
                        ForEach(InviteLinkUsageLimit.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section("审核") {
                    Toggle("需要管理员批准", isOn: $requestNeeded)
                }
            }
            .scrollContentBackground(.hidden)
            .background(HSTheme.grouped)
            .navigationTitle("创建邀请链接")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        onCreate(
                            trimmedTitle.isEmpty ? nil : trimmedTitle,
                            expiration.expireDate(),
                            usageLimit.value,
                            requestNeeded
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

private enum InviteLinkExpiration: Int, CaseIterable, Identifiable {
    case never
    case oneHour
    case oneDay
    case oneWeek
    case oneMonth

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .never:
            return "永不过期"
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

    func expireDate(now: Date = Date()) -> Int? {
        switch self {
        case .never:
            return nil
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
}

private enum InviteLinkUsageLimit: Int, CaseIterable, Identifiable {
    case unlimited
    case one
    case ten
    case oneHundred

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .unlimited:
            return "无限制"
        case .one:
            return "1 次"
        case .ten:
            return "10 次"
        case .oneHundred:
            return "100 次"
        }
    }

    var value: Int? {
        switch self {
        case .unlimited:
            return nil
        case .one:
            return 1
        case .ten:
            return 10
        case .oneHundred:
            return 100
        }
    }
}
