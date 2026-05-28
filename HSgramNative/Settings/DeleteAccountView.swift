import SwiftUI

struct DeleteAccountView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var password = ""
    @State private var requiresPassword = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showConfirmation = false

    var body: some View {
        Form {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }

            Section {
                Label("删除后将无法继续使用当前账号。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(HSTheme.warning)
                Text("云端资料、联系人、群组和消息记录会按服务端账号删除规则处理。")
                    .font(.footnote)
                    .foregroundStyle(HSTheme.secondaryText)
            }

            Section("原因") {
                TextField("可留空", text: $reason, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("两步验证") {
                SecureField("如已开启，请输入密码", text: $password)
                    .textContentType(.password)
                if requiresPassword {
                    Text("服务端要求先验证两步验证密码。")
                        .font(.footnote)
                        .foregroundStyle(HSTheme.warning)
                }
            }

            Section {
                Button(role: .destructive) {
                    showConfirmation = true
                } label: {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Label("立即删除账号", systemImage: "trash")
                    }
                }
                .disabled(isDeleting)
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("删除账号")
        .alert("删除账号", isPresented: $showConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("这个操作不可撤销。")
        }
    }

    private func deleteAccount() async {
        guard let session = authStore.session, !isDeleting else {
            return
        }
        isDeleting = true
        defer { isDeleting = false }

        do {
            let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
            let action = try await authStore.api.deleteAccount(
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
                password: trimmedPassword.isEmpty ? nil : trimmedPassword,
                session: session
            )
            guard action.ok else {
                errorMessage = "服务端未确认删除账号，请稍后重试。"
                return
            }
            authStore.signOut()
            dismiss()
        } catch {
            errorMessage = deletionErrorMessage(error)
        }
    }

    private func deletionErrorMessage(_ error: Error) -> String {
        guard let apiError = error as? HSAPIError else {
            return error.localizedDescription
        }
        let code = apiError.serverCode ?? ""
        if code == "SESSION_PASSWORD_NEEDED" || code == "PASSWORD_MISSING" || code == "PASSWORD_REQUIRED" {
            requiresPassword = true
            return "请输入两步验证密码后重试。"
        }
        if code == "PASSWORD_HASH_INVALID" {
            requiresPassword = true
            return "密码不正确，请重新输入。"
        }
        if code.hasPrefix("2FA_CONFIRM_WAIT_") {
            return "该账号需要等待两步验证保护期结束后才能删除。"
        }
        if code == "2FA_RECENT_CONFIRM" {
            return "该账号近期确认过两步验证，暂时不能删除。"
        }
        return apiError.errorDescription ?? "删除账号失败。"
    }
}
