import SwiftUI

struct HSSettingsHomeView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService

    var body: some View {
        VStack(spacing: 0) {
            HSNavigationBar(title: "设置")
            ScrollView {
                VStack(spacing: 18) {
                    profileCard.padding(.horizontal, 16).padding(.top, 16)
                    VStack(spacing: 0) {
                        ForEach(data.settingsItems) { item in
                            Button {
                                item.destination == .appearance ? router.open(.appearance) : router.open(.settingsDetail(item.destination))
                            } label: {
                                HSSettingsRow(item: item)
                            }
                            .buttonStyle(.plain)
                            if item.id != data.settingsItems.last?.id {
                                Rectangle().fill(HSPrototypeTheme.separator.opacity(0.55)).frame(height: 1 / UIScreen.main.scale).padding(.leading, 62)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    Button(role: .destructive) { router.signOut() } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right").font(.body.weight(.semibold)).frame(maxWidth: .infinity).frame(height: 48)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(HSPrototypeTheme.background)
        }
        .background(HSPrototypeTheme.background.ignoresSafeArea())
    }

    private var profileCard: some View {
        Button { router.open(.profile(data.currentUser.id)) } label: {
            HStack(spacing: 14) {
                HSAvatarView(initials: data.currentUser.initials, colorHex: data.currentUser.accentHex, size: 64, isOnline: true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(data.currentUser.displayName).font(.title3.weight(.bold)).foregroundStyle(HSPrototypeTheme.primaryText)
                    Text("@\(data.currentUser.username)").font(.subheadline).foregroundStyle(HSPrototypeTheme.accent)
                    Text(data.currentUser.email).font(.caption).foregroundStyle(HSPrototypeTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(HSPrototypeTheme.tertiaryText)
            }
            .padding(16)
            .background(HSPrototypeTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct HSSettingsDetailView: View {
    let destination: SettingsDestination

    var body: some View {
        List {
            Section {
                ForEach(rows, id: \.0) { title, subtitle, icon in
                    HStack(spacing: 12) {
                        Image(systemName: icon).foregroundStyle(HSPrototypeTheme.accent).frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title).font(.body.weight(.semibold))
                            Text(subtitle).font(.caption).foregroundStyle(HSPrototypeTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
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

    private var rows: [(String, String, String)] {
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
