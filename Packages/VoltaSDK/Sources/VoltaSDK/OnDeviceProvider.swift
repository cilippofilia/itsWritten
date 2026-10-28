//
//  OnDeviceProvider.swift
//  VoltaSDK
//
//  Wraps Apple Intelligence's on-device model (Foundation Models, iOS 26).
//  No network, no key, maximum privacy.
//

import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
public struct OnDeviceProvider: FoundationModelsCapableProvider {

    public let identifier = ProviderIdentifier.onDevice
    public let privacyLevel = PrivacyLevel.onDevice

    /// Warm-session reuse (D17): copies of this provider value share the one
    /// cache, so consecutive turns of the same conversation skip re-processing
    /// the whole prefix.
    private let sessionCache = SessionCache()

    /// The system model this provider talks to (e.g. one with a specific
    /// use case or guardrails). Defaults to the general-purpose model.
    let model: SystemLanguageModel

    /// Reports the provider unavailable whatever the model says
    /// (`AIConfiguration.simulateOnDeviceUnavailable`).
    let simulateUnavailable: Bool

    public init(model: SystemLanguageModel = .default, simulateUnavailable: Bool = false) {
        self.model = model
        self.simulateUnavailable = simulateUnavailable
    }

    /// The reason reported while `simulateUnavailable` is on.
    static let simulatedUnavailableReason = "Simulated unavailable for testing"

