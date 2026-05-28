import SwiftUI
import UIKit
import PhotosUI

struct AuthView: View {
    @EnvironmentObject private var authStore: AuthStore
    @FocusState private var focusedField: Field?

    @State private var email = ""
    @State private var code = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var inviteCode = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var selectedAvatarImage: UIImage?
    @State private var selectedAvatarData: Data?
    @State private var isLoadingAvatar = false
    @State private var avatarErrorMessage: String?
    @State private var hasAcceptedTerms = false
    @State private var currentTermsAcceptanceKey: String?
    @State private var showingTermsOfService = false
    @State private var showingTermsDecline = false

    enum Field: Hashable {
        case email
        case code
        case firstName
        case lastName
        case inviteCode
        case password
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        Group {
                            switch authStore.phase {
                            case .enteringEmail, .sendingCode:
                                emailEntryContent
                            case .enteringCode, .verifying:
                                codeEntryContent
                            case .enteringSignUp, .signingUp:
                                signUpEntryContent
                            case .enteringPassword, .verifyingPassword, .requestingPasswordRecovery:
                                passwordEntryContent
                            case .enteringRecoveryCode, .recoveringPassword:
                                recoveryCodeEntryContent
                            }
                        }
                        .frame(maxWidth: HSAuthLayout.maximumWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.top, contentTopPadding(for: proxy.size))
                        .padding(.bottom, 24)
                    }

