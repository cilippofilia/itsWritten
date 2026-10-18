//
//  ConversationViewModelTests.swift
//  itsWrittenTests
//
//  Created by Filippo Cilia on 09/08/2026.
//

import FoundationModels
import SwiftData
import Synchronization
import VoltaSDK
import XCTest
@testable import itsWritten

@MainActor
final class ConversationViewModelTests: ConversationViewModelTestCase {
    func testInitialStateIsComposing() {
        let viewModel = ConversationViewModel()

        XCTAssertEqual(viewModel.mode, .composing)
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertNil(viewModel.threadId)
        XCTAssertEqual(viewModel.title, "New Conversation")
        XCTAssertFalse(viewModel.isResponding)
    }

    func testResumeLoadsThreadOrderedByTimestampAndSwitchesToChatting() {
        let viewModel = ConversationViewModel()
        let older = ChatMessage(content: "Hi", isUser: true, timestamp: Date(timeIntervalSince1970: 100))
        let newer = ChatMessage(content: "Hello!", isUser: false, timestamp: Date(timeIntervalSince1970: 200))
        let thread = ChatThread(title: "Greeting", messages: [newer, older])

        viewModel.resume(thread: thread, config: ModelConfiguration())

        XCTAssertEqual(viewModel.mode, .chatting)
        XCTAssertEqual(viewModel.title, "Greeting")
        XCTAssertEqual(viewModel.threadId, thread.id)
        XCTAssertEqual(viewModel.messages.map(\.content), ["Hi", "Hello!"])
    }

    func testResetReturnsToComposingWithClearedState() {
        let viewModel = ConversationViewModel()
        let thread = ChatThread(title: "Greeting", messages: [ChatMessage(content: "Hi", isUser: true)])
        viewModel.resume(thread: thread, config: ModelConfiguration())

        viewModel.reset(config: ModelConfiguration())

        XCTAssertEqual(viewModel.mode, .composing)
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertNil(viewModel.threadId)
        XCTAssertEqual(viewModel.title, "New Conversation")
    }

    func testIsRefusalMessageDetectsKnownRefusalPhrases() {
        let viewModel = ConversationViewModel()

        XCTAssertTrue(viewModel.isRefusalMessage("I'm sorry, but I can't help with that request."))
        XCTAssertFalse(viewModel.isRefusalMessage("Here's a summary of the evidence you asked about."))
    }

    func testAppendInsertsNewThreadThenUpdatesOnSubsequentAppend() throws {
        let schema = Schema([ChatThread.self, ChatMessage.self])
        let configuration = SwiftData.ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let crossPromoSignal = CrossPromoSignal()

        let viewModel = ConversationViewModel()
        viewModel.configure(modelContext: context, pubMedStore: PubMedToolStore(), crossPromoSignal: crossPromoSignal, aiProvider: idleStore())
        viewModel.title = "Morning Pages"

        viewModel.append(ChatMessage(content: "Hi", isUser: true))

        var fetched = try context.fetch(FetchDescriptor<ChatThread>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.messages.count, 1)
        XCTAssertEqual(fetched.first?.title, "Morning Pages")
        XCTAssertEqual(crossPromoSignal.count, 1)
        XCTAssertEqual(viewModel.threadId, fetched.first?.id)

        viewModel.append(ChatMessage(content: "Hello!", isUser: false))

        fetched = try context.fetch(FetchDescriptor<ChatThread>())
        XCTAssertEqual(fetched.count, 1, "a follow-up append should update the existing thread, not insert a second one")
        XCTAssertEqual(fetched.first?.messages.count, 2)
        XCTAssertEqual(crossPromoSignal.count, 1, "crossPromoSignal should only bump once, when the thread is first created")
    }

    func testResetThenAppendCreatesASeparateNewThread() throws {
        let schema = Schema([ChatThread.self, ChatMessage.self])
        let configuration = SwiftData.ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let viewModel = ConversationViewModel()
        viewModel.configure(modelContext: context, pubMedStore: PubMedToolStore(), crossPromoSignal: CrossPromoSignal(), aiProvider: idleStore())
        viewModel.title = "First Thread"
        viewModel.append(ChatMessage(content: "Hi", isUser: true))

        viewModel.reset(config: ModelConfiguration())
        viewModel.title = "Second Thread"
        viewModel.append(ChatMessage(content: "Hello again", isUser: true))

        let fetched = try context.fetch(FetchDescriptor<ChatThread>())
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(Set(fetched.map(\.title)), Set(["First Thread", "Second Thread"]))
    }

    func testResetIncrementsGenerationAndClearsIsResponding() {
        let viewModel = ConversationViewModel()
        let thread = ChatThread(title: "Greeting", messages: [ChatMessage(content: "Hi", isUser: true)])
        viewModel.resume(thread: thread, config: ModelConfiguration())
        let generationAfterResume = viewModel.generation

        viewModel.reset(config: ModelConfiguration())

        XCTAssertEqual(viewModel.generation, generationAfterResume + 1)
        XCTAssertFalse(viewModel.isResponding)
    }

    func testResumeIncrementsGenerationAndClearsIsResponding() {
        let viewModel = ConversationViewModel()
        let generationBefore = viewModel.generation
        let thread = ChatThread(title: "Greeting", messages: [ChatMessage(content: "Hi", isUser: true)])

        viewModel.resume(thread: thread, config: ModelConfiguration())

        XCTAssertEqual(viewModel.generation, generationBefore + 1)
        XCTAssertFalse(viewModel.isResponding)
    }

