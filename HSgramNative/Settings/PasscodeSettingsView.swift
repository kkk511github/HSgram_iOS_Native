import SwiftUI

struct PasscodeSettingsView: View {
    @EnvironmentObject private var passcodeStore: PasscodeStore

    @State private var newPasscode = ""
    @State private var confirmPasscode = ""
    @State private var currentPasscode = ""
    @State private var replacementPasscode = ""
    @State private var replacementConfirmPasscode = ""
    @State private var disablePasscode = ""
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    private let autoLockOptions: [Int?] = [nil, 60, 5 * 60, 60 * 60, 5 * 60 * 60]

    var body: some View {
        List {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }
            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HSTheme.trust)
            }

            Section {
                LabeledContent("状态", value: passcodeStore.statusText)

                if passcodeStore.isEnabled {
                    LabeledContent(passcodeStore.biometricName, value: passcodeStore.biometricsStatusText)
                    Button {
                        passcodeStore.lockNow()
                    } label: {
                        Label("立即锁定", systemImage: "lock")
                    }
                }
            } header: {
                Text("密码锁")
            } footer: {
                Text("密码锁只保护本机 HSgram App，不会改变服务端登录密码或邮箱登录。")
            }

            if passcodeStore.isEnabled {
                enabledContent
            } else {
                setupContent
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("密码锁")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var setupContent: some View {
        Section("开启密码锁") {
            passcodeField("新的 4 或 6 位密码", text: $newPasscode)
            passcodeField("确认密码", text: $confirmPasscode)
            Button("开启密码锁") {
                enablePasscode()
            }
            .disabled(!canSet(newPasscode, confirmPasscode))
        }
    }

    @ViewBuilder
    private var enabledContent: some View {
        Section("更改密码") {
            passcodeField("当前密码", text: $currentPasscode)
            passcodeField("新的 4 或 6 位密码", text: $replacementPasscode)
            passcodeField("确认新密码", text: $replacementConfirmPasscode)
            Button("更改密码") {
                changePasscode()
            }
            .disabled(!canSet(replacementPasscode, replacementConfirmPasscode) || currentPasscode.count != passcodeStore.passcodeLength)
        }

        Section {
            Toggle(isOn: Binding(
                get: { passcodeStore.biometricsEnabled },
                set: { enabled in
                    if enabled {
                        Task {
                            await enableBiometrics()
                        }
                    } else {
                        passcodeStore.setBiometricsEnabled(false)
                        statusMessage = "\(passcodeStore.biometricName) 解锁已关闭。"
                        errorMessage = nil
                    }
                }
            )) {
                Label("使用 \(passcodeStore.biometricName) 解锁", systemImage: passcodeStore.biometricSystemImage)
            }
            .disabled(!passcodeStore.canUseBiometrics)
        } header: {
            Text("生物识别")
        } footer: {
            Text(passcodeStore.biometricUnavailableReason ?? "\(passcodeStore.biometricName) 只用于解锁本机 HSgram，不会改变服务端账号密码。")
        }

        Section {
            Picker("自动锁定", selection: Binding<Int?>(
                get: { passcodeStore.autoLockTimeoutSeconds },
                set: { passcodeStore.setAutoLockTimeout($0) }
            )) {
                ForEach(autoLockOptions.indices, id: \.self) { index in
                    let value = autoLockOptions[index]
                    Text(PasscodeStore.label(for: value)).tag(value)
                }
            }
        } header: {
            Text("自动锁定")
        } footer: {
            Text("与旧版 iOS 自动锁定选项保持一致：关闭、1 分钟、5 分钟、1 小时、5 小时。")
        }

        Section("关闭密码锁") {
            passcodeField("当前密码", text: $disablePasscode)
            Button(role: .destructive) {
                disable()
            } label: {
                Text("关闭密码锁")
            }
            .disabled(disablePasscode.count != passcodeStore.passcodeLength)
        }
    }

    private func passcodeField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .onChange(of: text.wrappedValue) { _ in
                text.wrappedValue = String(text.wrappedValue.filter(\.isNumber).prefix(6))
            }
    }

    private func enablePasscode() {
        guard validateMatch(newPasscode, confirmPasscode) else {
            return
        }
        passcodeStore.setPasscode(newPasscode)
        clearSetupFields()
        statusMessage = "密码锁已开启。"
        errorMessage = nil
    }

    private func changePasscode() {
        guard validateMatch(replacementPasscode, replacementConfirmPasscode) else {
            return
        }
        guard passcodeStore.changePasscode(current: currentPasscode, new: replacementPasscode) else {
            errorMessage = "当前密码不正确。"
            statusMessage = nil
            currentPasscode = ""
            return
        }
        currentPasscode = ""
        replacementPasscode = ""
        replacementConfirmPasscode = ""
        statusMessage = "密码已更改。"
        errorMessage = nil
    }

    private func enableBiometrics() async {
        let enabled = await passcodeStore.enableBiometrics(reason: "启用 \(passcodeStore.biometricName) 解锁 HSgram")
        if enabled {
            statusMessage = "\(passcodeStore.biometricName) 解锁已开启。"
            errorMessage = nil
        } else {
            statusMessage = nil
            errorMessage = "无法开启 \(passcodeStore.biometricName) 解锁。"
        }
    }

    private func disable() {
        guard passcodeStore.disable(passcode: disablePasscode) else {
            errorMessage = "当前密码不正确。"
            statusMessage = nil
            disablePasscode = ""
            return
        }
        clearSetupFields()
        disablePasscode = ""
        statusMessage = "密码锁已关闭。"
        errorMessage = nil
    }

    private func validateMatch(_ first: String, _ second: String) -> Bool {
        guard PasscodeStore.isValidPasscode(first) else {
            errorMessage = "密码必须为 4 或 6 位数字。"
            statusMessage = nil
            return false
        }
        guard first == second else {
            errorMessage = "两次输入的密码不一致。"
            statusMessage = nil
            return false
        }
        return true
    }

    private func canSet(_ first: String, _ second: String) -> Bool {
        PasscodeStore.isValidPasscode(first) && first == second
    }

    private func clearSetupFields() {
        newPasscode = ""
        confirmPasscode = ""
    }
}
