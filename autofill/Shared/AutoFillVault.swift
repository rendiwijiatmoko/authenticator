//
//  AutoFillVault.swift
//  Authenticator
//
//  Created by Rendi  on 06/10/26.
//

import Foundation
import Security

/// Both targets use the same Keychain access group; secrets never go into UserDefaults.
enum AutoFillVault {
    static let service = "xyz.0xmwehehe.Authenticator.vault"

    static func query(shared: Bool = true) throws -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "accounts",
            kSecAttrSynchronizable as String: false
        ]
        if shared {
            guard let group = Bundle.main.object(forInfoDictionaryKey: "AutoFillKeychainAccessGroup") as? String,
                  !group.isEmpty, !group.contains("$(") else {
                throw AutoFillVaultError(status: errSecMissingEntitlement)
            }
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    static func load(shared: Bool = true) throws -> [TOTPAccount]? {
        var request = try query(shared: shared)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw AutoFillVaultError(status: status)
        }
        let accounts = try JSONDecoder().decode([TOTPAccount].self, from: data)
        guard accounts.allSatisfy(\.isValid) else { throw AccountError.unsupportedParameters }
        return accounts
    }

    static func save(_ accounts: [TOTPAccount]) throws {
        let query = try query()
        let data = try JSONEncoder().encode(accounts)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var request = query
            request[kSecValueData as String] = data
            request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(request as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw AutoFillVaultError(status: status) }
    }
}

struct AutoFillVaultError: LocalizedError {
    var status: OSStatus
    var errorDescription: String? {
        (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain error (\(status))."
    }
}
