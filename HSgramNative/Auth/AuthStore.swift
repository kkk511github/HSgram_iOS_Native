import Foundation

@MainActor
final class AuthStore: ObservableObject {
    enum Phase: Equatable {
        case enteringEmail
        case sendingCode
        case enteringCode(transactionID: String, emailPattern: String, codeLength: Int)
        case verifying
        case enteringSignUp(email: String, transactionID: String, termsOfService: HSTermsOfService?)
        case signingUp(email: String, transactionID: String, termsOfService: HSTermsOfService?)
        case enteringPassword(email: String, hint: String?)
        case verifyingPassword
        case requestingPasswordRecovery(email: String, hint: String?)
        case enteringRecoveryCode(email: String, emailPattern: String, codeLength: Int)
        case recoveringPassword
    }

    @Published private(set) var session: HSUserSession?
    @Published private(set) var savedAccounts: [HSUserSession]
    @Published var phase: Phase = .enteringEmail
    @Published var errorMessage: String?

    let api: HSAPIClient
    private let sessionStore: AuthSessionStore

    init(api: HSAPIClient, sessionStore: AuthSessionStore = AuthSessionStore()) {
        self.api = api
        self.sessionStore = sessionStore
        self.session = sessionStore.load()
        self.savedAccounts = sessionStore.loadAccounts()
    }

    func sendCode(email: String) async {
        let normalized = normalizeLoginEmail(email)
        guard normalized.contains("@") else {
            self.errorMessage = "请输入有效邮箱地址。"
            return
        }
        self.phase = .sendingCode
        self.errorMessage = nil
        do {
            let response = try await api.sendEmailCode(email: normalized)
            self.phase = .enteringCode(transactionID: response.transactionID, emailPattern: response.emailPattern, codeLength: response.codeLength)
        } catch let error as HSAPIError where error.serverCode == "SESSION_PASSWORD_NEEDED" {
            self.phase = .enteringPassword(email: normalized, hint: Self.passwordHint(from: error))
            self.errorMessage = nil
        } catch {
            self.errorMessage = Self.loginErrorMessage(error)
            self.phase = .enteringEmail
        }
    }

