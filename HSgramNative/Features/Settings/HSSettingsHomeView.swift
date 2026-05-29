import SwiftUI

struct HSSettingsHomeView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService

    private var viewModel: HSSettingsHomeViewModel {
        HSSettingsHomeViewModel(currentUser: data.currentUser, settingsItems: data.settingsItems)
    }

    var body: some View {
        VStack(spacing: 0) {
            HSNavigationBar(title: "设置")
            ScrollView {
                VStack(spacing: 18) {
                    profileCard.padding(.horizontal, 16).padding(.top, 16)
                    VStack(spacing: 0) {
                        ForEach(viewModel.settingsItems) { item in
                            Button {
                                item.destination == .appearance ? router.open(.appearance) : router.open(.settingsDetail(item.destination))
                            } label: {
                                HSSettingsRow(item: item)
                            }
                            .buttonStyle(.plain)
                            if item.id != viewModel.settingsItems.last?.id {
                                Rectangle()
                                    .fill(data.themeConfig.separatorColor.color.opacity(0.55))
                                    .frame(height: 1 / UIScreen.main.scale)
                                    .padding(.leading, 62)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    Button(role: .destructive) { router.signOut() } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(data.themeConfig.destructiveColor.color)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(data.themeConfig.cardBackgroundColor.color, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .padding(.bottom, HSLayoutMetrics.rootTabBarClearance)
            }
            .background(data.themeConfig.groupedBackgroundColor.color)
        }
        .background(data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea())
    }

    private var profileCard: some View {
        Button { router.open(.profile(viewModel.currentUser.id)) } label: {
            HStack(spacing: 14) {
                HSAvatarView(initials: viewModel.currentUser.initials, colorHex: viewModel.currentUser.accentHex, size: 58, isOnline: true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.currentUser.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(data.themeConfig.primaryTextColor.color)
                    Text("@\(viewModel.currentUser.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                    Text(viewModel.currentUser.email)
                        .font(.caption)
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(data.themeConfig.mutedTextColor.color)
            }
            .padding(14)
            .background(data.themeConfig.cardBackgroundColor.color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct HSSettingsDetailView: View {
    @EnvironmentObject private var data: HSMockChatService
    @Environment(\.dismiss) private var dismiss
    let destination: SettingsDestination

    var body: some View {
        VStack(spacing: 0) {
            HSSimplePageHeader(title: title, leadingTitle: nil, trailingTitle: nil, onLeading: { dismiss() }, onTrailing: {})
                .padding(.horizontal, 12)

            ScrollView {
                HSGroupedSettingsCard {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            HStack(spacing: 12) {
                                Image(systemName: row.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(row.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(data.themeConfig.primaryTextColor.color)
                                    Text(row.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            if index != rows.count - 1 {
                                Rectangle()
                                    .fill(data.themeConfig.separatorColor.color)
                                    .frame(height: 1 / UIScreen.main.scale)
                                    .padding(.leading, 54)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)
            }
        }
        .background(data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var title: String {
        switch destination {
        case .profile: return "个人资料"
        case .accountSecurity: return "账号与安全"
        case .privacy: return "隐私设置"
        case .notifications: return "通知设置"
        case .chat: return "聊天设置"
        case .appearance: return "外观设置"
        case .storage: return "存储与数据"
        case .devices: return "设备管理"
        case .about: return "关于 HSgram"
        case .logout: return "退出登录"
        }
    }

    private var rows: [(title: String, subtitle: String, icon: String)] {
        switch destination {
        case .accountSecurity: return [("邮箱登录", "linhe@hsgram.app", "envelope"), ("手机号", "+86 138 0000 1024", "phone"), ("两步验证", "建议开启", "lock.shield")]
        case .privacy: return [("最后在线", "联系人可见", "eye"), ("资料照片", "所有人可见", "person.crop.circle"), ("黑名单", "0 个用户", "hand.raised")]
        case .notifications: return [("私聊通知", "已开启", "bell"), ("群聊通知", "提及和回复", "person.3"), ("消息预览", "显示发件人和内容", "text.bubble")]
        case .chat: return [("自动下载", "Wi-Fi 下下载图片", "arrow.down.circle"), ("发送键", "换行优先", "keyboard"), ("贴纸与表情", "最近使用和推荐", "face.smiling")]
        case .storage: return [("缓存", "128 MB", "internaldrive"), ("自动清理", "30 天", "trash"), ("网络用量", "本月 1.2 GB", "antenna.radiowaves.left.and.right")]
        case .devices: return [("当前设备", "iPhone 15 Pro", "iphone.gen3"), ("桌面端", "最近在线", "desktopcomputer"), ("退出其他设备", "保留当前设备", "rectangle.portrait.and.arrow.right")]
        case .about: return [("版本", "0.1.0 Prototype", "info.circle"), ("服务条款", "HSgram 自有品牌体验", "doc.text"), ("开源声明", "使用 SF Symbols 与 SwiftUI", "curlybraces")]
        default: return [("原型页面", "该设置项已预留真实 API 接入位置。", "hammer")]
        }
    }
}
