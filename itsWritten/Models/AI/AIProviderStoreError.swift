//
//  AIProviderStoreError.swift
//  itsWritten
//

import Foundation

/// Errors thrown by `AIProviderStore` key management.
enum AIProviderStoreError: Error, Equatable {
    /// The store was created without a key store, so keys cannot be changed.
    case keyStoreUnavailable
}
