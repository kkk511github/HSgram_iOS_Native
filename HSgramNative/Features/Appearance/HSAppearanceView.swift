import SwiftUI

struct HSAppearanceView: View {
    @EnvironmentObject private var data: HSMockChatService

    private var viewModel: HSAppearanceViewModel {
        HSAppearanceViewModel(themeConfig: data.themeConfig, users: data.users, currentUser: data.currentUser)
    }

    var body: some View {
        List {
            Section("模式") {
                Picker("浅色/深色模式", selection: $data.themeConfig.interfaceMode) {
                    ForEach(ThemeInterfaceMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("聊天气泡") {
                Picker("样式", selection: $data.themeConfig.bubbleStyle) {
                    ForEach(ChatBubbleStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("字体大小") {
                Slider(value: $data.themeConfig.fontScale, in: 0.86...1.22, step: 0.04) { Text("字体大小") }
                HStack {
                    Text("小")
                    Spacer()
                    Text("当前 \(Int(data.themeConfig.fontScale * 100))%")
                    Spacer()
                    Text("大")
                }
                .font(.caption)
                .foregroundStyle(HSPrototypeTheme.secondaryText)
            }
            Section("主题色") {
                HStack(spacing: 14) {
                    ForEach(viewModel.accentChoices, id: \.self) { hex in
                        Button { data.themeConfig.accentHex = hex } label: {
                            Circle().fill(Color(hex: hex)).frame(width: 34, height: 34).overlay {
                                if data.themeConfig.accentHex == hex {
                                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("聊天背景") {
                Picker("背景", selection: $data.themeConfig.chatBackground) {
                    ForEach(ChatBackgroundStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("预览") {
                preview.listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle("外观设置")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(HSPrototypeTheme.background)
    }

    private var preview: some View {
        ZStack {
            HSChatBackgroundView(style: data.themeConfig.chatBackground).frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(spacing: 10) {
                HSMessageBubble(message: viewModel.incomingPreview)
                HSMessageBubble(message: viewModel.outgoingPreview)
            }
            .padding(.vertical, 22)
        }
        .padding(12)
    }
}
