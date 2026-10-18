//
//  AIProviderStoreTests.swift
//  itsWrittenTests
//

import VoltaSDK
import XCTest
@testable import itsWritten

@MainActor
final class AIProviderStoreTests: XCTestCase {
    private func makeConsent() -> CloudConsentCoordinator {
        CloudConsentCoordinator(defaults: UserDefaults(suiteName: "AIProviderStoreTests") ?? .standard)
    }

    func testConfigurationHasNoDeveloperKeyAndPrefersOnDevice() {
        let config = AIProviderStore.configuration(keys: [:], consent: makeConsent())
        XCTAssertNil(config.developerKey)
        XCTAssertEqual(config.preference, .preferOnDevice)
        XCTAssertTrue(config.enableOnDevice)
    }

    func testConfigurationAsksOnPrivacyChange() {
        let config = AIProviderStore.configuration(keys: [:], consent: makeConsent())
        guard case .askOnPrivacyChange = config.privacyDisclosure else {
            return XCTFail("Expected askOnPrivacyChange")
        }
    }

    func testUserAccountsFollowVendorOrder() {
        let config = AIProviderStore.configuration(
            keys: [.gemini: "g", .openAI: "o"],
            consent: makeConsent()
        )
        XCTAssertEqual(config.userAccounts.map(\.vendor), [.openAI, .gemini])
    }

    func testSetKeyTrimsAndEmptyRemoves() throws {
        let keyStore = InMemoryAPIKeyStore()
        let store = AIProviderStore(keyStore: keyStore, consent: makeConsent())
        try store.setKey("  sk-1\n", for: .openAI)
        XCTAssertEqual(keyStore.key(for: .openAI), "sk-1")
        XCTAssertTrue(store.hasKey(for: .openAI))
        try store.setKey("   ", for: .openAI)
        XCTAssertFalse(store.hasKey(for: .openAI))
        XCTAssertNil(keyStore.key(for: .openAI))
    }

    func testSetKeyRebuildsOrchestrator() throws {
        let store = AIProviderStore(keyStore: InMemoryAPIKeyStore(), consent: makeConsent())
        let before = store.orchestrator
        try store.setKey("sk-1", for: .openAI)
        XCTAssertFalse(store.orchestrator === before)
    }

    func testConfiguredVendorsLoadFromStoreAtInit() {
        let keyStore = InMemoryAPIKeyStore(keys: [.anthropic: "a"])
        let store = AIProviderStore(keyStore: keyStore, consent: makeConsent())
        XCTAssertEqual(store.configuredVendors, [.anthropic])
        XCTAssertTrue(store.hasCloudFallback)
    }

    func testSetKeyThrowsWithoutKeyStore() {
        let store = AIProviderStore(
            orchestrator: AIOrchestrator(providers: []),
            consent: makeConsent()
        )
        XCTAssertThrowsError(try store.setKey("x", for: .openAI))
        XCTAssertThrowsError(try store.removeKey(for: .openAI))
    }

    func testOnDeviceConfigurationNeverLeavesTheDevice() {
        let base = AIProviderStore.configuration(keys: [.anthropic: "a", .openAI: "o"], consent: makeConsent())
        let config = AIProviderStore.onDeviceConfiguration(from: base)
        XCTAssertEqual(config.preference, .onDeviceOnly)
        XCTAssertTrue(config.userAccounts.isEmpty)
        XCTAssertFalse(config.enablePrivateCloudCompute)
        XCTAssertTrue(config.enableOnDevice)
    }

    func testSetKeyRebuildsOnDeviceOrchestrator() throws {
        let store = AIProviderStore(keyStore: InMemoryAPIKeyStore(), consent: makeConsent())
        let before = store.onDeviceOrchestrator
        try store.setKey("sk-1", for: .openAI)
        XCTAssertFalse(store.onDeviceOrchestrator === before)
    }

    func testTestInitDefaultsOnDeviceOrchestratorToMain() {
        let orchestrator = AIOrchestrator(providers: [])
        let store = AIProviderStore(orchestrator: orchestrator, consent: makeConsent())
        XCTAssertTrue(store.onDeviceOrchestrator === orchestrator)
    }
}