    func verify(email: String, code: String, transactionID: String, displayName: String) async {
        let normalizedEmail = normalizeLoginEmail(email)
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else {
            self.errorMessage = "请输入邮箱验证码。"
            return
        }

        self.phase = .verifying
        self.errorMessage = nil
        do {
            let session = try await api.verifyEmailCode(
                email: normalizedEmail,
                code: normalizedCode,
                transactionID: transactionID,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            self.session = session
            self.sessionStore.save(session)
            self.savedAccounts = sessionStore.loadAccounts()
        } catch let error as HSAPIError where error.serverCode == "SESSION_PASSWORD_NEEDED" {
            self.phase = .enteringPassword(email: normalizedEmail, hint: Self.passwordHint(from: error))
            self.errorMessage = nil
        } catch let error as HSAPIError where error.serverCode == "SIGN_UP_REQUIRED" || error.serverCode == "PHONE_NUMBER_UNOCCUPIED" {
            self.phase = .enteringSignUp(
                email: normalizedEmail,
                transactionID: transactionID,
                termsOfService: error.signUpTermsOfService
            )
            self.errorMessage = nil
        } catch {
            self.errorMessage = Self.loginErrorMessage(error)
            self.phase = .enteringCode(transactionID: transactionID, emailPattern: normalizedEmail, codeLength: 6)
        }
    }

    func signUp(email: String, transactionID: String, termsOfService: HSTermsOfService?, firstName: String, lastName: String, inviteCode: String, avatarData: Data?) async {
        let normalizedEmail = normalizeLoginEmail(email)
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInvite = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFirstName.isEmpty else {
            self.errorMessage = "请输入名字。"
            return
        }

        self.phase = .signingUp(email: normalizedEmail, transactionID: transactionID, termsOfService: termsOfService)
        self.errorMessage = nil
        do {
            let session = try await api.signUp(
                email: normalizedEmail,
                transactionID: transactionID,
                displayName: [trimmedFirstName, trimmedLastName].filter { !$0.isEmpty }.joined(separator: " "),
                inviteCode: trimmedInvite
            )
            if let avatarData {
                try? await api.uploadProfilePhoto(data: avatarData, session: session)
            }
            self.session = session
            self.sessionStore.save(session)
            self.savedAccounts = sessionStore.loadAccounts()
        } catch {
            self.errorMessage = Self.loginErrorMessage(error)
            self.phase = .enteringSignUp(email: normalizedEmail, transactionID: transactionID, termsOfService: termsOfService)
        }
    }

    func verifyPassword(email: String, password: String) async {
        let normalizedEmail = normalizeLoginEmail(email)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPassword.isEmpty else {
            self.errorMessage = "请输入登录密码。"
            return
        }

        self.phase = .verifyingPassword
        self.errorMessage = nil
        do {
            let session = try await api.verifyLoginPassword(email: normalizedEmail, password: normalizedPassword)
            self.session = session
            self.sessionStore.save(session)
            self.savedAccounts = sessionStore.loadAccounts()
        } catch {
            self.errorMessage = Self.loginErrorMessage(error)
            self.phase = .enteringPassword(email: normalizedEmail, hint: nil)
        }
    }

    func requestPasswordRecovery(email: String, hint: String?) async {
        let normalizedEmail = normalizeLoginEmail(email)
        guard normalizedEmail.contains("@") else {
            self.errorMessage = "请输入有效邮箱地址。"
            return
        }

        self.phase = .requestingPasswordRecovery(email: normalizedEmail, hint: hint)
        self.errorMessage = nil
        do {
            let response = try await api.requestPasswordRecovery(email: normalizedEmail)
            self.phase = .enteringRecoveryCode(
                email: normalizedEmail,
                emailPattern: response.emailPattern,
                codeLength: max(response.codeLength, 1)
            )
        } catch {
            self.errorMessage = Self.loginErrorMessage(error)
            self.phase = .enteringPassword(email: normalizedEmail, hint: hint)
        }
    }

    func recoverPassword(email: String, code: String) async {
        let normalizedEmail = normalizeLoginEmail(email)
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else {
            self.errorMessage = "请输入恢复验证码。"
            return
        }

        let recoveryContext: (pattern: String, length: Int)
        if case let .enteringRecoveryCode(_, emailPattern, codeLength) = phase {
            recoveryContext = (emailPattern, max(codeLength, 1))
        } else {
            recoveryContext = (normalizedEmail, 6)
        }

        self.phase = .recoveringPassword
        self.errorMessage = nil
        do {
            let session = try await api.recoverPassword(email: normalizedEmail, code: normalizedCode)
            self.session = session
            self.sessionStore.save(session)
            self.savedAccounts = sessionStore.loadAccounts()
        } catch {
            self.errorMessage = Self.loginErrorMessage(error)
            self.phase = .enteringRecoveryCode(
                email: normalizedEmail,
                emailPattern: recoveryContext.pattern,
                codeLength: recoveryContext.length
            )
        }
    }

    func signOut() {
        let nextSession: HSUserSession?
        if let session {
            nextSession = sessionStore.removeAccount(userID: session.userID)
        } else {
            sessionStore.clear()
            nextSession = nil
        }
        self.session = nextSession
        self.savedAccounts = sessionStore.loadAccounts()
        self.phase = .enteringEmail
        self.errorMessage = nil
    }

    func beginAddingAccount() {
        if let session {
            self.sessionStore.save(session)
        }
        self.sessionStore.clear()
        self.session = nil
        self.savedAccounts = sessionStore.loadAccounts()
        self.phase = .enteringEmail
        self.errorMessage = nil
    }

    func switchAccount(userID: Int64) {
        guard let selected = sessionStore.switchAccount(userID: userID) else {
            return
        }
        self.session = selected
        self.savedAccounts = sessionStore.loadAccounts()
        self.phase = .enteringEmail
        self.errorMessage = nil
    }

    func removeSavedAccount(userID: Int64) {
        self.session = sessionStore.removeAccount(userID: userID)
        self.savedAccounts = sessionStore.loadAccounts()
        self.phase = .enteringEmail
        self.errorMessage = nil
    }

    func resetToEmailEntry() {
        self.phase = .enteringEmail
        self.errorMessage = nil
    }

    func returnToPasswordEntry(email: String, hint: String? = nil) {
        self.phase = .enteringPassword(email: normalizeLoginEmail(email), hint: hint)
        self.errorMessage = nil
    }

    func replaceSessionProfile(displayName: String, email: String? = nil) {
        guard let current = session else {
            return
        }
        let updatedSession = HSUserSession(
            token: current.token,
            userID: current.userID,
            displayName: displayName,
            email: email ?? current.email
        )
        self.session = updatedSession
        self.sessionStore.save(updatedSession)
        self.savedAccounts = sessionStore.loadAccounts()
    }

    private func normalizeLoginEmail(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }

    private static func passwordHint(from error: HSAPIError) -> String? {
        guard let message = error.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty,
              message != error.serverCode,
              message != "SESSION_PASSWORD_NEEDED" else {
            return nil
        }
        return message
    }

    private static func loginErrorMessage(_ error: Error) -> String {
        if let apiError = error as? HSAPIError, apiError.serverCode == "LEGACY_MTPROTO_REQUIRED" {
            return "线上 HSgram 邮箱登录必须走 MTProto auth.sendCode/auth.signIn，请确认当前构建未启用本地 /v1 测试桥。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "NATIVE_REST_FACADE_NOT_DEPLOYED" {
            return "当前线上 HSgram server 没有 native /v1 REST facade，请关闭 HS_NATIVE_REST_BRIDGE 后使用默认 MTProto 生产协议。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "LEGACY_TRANSPORT_PENDING" {
            return "该操作还没有映射到 native MTProto 生产协议；登录主链路已接入 auth.sendCode/auth.signIn。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "SESSION_PASSWORD_NEEDED" {
            return "该账号已启用登录密码，请输入密码继续登录。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "PASSWORD_HASH_INVALID" {
            return "密码不正确，请重新输入。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "KDF_ERROR" {
            return "密码校验参数生成失败，请稍后重试。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "PASSWORD_RECOVERY_NA" {
            return "这个账号没有可用的恢复邮箱，请返回并联系支持。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "PASSWORD_RECOVERY_EXPIRED" {
            return "恢复验证码已过期，请重新请求。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "CODE_INVALID" {
            return "恢复验证码不正确，请检查后重试。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "SIGN_UP_REQUIRED" {
            return "该邮箱需要创建 HSgram 账号。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "FIRSTNAME_INVALID" {
            return "显示名称无效，请重新输入。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "LASTNAME_INVALID" {
            return "姓氏或邀请码参数无效，请重新输入。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "INVITE_CODE_REQUIRED" {
            return "当前注册需要邀请码。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "INVITE_CODE_INVALID" {
            return "邀请码无效，请检查后重试。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "INVITE_CODE_DISABLED" {
            return "该邀请码已停用。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "INVITE_CODE_LIMIT_REACHED" {
            return "该邀请码使用次数已达上限。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "INVITE_CODE_BUSY" {
            return "邀请码正在处理，请稍后重试。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode?.hasPrefix("FLOOD_WAIT") == true {
            return "请求过于频繁，请稍后再试。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "HTTP_405" {
            return "邮箱登录请求打到了未发布的 /v1 测试路由（HTTP 405）。请关闭 HS_NATIVE_REST_BRIDGE 使用默认 MTProto 登录。"
        }
        if let apiError = error as? HSAPIError, apiError.serverCode == "HTTP_404" {
            return "邮箱登录接口不存在（HTTP 404）。请关闭本地 REST 桥测试模式，使用默认 MTProto 登录。"
        }
        return error.localizedDescription
    }
}

@MainActor
final class HSSyncStore: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var lastErrorMessage: String?

