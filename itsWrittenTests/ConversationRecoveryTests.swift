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
@available(iOS 26.0, *)
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
                SequencedProvider(outcomes: [
                    .failure(.guardrailViolation("x")),
                    .failure(.rateLimited(retryAfter: nil))
                ]),
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

    func testStreamingGuardrailRetryNeverReachesCloud() async throws {
        let cloudCalls = Recorder<String>()
        let onDeviceCalls = Recorder<MockCapableProvider.Call>()
        let (viewModel, _) = try makeViewModel(
            // Same setup as the standard test: a retry through the main chain would
            // fall back to the always-allowed cloud provider.
            providers: [
                SequencedProvider(outcomes: [
                    .failure(.guardrailViolation("x")),
                    .failure(.rateLimited(retryAfter: nil))
                ]),
                cloudProvider(outcome: .success("cloud"), onRespond: { prompt, _, _ in cloudCalls.append(prompt) })
            ],
            onDeviceProviders: [
                MockCapableProvider(
                    outcome: .failure(.rateLimited(retryAfter: nil)),
                    onCall: { onDeviceCalls.append($0) }
                )
            ],
            consentAnswer: nil,
            alwaysAllowed: .vendor(.anthropic)
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .streaming)
        await viewModel.responseTask?.value

        XCTAssertTrue(cloudCalls.values.isEmpty, "guardrail-blocked content must never reach the cloud")
        XCTAssertEqual(onDeviceCalls.values.count, 1, "the retry should run on the on-device-only orchestrator")
        XCTAssertEqual(assistantMessages(viewModel).count, 1)
        XCTAssertEqual(viewModel.messages.last?.content, ConversationViewModel.recoveryFailureMessage)
        XCTAssertEqual(viewModel.messages.first?.wasBlocked, true)
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

    // MARK: - On-device compaction after a declined cloud prompt

    /// The main chain overflows on device, the user declines the cloud, and the
    /// on-device-only retry with half the history answers.
    private func makeDeclinedOverflowViewModel(
        cloudCalls: Recorder<String>,
        onDeviceCalls: Recorder<MockCapableProvider.Call>
    ) throws -> ConversationViewModel {
        let (viewModel, _) = try makeViewModel(
            providers: [
                MockCapableProvider(outcome: .failure(.contextWindowExceeded)),
                cloudProvider(onRespond: { prompt, _, _ in cloudCalls.append(prompt) })
            ],
            onDeviceProviders: [
                MockCapableProvider(outcome: .success("compacted"), onCall: { onDeviceCalls.append($0) })
            ],
            consentAnswer: false
        )
        return viewModel
    }

    func testDeclinedCloudStillCompactsOnDevice() async throws {
        let cloudCalls = Recorder<String>()
        let onDeviceCalls = Recorder<MockCapableProvider.Call>()
        let viewModel = try makeDeclinedOverflowViewModel(cloudCalls: cloudCalls, onDeviceCalls: onDeviceCalls)

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .standard)
        await viewModel.responseTask?.value

        XCTAssertEqual(viewModel.messages.last?.content, "compacted")
        XCTAssertTrue(cloudCalls.values.isEmpty, "the cloud provider must never be called after a decline")
        XCTAssertEqual(onDeviceCalls.values.count, 1)
        XCTAssertEqual(answeredConsentPrompts, 1)
    }

    func testDeclinedCloudStillCompactsOnDeviceWhenStreaming() async throws {
        let cloudCalls = Recorder<String>()
        let onDeviceCalls = Recorder<MockCapableProvider.Call>()
        let viewModel = try makeDeclinedOverflowViewModel(cloudCalls: cloudCalls, onDeviceCalls: onDeviceCalls)

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .streaming)
        await viewModel.responseTask?.value

        XCTAssertEqual(viewModel.messages.last?.content, "compacted")
        XCTAssertEqual(assistantMessages(viewModel).count, 1)
        XCTAssertTrue(cloudCalls.values.isEmpty, "the cloud provider must never be called after a decline")
        XCTAssertEqual(onDeviceCalls.values.count, 1)
    }

    func testDeclinedCloudShowsStayedOnDeviceWhenCompactionFails() async throws {
        let (viewModel, _) = try makeViewModel(
            providers: [
                MockCapableProvider(outcome: .failure(.contextWindowExceeded)),
                cloudProvider()
            ],
            onDeviceProviders: [MockCapableProvider(outcome: .failure(.contextWindowExceeded))],
            consentAnswer: false
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .standard)
        await viewModel.responseTask?.value

        XCTAssertEqual(viewModel.messages.last?.content, ConversationViewModel.stayedOnDeviceMessage)
    }

    // MARK: - Rejected cloud keys

    func testRejectedKeyShowsKeyCopyWithoutRetry() async throws {
        let cloudCalls = Recorder<String>()
        let onDeviceCalls = Recorder<MockCapableProvider.Call>()
        let (viewModel, _) = try makeViewModel(
            providers: [
                MockCapableProvider(availability: .unavailable(reason: "test")),
                cloudProvider(
                    outcome: .failure(.unauthorized),
                    onRespond: { prompt, _, _ in cloudCalls.append(prompt) }
                )
            ],
            onDeviceProviders: [
                MockCapableProvider(outcome: .success("retried"), onCall: { onDeviceCalls.append($0) })
            ],
            consentAnswer: true
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .standard)
        await viewModel.responseTask?.value

        XCTAssertEqual(viewModel.messages.last?.content, ConversationViewModel.keyRejectedMessage(vendorName: nil))
        XCTAssertEqual(
            viewModel.messages.last?.content,
            "The cloud model didn't accept your API key. Check it in Settings › Provider."
        )
        XCTAssertEqual(cloudCalls.values.count, 1, "a rejected key must not be retried")
        XCTAssertTrue(onDeviceCalls.values.isEmpty)
    }

    func testRejectedKeyNamesTheOnlyVendorWhenStreaming() async throws {
        let cloudCalls = Recorder<String>()
        let (viewModel, _) = try makeViewModel(
            providers: [
                MockCapableProvider(availability: .unavailable(reason: "test")),
                cloudProvider(
                    outcome: .failure(.unauthorized),
                    onRespond: { prompt, _, _ in cloudCalls.append(prompt) }
                )
            ],
            consentAnswer: true,
            configuredVendors: [.anthropic]
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .streaming)
        await viewModel.responseTask?.value

        XCTAssertEqual(
            viewModel.messages.last?.content,
            "Claude didn't accept your API key. Check it in Settings › Provider."
        )
        XCTAssertEqual(assistantMessages(viewModel).count, 1)
        XCTAssertEqual(cloudCalls.values.count, 1, "a rejected key must not be retried, streaming included")
    }

    func testRejectedRequestShowsCopyWithoutRetry() async throws {
        let cloudCalls = Recorder<String>()
        let (viewModel, _) = try makeViewModel(
            providers: [
                MockCapableProvider(availability: .unavailable(reason: "test")),
                cloudProvider(
                    outcome: .failure(.api(message: "API key not valid", code: "INVALID_ARGUMENT")),
                    onRespond: { prompt, _, _ in cloudCalls.append(prompt) }
                )
            ],
            consentAnswer: true
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .streaming)
        await viewModel.responseTask?.value

        XCTAssertEqual(viewModel.messages.last?.content, ConversationViewModel.requestRejectedMessage(vendorName: nil))
        XCTAssertEqual(cloudCalls.values.count, 1)
    }

    func testCloudRejectionCopyIsLeftOutOfHistory() {
        typealias ViewModel = ConversationViewModel
        XCTAssertTrue(ViewModel.isAppGeneratedCopy(ViewModel.keyRejectedMessage(vendorName: "Gemini")))
        XCTAssertTrue(ViewModel.isAppGeneratedCopy(ViewModel.requestRejectedMessage(vendorName: nil)))
        XCTAssertTrue(ConversationViewModel.isAppGeneratedCopy(ConversationViewModel.recoveryFailureMessage))
        XCTAssertFalse(ConversationViewModel.isAppGeneratedCopy("Here's what I found."))
    }

    // MARK: - Title generation

    func testResetCancelsTitleSoItCannotUseTheNextGrant() async throws {
        let gate = GatedProvider.Gate()
        let cloudCalls = Recorder<String>()
        let (viewModel, consent) = try makeViewModel(
            providers: [
                GatedProvider(gate: gate),
                cloudProvider(outcome: .success("Old Title"), onRespond: { prompt, _, _ in cloudCalls.append(prompt) })
            ],
            consentAnswer: nil
        )

        let title = Task { await viewModel.generateAndSetTitle(from: "I had a long day") }
        for _ in 0..<500 where gate.wasEntered == false {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(gate.wasEntered, "the title call should be parked in the on-device check")

        viewModel.reset(config: ModelConfiguration())
        XCTAssertNil(viewModel.titleTask)
        // The next conversation's grant must not reach the old title call.
        consent.setAlwaysAllowed(true, for: .vendor(.anthropic))
        gate.open()
        await title.value

        XCTAssertTrue(cloudCalls.values.isEmpty, "a superseded title call must not reach the cloud")
        XCTAssertEqual(viewModel.title, "New Conversation")
    }

    func testTitleTaskIsStoredWhileRunning() async throws {
        let (viewModel, _) = try makeViewModel(
            providers: [MockCapableProvider(outcome: .success("A Fine Title"))],
            consentAnswer: nil
        )

        await viewModel.generateAndSetTitle(from: "I had a long day")

        XCTAssertNotNil(viewModel.titleTask)
        XCTAssertEqual(viewModel.title, "A Fine Title")
    }
}
