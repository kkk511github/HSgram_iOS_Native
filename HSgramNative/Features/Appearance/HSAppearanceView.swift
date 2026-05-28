import SwiftUI

struct HSAppearanceView: View {
    @EnvironmentObject private var data: HSMockChatService

    private var viewModel: HSAppearanceViewModel {
        HSAppearanceViewModel(
            themeConfig: data.themeConfig,
            users: data.users,
            currentUser: data.currentUser
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                sectionTitle("模式")
                HSGroupedSettingsCard {
                    Picker("浅色/深色模式", selection: $data.themeConfig.interfaceMode) {
                        ForEach(ThemeInterfaceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(16)
                }

                sectionTitle("主题色")
                HSGroupedSettingsCard {
                    HStack(spacing: 16) {
                        ForEach(viewModel.accentChoices, id: \.self) { hex in
                            Button {
                                data.themeConfig.primaryAccentColor = HSThemeColor(hex)
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 38, height: 38)
                                    .overlay {
                                        if data.themeConfig.primaryAccentColor.hex == hex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                }

                sectionTitle("聊天背景")
                HSGroupedSettingsCard {
                    ForEach(data.themeConfig.availableChatThemes) { theme in
                        Button {
                            data.setChatTheme(theme)
                        } label: {
                            HStack(spacing: 14) {
                                ChatThemeSwatch(theme: theme)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(theme.name)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(data.themeConfig.primaryTextColor.color)
                                    Text(theme.chatWallpaperType.label)
                                        .font(.caption)
                                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                                }
                                Spacer()
                                if data.themeConfig.activeChatTheme.id == theme.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)
                        if theme.id != data.themeConfig.availableChatThemes.last?.id {
                            Rectangle()
                                .fill(data.themeConfig.separatorColor.color)
                                .frame(height: 1 / UIScreen.main.scale)
                                .padding(.leading, 78)
                        }
                    }
                }

                sectionTitle("字体大小")
                HSSliderControl(
                    value: $data.themeConfig.fontScale,
                    bounds: 0.86...1.22,
                    step: 0.04,
                    labels: ["小", "大"],
                    centerTitle: "\(Int(data.themeConfig.fontScale * 100))%"
                )

                sectionTitle("预览")
                ZStack {
                    HSChatWallpaperView(theme: data.themeConfig.activeChatTheme)
                    VStack(spacing: 10) {
                        HSMessageBubble(message: viewModel.incomingPreview, showAuthor: true)
                        HSMessageBubble(message: viewModel.outgoingPreview)
                    }
                    .padding(.vertical, 22)
                }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea())
        .navigationTitle("外观设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(data.themeConfig.secondaryTextColor.color)
            .padding(.leading, 18)
            .padding(.bottom, -10)
    }
}

private struct ChatThemeSwatch: View {
    let theme: ChatThemeConfig

    var body: some View {
        ZStack {
            HSChatWallpaperView(theme: theme)
            VStack(spacing: 4) {
                Capsule()
                    .fill(theme.incomingBubbleColor.color)
                    .frame(width: 36, height: 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Capsule()
                    .fill(theme.outgoingBubbleColor.color)
                    .frame(width: 42, height: 12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(8)
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
