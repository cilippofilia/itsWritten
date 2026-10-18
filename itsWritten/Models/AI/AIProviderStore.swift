//
//  AIProviderStore.swift
//  itsWritten
//

import Foundation
import Observation
import VoltaSDK

/// Owns the app's `AIOrchestrator` and the user's cloud API keys.
///
/// Any key change rebuilds the orchestrator so new accounts take effect immediately.
@MainActor
@Observable
final class AIProviderStore {
    /// Gate for cloud privacy downgrades.
    let consent: CloudConsentCoordinator

    /// The orchestrator every model call should go through.
    private(set) var orchestrator: AIOrchestrator

    /// An orchestrator that never leaves the device. Used to retry after an
    /// on-device guardrail violation, so blocked content is never sent to the cloud.
    private(set) var onDeviceOrchestrator: AIOrchestrator

    /// Vendors that currently have a stored key.
    private(set) var configuredVendors: Set<CloudVendor>

    /// Whether at least one cloud vendor can serve as a fallback.
    var hasCloudFallback: Bool { !configuredVendors.isEmpty }

    @ObservationIgnored private let keyStore: (any APIKeyStoring)?

    init(
        keyStore: any APIKeyStoring = KeychainAPIKeyStore(),
        consent: CloudConsentCoordinator? = nil
    ) {
        let consent = consent ?? CloudConsentCoordinator()
        self.keyStore = keyStore
        self.consent = consent
        let keys = Self.storedKeys(in: keyStore)
        self.configuredVendors = Set(keys.keys)
        let configuration = Self.configuration(keys: keys, consent: consent)
        self.orchestrator = AIOrchestrator(configuration: configuration)
        self.onDeviceOrchestrator = AIOrchestrator(configuration: Self.onDeviceConfiguration(from: configuration))
    }

    /// Test-only initializer: no key store, so `setKey` and `removeKey` throw.
    /// `onDeviceOrchestrator` defaults to `orchestrator`.
    init(
        orchestrator: AIOrchestrator,
        consent: CloudConsentCoordinator,
        onDeviceOrchestrator: AIOrchestrator? = nil
    ) {
        self.keyStore = nil
        self.consent = consent
        self.orchestrator = orchestrator
        self.onDeviceOrchestrator = onDeviceOrchestrator ?? orchestrator
        self.configuredVendors = []
    }

    /// Saves `key` for `vendor` after trimming whitespace. An empty key removes it.
    func setKey(_ key: String, for vendor: CloudVendor) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try update(trimmed.isEmpty ? nil : trimmed, for: vendor)
    }

    /// Deletes the stored key for `vendor`.
    func removeKey(for vendor: CloudVendor) throws {
        try update(nil, for: vendor)
    }

    /// Whether a key is stored for `vendor`.
    func hasKey(for vendor: CloudVendor) -> Bool {
        configuredVendors.contains(vendor)
    }

    /// Builds the orchestrator configuration for the given keys.
    static func configuration(
        keys: [CloudVendor: String],
        consent: CloudConsentCoordinator
    ) -> AIConfiguration {
        var configuration = AIConfiguration()
        configuration.enableOnDevice = true
        configuration.onDeviceModel = AppLanguageModel.model
        configuration.enablePrivateCloudCompute = true
        configuration.preference = .preferOnDevice
        configuration.developerKey = nil
        configuration.userAccounts = CloudVendor.allCases.compactMap { vendor in
            keys[vendor].map { UserAccount(vendor: vendor, apiKey: $0) }
        }
        configuration.privacyDisclosure = .askOnPrivacyChange { await consent.request($0) }
        return configuration
    }

    /// Derives a configuration that only ever uses the on-device model: no cloud
    /// accounts, no Private Cloud Compute, `.onDeviceOnly` preference.
    static func onDeviceConfiguration(from configuration: AIConfiguration) -> AIConfiguration {
        var onDevice = configuration
        onDevice.preference = .onDeviceOnly
        onDevice.userAccounts = []
        onDevice.enablePrivateCloudCompute = false
        return onDevice
    }

    private func update(_ key: String?, for vendor: CloudVendor) throws {
        guard let keyStore else { throw AIProviderStoreError.keyStoreUnavailable }
        try keyStore.setKey(key, for: vendor)
        let keys = Self.storedKeys(in: keyStore)
        configuredVendors = Set(keys.keys)
        let configuration = Self.configuration(keys: keys, consent: consent)
        orchestrator = AIOrchestrator(configuration: configuration)
        onDeviceOrchestrator = AIOrchestrator(configuration: Self.onDeviceConfiguration(from: configuration))
    }

    private static func storedKeys(in keyStore: any APIKeyStoring) -> [CloudVendor: String] {
        var keys: [CloudVendor: String] = [:]
        for vendor in CloudVendor.allCases {
            if let key = keyStore.key(for: vendor), !key.isEmpty {
                keys[vendor] = key
            }
        }
        return keys
    }
}