                    if shouldShowPrimaryFooter {
                        primaryFooter(maximumWidth: min(HSAuthLayout.maximumWidth, proxy.size.width))
                    }
                }

                closeButton
                    .padding(.leading, 6)
                    .padding(.top, 4)
            }
        }
        .onAppear {
            focusedField = initialFocusedField
        }
        .onChange(of: authStore.phase) { phase in
            switch phase {
            case .enteringEmail:
                selectedAvatarItem = nil
                selectedAvatarImage = nil
                selectedAvatarData = nil
                isLoadingAvatar = false
                avatarErrorMessage = nil
                currentTermsAcceptanceKey = nil
                hasAcceptedTerms = false
                showingTermsOfService = false
                showingTermsDecline = false
                focusedField = .email
            case .sendingCode:
                focusedField = nil
            case .enteringCode:
                code = ""
                focusedField = .code
            case let .enteringSignUp(email, _, termsOfService):
                self.email = email
                code = ""
                let termsKey = termsAcceptanceKey(email: email, termsOfService: termsOfService)
                if currentTermsAcceptanceKey != termsKey {
                    currentTermsAcceptanceKey = termsKey
                    hasAcceptedTerms = termsOfService == nil
                }
                if termsOfService?.isPopup == true && !hasAcceptedTerms {
                    showingTermsOfService = true
                }
                if firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    firstName = email.split(separator: "@").first.map(String.init) ?? ""
                }
                focusedField = .firstName
            case .signingUp:
                focusedField = nil
            case let .enteringPassword(email, _):
                self.email = email
                password = ""
                focusedField = .password
            case let .requestingPasswordRecovery(email, _):
                self.email = email
                focusedField = nil
            case let .enteringRecoveryCode(email, _, _):
                self.email = email
                code = ""
                focusedField = .code
            case .verifying, .verifyingPassword, .recoveringPassword:
                focusedField = nil
            }
        }
        .sheet(isPresented: $showingTermsOfService) {
            if let termsOfService = currentSignUpContext.termsOfService {
                HSTermsOfServiceSheet(
                    termsOfService: termsOfService,
                    onDecline: {
                        showingTermsOfService = false
                        showingTermsDecline = true
                    },
                    onAgree: {
                        hasAcceptedTerms = true
                        showingTermsOfService = false
                    }
                )
            }
        }
        .alert("服务条款", isPresented: $showingTermsDecline) {
            Button("继续注册", role: .cancel) {}
            Button("拒绝", role: .destructive) {
                authStore.resetToEmailEntry()
            }
        } message: {
            Text("很遗憾，如果不同意服务条款，将无法创建 HSgram 账号。")
        }
        .onChange(of: selectedAvatarItem) { item in
            Task {
                await loadSelectedAvatar(item)
            }
        }
    }

    private var closeButton: some View {
        Button {
            closeTapped()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(HSTheme.primaryText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("关闭登录")
    }

    private var emailEntryContent: some View {
        VStack(spacing: 0) {
            HSAuthMailMark()
                .frame(width: 100, height: 100)
                .padding(.bottom, 18)

            Text("登录 HSgram")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(HSTheme.primaryText)
                .multilineTextAlignment(.center)

            Text("请输入邮箱地址。")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(HSTheme.primaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 18)

            HSAuthUnderlinedInput {
                TextField("输入你的邮箱", text: $email)
                    .focused($focusedField, equals: .email)
                    .font(.system(size: 20, weight: .regular))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        Task {
                            await sendCode()
                        }
                    }
            }
            .padding(.top, 24)

            authStatusContent
                .padding(.top, 14)

            savedAccountsContent
                .padding(.top, 18)
        }
    }

    private var codeEntryContent: some View {
        let context = currentCodeContext

        return VStack(spacing: 0) {
            HSAuthEnvelopeMark()
                .frame(width: 82, height: 82)
                .padding(.bottom, 18)

            Text("检查你的邮箱")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(HSTheme.primaryText)
                .multilineTextAlignment(.center)

            Text("我们已向 \(context.pattern) 发送 \(context.length) 位验证码")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(HSTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 14)
                .frame(maxWidth: 320)

            HSAuthCodeCard(
                code: $code,
                length: context.length,
                focusedField: $focusedField,
                focusValue: .code,
                normalize: normalizeCode,
                buttonTitle: primaryButtonTitle,
                isBusy: isBusy,
                isButtonDisabled: primaryButtonDisabled,
                errorMessage: authStore.errorMessage,
                action: {
                    Task {
                        await primaryAction()
                    }
                },
                linkTitle: "重新发送",
                linkAction: {
                    Task {
                        await resendCode()
                    }
                }
            )
            .padding(.top, 24)

            HSAuthTrustCard(
                text: "验证码仅用于本次登录，请勿分享给他人"
            )
            .padding(.top, 20)
        }
    }

    private var signUpEntryContent: some View {
        let context = currentSignUpContext

        VStack(spacing: 0) {
            PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                HSAuthAddPhotoMark(image: selectedAvatarImage, isLoading: isLoadingAvatar)
                    .frame(width: 96, height: 96)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .padding(.bottom, 18)

            Text("完善你的资料")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(HSTheme.primaryText)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("Auth.SetName.Title")

            Text("填写昵称并添加头像，之后可以在资料页修改。")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(HSTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 10)

            HSAuthSignUpFormCard(
                firstName: $firstName,
                lastName: $lastName,
                inviteCode: $inviteCode,
                focusedField: $focusedField
            )
            .padding(.top, 32)

            if let avatarErrorMessage {
                Text(avatarErrorMessage)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HSTheme.warning)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }

            if let termsOfService = context.termsOfService {
                HSAuthTermsOfServiceRow(
                    termsOfService: termsOfService,
                    isAccepted: $hasAcceptedTerms,
                    openTerms: {
                        showingTermsOfService = true
                    }
                )
                .padding(.top, 18)
            }

            authStatusContent
                .padding(.top, 16)
        }
    }

    private var passwordEntryContent: some View {
        let context = currentPasswordContext

        return VStack(spacing: 0) {
            HSAuthShieldMark()
                .frame(width: 88, height: 88)
                .padding(.bottom, 18)

            Text("验证安全密码")
                .font(.system(size: 29, weight: .semibold))
                .foregroundStyle(HSTheme.primaryText)
                .multilineTextAlignment(.center)

            Text("请输入你设置的安全密码，\n以继续登录和保护你的账号安全")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(HSTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 12) {
                Text("安全密码")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HSTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 16) {
                    Image(systemName: "lock")
                        .font(.system(size: 23, weight: .regular))
                        .foregroundStyle(HSTheme.secondaryText)
                        .frame(width: 28)

                    Group {
                        if isPasswordVisible {
                            TextField("请输入安全密码", text: $password)
                        } else {
                            SecureField("请输入安全密码", text: $password)
                        }
                    }
                    .focused($focusedField, equals: .password)
                    .font(.system(size: 18, weight: .regular))
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit {
                        Task {
                            await verifyPassword(email: context.email)
                        }
                    }

                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPasswordVisible ? "隐藏密码" : "显示密码")
                }
                .padding(.horizontal, 24)
                .frame(height: 64)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(HSTheme.separator.opacity(0.75), lineWidth: 1)
                )
            }
            .padding(.top, 34)

            if let hint = context.hint, !hint.isEmpty {
                Text("密码提示：\(hint)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HSTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                    .padding(.horizontal, 4)
            }

            Button("忘记安全密码？") {
                Task {
                    await authStore.requestPasswordRecovery(email: context.email, hint: context.hint)
                }
            }
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(HSAuthPalette.purple)
            .buttonStyle(.plain)
            .disabled(isRequestingPasswordRecovery)
            .padding(.top, 24)

            authStatusContent
                .padding(.top, 16)

            HSAuthInfoRow(
                icon: "shield.lefthalf.filled",
                title: "验证码与密码保护",
                subtitle: "先完成身份验证；如果已开启额外密码保护，系统将继续验证安全密码。"
            )
            .padding(.top, 54)
        }
    }

    private var recoveryCodeEntryContent: some View {
        let context = currentRecoveryContext

        return VStack(spacing: 0) {
            HSAuthEnvelopeMark()
                .frame(width: 96, height: 96)
                .padding(.bottom, 18)

            Text("输入恢复验证码")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(HSTheme.primaryText)
                .multilineTextAlignment(.center)

            Text("我们已向 \(context.pattern) 发送 \(context.length) 位恢复验证码")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(HSTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 14)
                .frame(maxWidth: 330)

            HSAuthCodeCard(
                code: $code,
                length: context.length,
                focusedField: $focusedField,
                focusValue: .code,
                normalize: normalizeCode
            )
            .padding(.top, 28)

            HStack(spacing: 24) {
                Button("粘贴验证码") {
                    pasteCode(length: context.length)
                }
                Button("重新发送") {
                    Task {
                        await authStore.requestPasswordRecovery(email: context.email, hint: nil)
                    }
                }
                Button("返回密码") {
                    password = ""
                    authStore.returnToPasswordEntry(email: context.email)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(HSTheme.accent)
            .buttonStyle(.plain)
            .padding(.top, 22)

            authStatusContent
                .padding(.top, 16)

            HSAuthInfoRow(
                icon: "envelope.badge.shield.half.filled",
                title: "恢复码用于重置安全密码",
                subtitle: "验证成功后会按服务端旧流程移除当前安全密码；你可以登录后在设置中重新开启。"
            )
            .padding(.top, 54)
        }
    }

    @ViewBuilder
    private var authStatusContent: some View {
        if let error = authStore.errorMessage {
            Text(error)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(HSTheme.warning)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if isBusy {
            ProgressView()
                .tint(HSTheme.accent)
        }
    }

    @ViewBuilder
    private var savedAccountsContent: some View {
        if authStore.phase == .enteringEmail && !authStore.savedAccounts.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("已保存账号")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HSTheme.secondaryText)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(authStore.savedAccounts, id: \.userID) { account in
                        Button {
                            authStore.switchAccount(userID: account.userID)
                        } label: {
                            SavedAccountRow(account: account)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                authStore.removeSavedAccount(userID: account.userID)
                            } label: {
                                Label("从此设备移除", systemImage: "trash")
                            }
                        }

                        if account.userID != authStore.savedAccounts.last?.userID {
                            Divider()
                                .padding(.leading, 68)
                        }
                    }
                }
                .background(Color.white)
            }
        }
    }

    private func primaryFooter(maximumWidth: CGFloat) -> some View {
        Button {
            Task {
                await primaryAction()
            }
        } label: {
            HStack {
                Spacer()
                if isBusy {
                    ProgressView()
                        .tint(primaryButtonDisabled ? HSTheme.secondaryText : .white)
                } else {
                    Text(primaryButtonTitle)
                        .font(.system(size: 17, weight: .semibold))
                }
                Spacer()
            }
            .frame(height: HSAuthLayout.buttonHeight)
            .foregroundStyle(primaryButtonDisabled ? HSTheme.secondaryText : .white)
            .background(primaryButtonDisabled ? Color(rgb: 0xeeeeef) : HSTheme.accent, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(primaryButtonDisabled)
        .frame(width: max(0, maximumWidth - 48))
        .frame(maxWidth: .infinity)
        .padding(.bottom, 28)
        .padding(.top, 8)
        .background(Color.white)
    }

    private func contentTopPadding(for size: CGSize) -> CGFloat {
        if size.height < 680 {
            return 112
        }
        return max(128, size.height * 0.23)
    }

    private var normalizedEmail: String {
        email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }

    private var shouldShowPrimaryFooter: Bool {
        switch authStore.phase {
        case .enteringCode, .verifying:
            return false
        case .enteringEmail, .sendingCode, .enteringSignUp, .signingUp, .enteringPassword, .verifyingPassword, .requestingPasswordRecovery, .enteringRecoveryCode, .recoveringPassword:
            return true
        }
    }

    private var isBusy: Bool {
        if case .signingUp = authStore.phase {
            return true
        }
        return authStore.phase == .sendingCode
            || authStore.phase == .verifying
            || authStore.phase == .verifyingPassword
            || isRequestingPasswordRecovery
            || authStore.phase == .recoveringPassword
    }

    private var isRequestingPasswordRecovery: Bool {
        if case .requestingPasswordRecovery = authStore.phase {
            return true
        }
        return false
    }

    private var primaryButtonTitle: String {
        switch authStore.phase {
        case .enteringEmail:
            return "继续"
        case .sendingCode:
            return "正在判断账号"
        case .enteringCode:
            return "验证并登录"
        case .verifying:
            return "正在验证"
        case .enteringSignUp:
            return "完成并进入 HSgram"
        case .signingUp:
            return "正在创建"
        case .enteringPassword:
            return "验证并继续"
        case .verifyingPassword:
            return "正在验证"
        case .requestingPasswordRecovery:
            return "正在发送恢复码"
        case .enteringRecoveryCode:
            return "恢复并登录"
        case .recoveringPassword:
            return "正在恢复"
        }
    }

    private var primaryButtonDisabled: Bool {
        if isBusy {
            return true
        }
        switch authStore.phase {
        case .enteringEmail:
            return normalizedEmail.isEmpty || !normalizedEmail.contains("@")
        case .enteringCode:
            return code.count < currentCodeContext.length
        case .enteringSignUp:
            return firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (currentSignUpContext.termsOfService != nil && !hasAcceptedTerms)
        case .enteringPassword:
            return password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .enteringRecoveryCode:
            return code.count < currentRecoveryContext.length
        case .sendingCode, .verifying, .signingUp, .verifyingPassword, .requestingPasswordRecovery, .recoveringPassword:
            return true
        }
    }

    private var currentCodeContext: (pattern: String, length: Int) {
        if case let .enteringCode(_, emailPattern, codeLength) = authStore.phase {
            return (emailPattern, max(codeLength, 1))
        }
        return (maskedEmail(normalizedEmail), 6)
    }

    private var currentSignUpContext: (email: String, transactionID: String, termsOfService: HSTermsOfService?) {
        if case let .enteringSignUp(email, transactionID, termsOfService) = authStore.phase {
            return (email, transactionID, termsOfService)
        }
        if case let .signingUp(email, transactionID, termsOfService) = authStore.phase {
            return (email, transactionID, termsOfService)
        }
        return (normalizedEmail, "", nil)
    }

    private var currentPasswordContext: (email: String, hint: String?) {
        if case let .enteringPassword(email, hint) = authStore.phase {
            return (email, hint)
        }
        if case let .requestingPasswordRecovery(email, hint) = authStore.phase {
            return (email, hint)
        }
        return (normalizedEmail, nil)
    }

    private var currentRecoveryContext: (email: String, pattern: String, length: Int) {
        if case let .enteringRecoveryCode(email, emailPattern, codeLength) = authStore.phase {
            return (email, emailPattern, max(codeLength, 1))
        }
        return (normalizedEmail, maskedEmail(normalizedEmail), 6)
    }

    private var initialFocusedField: Field {
        switch authStore.phase {
        case .enteringEmail, .sendingCode:
            return .email
        case .enteringCode, .verifying:
            return .code
        case .enteringSignUp, .signingUp:
            return .firstName
        case .enteringPassword, .verifyingPassword, .requestingPasswordRecovery:
            return .password
        case .enteringRecoveryCode, .recoveringPassword:
            return .code
        }
    }

    private func primaryAction() async {
        switch authStore.phase {
        case .enteringEmail:
            await sendCode()
        case let .enteringCode(transactionID, _, _):
            await authStore.verify(email: email, code: code, transactionID: transactionID, displayName: "")
        case let .enteringSignUp(email, transactionID, termsOfService):
            await authStore.signUp(
                email: email,
                transactionID: transactionID,
                termsOfService: termsOfService,
                firstName: firstName,
                lastName: lastName,
                inviteCode: inviteCode,
                avatarData: selectedAvatarData
            )
        case let .enteringPassword(email, _):
            await verifyPassword(email: email)
        case let .enteringRecoveryCode(email, _, _):
            await authStore.recoverPassword(email: email, code: code)
        case .sendingCode, .verifying, .signingUp, .verifyingPassword, .requestingPasswordRecovery, .recoveringPassword:
            break
        }
    }

    private func sendCode() async {
        await authStore.sendCode(email: email)
    }

    private func resendCode() async {
        code = ""
        await authStore.sendCode(email: email)
    }

    private func verifyPassword(email: String) async {
        await authStore.verifyPassword(email: email, password: password)
    }

    private func normalizeCode(_ value: String, length: Int) {
        let digits = value.filter(\.isNumber)
        let limited = String(digits.prefix(length))
        if limited != value {
            code = limited
        }
    }

    private func pasteCode(length: Int) {
        guard let text = UIPasteboard.general.string else {
            return
        }
        code = String(text.filter(\.isNumber).prefix(length))
    }

    private func loadSelectedAvatar(_ item: PhotosPickerItem?) async {
        await MainActor.run {
            avatarErrorMessage = nil
            isLoadingAvatar = item != nil
            if item == nil {
                selectedAvatarImage = nil
                selectedAvatarData = nil
            }
        }
        guard let item else {
            return
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpegData = Self.compressedAvatarJPEG(from: image) else {
                await MainActor.run {
                    avatarErrorMessage = "无法读取头像图片。"
                    selectedAvatarImage = nil
                    selectedAvatarData = nil
                    isLoadingAvatar = false
                }
                return
            }
            await MainActor.run {
                selectedAvatarImage = UIImage(data: jpegData) ?? image
                selectedAvatarData = jpegData
                isLoadingAvatar = false
            }
        } catch {
            await MainActor.run {
                avatarErrorMessage = "无法读取头像图片。"
                selectedAvatarImage = nil
                selectedAvatarData = nil
                isLoadingAvatar = false
            }
        }
    }

    private func closeTapped() {
        if authStore.phase == .enteringEmail {
            email = ""
            focusedField = .email
        } else {
            code = ""
            password = ""
            authStore.resetToEmailEntry()
        }
    }

    private func maskedEmail(_ text: String) -> String {
        guard let atIndex = text.firstIndex(of: "@"),
              atIndex != text.startIndex,
              atIndex != text.index(before: text.endIndex),
              !text.contains("*") else {
            return text
        }
        let visiblePrefix = text[..<atIndex].prefix(3)
        return "\(visiblePrefix)***\(text[atIndex...])"
    }

    private static func compressedAvatarJPEG(from image: UIImage) -> Data? {
        let maxSide: CGFloat = 1024
        let longestSide = max(image.size.width, image.size.height)
        let scale = longestSide > maxSide ? maxSide / longestSide : 1
        let targetSize = CGSize(
            width: max(1, floor(image.size.width * scale)),
            height: max(1, floor(image.size.height * scale))
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: 0.7)
    }

    private func termsAcceptanceKey(email: String, termsOfService: HSTermsOfService?) -> String? {
        guard let termsOfService else {
            return nil
        }
        return "\(email)|\(termsOfService.id)"
    }
}

private enum HSAuthLayout {
    static let maximumWidth: CGFloat = 430
    static let buttonHeight: CGFloat = 50
}

private enum HSAuthPalette {
    static let purple = Color(rgb: 0x8e63ce)
}

private struct HSAuthUnderlinedInput<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                content
                    .tint(HSTheme.accent)
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            Rectangle()
                .fill(HSTheme.separator)
                .frame(height: 1 / UIScreen.main.scale)
        }
        .frame(maxWidth: HSAuthLayout.maximumWidth - 48)
    }
}

