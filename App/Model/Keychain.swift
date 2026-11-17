import Foundation
import Security

/// One secret in the system's key store, kept on this device only.
struct Keychain {
    let service: String
    private let account = "secret"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func read() -> String? {
        var query = query
        query[kSecReturnData as String] = true
        var found: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess,
              let data = found as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Returns whether the secret is stored now.
    @discardableResult
    func write(_ secret: String) -> Bool {
        remove()
        var item = query
        item[kSecValueData as String] = Data(secret.utf8)
        // Readable for a sync in the background, never part of a backup.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    func remove() {
        SecItemDelete(query as CFDictionary)
    }
}
