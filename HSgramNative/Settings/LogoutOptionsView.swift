import SwiftUI

struct LogoutOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var passcodeStore: PasscodeStore

    @State private var statusMessage: String?
    @State private var isConfirmingLogout = false

    var body: some View {
        List {
            if let statusMessage {
                Label(statusMessage, systemImage: "info.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HSTheme.accent)
            }

            Section("其他选项") {
                Button {
                    authStore.beginAddingAccount()
                    dismiss()
                } label: {
                    LogoutOptionRow(
                        title: "添加另一个账号",
                        subtitle: "设置多个登录账号并随时切换。",
                        systemImage: "person.crop.circle.badge.plus"
                    )
                }

                if !passcodeStore.isEnabled {
                    NavigationLink {
                        PasscodeSettingsView()
                    } label: {
                        LogoutOptionRow(
                            title: "设置密码锁",
                            subtitle: "打开 HSgram 前先进行本地解锁。",
                            systemImage: "lock"
                        )
                    }
                }

                NavigationLink {
                    DataStorageSettingsView()
                } label: {
                    LogoutOptionRow(
                        title: "清理缓存",
                        subtitle: "查看本地存储，云端媒体仍可使用。",
                        systemImage: "externaldrive.badge.minus"
                    )
                }

                NavigationLink {
                    ProfileSettingsView()
                } label: {
                    LogoutOptionRow(
                        title: "更改邮箱或资料",
                        subtitle: "退出登录前更新账号展示信息。",
                        systemImage: "person.text.rectangle"
                    )
                }

                Link(destination: URL(string: "mailto:support@hsgram.cloud")!) {
                    LogoutOptionRow(
                        title: "联系支持",
                        subtitle: "把遇到的问题告诉我们。",
                        systemImage: "envelope"
                    )
                }
            }

            Section {
                Button(role: .destructive) {
                    isConfirmingLogout = true
                } label: {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } footer: {
                Text("退出登录会移除此设备上的本地 HSgram 会话。")
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("退出登录")
        .alert("退出 HSgram？", isPresented: $isConfirmingLogout) {
            Button("取消", role: .cancel) {}
            Button("退出登录", role: .destructive) {
                authStore.signOut()
            }
        } message: {
            Text("你需要重新登录才能在此设备上使用这个账号。")
        }
    }
}

private struct LogoutOptionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(HSTheme.primaryText)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(HSTheme.secondaryText)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(HSTheme.accent)
        }
    }
}
