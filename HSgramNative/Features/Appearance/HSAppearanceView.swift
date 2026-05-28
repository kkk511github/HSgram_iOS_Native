import SwiftUI

struct HSAppearanceView: View {
    @EnvironmentObject private var data: HSMockChatService
    private let accentChoices: [UInt32] = [0x168BFF, 0x30B7C5, 0x34C759, 0xFF9500, 0xAF52DE]

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
                    ForEach(accentChoices, id: \.self) { hex in
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
                HSMessageBubble(message: Message(conversationID: UUID(), sender: data.users.first ?? data.currentUser, body: "这是一条收到的消息预览。", sentAt: Date().addingTimeInterval(-120), isOutgoing: false))
                HSMessageBubble(message: Message(conversationID: UUID(), sender: data.currentUser, body: "主题色和背景会实时影响界面。", sentAt: Date(), isOutgoing: true, deliveryState: .read, reactions: [MessageReaction(emoji: "👍", count: 1, isSelectedByCurrentUser: true)]))
            }
            .padding(.vertical, 22)
        }
        .padding(12)
    }
}
