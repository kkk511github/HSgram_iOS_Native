import SwiftUI

struct PasscodeLockView: View {
    @EnvironmentObject private var passcodeStore: PasscodeStore
    @State private var passcode = ""
    @State private var errorMessage: String?
    @State private var didAttemptBiometrics = false
    @State private var isAuthenticatingBiometrics = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "lock.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(HSTheme.accent)

            VStack(spacing: 6) {
                Text("输入密码")
                    .font(.title2.weight(.bold))
                Text("HSgram 已锁定。")
                    .font(.footnote)
                    .foregroundStyle(HSTheme.secondaryText)
            }

            SecureField(passcodeStore.passcodeLengthLabel, text: $passcode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title3.monospacedDigit())
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(HSTheme.separator.opacity(0.75), lineWidth: 1)
                )
                .padding(.horizontal, 42)
                .onChange(of: passcode) { _ in
                    passcode = String(passcode.filter(\.isNumber).prefix(6))
                    if passcode.count == passcodeStore.passcodeLength {
                        unlock()
                    }
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HSTheme.warning)
            }

            Button("解锁") {
                unlock()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(passcode.count == passcodeStore.passcodeLength ? .white : HSTheme.secondaryText)
            .frame(maxWidth: 240)
            .frame(height: 50)
            .background(passcode.count == passcodeStore.passcodeLength ? HSTheme.accent : Color(rgb: 0xeeeeef), in: Capsule())
            .buttonStyle(.plain)
            .disabled(passcode.count != passcodeStore.passcodeLength)

            if passcodeStore.canUnlockWithBiometrics {
                Button {
                    Task {
                        await biometricUnlock(showFailure: true)
                    }
                } label: {
                    Label(
                        isAuthenticatingBiometrics ? "验证中" : "使用 \(passcodeStore.biometricName)",
                        systemImage: passcodeStore.biometricSystemImage
                    )
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HSTheme.accent)
                .disabled(isAuthenticatingBiometrics)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HSTheme.grouped)
        .task {
            await biometricUnlock(showFailure: false)
        }
    }

    private func unlock() {
        switch passcodeStore.unlock(passcode: passcode) {
        case .unlocked:
            errorMessage = nil
        case .failed(let remainingAttempts):
            passcode = ""
            if remainingAttempts <= 0 {
                errorMessage = "密码不正确。"
            } else {
                errorMessage = "密码不正确，还可尝试 \(remainingAttempts) 次。"
            }
        case .throttled(let seconds):
            passcode = ""
            errorMessage = "尝试次数过多，请 \(seconds) 秒后重试。"
        }
    }

    private func biometricUnlock(showFailure: Bool) async {
        guard passcodeStore.canUnlockWithBiometrics, !isAuthenticatingBiometrics else {
            return
        }
        if didAttemptBiometrics && !showFailure {
            return
        }
        didAttemptBiometrics = true
        isAuthenticatingBiometrics = true
        defer { isAuthenticatingBiometrics = false }
        let unlocked = await passcodeStore.unlockWithBiometrics(reason: "解锁 HSgram")
        if unlocked {
            errorMessage = nil
        } else if showFailure {
            errorMessage = "\(passcodeStore.biometricName) 验证失败，请输入密码。"
        }
    }
}
