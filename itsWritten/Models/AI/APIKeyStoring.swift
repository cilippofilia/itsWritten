//
//  APIKeyStoring.swift
//  itsWritten
//

import VoltaSDK

/// Storage for the user's cloud provider API keys.
protocol APIKeyStoring: Sendable {
    /// Returns the stored key for `vendor`, or `nil` if none is saved.
    func key(for vendor: CloudVendor) -> String?

    /// Saves `key` for `vendor`. Passing `nil` deletes any stored key.
    func setKey(_ key: String?, for vendor: CloudVendor) throws
}
