import Foundation
import Security

public protocol APIKeyStoring: Sendable {
    func saveAPIKey(_ key: String) async throws
    func loadAPIKey() async throws -> String?
    func deleteAPIKey() async throws
}

public enum KeychainStoreError: Error, Equatable {
    case invalidKey
    case unexpectedStatus(OSStatus)
    case invalidStoredValue
}

extension KeychainStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidKey: "Enter a valid OpenAI API key."
        case .unexpectedStatus: "macOS Keychain could not complete the request."
        case .invalidStoredValue: "The stored API key is unreadable. Delete it and save a new one."
        }
    }
}

public actor KeychainStore: APIKeyStoring {
    private let service: String
    private let account: String

    public init(
        service: String = "com.desktopcleaner.openai",
        account: String = "user-api-key"
    ) {
        self.service = service
        self.account = account
    }

    public func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("sk-"), trimmed.count >= 20,
              let data = trimmed.data(using: .utf8) else {
            throw KeychainStoreError.invalidKey
        }

        let base = baseQuery()
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
    }

    public func loadAPIKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
        guard let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw KeychainStoreError.invalidStoredValue
        }
        return key
    }

    public func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
