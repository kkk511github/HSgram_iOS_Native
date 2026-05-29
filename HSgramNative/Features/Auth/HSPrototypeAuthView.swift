import SwiftUI

struct HSPrototypeAuthView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService
    @State private var mode: HSAuthMode = .login
    @State private var loginMethod: HSAuthLoginMethod = .email
    @State private var email = "linhe@hsgram.app"
    @State private var phone = "+86 138 0000 1024"
    @State private var code = ""
    @State private var name = "林河"
    @State private var codeSent = false

    private var viewModel: HSAuthViewModel {
        HSAuthViewModel(mode: mode, loginMethod: loginMethod, codeSent: codeSent)
    }

    var body: some View {
        ZStack {
            data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    brandHeader
                    VStack(spacing: 14) {
                        Picker("模式", selection: $mode) {
                            Text("登录").tag(HSAuthMode.login)
                            Text("注册").tag(HSAuthMode.register)
                        }
                        .pickerStyle(.segmented)
                        Picker("登录方式", selection: $loginMethod) {
                            Label("邮箱", systemImage: "envelope").tag(HSAuthLoginMethod.email)
                            Label("手机", systemImage: "phone").tag(HSAuthLoginMethod.phone)
                        }
                        .pickerStyle(.segmented)
                        if viewModel.showsNameField {
                            authField(title: "昵称", text: $name, icon: "person.crop.circle", keyboard: .default)
                        }
                        if viewModel.usesEmailLogin {
                            authField(title: "邮箱", text: $email, icon: "envelope", keyboard: .emailAddress)
                        } else {
                            authField(title: "手机号", text: $phone, icon: "phone", keyboard: .phonePad)
                        }
                        if codeSent {
                            authField(title: "验证码", text: $code, icon: "number", keyboard: .numberPad)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                if codeSent {
                                    router.signIn()
                                } else {
                                    codeSent = true
                                    code = viewModel.verificationSeed
                                }
                            }
                        } label: {
                            Text(viewModel.primaryActionTitle)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(data.themeConfig.inverseTextColor.color)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(data.themeConfig.primaryAccentColor.color, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                mode = viewModel.toggledMode()
                                codeSent = false
                                code = ""
                            }
                        } label: {
                            Text(viewModel.switchPrompt)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(data.themeConfig.cardBackgroundColor.color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: data.themeConfig.shadowColor.color.opacity(0.68), radius: 18, x: 0, y: 9)
                    Text(viewModel.helperText)
                        .font(.footnote)
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, 22)
                .padding(.vertical, 36)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [data.themeConfig.primaryAccentColor.color, data.themeConfig.secondaryAccentColor.color], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 82, height: 82)
                    .shadow(color: data.themeConfig.primaryAccentColor.color.opacity(0.30), radius: 18, x: 0, y: 9)
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(data.themeConfig.inverseTextColor.color)
                    .rotationEffect(.degrees(-8))
            }
            VStack(spacing: 7) {
                Text("HSgram")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                Text("轻快、安全、清爽的聊天体验")
                    .font(.subheadline)
                    .foregroundStyle(data.themeConfig.secondaryTextColor.color)
            }
        }
    }

    private func authField(title: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                .frame(width: 24)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 16))
                .foregroundStyle(data.themeConfig.primaryTextColor.color)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(data.themeConfig.groupedBackgroundColor.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
