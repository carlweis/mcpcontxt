//
//  KeychainService.swift
//  MCPContxt
//
//  Secure credential storage using macOS Keychain
//

import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "com.mcpcontxt.credentials"

    private init() {}

    func store(credential: String, for serverID: UUID, key: String) throws {
        let account = "\(serverID.uuidString):\(key)"

        // Delete existing item first
        try? delete(for: serverID, key: key)

        guard let data = credential.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    func retrieve(for serverID: UUID, key: String) throws -> String? {
        let account = "\(serverID.uuidString):\(key)"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.retrieveFailed(status)
        }

        guard let data = result as? Data,
              let credential = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }

        return credential
    }

    func delete(for serverID: UUID, key: String) throws {
        let account = "\(serverID.uuidString):\(key)"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    func deleteAll(for serverID: UUID) throws {
        let accountPrefix = serverID.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        // We need to find all items and delete ones matching this server
        var queryWithReturn = query
        queryWithReturn[kSecReturnAttributes as String] = true
        queryWithReturn[kSecMatchLimit as String] = kSecMatchLimitAll

        var result: AnyObject?
        let status = SecItemCopyMatching(queryWithReturn as CFDictionary, &result)

        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return
        }

        for item in items {
            if let account = item[kSecAttrAccount as String] as? String,
               account.hasPrefix(accountPrefix) {
                var deleteQuery = query
                deleteQuery[kSecAttrAccount as String] = account
                SecItemDelete(deleteQuery as CFDictionary)
            }
        }
    }

    func update(credential: String, for serverID: UUID, key: String) throws {
        let account = "\(serverID.uuidString):\(key)"

        guard let data = credential.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // Item doesn't exist, create it
            try store(credential: credential, for: serverID, key: key)
        } else if status != errSecSuccess {
            throw KeychainError.updateFailed(status)
        }
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case updateFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode credential"
        case .decodingFailed:
            return "Failed to decode credential"
        case .storeFailed(let status):
            return "Failed to store credential: \(status)"
        case .retrieveFailed(let status):
            return "Failed to retrieve credential: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete credential: \(status)"
        case .updateFailed(let status):
            return "Failed to update credential: \(status)"
        }
    }
}

// MARK: - Credential Keys

enum CredentialKey: String {
    case authorizationHeader = "authorization"
    case apiKey = "apiKey"
    case accessToken = "accessToken"
    case bearerToken = "bearerToken"
}
