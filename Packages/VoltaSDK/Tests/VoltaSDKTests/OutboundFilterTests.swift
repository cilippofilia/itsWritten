//
//  OutboundFilterTests.swift
//  VoltaSDKTests
//
//  The outbound filter must change what the provider actually receives on
//  every chain walk. Each test records the provider's input, so a closure
//  that still captured the caller's original text would fail here.
//

import Foundation
import FoundationModels
import Synchronization
import Testing
@testable import VoltaSDK

@Suite("Outbound filter")
struct OutboundFilterTests {

    /// What a provider was called with.
    struct Received: Sendable, Equatable {
        let prompt: String
        let instructions: String?
        let history: [ChatTurn]
    }

    /// Collects what providers receive. A class, so escaping closures share it.
    final class Recorder: Sendable {
        private let storage = Mutex<[Received]>([])
        func append(_ prompt: String, _ instructions: String?, _ history: [ChatTurn]) {
            storage.withLock { $0.append(Received(prompt: prompt, instructions: instructions, history: history)) }
        }
        var all: [Received] { storage.withLock { $0 } }
    }

    /// Rewrites every "Marta" to "[PERSON_1]" for external providers only.
    static let redactExternal: OutboundFilter = { call in
        guard call.privacyLevel == .external else { return call }
        var call = call
        call.prompt = call.prompt.replacing("Marta", with: "[PERSON_1]")
        call.instructions = call.instructions?.replacing("Marta", with: "[PERSON_1]")
        call.history = call.history.map { ChatTurn(role: $0.role, text: $0.text.replacing("Marta", with: "[PERSON_1]")) }
        return call
    }

    static let history: [ChatTurn] = [.user("Marta is my sister"), .assistant("Say hi to Marta")]
    static let expected = Received(
        prompt: "Plan a day with [PERSON_1]",
        instructions: "Be kind to [PERSON_1]",
        history: [.user("[PERSON_1] is my sister"), .assistant("Say hi to [PERSON_1]")]
    )

    /// Chain: on-device (unavailable) → external mock that records its input.
    private func chain(recording received: Recorder, fragments: [String]? = nil) -> [any ModelProvider] {
        [
            MockProvider(identifier: .onDevice, privacyLevel: .onDevice, availability: .unavailable(reason: "off")),
            MockProvider(
                identifier: .openAI,
                privacyLevel: .external,
                outcome: .success("ok"),
                streamFragments: fragments,
                onRespond: { received.append($0, $1, $2) }
            )
        ]
    }

    private func orchestrator(_ providers: [any ModelProvider], filter: OutboundFilter?) -> AIOrchestrator {
        AIOrchestrator(providers: providers, privacyDisclosure: .silent, outboundFilter: filter)
    }

    @Test("Buffered plain call sends the filtered text")
    func bufferedPlain() async throws {
        let received = Recorder()
        let kit = orchestrator(chain(recording: received), filter: Self.redactExternal)
        _ = try await kit.respond(to: "Plan a day with Marta", instructions: "Be kind to Marta", history: Self.history)
        #expect(received.all == [Self.expected])
    }

    @Test("Buffered tools call sends the filtered text to a plain provider")
    @available(iOS 26.0, macOS 26.0, *)
    func bufferedTools() async throws {
        let received = Recorder()
        let kit = orchestrator(chain(recording: received), filter: Self.redactExternal)
        _ = try await kit.respond(
            to: "Plan a day with Marta", instructions: "Be kind to Marta", history: Self.history, tools: []
        )
        #expect(received.all == [Self.expected])
    }

    @Test("Streaming plain call sends the filtered text")
    func streamingPlain() async throws {
        let received = Recorder()
        let kit = orchestrator(chain(recording: received, fragments: ["o", "k"]), filter: Self.redactExternal)
        for try await _ in await kit.streamResponse(
            to: "Plan a day with Marta", instructions: "Be kind to Marta", history: Self.history
        ) {}
        #expect(received.all == [Self.expected])
    }

    @Test("Streaming tools call sends the filtered text to a plain provider")
    @available(iOS 26.0, macOS 26.0, *)
    func streamingTools() async throws {
        let received = Recorder()
        let kit = orchestrator(chain(recording: received, fragments: ["o", "k"]), filter: Self.redactExternal)
        for try await _ in await kit.streamResponse(
            to: "Plan a day with Marta", instructions: "Be kind to Marta", history: Self.history, tools: []
        ) {}
        #expect(received.all == [Self.expected])
    }

