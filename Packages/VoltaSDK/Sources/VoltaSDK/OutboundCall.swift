//
//  OutboundCall.swift
//  VoltaSDK
//
//  The text of one call as it is about to reach a provider, and the hook
//  that may rewrite it.
//
//  Why this exists: only the chain knows which provider will answer, so an
//  app that wants to change what an external provider receives (for example,
//  replace personal details with placeholders) cannot do it before calling
//  `respond`. Doing it there would also change what the on-device model
//  sees, for no privacy gain.
//

import Foundation

/// What a provider is about to receive, and who that provider is.
public struct OutboundCall: Sendable, Equatable {
    public var prompt: String
    public var instructions: String?
    public var history: [ChatTurn]
    /// The provider the call is about to be sent to.
    public let provider: ProviderIdentifier
    /// Where the provider's data goes.
    public let privacyLevel: PrivacyLevel

    public init(
        prompt: String,
        instructions: String?,
        history: [ChatTurn],
        provider: ProviderIdentifier,
        privacyLevel: PrivacyLevel
    ) {
        self.prompt = prompt
        self.instructions = instructions
        self.history = history
        self.provider = provider
        self.privacyLevel = privacyLevel
    }
}

/// Called with every call after its provider is admitted (availability,
/// capability, context pre-flight and privacy disclosure all passed) and
/// right before the provider is called. The provider receives the returned
/// call's `prompt`, `instructions` and `history`; changes to `provider` and
/// `privacyLevel` are ignored. Returning `nil` skips the provider, recorded
/// as `.privacyRestricted`, and the chain moves on as for a declined
/// disclosure.
///
/// Runs for every admitted provider, not only on a privacy downgrade, so a
/// chain whose first provider is already external is filtered too.
public typealias OutboundFilter = @Sendable (OutboundCall) async -> OutboundCall?