private struct HSAuthCodeCard: View {
    @Binding var code: String
    let length: Int
    var focusedField: FocusState<AuthView.Field?>.Binding
    let focusValue: AuthView.Field
    let normalize: (String, Int) -> Void
    let buttonTitle: String?
    let isBusy: Bool
    let isButtonDisabled: Bool
    let errorMessage: String?
    let action: (() -> Void)?
    let linkTitle: String?
    let linkAction: (() -> Void)?

    init(
        code: Binding<String>,
        length: Int,
        focusedField: FocusState<AuthView.Field?>.Binding,
        focusValue: AuthView.Field,
        normalize: @escaping (String, Int) -> Void,
        buttonTitle: String? = nil,
        isBusy: Bool = false,
        isButtonDisabled: Bool = false,
        errorMessage: String? = nil,
        action: (() -> Void)? = nil,
        linkTitle: String? = nil,
        linkAction: (() -> Void)? = nil
    ) {
        self._code = code
        self.length = length
        self.focusedField = focusedField
        self.focusValue = focusValue
        self.normalize = normalize
        self.buttonTitle = buttonTitle
        self.isBusy = isBusy
        self.isButtonDisabled = isButtonDisabled
        self.errorMessage = errorMessage
        self.action = action
        self.linkTitle = linkTitle
        self.linkAction = linkAction
    }

