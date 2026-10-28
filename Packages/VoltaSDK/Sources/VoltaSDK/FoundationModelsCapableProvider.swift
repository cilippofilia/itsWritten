//
//  FoundationModelsCapableProvider.swift
//  VoltaSDK
//
//  Optional capability: a provider that can carry Foundation Models tools,
//  `@Generable` structured output and `GenerationOptions`. The orchestrator
//  routes calls that need these only to providers adopting this protocol.
//

import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
public protocol FoundationModelsCapableProvider: ModelProvider {

    /// Text response with tools and generation options.
    func respond(
        to prompt: String,
        instructions: String?,
        history: [ChatTurn],
        tools: [any Tool],
        options: GenerationOptions
    ) async throws -> String

    /// Streaming text response (deltas) with tools and options.
    func streamResponse(
        to prompt: String,
        instructions: String?,
        history: [ChatTurn],
        tools: [any Tool],
        options: GenerationOptions
    ) -> AsyncThrowingStream<String, Error>

    /// Guided generation of a `@Generable` type.
    func respond<Content: Generable & Sendable>(
        to prompt: String,
        generating type: Content.Type,
        instructions: String?,
        history: [ChatTurn],
        tools: [any Tool],
        options: GenerationOptions
    ) async throws -> Content

    /// Token count including the tool definitions; `nil` when unknown.
    func tokenCount(
        prompt: String,
        instructions: String?,
        history: [ChatTurn],
        tools: [any Tool]
    ) async -> Int?

    /// Warms the model for the upcoming call. Default: no-op.
    func prewarm(instructions: String?, tools: [any Tool]) async
}

@available(iOS 26.0, macOS 26.0, *)
extension FoundationModelsCapableProvider {
    public func prewarm(instructions: String?, tools: [any Tool]) async {}
}
