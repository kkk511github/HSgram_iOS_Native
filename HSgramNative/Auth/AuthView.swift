import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var email = ""
    @State private var code = ""
    @State private var displayName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HSgram")
                            .font(.largeTitle.weight(.bold))
                        Text("Sign in or create your account with email.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    HSCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Email")
                                .font(.headline)
                            TextField("name@example.com", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))

                            if case .enteringCode(_, let emailPattern, let codeLength) = authStore.phase {
                                Text("Code sent to \(emailPattern)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                TextField("\(codeLength)-digit code", text: $code)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .padding(12)
                                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))

                                TextField("Display name", text: $displayName)
                                    .textContentType(.name)
                                    .padding(12)
                                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                            }

                            if let error = authStore.errorMessage {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(HSTheme.warning)
                            }

                            Button {
                                Task {
                                    await continueTapped()
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    if authStore.phase == .sendingCode || authStore.phase == .verifying {
                                        ProgressView()
                                    } else {
                                        Text(primaryButtonTitle)
                                            .font(.headline)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(authStore.phase == .sendingCode || authStore.phase == .verifying)
                        }
                    }

                }
                .padding(20)
            }
            .background(HSTheme.grouped)
        }
    }

    private var primaryButtonTitle: String {
        switch authStore.phase {
        case .enteringEmail:
            return "Send Email Code"
        case .sendingCode:
            return "Sending"
        case .enteringCode:
            return "Verify and Continue"
        case .verifying:
            return "Verifying"
        }
    }

    private func continueTapped() async {
        switch authStore.phase {
        case .enteringEmail:
            await authStore.sendCode(email: email)
        case .enteringCode(let transactionID, _, _):
            await authStore.verify(email: email, code: code, transactionID: transactionID, displayName: displayName)
        case .sendingCode, .verifying:
            break
        }
    }
}
