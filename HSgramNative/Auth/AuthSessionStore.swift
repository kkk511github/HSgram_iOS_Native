import Foundation
import Security

struct AuthSessionStore {
    private let service = "cloud.hsgram.native.session"
    private let currentAccount = "current"
    private let accountsAccount = "accounts"

    func load() -> HSUserSession? {
        readValue(HSUserSession.self, account: currentAccount)
    }

    func loadAccounts() -> [HSUserSession] {
        let accounts = readValue([HSUserSession].self, account: accountsAccount) ?? []
        guard let current = load() else {
            return accounts
        }
        return mergedAccounts(primary: current, accounts: accounts)
    }

    func save(_ session: HSUserSession) {
        writeValue(session, account: currentAccount)
        saveAccounts(mergedAccounts(primary: session, accounts: loadAccounts()))
    }

    func clear() {
        SecItemDelete(baseQuery(account: currentAccount) as CFDictionary)
    }

    func removeAccount(userID: Int64) -> HSUserSession? {
        let remaining = loadAccounts().filter { $0.userID != userID }
        saveAccounts(remaining)
        if load()?.userID == userID {
            if let next = remaining.first {
                writeValue(next, account: currentAccount)
                return next
            } else {
                clear()
            }
        }
        return load()
    }

    func switchAccount(userID: Int64) -> HSUserSession? {
        guard let selected = loadAccounts().first(where: { $0.userID == userID }) else {
            return nil
        }
        writeValue(selected, account: currentAccount)
        saveAccounts(mergedAccounts(primary: selected, accounts: loadAccounts()))
        return selected
    }

    private func saveAccounts(_ accounts: [HSUserSession]) {
        writeValue(accounts, account: accountsAccount)
    }

    private func mergedAccounts(primary: HSUserSession, accounts: [HSUserSession]) -> [HSUserSession] {
        [primary] + accounts.filter { $0.userID != primary.userID }
    }

    private func readValue<Value: Decodable>(_ type: Value.Type, account: String) -> Value? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    private func writeValue<Value: Encodable>(_ value: Value, account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }

        var item = baseQuery(account: account)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
