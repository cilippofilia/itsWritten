//
//  ConversationRecoveryTests.swift
//  itsWrittenTests
//

import FoundationModels
import SwiftData
import Synchronization
import VoltaSDK
import XCTest
@testable import itsWritten

/// Failure handling: guardrail retries, blocked turns, on-device compaction,
/// rejected cloud keys and title generation.
@MainActor
final class ConversationRecoveryTests: ConversationViewModelTestCase {
    func testTitleDeclinedKeepsPlaceholder() async throws {
        let (viewModel, _) = try makeViewModel(
            providers: [
                MockCapableProvider(availability: .unavailable(reason: "test")),
                cloudProvider(outcome: .success("A Cloud Title"))
            ],
            consentAnswer: false
        )

        await viewModel.generateAndSetTitle(from: "I had a long day")

        XCTAssertEqual(viewModel.title, "New Conversation")
    }

    func testGuardrailRetryNeverReachesCloud() async throws {
        let cloudCalls = Recorder<String>()
        let (viewModel, _) = try makeViewModel(
            // The second on-device call fails recoverably, so a retry through the main
            // chain would fall back to the always-allowed cloud provider.
            providers: [
                SequencedProvider(outcomes: [.failure(.guardrailViolation("x")), .failure(.rateLimited(retryAfter: nil))]),
                cloudProvider(outcome: .success("cloud"), onRespond: { prompt, _, _ in cloudCalls.append(prompt) })
            ],
            onDeviceProviders: [MockCapableProvider(outcome: .failure(.rateLimited(retryAfter: nil)))],
            consentAnswer: nil,
            alwaysAllowed: .vendor(.anthropic)
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .standard)
        await viewModel.responseTask?.value

        XCTAssertTrue(cloudCalls.values.isEmpty, "guardrail-blocked content must never reach the cloud")
        XCTAssertEqual(
            viewModel.messages.last?.content,
            ConversationViewModel.recoveryFailureMessage
        )
    }

    func testBlockedTurnIsLeftOutOfLaterHistory() async throws {
        let requests = Recorder<RecordedRequest>()
        let (viewModel, _) = try makeViewModel(
            providers: [
                SequencedProvider(
                    outcomes: [.failure(.guardrailViolation("x")), .success("ok")],
                    onRespond: { prompt, history in requests.append(RecordedRequest(prompt: prompt, history: history)) }
                )
            ],
            onDeviceProviders: [MockCapableProvider(outcome: .failure(.guardrailViolation("x")))],
            consentAnswer: nil
        )
        let config = ModelConfiguration()

        viewModel.startConversation(with: "blocked text", config: config, responseType: .standard)
        await viewModel.responseTask?.value
        XCTAssertEqual(viewModel.messages.first?.wasBlocked, true)

        viewModel.sendMessage("Tell me more", config: config, responseType: .standard)
        await viewModel.responseTask?.value

        let second = try XCTUnwrap(requests.values.last)
        XCTAssertEqual(requests.values.count, 2)
        XCTAssertEqual(second.prompt, "Tell me more")
        XCTAssertFalse(second.history.contains(.user("blocked text")), "blocked content must not be resent")
        XCTAssertFalse(second.history.contains(.assistant(ConversationViewModel.recoveryFailureMessage)))
        XCTAssertEqual(viewModel.messages.last?.content, "ok")
    }

    func testGuardrailRecoveredOnDeviceIsNotBlocked() async throws {
        let (viewModel, _) = try makeViewModel(
            providers: [SequencedProvider(outcomes: [.failure(.guardrailViolation("x"))])],
            onDeviceProviders: [MockCapableProvider(outcome: .success("fine"))],
            consentAnswer: nil
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .standard)
        await viewModel.responseTask?.value

        XCTAssertEqual(viewModel.messages.last?.content, "fine")
        XCTAssertEqual(viewModel.messages.first?.wasBlocked, false)
    }

}