    var body: some View {
        VStack(spacing: 0) {
            HSAuthDigitCodeInput(
                code: $code,
                length: length,
                focusedField: focusedField,
                focusValue: focusValue,
                normalize: normalize
            )

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HSTheme.warning)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }

            if let buttonTitle {
                Button {
                    action?()
                } label: {
                    HStack {
                        Spacer()
                        if isBusy {
                            ProgressView()
                                .tint(isButtonDisabled ? HSTheme.secondaryText : .white)
                        } else {
                            Text(buttonTitle)
                                .font(.system(size: 17, weight: .semibold))
                        }
                        Spacer()
                    }
                    .frame(height: HSAuthLayout.buttonHeight)
                    .foregroundStyle(isButtonDisabled ? HSTheme.secondaryText : .white)
                    .background(isButtonDisabled ? Color(rgb: 0xeeeeef) : HSTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isButtonDisabled)
                .padding(.top, errorMessage == nil ? 14 : 10)
                .accessibilityIdentifier("Auth.CodeEntry.ContinueButton")
            }

            if let linkTitle {
                Button {
                    linkAction?()
                } label: {
                    Text(linkTitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(HSTheme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 20)
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .frame(minHeight: buttonTitle == nil ? nil : 202)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
        .frame(maxWidth: min(374, HSAuthLayout.maximumWidth - 48))
    }
}

private struct HSAuthDigitCodeInput: View {
    @Binding var code: String
    let length: Int
    var focusedField: FocusState<AuthView.Field?>.Binding
    let focusValue: AuthView.Field
    let normalize: (String, Int) -> Void

    var body: some View {
        let safeLength = max(length, 1)
        let characters = Array(code.prefix(safeLength))
        let isFocused = focusedField.wrappedValue == focusValue

        ZStack {
            GeometryReader { proxy in
                let spacing: CGFloat = safeLength > 5 ? 6 : 8
                let totalSpacing = CGFloat(max(safeLength - 1, 0)) * spacing
                let boxWidth = min(46, max(32, floor((proxy.size.width - totalSpacing) / CGFloat(safeLength))))

                HStack(spacing: spacing) {
                    ForEach(0..<safeLength, id: \.self) { index in
                        let isActiveSlot = isFocused && min(characters.count, safeLength - 1) == index
                        Text(index < characters.count ? String(characters[index]) : "")
                            .font(.system(size: 28, weight: .semibold, design: .monospaced))
                            .foregroundStyle(HSTheme.primaryText)
                            .frame(width: boxWidth, height: 56)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isActiveSlot ? HSTheme.accent : HSTheme.separator, lineWidth: isActiveSlot ? 1.5 : 1)
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            TextField("", text: $code)
                .focused(focusedField, equals: focusValue)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .tint(.clear)
                .opacity(0.02)
                .accessibilityIdentifier("Auth.CodeEntry.CodeField")
                .onChange(of: code) { value in
                    normalize(value, safeLength)
                }
        }
        .frame(height: 56)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField.wrappedValue = focusValue
        }
    }
}

private struct HSAuthTrustCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(HSTheme.secondaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .frame(maxWidth: min(374, HSAuthLayout.maximumWidth - 48))
            .frame(minHeight: 58)
            .background(Color(rgb: 0xf7f7f8).opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 8)
    }
}

private struct HSAuthSignUpFormCard: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var inviteCode: String
    var focusedField: FocusState<AuthView.Field?>.Binding

    var body: some View {
        VStack(spacing: 10) {
            HSAuthSignUpField(
                placeholder: "名字",
                text: $firstName,
                focusedField: focusedField,
                focusValue: .firstName,
                contentType: .givenName,
                returnKey: .next,
                accessibilityIdentifier: "Auth.SetName.FirstNameField",
                onSubmit: {
                    focusedField.wrappedValue = .lastName
                }
            )

            HSAuthSignUpField(
                placeholder: "姓氏",
                text: $lastName,
                focusedField: focusedField,
                focusValue: .lastName,
                contentType: .familyName,
                returnKey: .next,
                accessibilityIdentifier: "Auth.SetName.LastNameField",
                onSubmit: {
                    focusedField.wrappedValue = .inviteCode
                }
            )

            HSAuthSignUpField(
                placeholder: "邀请码（可选）",
                text: $inviteCode,
                focusedField: focusedField,
                focusValue: .inviteCode,
                contentType: nil,
                returnKey: .done,
                accessibilityIdentifier: "Auth.SetName.InviteCodeField",
                onSubmit: {}
            )
            .textInputAutocapitalization(.characters)
        }
        .padding(16)
        .background(Color(rgb: 0xf2f2f7).opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxWidth: HSAuthLayout.maximumWidth - 48)
    }
}

private struct HSAuthTermsOfServiceRow: View {
    let termsOfService: HSTermsOfService
    @Binding var isAccepted: Bool
    let openTerms: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                isAccepted.toggle()
            } label: {
                Image(systemName: isAccepted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isAccepted ? HSTheme.accent : HSTheme.secondaryText)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isAccepted ? "取消同意服务条款" : "同意服务条款")

            Button {
                openTerms()
            } label: {
                agreementText
                    .font(.system(size: 14, weight: .regular))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color(rgb: 0xf7f7f8), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: HSAuthLayout.maximumWidth - 48)
    }

