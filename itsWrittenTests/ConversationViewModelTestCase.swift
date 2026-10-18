//
//  ConversationViewModelTestCase.swift
//  itsWrittenTests
//

import FoundationModels
import SwiftData
import Synchronization
import VoltaSDK
import XCTest
@testable import itsWritten

/// Shared setup for view model tests that drive mock providers through a real
/// `AIOrchestrator` and an in-memory SwiftData store.
@available(iOS 26.0, *)
@MainActor
class ConversationViewModelTestCase: XCTestCase {

    /// A store whose orchestrator has no providers, for tests that never call a model.
    func idleStore() -> AIProviderStore {
        AIProviderStore(orchestrator: AIOrchestrator(providers: []), consent: CloudConsentCoordinator())
    }

    var container: ModelContainer?
    var consentAnswerer: Task<Void, Never>?
    /// How many consent prompts the background answerer has answered.
    var answeredConsentPrompts = 0

    override func tearDown() async throws {
        consentAnswerer?.cancel()
        consentAnswerer = nil
        container = nil
        try await super.tearDown()
    }

    /// Builds a configured view model backed by `providers`. When `consentAnswer`
    /// is non-nil, a background task answers every consent prompt with it.
    func makeViewModel(
        providers: [any ModelProvider],
        onDeviceProviders: [any ModelProvider]? = nil,
        consentAnswer: Bool?,
        alwaysAllowed: ConsentDestination? = nil,
        configuredVendors: Set<CloudVendor> = []
    ) throws -> (ConversationViewModel, CloudConsentCoordinator) {
        let consent = CloudConsentCoordinator(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let orchestrator = AIOrchestrator(
            providers: providers,
            privacyDisclosure: .askOnPrivacyChange { await consent.request($0) }
        )
        if let alwaysAllowed {
            consent.setAlwaysAllowed(true, for: alwaysAllowed)
        }
        let onDeviceOrchestrator = onDeviceProviders.map { AIOrchestrator(providers: $0) }
        let store = AIProviderStore(
            orchestrator: orchestrator,
            consent: consent,
            onDeviceOrchestrator: onDeviceOrchestrator,
            configuredVendors: configuredVendors
        )

        let schema = Schema([ChatThread.self, ChatMessage.self])
        let configuration = SwiftData.ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        self.container = container

        let viewModel = ConversationViewModel()
        viewModel.configure(
            modelContext: ModelContext(container),
            pubMedStore: PubMedToolStore(),
            crossPromoSignal: CrossPromoSignal(),
            aiProvider: store
        )

        if let consentAnswer {
            consentAnswerer = Task { @MainActor in
                for _ in 0..<500 {
                    if let request = consent.pendingRequest {
                        consent.respond(to: request.id, allow: consentAnswer)
                        self.answeredConsentPrompts += 1
                    }
                    do {
                        try await Task.sleep(for: .milliseconds(10))
                    } catch {
                        return
                    }
                }
            }
        }
        return (viewModel, consent)
    }

    func cloudProvider(
        outcome: Result<String, ProviderError> = .success("hi"),
        onRespond: (@Sendable (String, String?, [ChatTurn]) -> Void)? = nil
    ) -> MockProvider {
        MockProvider(
            identifier: .userAccount(.anthropic),
            privacyLevel: .external,
            outcome: outcome,
            onRespond: onRespond
        )
    }

    func waitForPendingConsent(_ consent: CloudConsentCoordinator) async throws {
        for _ in 0..<500 where consent.pendingRequest == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(consent.pendingRequest, "expected a consent prompt")
    }

    func assistantMessages(_ viewModel: ConversationViewModel) -> [ChatMessage] {
        viewModel.messages.filter { $0.isUser == false }
    }

}