    func testPersistCurrentTurnDoesNothingWithEmptyMessages() throws {
        let schema = Schema([ChatThread.self, ChatMessage.self])
        let configuration = SwiftData.ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let viewModel = ConversationViewModel()
        viewModel.configure(modelContext: context, pubMedStore: PubMedToolStore(), crossPromoSignal: CrossPromoSignal(), aiProvider: idleStore())
        viewModel.title = "Stale Title"

        viewModel.persistCurrentTurn()

        let fetched = try context.fetch(FetchDescriptor<ChatThread>())
        XCTAssertTrue(fetched.isEmpty, "persisting with no messages should not create a thread")
    }

    // MARK: - Orchestrator

    func testOnDeviceReplyHasNoProviderName() async throws {
        let (viewModel, _) = try makeViewModel(
            providers: [MockCapableProvider(outcome: .success("ok"))],
            consentAnswer: nil
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .standard)
        await viewModel.responseTask?.value

        XCTAssertEqual(viewModel.messages.last?.content, "ok")
        XCTAssertNil(viewModel.messages.last?.providerName)
    }

    func testToolsAndOptionsReachOnDevice() async throws {
        let calls = Recorder<MockCapableProvider.Call>()
        let (viewModel, _) = try makeViewModel(
            providers: [MockCapableProvider(outcome: .success("ok"), onCall: { calls.append($0) })],
            consentAnswer: nil
        )
        var config = ModelConfiguration()
        config.temperature = 0.42

        viewModel.startConversation(with: "I had a long day", config: config, responseType: .standard)
        await viewModel.responseTask?.value

        let call = try XCTUnwrap(calls.values.first)
        XCTAssertEqual(call.toolNames, AppLanguageModel.tools.map(\.name))
        XCTAssertEqual(call.temperature, config.temperature)
    }

    func testCloudFallbackAfterConsentStoresProviderName() async throws {
        let (viewModel, _) = try makeViewModel(
            providers: [
                MockCapableProvider(availability: .unavailable(reason: "test")),
                cloudProvider()
            ],
            consentAnswer: true
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .standard)
        await viewModel.responseTask?.value

        XCTAssertEqual(viewModel.messages.last?.content, "hi")
        XCTAssertEqual(viewModel.messages.last?.providerName, "Claude")
    }

    func testDeclinedConsentAppendsStayedOnDeviceMessage() async throws {
        let cloudCalls = Recorder<String>()
        let (viewModel, _) = try makeViewModel(
            providers: [
                MockCapableProvider(availability: .unavailable(reason: "test")),
                cloudProvider(onRespond: { prompt, _, _ in cloudCalls.append(prompt) })
            ],
            consentAnswer: false
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .standard)
        await viewModel.responseTask?.value

        XCTAssertEqual(viewModel.messages.last?.content, ConversationViewModel.stayedOnDeviceMessage)
        XCTAssertNil(viewModel.messages.last?.providerName)
        XCTAssertTrue(cloudCalls.values.isEmpty, "the cloud provider must never be called after a decline")
    }

    func testStreamingAccumulatesDeltas() async throws {
        let (viewModel, _) = try makeViewModel(
            providers: [MockCapableProvider(streamFragments: ["Hel", "lo"])],
            consentAnswer: nil
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .streaming)
        await viewModel.responseTask?.value

        let assistants = assistantMessages(viewModel)
        XCTAssertEqual(assistants.count, 1)
        XCTAssertEqual(assistants.first?.content, "Hello")
    }

    func testStreamFailureAfterFragmentsLeavesSingleMessage() async throws {
        let (viewModel, _) = try makeViewModel(
            providers: [
                MockCapableProvider(
                    outcome: .success("recovered"),
                    streamFragments: ["Hel"],
                    streamFailure: .network(code: 500)
                )
            ],
            consentAnswer: nil
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .streaming)
        await viewModel.responseTask?.value

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages.first?.isUser, true)
        XCTAssertEqual(viewModel.messages.last?.isUser, false)
        XCTAssertEqual(viewModel.messages.last?.content, "recovered")
    }

    func testHistoryExcludesInFlightUserMessage() async throws {
        let requests = Recorder<RecordedRequest>()
        let provider = MockProvider(
            identifier: .onDevice,
            outcome: .success("ok"),
            onRespond: { prompt, _, history in requests.append(RecordedRequest(prompt: prompt, history: history)) }
        )
        let (viewModel, _) = try makeViewModel(providers: [provider], consentAnswer: nil)
        let config = ModelConfiguration()

        viewModel.startConversation(with: "I had a long day", config: config, responseType: .standard)
        await viewModel.responseTask?.value
        viewModel.sendMessage("Tell me more", config: config, responseType: .standard)
        await viewModel.responseTask?.value

        let second = try XCTUnwrap(requests.values.last)
        XCTAssertEqual(requests.values.count, 2)
        XCTAssertEqual(second.prompt, "Tell me more")
        XCTAssertEqual(second.history.last, .assistant("ok"))
        XCTAssertFalse(second.history.contains(.user("Tell me more")))
    }

    func testSendMarksRespondingSynchronously() async throws {
        let (viewModel, _) = try makeViewModel(
            providers: [MockCapableProvider(outcome: .success("ok"))],
            consentAnswer: nil
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .standard)
        XCTAssertTrue(viewModel.isResponding)
        await viewModel.responseTask?.value

        XCTAssertFalse(viewModel.isResponding)
    }

    func testResetDuringPendingConsentAppendsNothing() async throws {
        let (viewModel, consent) = try makeViewModel(
            providers: [
                MockCapableProvider(availability: .unavailable(reason: "test")),
                cloudProvider()
            ],
            consentAnswer: nil
        )

        viewModel.startConversation(with: "I had a long day", config: ModelConfiguration(), responseType: .standard)
        try await waitForPendingConsent(consent)
        viewModel.reset(config: ModelConfiguration())
        await viewModel.responseTask?.value

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertNil(consent.pendingRequest)
    }
}