    private var agreementText: Text {
        let suffix = termsOfService.minAgeConfirm.map { "，并确认你已满 \($0) 岁。" } ?? "。"
        let prefix = Text("注册即代表你同意").foregroundColor(HSTheme.secondaryText)
        let link = Text("服务条款").foregroundColor(HSTheme.accent)
        let ending = Text(suffix).foregroundColor(HSTheme.secondaryText)
        return prefix + link + ending
    }
}

private struct HSTermsOfServiceSheet: View {
    let termsOfService: HSTermsOfService
    let onDecline: () -> Void
    let onAgree: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(termsOfService.text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(HSTheme.primaryText)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)

                if let age = termsOfService.minAgeConfirm {
                    Text("继续注册表示你确认已满 \(age) 岁。")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HSTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("服务条款")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("拒绝", role: .destructive) {
                        onDecline()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("同意并继续") {
                        onAgree()
                    }
                }
            }
        }
    }
}

private struct HSAuthSignUpField: View {
    let placeholder: String
    @Binding var text: String
    var focusedField: FocusState<AuthView.Field?>.Binding
    let focusValue: AuthView.Field
    let contentType: UITextContentType?
    let returnKey: SubmitLabel
    let accessibilityIdentifier: String
    let onSubmit: () -> Void

    var body: some View {
        TextField(placeholder, text: $text)
            .focused(focusedField, equals: focusValue)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(HSTheme.primaryText)
            .textContentType(contentType)
            .autocorrectionDisabled()
            .submitLabel(returnKey)
            .onSubmit(onSubmit)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct HSAuthMailMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(HSTheme.accent.opacity(0.10))
                .frame(width: 86, height: 64)
                .rotationEffect(.degrees(-8))

            Image(systemName: "envelope.fill")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(HSTheme.accent)
        }
        .accessibilityHidden(true)
    }
}

