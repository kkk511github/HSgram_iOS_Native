import Foundation

@MainActor
final class AuthStore: ObservableObject {
    enum Phase: Equatable {
        case enteringEmail
        case sendingCode
        case enteringCode(transactionID: String, emailPattern: String, codeLength: Int)
        case verifying
    }

    @Published private(set) var session: HSUserSession?
    @Published var phase: Phase = .enteringEmail
    @Published var errorMessage: String?

    let api: HSAPIClient

    init(api: HSAPIClient) {
        self.api = api
    }

    func sendCode(email: String) async {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.contains("@") else {
            self.errorMessage = "请输入有效邮箱地址。"
            return
        }
        self.phase = .sendingCode
        self.errorMessage = nil
        do {
            let response = try await api.sendEmailCode(email: normalized)
            self.phase = .enteringCode(transactionID: response.transactionID, emailPattern: response.emailPattern, codeLength: response.codeLength)
        } catch {
            self.errorMessage = error.localizedDescription
            self.phase = .enteringEmail
        }
    }

    func verify(email: String, code: String, transactionID: String, displayName: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else {
            self.errorMessage = "请输入邮箱验证码。"
            return
        }

        self.phase = .verifying
        self.errorMessage = nil
        do {
            self.session = try await api.verifyEmailCode(
                email: normalizedEmail,
                code: normalizedCode,
                transactionID: transactionID,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            self.errorMessage = error.localizedDescription
            self.phase = .enteringCode(transactionID: transactionID, emailPattern: normalizedEmail, codeLength: 6)
        }
    }

    func signOut() {
        self.session = nil
        self.phase = .enteringEmail
        self.errorMessage = nil
    }

    func replaceSessionProfile(displayName: String, email: String? = nil) {
        guard let current = session else {
            return
        }
        self.session = HSUserSession(
            token: current.token,
            userID: current.userID,
            displayName: displayName,
            email: email ?? current.email
        )
    }
}
