//
//  InMemoryAPIKeyStore.swift
//  itsWrittenTests
//

import Foundation
import VoltaSDK
@testable import itsWritten

/// Dictionary-backed key store for tests.
final class InMemoryAPIKeyStore: APIKeyStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var keys: [CloudVendor: String]

    init(keys: [CloudVendor: String] = [:]) {
        self.keys = keys
    }

    func key(for vendor: CloudVendor) -> String? {
        lock.withLock { keys[vendor] }
    }

    func setKey(_ key: String?, for vendor: CloudVendor) throws {
        lock.withLock { keys[vendor] = key }
    }
}
