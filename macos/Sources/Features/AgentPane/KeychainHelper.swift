import Foundation
import Security

/// Helper for storing and retrieving API keys from macOS Keychain.
/// Keys are stored securely and persist across app launches, working
/// regardless of how the app is launched (Finder, Spotlight, terminal).
struct KeychainHelper {
    static let service = "com.geofftty.ai"

    enum KeychainError: Error {
        case encodingFailed
        case saveFailed(OSStatus)
        case deleteFailed(OSStatus)
        case unexpectedData
    }

    /// Save an API key to Keychain for the given provider account.
    /// - Parameters:
    ///   - key: The API key string to store
    ///   - account: Provider identifier (e.g., "openai", "anthropic", "ollama")
    static func save(key: String, account: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // First try to delete any existing key
        try? delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Load an API key from Keychain for the given provider account.
    /// - Parameter account: Provider identifier (e.g., "openai", "anthropic", "ollama")
    /// - Returns: The API key string, or nil if not found
    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    /// Delete an API key from Keychain for the given provider account.
    /// - Parameter account: Provider identifier (e.g., "openai", "anthropic", "ollama")
    static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Check if an API key exists in Keychain for the given provider account.
    /// - Parameter account: Provider identifier (e.g., "openai", "anthropic", "ollama")
    /// - Returns: true if a key exists
    static func exists(account: String) -> Bool {
        return load(account: account) != nil
    }

    /// List all provider accounts that have keys stored in Keychain.
    /// - Returns: Array of account names
    static func listAccounts() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
}
