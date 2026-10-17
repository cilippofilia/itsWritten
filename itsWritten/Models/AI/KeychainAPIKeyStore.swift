//
//  KeychainAPIKeyStore.swift
//  itsWritten
//

import Foundation
import Security
import VoltaSDK

/// Keychain-backed `APIKeyStoring`. One generic-password item per vendor,
/// with the vendor's raw value as the account.
struct KeychainAPIKeyStore: APIKeyStoring {
    /// Error carrying the underlying Keychain `OSStatus`.
    struct KeychainError: Error, Equatable {
        let status: OSStatus
    }

    private let service: String

    init(service: String = "itsWritten.cloudAPIKeys") {
        self.service = service
    }

    func key(for vendor: CloudVendor) -> String? {
        var query = baseQuery(for: vendor)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func setKey(_ key: String?, for vendor: CloudVendor) throws {
        let query = baseQuery(for: vendor)

        guard let key else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError(status: status)
            }
            return
        }

        let data = Data(key.utf8)
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        default:
            throw KeychainError(status: updateStatus)
        }
    }

    private func baseQuery(for vendor: CloudVendor) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: vendor.rawValue
        ]
    }
}
