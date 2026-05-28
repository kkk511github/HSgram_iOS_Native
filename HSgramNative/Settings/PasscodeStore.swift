import CryptoKit
import Foundation
import LocalAuthentication
import Security

private struct HSPasscodeRecord: Codable {
    let salt: String
    let hash: String
    let passcodeLength: Int

    init?(salt: String, hash: String, passcodeLength: Int) {
        guard !salt.isEmpty, !hash.isEmpty else {
            return nil
        }
        self.salt = salt
        self.hash = hash
        self.passcodeLength = passcodeLength == 4 || passcodeLength == 6 ? passcodeLength : 6
    }
}

private struct PasscodeKeychainStore {
    private let service = "cloud.hsgram.native.passcode"
    private let account = "local-app-lock"

    func load() -> HSPasscodeRecord? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(HSPasscodeRecord.self, from: data)
    }

    @discardableResult
    func save(_ record: HSPasscodeRecord) -> Bool {
        guard let data = try? JSONEncoder().encode(record) else {
            return false
        }

        var item = baseQuery()
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(item as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let attributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            return SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary) == errSecSuccess
        }
        return status == errSecSuccess
    }

    func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

@MainActor
final class PasscodeStore: ObservableObject {
    enum UnlockResult {
        case unlocked
        case failed(remainingAttempts: Int)
        case throttled(seconds: Int)
    }

    @Published private(set) var isEnabled: Bool
    @Published private(set) var autoLockTimeoutSeconds: Int?
    @Published private(set) var biometricsEnabled: Bool
    @Published private(set) var passcodeLength: Int
    @Published private(set) var retryAllowedAt: Date?
    @Published var isLocked: Bool

    private let defaults: UserDefaults
    private let keychain: PasscodeKeychainStore
    private var passcodeRecord: HSPasscodeRecord?
    private var inactiveDate: Date?
    private var failedPasscodeAttempts: Int

    private enum Key {
        static let salt = "HSPasscodeSalt"
        static let hash = "HSPasscodeHash"
        static let passcodeLength = "HSPasscodeLength"
        static let autoLockTimeout = "HSPasscodeAutoLockTimeout"
        static let biometricsEnabled = "HSPasscodeBiometricsEnabled"
        static let biometricsDomainState = "HSPasscodeBiometricsDomainState"
        static let failedPasscodeAttempts = "HSPasscodeFailedAttempts"
        static let retryAllowedAt = "HSPasscodeRetryAllowedAt"
    }

    private static let retryLimit = 6
    private static let retryDelaySeconds: TimeInterval = 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let keychain = PasscodeKeychainStore()
        self.keychain = keychain
        let record = Self.loadPasscodeRecord(defaults: defaults, keychain: keychain)
        self.passcodeRecord = record
        let enabled = record != nil
        self.isEnabled = enabled
        self.isLocked = enabled
        self.biometricsEnabled = enabled && defaults.bool(forKey: Key.biometricsEnabled)
        let storedLength = defaults.integer(forKey: Key.passcodeLength)
        self.passcodeLength = record?.passcodeLength ?? (storedLength == 4 || storedLength == 6 ? storedLength : 6)
        self.failedPasscodeAttempts = defaults.integer(forKey: Key.failedPasscodeAttempts)

        if let retryAllowedAt = defaults.object(forKey: Key.retryAllowedAt) as? Date,
           retryAllowedAt > Date() {
            self.retryAllowedAt = retryAllowedAt
        } else {
            self.retryAllowedAt = nil
        }

        let storedTimeout = defaults.integer(forKey: Key.autoLockTimeout)
        if defaults.object(forKey: Key.autoLockTimeout) == nil {
            self.autoLockTimeoutSeconds = nil
        } else {
            self.autoLockTimeoutSeconds = storedTimeout > 0 ? storedTimeout : nil
        }

