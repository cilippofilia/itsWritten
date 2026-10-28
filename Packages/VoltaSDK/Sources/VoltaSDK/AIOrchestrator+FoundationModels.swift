//
//  AIOrchestrator+FoundationModels.swift
//  VoltaSDK
//
//  Foundation Models pass-through (iOS 26+): tools, `GenerationOptions` and
//  `@Generable` guided generation, carried through the same chain as the
//  plain calls. Every overload walks `orderedProviders(for:task:mode:)` (the
//  user's selection, the need's order, the capability map) and admits each
//  provider through the shared `admit`, which adds the capability step.
//

import Foundation
import FoundationModels

extension AIOrchestrator {

    /// Like `respond`, but carries Foundation Models `tools` and generation
    /// `options` to providers that can use them (`FoundationModelsCapableProvider`).
    /// The call PREFERS such providers but does not require one: a plain
    /// provider later in the chain still answers, with the tools and options
    /// dropped (its plain `respond(to:instructions:history:)` is called).
    @available(iOS 26.0, macOS 26.0, *)
    public func respond(
        to prompt: String,
        instructions: String? = nil,
        history: [ChatTurn] = [],
        need: ModelNeed? = nil,
        tools: [any Tool],
        options: GenerationOptions? = nil,
        task: TaskRequirement? = nil
    ) async throws -> String {
        try await respondDetailed(
            to: prompt, instructions: instructions, history: history,
            need: need, tools: tools, options: options, task: task
        ).text
    }

    /// Like `respond(to:…tools:options:)`, but also returns which provider
    /// answered and its privacy level.
    @available(iOS 26.0, macOS 26.0, *)
    public func respondDetailed(
        to prompt: String,
        instructions: String? = nil,
        history: [ChatTurn] = [],
        need: ModelNeed? = nil,
        tools: [any Tool],
        options: GenerationOptions? = nil,
        task: TaskRequirement? = nil
    ) async throws -> AIResponse {
        let generationOptions = options ?? GenerationOptions()
        return try await runTextChain(ChainRequest(
            prompt: prompt, instructions: instructions, history: history,
            need: need, task: task, mode: .raw,
            requirement: .prefersFoundationModels, tools: tools
        )) { provider, call in
            if let capable = provider as? any FoundationModelsCapableProvider {
                return try await capable.respond(
                    to: call.prompt, instructions: call.instructions, history: call.history,
                    tools: tools, options: generationOptions
                )
            }
            // Plain fallback: tools and options cannot travel.
            return try await provider.respond(to: call.prompt, instructions: call.instructions, history: call.history)
        }
    }

    /// Guided generation of a `@Generable` type through the chain. Only
    /// `FoundationModelsCapableProvider`s can serve it: plain providers are
    /// skipped BEFORE the privacy gate (so the user is never asked about a
    /// provider that cannot answer), and if nothing capable is left the call
    /// throws the last error recorded while walking the chain: usually
    /// `.capabilityUnavailable`, `.noProviderAvailable` when no provider was
    /// available at all, or an earlier recoverable error from a capable
    /// provider (e.g. `.rateLimited`) that a later plain skip must not mask.
    ///
    /// For a schema every provider can answer (cloud included), use
    /// `respondStructured(schema:)` instead. With a `task`, the capability
    /// map is read in `.structured` mode (constrained decoding, no repair).
    @available(iOS 26.0, macOS 26.0, *)
    public func respond<Content: Generable & Sendable>(
        to prompt: String,
        generating type: Content.Type,
        instructions: String? = nil,
        history: [ChatTurn] = [],
        tools: [any Tool] = [],
        options: GenerationOptions? = nil,
        need: ModelNeed? = nil,
        task: TaskRequirement? = nil
    ) async throws -> Content {
        let generationOptions = options ?? GenerationOptions()
        let response = try await runChain(ChainRequest(
            prompt: prompt, instructions: instructions, history: history,
            need: need, task: task, mode: .structured,
            requirement: .requiresFoundationModels, tools: tools
        )) { provider, call -> Content in
            // Admission only lets capable providers through for this requirement.
            guard let capable = provider as? any FoundationModelsCapableProvider else {
                throw ProviderError.capabilityUnavailable
            }
            return try await capable.respond(
                to: call.prompt, generating: type, instructions: call.instructions,
                history: call.history, tools: tools, options: generationOptions
            )
        }
        return response.value
    }

    // MARK: Streaming (D16)

    /// Like `streamResponse`, but carries Foundation Models `tools` and
    /// generation `options` to providers that can use them. As with the
    /// buffered overload, the call PREFERS capable providers: a plain provider
    /// still streams, with tools and options dropped. The D16 first-fragment
    /// fallback rule is unchanged.
    @available(iOS 26.0, macOS 26.0, *)
    public func streamResponse(
        to prompt: String,
        instructions: String? = nil,
        history: [ChatTurn] = [],
        need: ModelNeed? = nil,
        tools: [any Tool],
        options: GenerationOptions? = nil,
        task: TaskRequirement? = nil
    ) -> AsyncThrowingStream<String, Error> {
        Self.textFragments(of: streamDetailed(
            to: prompt, instructions: instructions, history: history,
            need: need, tools: tools, options: options, task: task
        ))
    }

    /// Like `streamResponse(to:…tools:options:)`, with a `.began` provenance
    /// event before the first fragment.
    @available(iOS 26.0, macOS 26.0, *)
    public func streamDetailed(
        to prompt: String,
        instructions: String? = nil,
        history: [ChatTurn] = [],
        need: ModelNeed? = nil,
        tools: [any Tool],
        options: GenerationOptions? = nil,
        task: TaskRequirement? = nil
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        let generationOptions = options ?? GenerationOptions()
        return makeStream(ChainRequest(
            prompt: prompt, instructions: instructions, history: history,
            need: need, task: task, mode: .raw,
            requirement: .prefersFoundationModels, tools: tools
        )) { provider, call in
            if let capable = provider as? any FoundationModelsCapableProvider {
                return capable.streamResponse(
                    to: call.prompt, instructions: call.instructions, history: call.history,
                    tools: tools, options: generationOptions
                )
            }
            // Plain fallback: tools and options cannot travel.
            return provider.streamResponse(to: call.prompt, instructions: call.instructions, history: call.history)
        }
    }

    // MARK: Prewarm

    /// Prewarms the first available provider of the chain a plain call would
    /// walk (the user's selection honoured), but only when it is a
    /// `FoundationModelsCapableProvider` (i.e. the on-device model would serve
    /// the next call). Resolves by availability only: no privacy prompt,
    /// nothing is sent anywhere. A plain first provider, or none, is a no-op.
    @available(iOS 26.0, macOS 26.0, *)
    public func prewarm(instructions: String? = nil, tools: [any Tool]) async {
        for provider in orderedProviders(for: nil, task: nil, mode: .raw) {
            if case .unavailable = await provider.availability() { continue }
            if let capable = provider as? any FoundationModelsCapableProvider {
                await capable.prewarm(instructions: instructions, tools: tools)
            }
            return
        }
    }
}