    @Test("Schema-structured call sends the filtered text")
    func schemaStructured() async throws {
        let received = Recorder()
        let providers: [any ModelProvider] = [
            MockProvider(identifier: .onDevice, privacyLevel: .onDevice, availability: .unavailable(reason: "off")),
            MockProvider(
                identifier: .openAI,
                privacyLevel: .external,
                structuredAnswers: ["{\"a\":1}"],
                onRespond: { received.append($0, $1, $2) }
            )
        ]
        let kit = orchestrator(providers, filter: Self.redactExternal)
        _ = try await kit.respondStructured(
            to: "Plan a day with Marta", instructions: "Be kind to Marta", history: Self.history,
            schema: .object(name: "T", properties: [.init("a", .integer())])
        )
        #expect(received.all == [Self.expected])
    }

    @Test("Generable call sends the filtered prompt")
    @available(iOS 26.0, macOS 26.0, *)
    func generable() async throws {
        let calls = Mutex<[MockCapableProvider.Call]>([])
        let capable = MockCapableProvider(
            identifier: .openAI,
            privacyLevel: .external,
            structuredContent: FilterVerdict(label: "yes").generatedContent,
            onCall: { call in calls.withLock { $0.append(call) } }
        )
        let kit = orchestrator([capable], filter: Self.redactExternal)
        _ = try await kit.respond(to: "Plan a day with Marta", generating: FilterVerdict.self)
        #expect(calls.withLock { $0.map(\.prompt) } == ["Plan a day with [PERSON_1]"])
    }

    @Test("The filter sees the provider it is filtering for")
    func filterSeesProvider() async throws {
        let seen = Mutex<[OutboundCall]>([])
        let providers: [any ModelProvider] = [
            MockProvider(identifier: .onDevice, privacyLevel: .onDevice, outcome: .failure(.rateLimited(retryAfter: nil))),
            MockProvider(identifier: .openAI, privacyLevel: .external, outcome: .success("ok"))
        ]
        let kit = orchestrator(providers) { call in
            seen.withLock { $0.append(call) }
            return call
        }
        _ = try await kit.respond(to: "hi")
        #expect(seen.withLock { $0.map(\.provider) } == [.onDevice, .openAI])
        #expect(seen.withLock { $0.map(\.privacyLevel) } == [.onDevice, .external])
    }

    @Test("A nil from the filter skips the provider as privacyRestricted")
    func nilSkipsProvider() async {
        let received = Recorder()
        let kit = orchestrator(chain(recording: received)) { _ in nil }
        await #expect(throws: ProviderError.privacyRestricted) {
            _ = try await kit.respond(to: "Plan a day with Marta")
        }
        #expect(received.all.isEmpty)
    }

    @Test("A nil from the filter skips a streaming provider before it is opened")
    func nilSkipsStreamingProvider() async {
        let received = Recorder()
        let kit = orchestrator(chain(recording: received, fragments: ["x"])) { _ in nil }
        await #expect(throws: ProviderError.privacyRestricted) {
            for try await _ in await kit.streamResponse(to: "Plan a day with Marta") {}
        }
        #expect(received.all.isEmpty)
    }

    @Test("A nil skip falls through to the next provider")
    func nilFallsThrough() async throws {
        let providers: [any ModelProvider] = [
            MockProvider(identifier: .openAI, privacyLevel: .external, outcome: .success("openai")),
            MockProvider(identifier: .anthropic, privacyLevel: .external, outcome: .success("anthropic"))
        ]
        let kit = orchestrator(providers) { call in call.provider == .openAI ? nil : call }
        #expect(try await kit.respond(to: "hi") == "anthropic")
    }

    @Test("The filter runs after the privacy disclosure")
    func runsAfterDisclosure() async {
        let filtered = Mutex(0)
        let kit = AIOrchestrator(
            providers: chain(recording: Recorder()),
            privacyDisclosure: .askOnPrivacyChange { _ in false },
            outboundFilter: { call in
                filtered.withLock { $0 += 1 }
                return call
            }
        )
        await #expect(throws: ProviderError.privacyRestricted) {
            _ = try await kit.respond(to: "hi")
        }
        #expect(filtered.withLock { $0 } == 0)
    }

    @Test("Configuration carries the filter to the orchestrator")
    func configurationCarriesFilter() async {
        var configuration = AIConfiguration()
        configuration.outboundFilter = { $0 }
        let kit = AIOrchestrator(configuration: configuration)
        #expect(await kit.outboundFilter != nil)
    }
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct FilterVerdict: Equatable {
    var label: String
}
