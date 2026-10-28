//
//  Mocks.swift
//  VoltaSDK
//
//  Inherits the pattern of the original ChatGptManagerMock, generalized.
//  Lets you test the orchestrator and the fallback without network or a
//  real device. Public on purpose: adopters can use it in their own tests.
//

import Foundation
import FoundationModels
import Synchronization

/// A reference-typed counter so the value-typed mock can script sequences.
final class Counter: @unchecked Sendable {
    private let value = Mutex(0)
    func next() -> Int { value.withLock { v in defer { v += 1 }; return v } }
}

/// Fake provider with a configurable outcome. Covers both success and
/// failure, so the fallback chain can be tested (e.g. one provider that
/// returns .rateLimited and one that answers correctly right after).
public struct MockProvider: ModelProvider {

    public let identifier: ProviderIdentifier
    public let privacyLevel: PrivacyLevel

    private let availabilityResult: ProviderAvailability
    private let outcome: Result<String, ProviderError>
    private let onRespond: (@Sendable (_ prompt: String, _ instructions: String?, _ history: [ChatTurn]) -> Void)?

    /// Simulated token-awareness capability (D13). Default: unsupported.
    public let contextSize: Int?
    private let tokenCountValue: Int?

    /// Simulated streaming capability (D16). When set, `streamResponse`
    /// yields these fragments (then fails with `streamFailure`, if any);
    /// when nil, streaming mirrors `outcome` as a single fragment.
    private let streamFragments: [String]?
    private let streamFailure: ProviderError?

    /// Simulated structured-output capability (D21). When set, each
    /// `respondStructured` call pops the next answer (the last one repeats),
    /// so a test can script "malformed first, fixed on repair"; when nil,
    /// the prompted default applies over `outcome`.
    private let structuredAnswers: [String]?
    private let structuredCounter = Counter()

    public init(
        identifier: ProviderIdentifier,
        privacyLevel: PrivacyLevel = .onDevice,
        availability: ProviderAvailability = .available,
        outcome: Result<String, ProviderError> = .success(""),
        contextSize: Int? = nil,
        tokenCount: Int? = nil,
        streamFragments: [String]? = nil,
        streamFailure: ProviderError? = nil,
        structuredAnswers: [String]? = nil,
        onRespond: (@Sendable (_ prompt: String, _ instructions: String?, _ history: [ChatTurn]) -> Void)? = nil
    ) {
        self.identifier = identifier
        self.privacyLevel = privacyLevel
        self.availabilityResult = availability
        self.outcome = outcome
        self.contextSize = contextSize
        self.tokenCountValue = tokenCount
        self.streamFragments = streamFragments
        self.streamFailure = streamFailure
        self.structuredAnswers = structuredAnswers
        self.onRespond = onRespond
    }

    public var supportsNativeStructuredOutput: Bool { structuredAnswers != nil }

    public func respondStructured(
        to prompt: String,
        instructions: String?,
        history: [ChatTurn],
        schema: OutputSchema
    ) async throws -> String {
        guard let structuredAnswers, !structuredAnswers.isEmpty else {
            return try await respond(
                to: prompt,
                instructions: StructuredOutput.promptedInstructions(instructions, schema: schema),
                history: history
            )
        }
        onRespond?(prompt, instructions, history)
        let index = min(structuredCounter.next(), structuredAnswers.count - 1)
        return structuredAnswers[index]
    }

    public func availability() async -> ProviderAvailability {
        availabilityResult
    }

    public func tokenCount(
        prompt: String,
        instructions: String?,
        history: [ChatTurn]
    ) async -> Int? {
        tokenCountValue
    }

    public func respond(
        to prompt: String,
        instructions: String?,
        history: [ChatTurn]
    ) async throws -> String {
        onRespond?(prompt, instructions, history)
        switch outcome {
        case .success(let text):
            return text
        case .failure(let error):
            throw error
        }
    }

