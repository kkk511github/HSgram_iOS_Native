import SwiftUI

struct HSPrototypeAuthView: View {
    @EnvironmentObject private var router: HSAppRouter
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
            HSPrototypeTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    brandHeader
                    VStack(spacing: 16) {
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
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(HSPrototypeTheme.accent)
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                mode = viewModel.toggledMode()
                                codeSent = false
                                code = ""
                            }
                        } label: {
                            Text(viewModel.switchPrompt)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(HSPrototypeTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(18)
                    .background(HSPrototypeTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 12)
                    Text(viewModel.helperText)
                        .font(.footnote)
                        .foregroundStyle(HSPrototypeTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 430)
                .padding(.horizontal, 24)
                .padding(.vertical, 42)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [HSPrototypeTheme.accent, Color(hex: 0x62C6FF)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 94, height: 94)
                    .shadow(color: HSPrototypeTheme.accent.opacity(0.35), radius: 22, x: 0, y: 12)
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-8))
            }
            VStack(spacing: 8) {
                Text("HSgram").font(.largeTitle.weight(.bold)).foregroundStyle(HSPrototypeTheme.primaryText)
                Text("轻快、安全、清爽的聊天体验").font(.subheadline).foregroundStyle(HSPrototypeTheme.secondaryText)
            }
        }
    }

    private func authField(title: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(HSPrototypeTheme.accent).frame(width: 24)
            TextField(title, text: text).keyboardType(keyboard).textInputAutocapitalization(.never).autocorrectionDisabled().font(.body)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(HSPrototypeTheme.secondarySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