private struct HSAuthEnvelopeMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(HSTheme.accent.opacity(0.10))

            Image(systemName: "envelope")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(HSTheme.accent)
        }
        .accessibilityHidden(true)
    }
}

private struct HSAuthAddPhotoMark: View {
    let image: UIImage?
    let isLoading: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(HSTheme.accent.opacity(0.10))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(systemName: "camera.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(HSTheme.accent)
            }

            if isLoading {
                ProgressView()
                    .tint(HSTheme.accent)
                    .frame(width: 96, height: 96)
                    .background(.white.opacity(0.72), in: Circle())
            } else if image != nil {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(HSTheme.accent, in: Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: 32, y: 32)
            }
        }
        .clipShape(Circle())
        .contentShape(Circle())
        .accessibilityLabel(image == nil ? "添加头像" : "更换头像")
    }
}

private struct HSAuthShieldMark: View {
    var body: some View {
        ZStack {
            Image(systemName: "shield")
                .font(.system(size: 78, weight: .regular))
            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .semibold))
                .offset(y: 5)
        }
        .foregroundStyle(HSAuthPalette.purple)
        .accessibilityHidden(true)
    }
}

private struct HSAuthInfoRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(HSAuthPalette.purple)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(HSTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(HSTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

private struct SavedAccountRow: View {
    let account: HSUserSession

    var body: some View {
        HStack(spacing: 12) {
            HSClassicAvatar(title: account.displayName, icon: "person.fill", tint: HSTheme.accent, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HSTheme.primaryText)
                Text(account.email)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HSTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HSTheme.disclosure)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