    public func streamResponse(
        to prompt: String,
        instructions: String?,
        history: [ChatTurn]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                onRespond?(prompt, instructions, history)
                if let streamFragments {
                    for fragment in streamFragments {
                        continuation.yield(fragment)
                    }
                    continuation.finish(throwing: streamFailure)
                } else {
                    switch outcome {
                    case .success(let text):
                        continuation.yield(text)
                        continuation.finish()
                    case .failure(let error):
                        continuation.finish(throwing: error)
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Fake `FoundationModelsCapableProvider`: records tools, temperature and the
/// structured type of each call, and returns configured text or content.
@available(iOS 26.0, macOS 26.0, *)
public struct MockCapableProvider: FoundationModelsCapableProvider {

    public struct Call: Sendable, Equatable {
        public let prompt: String
        public let toolNames: [String]
        public let temperature: Double?
        /// `String(describing: Content.self)`; nil for text calls.
        public let generatingTypeName: String?

        public init(prompt: String, toolNames: [String], temperature: Double?, generatingTypeName: String?) {
            self.prompt = prompt
            self.toolNames = toolNames
            self.temperature = temperature
            self.generatingTypeName = generatingTypeName
        }
    }

    public let identifier: ProviderIdentifier
    public let privacyLevel: PrivacyLevel

    private let availabilityResult: ProviderAvailability
    private let outcome: Result<String, ProviderError>
    private let structuredContent: GeneratedContent?
    private let streamFragments: [String]?
    private let streamFailure: ProviderError?
    private let onCall: (@Sendable (Call) -> Void)?
    private let onPrewarm: (@Sendable () -> Void)?

    public init(
        identifier: ProviderIdentifier = .onDevice,
        privacyLevel: PrivacyLevel = .onDevice,
        availability: ProviderAvailability = .available,
        outcome: Result<String, ProviderError> = .success(""),
        structuredContent: GeneratedContent? = nil,
        streamFragments: [String]? = nil,
        streamFailure: ProviderError? = nil,
        onCall: (@Sendable (Call) -> Void)? = nil,
        onPrewarm: (@Sendable () -> Void)? = nil
    ) {
        self.identifier = identifier
        self.privacyLevel = privacyLevel
        self.availabilityResult = availability
        self.outcome = outcome
        self.structuredContent = structuredContent
        self.streamFragments = streamFragments
        self.streamFailure = streamFailure
        self.onCall = onCall
        self.onPrewarm = onPrewarm
    }

    public func availability() async -> ProviderAvailability { availabilityResult }

    public func respond(to prompt: String, instructions: String?, history: [ChatTurn]) async throws -> String {
        try await respond(to: prompt, instructions: instructions, history: history, tools: [], options: GenerationOptions())
    }

    public func respond(
        to prompt: String, instructions: String?, history: [ChatTurn],
        tools: [any Tool], options: GenerationOptions
    ) async throws -> String {
        onCall?(Call(prompt: prompt, toolNames: tools.map(\.name), temperature: options.temperature, generatingTypeName: nil))
        return try outcome.get()
    }

    public func streamResponse(
        to prompt: String, instructions: String?, history: [ChatTurn],
        tools: [any Tool], options: GenerationOptions
    ) -> AsyncThrowingStream<String, Error> {
        onCall?(Call(prompt: prompt, toolNames: tools.map(\.name), temperature: options.temperature, generatingTypeName: nil))
        let fragments = streamFragments, failure = streamFailure, outcome = outcome
        return AsyncThrowingStream { continuation in
            if let fragments {
                for fragment in fragments { continuation.yield(fragment) }
                continuation.finish(throwing: failure)
            } else {
                switch outcome {
                case .success(let text):
                    continuation.yield(text)
                    continuation.finish()
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func respond<Content: Generable & Sendable>(
        to prompt: String, generating type: Content.Type,
        instructions: String?, history: [ChatTurn],
        tools: [any Tool], options: GenerationOptions
    ) async throws -> Content {
        onCall?(Call(
            prompt: prompt, toolNames: tools.map(\.name), temperature: options.temperature,
            generatingTypeName: String(describing: Content.self)
        ))
        if case .failure(let error) = outcome { throw error }
        guard let structuredContent else {
            throw ProviderError.decoding("No structured content configured")
        }
        do {
            return try Content(structuredContent)
        } catch {
            throw ProviderError.decoding(String(describing: error))
        }
    }

    public func tokenCount(prompt: String, instructions: String?, history: [ChatTurn], tools: [any Tool]) async -> Int? {
        nil
    }

    public func prewarm(instructions: String?, tools: [any Tool]) async {
        onPrewarm?()
    }
}
