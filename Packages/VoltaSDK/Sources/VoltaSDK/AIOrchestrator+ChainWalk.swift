//
//  AIOrchestrator+ChainWalk.swift
//  VoltaSDK
//
//  The buffered chain walk shared by the plain text call and the Foundation
//  Models pass-through overloads, plus the pieces `admit` uses for the
//  capability step: the call requirement, skip recording, and the
//  tool-aware pre-flight count.
//

import Foundation
import FoundationModels

extension AIOrchestrator {

    /// One buffered call's shape, as the chain walk needs it.
    struct ChainRequest: Sendable {
        var prompt: String
        var instructions: String?
        var history: [ChatTurn]
        var need: ModelNeed?
        var task: TaskRequirement?
        /// Which capability-map row (D22) judges this call.
        var mode: MeasuredCapabilities.Mode
        var requirement: CallRequirement
        /// Type-erased `[any Tool]` (the plain path also runs below iOS 26).
        var tools: [any Sendable]
    }

    /// What a call needs from the provider that serves it.
    enum CallRequirement: Sendable {
        /// The original API (and the schema-based `respondStructured`):
        /// any provider, plain path.
        case plain
        /// Tools/options: capable providers get them, plain ones answer
        /// without. Never skips a provider for capability.
        case prefersFoundationModels
        /// `@Generable` output: only `FoundationModelsCapableProvider`s can
        /// serve the call.
        case requiresFoundationModels
    }

    // MARK: Chain walk (shared by every buffered text and `@Generable` call)

    /// Walks the chain a call is entitled to (`orderedProviders(for:task:mode:)`:
    /// the user's selection, reordered for the need, filtered by the
    /// capability map): each provider goes through `admit`, then `execute`.
    /// Recoverable `ProviderError`s fall through to the next provider;
    /// terminal ones are rethrown.
    func runChain<Value: Sendable>(
        _ request: ChainRequest,
        execute: @Sendable (any ModelProvider, OutboundCall) async throws -> Value
    ) async throws -> (value: Value, provider: any ModelProvider) {
        let providers = orderedProviders(for: request.need, task: request.task, mode: request.mode)
        guard let first = providers.first else {
            throw ProviderError.noProviderAvailable
        }

        // The chain's privacy "promise" is the preferred provider's level:
        // going below it is a downgrade.
        let baseline = first.privacyLevel
        var lastError: ProviderError = .noProviderAvailable

        for provider in providers {
            // Availability skip, capability step, context pre-flight (D13),
            // privacy gate (D7/D10) — the shared admission step.
            if let skip = await Self.admit(
                provider, baseline: baseline, disclosure: privacyDisclosure,
                reserve: responseTokenReserve,
                prompt: request.prompt, instructions: request.instructions, history: request.history,
                requirement: request.requirement, tools: request.tools
            ) {
                Self.record(skip, into: &lastError)
                continue
            }
            guard let call = await Self.outboundCall(request, for: provider, through: outboundFilter) else {
                Self.record(.privacyRestricted, into: &lastError)
                continue
            }

            do {
                let value = try await execute(provider, call)
                return (value, provider)
            } catch let error as ProviderError {
                lastError = error
                if error.isRecoverableByFallback {
                    continue        // try the next provider
                }
                throw error         // terminal error (auth, guardrail, decoding, ...)
            }
        }

        throw lastError
    }

    /// `runChain` for text calls, packaged with provenance.
    func runTextChain(
        _ request: ChainRequest,
        execute: @Sendable (any ModelProvider, OutboundCall) async throws -> String
    ) async throws -> AIResponse {
        let result: (value: String, provider: any ModelProvider) = try await runChain(request, execute: execute)
        return AIResponse(
            text: result.value,
            provider: result.provider.identifier,
            privacyLevel: result.provider.privacyLevel
        )
    }

    /// The call `provider` receives: the request's text, passed through the
    /// app's outbound filter when there is one. `nil` = the filter blocked it.
    /// Execute and open closures must read the text from this call, never
    /// from the variables they were built with, or the filter is bypassed.
    static func outboundCall(
        _ request: ChainRequest,
        for provider: any ModelProvider,
        through filter: OutboundFilter?
    ) async -> OutboundCall? {
        let call = OutboundCall(
            prompt: request.prompt,
            instructions: request.instructions,
            history: request.history,
            provider: provider.identifier,
            privacyLevel: provider.privacyLevel
        )
        guard let filter else { return call }
        return await filter(call)
    }

    /// Records an admission skip as the chain's last error. A capability
    /// skip is the least informative failure: it is recorded only while no
    /// earlier error was, so it never masks a real failure (e.g. a
    /// `.rateLimited` from an earlier capable provider).
    static func record(_ skip: ProviderError?, into lastError: inout ProviderError) {
        guard let skip else { return }
        if skip == .capabilityUnavailable, lastError != .noProviderAvailable { return }
        lastError = skip
    }

    static func isFoundationModelsCapable(_ provider: any ModelProvider) -> Bool {
        if #available(iOS 26.0, macOS 26.0, *) {
            return provider is any FoundationModelsCapableProvider
        }
        return false
    }

    /// The pre-flight count. `countingTools` non-nil = a capable provider on
    /// a call that carries Foundation Models features: count with the tool
    /// definitions. `nil` = the plain count.
    static func preflightTokenCount(
        on provider: any ModelProvider,
        countingTools tools: [any Sendable]?,
        prompt: String,
        instructions: String?,
        history: [ChatTurn]
    ) async -> Int? {
        if let tools, #available(iOS 26.0, macOS 26.0, *),
           let capable = provider as? any FoundationModelsCapableProvider {
            return await capable.tokenCount(
                prompt: prompt, instructions: instructions, history: history,
                tools: tools.compactMap { $0 as? any Tool }
            )
        }
        return await provider.tokenCount(
            prompt: prompt, instructions: instructions, history: history
        )
    }
}
