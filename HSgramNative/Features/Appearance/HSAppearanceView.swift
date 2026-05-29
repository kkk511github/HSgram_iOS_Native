import SwiftUI

struct HSAppearanceView: View {
    @EnvironmentObject private var data: HSMockChatService
    @Environment(\.dismiss) private var dismiss

    private var viewModel: HSAppearanceViewModel {
        HSAppearanceViewModel(
            themeConfig: data.themeConfig,
            users: data.users,
            currentUser: data.currentUser
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HSSimplePageHeader(title: "外观设置", leadingTitle: nil, trailingTitle: nil, onLeading: { dismiss() }, onTrailing: {})
                .padding(.horizontal, 12)

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
                        .padding(14)
                    }

                    sectionTitle("主题色")
                    HSGroupedSettingsCard {
                        HStack(spacing: 14) {
                            ForEach(viewModel.accentChoices, id: \.self) { hex in
                                Button {
                                    data.themeConfig.primaryAccentColor = HSThemeColor(hex)
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 30, height: 30)
                                        .overlay {
                                            if data.themeConfig.primaryAccentColor.hex == hex {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(data.themeConfig.inverseTextColor.color)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                    }

                    sectionTitle("聊天背景")
                    HSGroupedSettingsCard {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                            ForEach(data.themeConfig.availableChatThemes) { theme in
                                Button {
                                    data.setChatTheme(theme)
                                } label: {
                                    ChatThemeChoiceCard(
                                        theme: theme,
                                        isSelected: data.themeConfig.activeChatTheme.id == theme.id
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
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
                        .padding(.vertical, 18)
                    }
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .background(data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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
    @EnvironmentObject private var data: HSMockChatService
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
        .frame(height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(data.themeConfig.glassStrokeColor.color.opacity(0.70), lineWidth: 1 / UIScreen.main.scale)
        }
    }
}

private struct ChatThemeChoiceCard: View {
    @EnvironmentObject private var data: HSMockChatService
    let theme: ChatThemeConfig
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ChatThemeSwatch(theme: theme)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                        .background(data.themeConfig.cardBackgroundColor.color, in: Circle())
                        .padding(5)
                }
            }
            Text(theme.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(data.themeConfig.primaryTextColor.color)
                .lineLimit(1)
            Text(theme.chatWallpaperType.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                .lineLimit(1)
        }
        .padding(8)
        .background(
            isSelected ? data.themeConfig.primaryAccentColor.color.opacity(0.10) : data.themeConfig.groupedBackgroundColor.color.opacity(0.66),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? data.themeConfig.primaryAccentColor.color.opacity(0.50) : data.themeConfig.separatorColor.color.opacity(0.45), lineWidth: 1 / UIScreen.main.scale)
        }
    }
}