        if self.retryAllowedAt == nil {
            defaults.removeObject(forKey: Key.retryAllowedAt)
        }
        if self.biometricsEnabled && !Self.hasMatchingBiometricDomainState(defaults: defaults) {
            defaults.set(false, forKey: Key.biometricsEnabled)
            self.biometricsEnabled = false
        }
    }

    var statusText: String {
        isEnabled ? "开启" : "关闭"
    }

    var biometricsStatusText: String {
        biometricsEnabled ? "开启" : "关闭"
    }

    var passcodeLengthLabel: String {
        "\(passcodeLength) 位密码"
    }

    var biometricName: String {
        Self.biometricName()
    }

    var biometricSystemImage: String {
        Self.biometricSystemImage()
    }

    var canUseBiometrics: Bool {
        Self.canUseBiometrics()
    }

    var canUnlockWithBiometrics: Bool {
        biometricsEnabled && Self.canUseBiometrics() && Self.hasMatchingBiometricDomainState(defaults: defaults)
    }

    var biometricUnavailableReason: String? {
        if let reason = Self.biometricUnavailableReason() {
            return reason
        }
        if biometricsEnabled && !Self.hasMatchingBiometricDomainState(defaults: defaults) {
            return "\(biometricName) 信息已变化，请关闭后重新开启。"
        }
        return nil
    }

    var autoLockLabel: String {
        Self.label(for: autoLockTimeoutSeconds)
    }

    func setPasscode(_ passcode: String) {
        let salt = UUID().uuidString
        if let record = HSPasscodeRecord(salt: salt, hash: Self.hash(passcode: passcode, salt: salt), passcodeLength: passcode.count) {
            savePasscodeRecord(record)
        }
        isEnabled = true
        isLocked = false
        passcodeLength = passcode.count
        clearFailedPasscodeThrottle()
        if defaults.object(forKey: Key.autoLockTimeout) == nil {
            setAutoLockTimeout(60 * 60)
        }
    }

    func changePasscode(current: String, new: String) -> Bool {
        guard verify(current) else {
            return false
        }
        setPasscode(new)
        return true
    }

    func disable(passcode: String) -> Bool {
        guard verify(passcode) else {
            return false
        }
        defaults.removeObject(forKey: Key.salt)
        defaults.removeObject(forKey: Key.hash)
        defaults.removeObject(forKey: Key.passcodeLength)
        keychain.clear()
        passcodeRecord = nil
        defaults.removeObject(forKey: Key.autoLockTimeout)
        defaults.removeObject(forKey: Key.biometricsEnabled)
        defaults.removeObject(forKey: Key.biometricsDomainState)
        isEnabled = false
        isLocked = false
        autoLockTimeoutSeconds = nil
        biometricsEnabled = false
        passcodeLength = 6
        clearFailedPasscodeThrottle()
        return true
    }

    func verify(_ passcode: String) -> Bool {
        guard let record = passcodeRecord else {
            return true
        }
        let matches = Self.hash(passcode: passcode, salt: record.salt) == record.hash
        if matches {
            isLocked = false
            clearFailedPasscodeThrottle()
        }
        return matches
    }

    func setBiometricsEnabled(_ enabled: Bool) {
        guard isEnabled else {
            defaults.removeObject(forKey: Key.biometricsEnabled)
            defaults.removeObject(forKey: Key.biometricsDomainState)
            biometricsEnabled = false
            return
        }
        guard enabled else {
            defaults.set(false, forKey: Key.biometricsEnabled)
            defaults.removeObject(forKey: Key.biometricsDomainState)
            biometricsEnabled = false
            return
        }
        guard Self.canUseBiometrics(), let domainState = Self.currentBiometricDomainState() else {
            defaults.set(false, forKey: Key.biometricsEnabled)
            defaults.removeObject(forKey: Key.biometricsDomainState)
            biometricsEnabled = false
            return
        }
        defaults.set(domainState, forKey: Key.biometricsDomainState)
        defaults.set(true, forKey: Key.biometricsEnabled)
        biometricsEnabled = true
    }

    func enableBiometrics(reason: String) async -> Bool {
        guard isEnabled, Self.canUseBiometrics() else {
            setBiometricsEnabled(false)
            return false
        }
        guard let domainState = await Self.evaluateBiometrics(reason: reason) else {
            setBiometricsEnabled(false)
            return false
        }
        defaults.set(domainState, forKey: Key.biometricsDomainState)
        defaults.set(true, forKey: Key.biometricsEnabled)
        biometricsEnabled = true
        return true
    }

    func unlockWithBiometrics(reason: String) async -> Bool {
        guard isEnabled, biometricsEnabled, Self.canUseBiometrics(),
              let storedDomainState = defaults.data(forKey: Key.biometricsDomainState),
              Self.hasMatchingBiometricDomainState(defaults: defaults) else {
            return false
        }
        guard let domainState = await Self.evaluateBiometrics(reason: reason),
              domainState == storedDomainState else {
            setBiometricsEnabled(false)
            return false
        }
        isLocked = false
        clearFailedPasscodeThrottle()
        return true
    }

    func unlock(passcode: String) -> UnlockResult {
        clearExpiredPasscodeThrottle()
        if let retryAllowedAt {
            return .throttled(seconds: remainingRetrySeconds(until: retryAllowedAt))
        }
        guard verify(passcode) else {
            recordFailedPasscodeAttempt()
            if let retryAllowedAt {
                return .throttled(seconds: remainingRetrySeconds(until: retryAllowedAt))
            }
            return .failed(remainingAttempts: max(0, Self.retryLimit - failedPasscodeAttempts))
        }
        return .unlocked
    }

    func setAutoLockTimeout(_ seconds: Int?) {
        autoLockTimeoutSeconds = seconds
        defaults.set(seconds ?? 0, forKey: Key.autoLockTimeout)
    }

    func lockNow() {
        guard isEnabled else {
            return
        }
        isLocked = true
    }

    func noteInactive() {
        guard isEnabled else {
            return
        }
        inactiveDate = Date()
    }

    func resumeActive() {
        guard isEnabled, let inactiveDate, let autoLockTimeoutSeconds else {
            inactiveDate = nil
            return
        }
        if Date().timeIntervalSince(inactiveDate) >= Double(autoLockTimeoutSeconds) {
            isLocked = true
        }
        self.inactiveDate = nil
    }

    static func isValidPasscode(_ value: String) -> Bool {
        (value.count == 4 || value.count == 6) && value.allSatisfy(\.isNumber)
    }

    static func label(for timeout: Int?) -> String {
        switch timeout {
        case nil:
            return "关闭"
        case 60:
            return "离开 1 分钟后"
        case 5 * 60:
            return "离开 5 分钟后"
        case 60 * 60:
            return "离开 1 小时后"
        case 5 * 60 * 60:
            return "离开 5 小时后"
        default:
            return "自定义"
        }
    }

    private static func canUseBiometrics() -> Bool {
        var error: NSError?
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    private static func biometricName() -> String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        if #available(iOS 17.0, *), context.biometryType == .opticID {
            return "Face ID"
        }
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "生物识别"
        }
    }

    private static func biometricSystemImage() -> String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        if #available(iOS 17.0, *), context.biometryType == .opticID {
            return "faceid"
        }
        switch context.biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "person.badge.key"
        }
    }

    private static func biometricUnavailableReason() -> String? {
        var error: NSError?
        let context = LAContext()
        guard !context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        guard let error else {
            return "当前设备未开启 Face ID 或 Touch ID。"
        }
        switch LAError.Code(rawValue: error.code) {
        case .biometryNotAvailable:
            return "当前设备不支持 Face ID 或 Touch ID。"
        case .biometryNotEnrolled:
            return "请先在系统设置中录入 Face ID 或 Touch ID。"
        case .biometryLockout:
            return "Face ID 或 Touch ID 已锁定，请先使用系统密码解锁。"
        default:
            return error.localizedDescription
        }
    }

    private static func currentBiometricDomainState() -> Data? {
        var error: NSError?
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        return context.evaluatedPolicyDomainState
    }

    private static func hasMatchingBiometricDomainState(defaults: UserDefaults) -> Bool {
        guard let storedDomainState = defaults.data(forKey: Key.biometricsDomainState),
              let currentDomainState = currentBiometricDomainState() else {
            return false
        }
        return storedDomainState == currentDomainState
    }

    private static func evaluateBiometrics(reason: String) async -> Data? {
        let context = LAContext()
        context.localizedCancelTitle = "输入密码"
        do {
            let allowed = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            return allowed ? context.evaluatedPolicyDomainState : nil
        } catch {
            return nil
        }
    }

    private func recordFailedPasscodeAttempt() {
        failedPasscodeAttempts += 1
        defaults.set(failedPasscodeAttempts, forKey: Key.failedPasscodeAttempts)
        guard failedPasscodeAttempts >= Self.retryLimit else {
            return
        }
        let retryAllowedAt = Date().addingTimeInterval(Self.retryDelaySeconds)
        defaults.set(retryAllowedAt, forKey: Key.retryAllowedAt)
        self.retryAllowedAt = retryAllowedAt
    }

    private func clearExpiredPasscodeThrottle() {
        guard let retryAllowedAt, retryAllowedAt <= Date() else {
            return
        }
        clearFailedPasscodeThrottle()
    }

    private func clearFailedPasscodeThrottle() {
        failedPasscodeAttempts = 0
        retryAllowedAt = nil
        defaults.removeObject(forKey: Key.failedPasscodeAttempts)
        defaults.removeObject(forKey: Key.retryAllowedAt)
    }

    private func remainingRetrySeconds(until date: Date) -> Int {
        max(1, Int(ceil(date.timeIntervalSince(Date()))))
    }

    private static func loadPasscodeRecord(defaults: UserDefaults, keychain: PasscodeKeychainStore) -> HSPasscodeRecord? {
        if let record = keychain.load() {
            clearLegacyPasscode(defaults: defaults)
            return record
        }

        guard let salt = defaults.string(forKey: Key.salt),
              let hash = defaults.string(forKey: Key.hash) else {
            return nil
        }
        let storedLength = defaults.integer(forKey: Key.passcodeLength)
        guard let record = HSPasscodeRecord(salt: salt, hash: hash, passcodeLength: storedLength) else {
            return nil
        }
        if keychain.save(record) {
            clearLegacyPasscode(defaults: defaults)
        }
        return record
    }

    private func savePasscodeRecord(_ record: HSPasscodeRecord) {
        passcodeRecord = record
        if keychain.save(record) {
            Self.clearLegacyPasscode(defaults: defaults)
        } else {
            defaults.set(record.salt, forKey: Key.salt)
            defaults.set(record.hash, forKey: Key.hash)
            defaults.set(record.passcodeLength, forKey: Key.passcodeLength)
        }
    }

    private static func clearLegacyPasscode(defaults: UserDefaults) {
        defaults.removeObject(forKey: Key.salt)
        defaults.removeObject(forKey: Key.hash)
        defaults.removeObject(forKey: Key.passcodeLength)
    }

    private static func hash(passcode: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data("\(salt):\(passcode)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