    public func availability() async -> ProviderAvailability {
        if simulateUnavailable {
            return .unavailable(reason: Self.simulatedUnavailableReason)
        }
        switch model.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(reason: Self.describe(reason))
        @unknown default:
            return .unavailable(reason: "Unknown unavailability reason")
        }
    }

    public func respond(
        to prompt: String,
        instructions: String?,
        history: [ChatTurn]
    ) async throws -> String {
        try await respond(
            to: prompt, instructions: instructions, history: history,
            tools: [], options: GenerationOptions()
        )
    }

    // MARK: Structured output (D21) — guided generation

    /// Constrained decoding: the schema becomes a `GenerationSchema` and the
    /// session generates a value that is well-formed by construction. The
    /// orchestrator still validates the SDK-side constraints (patterns,
    /// array bounds) and content the schema cannot express.
    public var supportsNativeStructuredOutput: Bool { true }

    public func respondStructured(
        to prompt: String,
        instructions: String?,
        history: [ChatTurn],
        schema: OutputSchema
    ) async throws -> String {
        let session = sessionCache.checkOut(instructions: instructions, history: history, toolNames: [])
            ?? Self.makeSession(model: model, tools: [], instructions: instructions, history: history)
        do {
            let json = try await GuidedGeneration.respond(session: session, prompt: prompt, schema: schema)
            sessionCache.checkIn(
                session,
                instructions: instructions,
                history: history + [.user(prompt), .assistant(json)],
                toolNames: []
            )
            return json
        } catch let error as LanguageModelSession.GenerationError {
            throw Self.map(error)
        } catch is CancellationError {
            throw ProviderError.cancelled
        } catch {
            throw Self.mapOther(error)
        }
    }

    // MARK: Streaming (D16)

    /// Native token streaming via the session's `streamResponse`, with the
    /// framework's cumulative snapshots converted to deltas (shared helper).
    public func streamResponse(
        to prompt: String,
        instructions: String?,
        history: [ChatTurn]
    ) -> AsyncThrowingStream<String, Error> {
        streamResponse(
            to: prompt, instructions: instructions, history: history,
            tools: [], options: GenerationOptions()
        )
    }

    // MARK: FoundationModelsCapableProvider

    public func respond(
        to prompt: String,
        instructions: String?,
        history: [ChatTurn],
        tools: [any Tool],
        options: GenerationOptions
    ) async throws -> String {
        // Warm-session reuse (D17): when the call continues exactly the
        // conversation the cached session absorbed (same tool set too), only
        // the new prompt is processed. Otherwise the session is rebuilt from
        // the app-supplied history (stateless semantics, D12).
        let toolNames = tools.map(\.name)
        let session = sessionCache.checkOut(instructions: instructions, history: history, toolNames: toolNames)
            ?? Self.makeSession(model: model, tools: tools, instructions: instructions, history: history)

        do {
            let response = try await session.respond(to: prompt, options: options)
            sessionCache.checkIn(
                session,
                instructions: instructions,
                history: history + [.user(prompt), .assistant(response.content)],
                toolNames: toolNames
            )
            return response.content
        } catch {
            throw Self.providerError(for: error)
        }
    }

    public func streamResponse(
        to prompt: String,
        instructions: String?,
        history: [ChatTurn],
        tools: [any Tool],
        options: GenerationOptions
    ) -> AsyncThrowingStream<String, Error> {
        let model = self.model
        return SessionStreaming.stream(
            prompt: prompt,
            instructions: instructions,
            history: history,
            toolNames: tools.map(\.name),
            options: options,
            cache: sessionCache,
            makeSession: { Self.makeSession(model: model, tools: tools, instructions: instructions, history: history) },
            mapError: { Self.providerError(for: $0) }
        )
    }

    /// Structured output always runs on a fresh session and never checks in:
    /// its transcript holds generated content, not the plain-text exchange
    /// the cache's history comparison models (spec 1.3).
    public func respond<Content: Generable & Sendable>(
        to prompt: String,
        generating type: Content.Type,
        instructions: String?,
        history: [ChatTurn],
        tools: [any Tool],
        options: GenerationOptions
    ) async throws -> Content {
        let session = Self.makeSession(model: model, tools: tools, instructions: instructions, history: history)
        do {
            return try await session.respond(to: prompt, generating: type, options: options).content
        } catch {
            throw Self.providerError(for: error)
        }
    }

    /// Builds the session `respond` would build for this call shape and warms
    /// it, then parks it in the cache so the first real turn reuses it.
    public func prewarm(instructions: String?, tools: [any Tool]) async {
        let session = Self.makeSession(model: model, tools: tools, instructions: instructions, history: [])
        session.prewarm()
        sessionCache.checkIn(session, instructions: instructions, history: [], toolNames: tools.map(\.name))
    }

    // MARK: Token awareness (D13)

    /// Context window of the on-device model. The property is back-deployed:
    /// available across all of 26.x.
    public var contextSize: Int? {
        model.contextSize
    }

    /// EXACT count via the SDK from iOS/macOS 26.4; `nil` on 26.0–26.3
    /// (the base tier stays reactive-only: error after the call).
    public func tokenCount(
        prompt: String,
        instructions: String?,
        history: [ChatTurn]
    ) async -> Int? {
        await tokenCount(prompt: prompt, instructions: instructions, history: history, tools: [])
    }

    public func tokenCount(
        prompt: String,
        instructions: String?,
        history: [ChatTurn],
        tools: [any Tool]
    ) async -> Int? {
        guard #available(iOS 26.4, macOS 26.4, *) else { return nil }
        var entries = FoundationModelsTranscript.entries(
            instructions: instructions,
            history: history,
            toolDefinitions: tools.map { Transcript.ToolDefinition(tool: $0) }
        )
        if !prompt.isEmpty {
            entries.append(.prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: prompt))]
            )))
        }
        return try? await model.tokenCount(for: entries)
    }

    // MARK: Session/transcript construction

    /// Builds the session for a single call. Without history it uses the
    /// instructions initializer; with history it rebuilds a native
    /// `Transcript`, so the model sees the conversation exactly as if it were
    /// its own.
    private static func makeSession(
        model: SystemLanguageModel,
        tools: [any Tool],
        instructions: String?,
        history: [ChatTurn]
    ) -> LanguageModelSession {
        guard !history.isEmpty else {
            if let instructions, !instructions.isEmpty {
                return LanguageModelSession(model: model, tools: tools, instructions: instructions)
            }
            return LanguageModelSession(model: model, tools: tools)
        }
        let entries = FoundationModelsTranscript.entries(
            instructions: instructions,
            history: history,
            toolDefinitions: tools.map { Transcript.ToolDefinition(tool: $0) }
        )
        return LanguageModelSession(model: model, tools: tools, transcript: Transcript(entries: entries))
    }

    /// Any thrown error → ProviderError (guardrail stays terminal). The
    /// tail is `mapOther`, so the iOS 27 `LanguageModelError` keeps the same
    /// routing here as on the plain and schema paths. Internal (not private)
    /// so tests can exercise the mapping.
    static func providerError(for error: any Error) -> any Error {
        if let provider = error as? ProviderError { return provider }
        if let generation = error as? LanguageModelSession.GenerationError { return map(generation) }
        if error is CancellationError { return ProviderError.cancelled }
        return mapOther(error)
    }

    /// Maps generation errors onto ProviderError, separating the cases the
    /// fallback can recover from (context window, language, rate limit) from
    /// the terminal ones (guardrail: we do not auto-forward content the
    /// system blocked to an external provider).
    private static func map(_ error: LanguageModelSession.GenerationError) -> ProviderError {
        switch error {
        case .exceededContextWindowSize:
            return .contextWindowExceeded
        case .guardrailViolation:
            return .guardrailViolation(error.localizedDescription)
        case .unsupportedLanguageOrLocale:
            return .unsupportedLanguage
        case .rateLimited:
            // On-device rate limit (e.g. app in background): falling back
            // to a cloud provider is legitimate.
            return .rateLimited(retryAfter: nil)
        default:
            return .generation(String(describing: error))
        }
    }

    /// Errors outside `GenerationError`. On iOS 27 the system model can also
    /// throw the framework-wide `LanguageModelError` — observed live on an
    /// iPhone 15 Pro Max (Sep 2026): a hosted test run with the screen
    /// locked got `rateLimited` ("Request has been rate limited … background
    /// request") on every call after the first. Without this mapping that
    /// surfaced as a terminal `.generation(...)`, so the chain could neither
    /// fall back nor report it as unavailability.
    private static func mapOther(_ error: any Error) -> ProviderError {
        if #available(iOS 27.0, macOS 27.0, *), let framework = error as? LanguageModelError {
            return ProviderError(framework)
        }
        return .generation(String(describing: error))
    }

    private static func describe(
        _ reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device does not support Apple Intelligence"
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled in Settings"
        case .modelNotReady:
            return "The model is still downloading or not ready"
        @unknown default:
            return "On-device model unavailable"
        }
    }
}
