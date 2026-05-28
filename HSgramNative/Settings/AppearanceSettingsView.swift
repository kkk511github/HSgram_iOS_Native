import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("HSAppearanceColorScheme") private var colorScheme = "system"
    @AppStorage("HSAppearanceTextSize") private var textSize = "system"

    var body: some View {
        Form {
            Section("颜色主题") {
                Picker("颜色主题", selection: $colorScheme) {
                    Text("跟随系统").tag("system")
                    Text("日间").tag("light")
                    Text("夜间").tag("dark")
                }
                .pickerStyle(.inline)
            }

            Section("文字大小") {
                Picker("文字大小", selection: $textSize) {
                    Text("跟随系统").tag("system")
                    Text("小").tag("small")
                    Text("标准").tag("large")
                    Text("大").tag("xlarge")
                    Text("特大").tag("xxlarge")
                }
                .pickerStyle(.inline)
            }

            Section("聊天预览") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("HSgram")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(HSTheme.accent)
                            Text("新版原生客户端保持一致聊天体验。")
                                .font(.body)
                        }
                        .padding(12)
                        .background(HSTheme.Chat.incomingBubble, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        Spacer(minLength: 48)
                    }

                    HStack {
                        Spacer(minLength: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("You")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(HSTheme.Chat.outgoingSecondary)
                            Text("外观设置会同步到整个 App。")
                                .font(.body)
                        }
                        .padding(12)
                        .foregroundStyle(HSTheme.primaryText)
                        .background(HSTheme.Chat.outgoingBubble, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("外观")
    }
}
