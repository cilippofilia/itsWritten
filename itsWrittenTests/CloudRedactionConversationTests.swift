//
//  CloudRedactionConversationTests.swift
//  itsWrittenTests
//

import FoundationModels
import VoltaSDK
import XCTest
@testable import itsWritten

/// End to end through `ConversationViewModel` and a real orchestrator: a vendor
/// only ever receives placeholders, and the user only ever reads real words.
@available(iOS 26.0, *)
@MainActor
final class CloudRedactionConversationTests: ConversationViewModelTestCase {
    private static let prompt = "Write a note to marta@example.com about the trip"

    /// What the vendor received, one entry per call.
    private struct Received: Sendable {
        let prompt: String
        let instructions: String?
        let history: [ChatTurn]
    }

    private func vendor(recording received: Recorder<Received>, reply: String, fragments: [String]? = nil) -> MockProvider {
        MockProvider(
            identifier: .userAccount(.anthropic),
            privacyLevel: .external,
            outcome: .success(reply),
            streamFragments: fragments,
            onRespond: { prompt, instructions, history in
                received.append(Received(prompt: prompt, instructions: instructions, history: history))
            }
        )
    }

    /// Every piece of text a vendor received across all calls.
    private func everythingSent(_ received: Recorder<Received>) -> String {
        received.values
            .flatMap { [$0.prompt, $0.instructions ?? ""] + $0.history.map(\.text) }
            .joined(separator: "\n")
    }

    func testStandardReplyIsRedactedOutAndRestoredIn() async throws {
        let received = Recorder<Received>()
        let (viewModel, _) = try makeViewModel(
            providers: [
                MockCapableProvider(availability: .unavailable(reason: "test")),
                vendor(recording: received, reply: "Here's a note for [EMAIL_1].")
            ],
            consentAnswer: true
        )

        viewModel.startConversation(with: Self.prompt, config: ModelConfiguration(), responseType: .standard)
        await viewModel.responseTask?.value

        XCTAssertEqual(received.values.first?.prompt, "Write a note to [EMAIL_1] about the trip")
        XCTAssertFalse(everythingSent(received).contains("marta@example.com"))
        XCTAssertTrue(received.values.first?.instructions?.contains(RedactionSession.placeholderNote) == true)
        XCTAssertEqual(assistantMessages(viewModel).last?.content, "Here's a note for marta@example.com.")
    }

    func testStreamingReplyIsRestoredAcrossFragments() async throws {
        let received = Recorder<Received>()
        let (viewModel, _) = try makeViewModel(
            providers: [
                MockCapableProvider(availability: .unavailable(reason: "test")),
                vendor(recording: received, reply: "", fragments: ["Here's a note for [EMA", "IL_1]", "."])
            ],
            consentAnswer: true
        )

        viewModel.startConversation(with: Self.prompt, config: ModelConfiguration(), responseType: .streaming)
        await viewModel.responseTask?.value

        XCTAssertFalse(everythingSent(received).contains("marta@example.com"))
        XCTAssertEqual(assistantMessages(viewModel).last?.content, "Here's a note for marta@example.com.")
    }

    func testFollowUpHistoryIsRedactedWithoutAskingAgain() async throws {
        let received = Recorder<Received>()
        let (viewModel, _) = try makeViewModel(
            providers: [
                MockCapableProvider(availability: .unavailable(reason: "test")),
                vendor(recording: received, reply: "Sure, [EMAIL_1] it is.")
            ],
            consentAnswer: true
        )

        viewModel.startConversation(with: Self.prompt, config: ModelConfiguration(), responseType: .standard)
        await viewModel.responseTask?.value
        let promptsAfterFirst = answeredConsentPrompts
        viewModel.sendMessage("Make it shorter", config: ModelConfiguration(), responseType: .standard)
        await viewModel.responseTask?.value

        XCTAssertEqual(answeredConsentPrompts, promptsAfterFirst, "no new details, so no new prompt")
        let followUp = try XCTUnwrap(received.values.last)
        XCTAssertEqual(followUp.prompt, "Make it shorter")
        XCTAssertEqual(
            followUp.history.map(\.text),
            ["Write a note to [EMAIL_1] about the trip", "Sure, [EMAIL_1] it is."]
        )
        XCTAssertFalse(everythingSent(received).contains("marta@example.com"))
    }

    func testDeclinedReviewSendsNothing() async throws {
        let received = Recorder<Received>()
        let (viewModel, consent) = try makeViewModel(
            providers: [
                MockCapableProvider(availability: .unavailable(reason: "test")),
                vendor(recording: received, reply: "unused")
            ],
            consentAnswer: false
        )

        viewModel.startConversation(with: Self.prompt, config: ModelConfiguration(), responseType: .standard)
        await viewModel.responseTask?.value

        XCTAssertTrue(received.values.isEmpty)
        XCTAssertTrue(consent.redaction.isEmpty)
        XCTAssertEqual(assistantMessages(viewModel).last?.content, ConversationViewModel.stayedOnDeviceMessage)
    }

    func testOnDeviceAnswerIsNotRedacted() async throws {
        let calls = Recorder<MockCapableProvider.Call>()
        let (viewModel, consent) = try makeViewModel(
            providers: [MockCapableProvider(outcome: .success("Done"), onCall: { calls.append($0) })],
            consentAnswer: nil
        )

        viewModel.startConversation(with: Self.prompt, config: ModelConfiguration(), responseType: .standard)
        await viewModel.responseTask?.value

        XCTAssertEqual(calls.values.first?.prompt, Self.prompt)
        XCTAssertNil(consent.pendingRequest)
        XCTAssertTrue(consent.redaction.isEmpty)
    }

    func testProviderStoreConfigurationRedactsVendors() async throws {
        let consent = CloudConsentCoordinator(defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard)
        consent.setAlwaysAllowed(true, for: .vendor(.anthropic))
        let configuration = AIProviderStore.configuration(keys: [:], consent: consent)
        let filter = try XCTUnwrap(configuration.outboundFilter)

        let call = OutboundCall(
            prompt: "hello", instructions: nil, history: [], provider: .userAccount(.anthropic), privacyLevel: .external
        )
        let filtered = await filter(call)
        XCTAssertEqual(filtered?.prompt, "hello")

        let unknown = OutboundCall(
            prompt: "hello", instructions: nil, history: [], provider: ProviderIdentifier("x"), privacyLevel: .external
        )
        let blocked = await filter(unknown)
        XCTAssertNil(blocked)
    }
}