    private let api: HSAPIClient
    private let stateStore: HSSyncStateStore
    private var task: Task<Void, Never>?
    private var runningUserID: Int64?
    private var runGeneration = 0

    init(api: HSAPIClient, stateStore: HSSyncStateStore = HSSyncStateStore()) {
        self.api = api
        self.stateStore = stateStore
    }

    func start(session: HSUserSession?) {
        guard let session else {
            stop()
            return
        }
        if isRunning, runningUserID == session.userID {
            return
        }
        stop()
        runGeneration += 1
        let generation = runGeneration
        runningUserID = session.userID
        isRunning = true
        task = Task { [weak self] in
            await self?.run(session: session, generation: generation)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        runGeneration += 1
        runningUserID = nil
        isRunning = false
    }

    private func run(session: HSUserSession, generation: Int) async {
        var retryDelay: UInt64 = 5
        while !Task.isCancelled {
            let nextDelay: UInt64
            do {
                nextDelay = try await syncOnce(session: session)
                retryDelay = 5
            } catch is CancellationError {
                break
            } catch {
                lastErrorMessage = error.localizedDescription
                nextDelay = retryDelay
                retryDelay = min(retryDelay * 2, 30)
            }

            do {
                try await Task.sleep(nanoseconds: nextDelay * 1_000_000_000)
            } catch {
                break
            }
        }
        if runGeneration == generation {
            task = nil
            runningUserID = nil
            isRunning = false
        }
    }

    @discardableResult
    private func syncOnce(session: HSUserSession) async throws -> UInt64 {
        if let state = stateStore.load(userID: session.userID) {
            let difference = try await api.syncDifference(since: state, session: session)
            stateStore.save(difference.state, userID: session.userID)
            lastSyncedAt = Date()
            lastErrorMessage = nil
            if difference.requiresRefresh {
                postSyncChange(difference)
            }
            return difference.isSlice ? 1 : 8
        } else {
            let state = try await api.syncState(session: session)
            stateStore.save(state, userID: session.userID)
            lastSyncedAt = Date()
            lastErrorMessage = nil
            return 3
        }
    }

    private func postSyncChange(_ difference: HSSyncDifference) {
        var userInfo: [String: Any] = [
            "full_refresh": difference.isTooLong
        ]
        if !difference.changedDialogIDs.isEmpty {
            userInfo["dialog_ids"] = difference.changedDialogIDs
        }
        if !difference.readOutboxMaxIDsByDialogID.isEmpty {
            userInfo["read_outbox_max_ids"] = difference.readOutboxMaxIDsByDialogID
        }
        NotificationCenter.default.post(name: .hsNativeSyncDidChange, object: self, userInfo: userInfo)
    }
}

struct HSSyncStateStore {
    private let defaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(userID: Int64) -> HSSyncState? {
        guard let data = defaults.data(forKey: key(userID: userID)) else {
            return nil
        }
        return try? decoder.decode(HSSyncState.self, from: data)
    }

    func save(_ state: HSSyncState, userID: Int64) {
        guard let data = try? encoder.encode(state) else {
            return
        }
        defaults.set(data, forKey: key(userID: userID))
    }

    func clear(userID: Int64) {
        defaults.removeObject(forKey: key(userID: userID))
    }

    private func key(userID: Int64) -> String {
        "hs.native.sync.state.\(userID)"
    }
}
