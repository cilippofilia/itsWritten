//
//  SequencedProvider.swift
//  itsWrittenTests
//

import VoltaSDK

/// On-device plain provider that returns `outcomes` in order, repeating the last one.
@available(iOS 26.0, *)
struct SequencedProvider: ModelProvider {
    let identifier = ProviderIdentifier.onDevice
    let privacyLevel = PrivacyLevel.onDevice
    let outcomes: [Result<String, ProviderError>]
    private let callCount = Recorder<Int>()
    private let onRespond: (@Sendable (String, [ChatTurn]) -> Void)?

    init(
        outcomes: [Result<String, ProviderError>],
        onRespond: (@Sendable (String, [ChatTurn]) -> Void)? = nil
    ) {
        self.outcomes = outcomes
        self.onRespond = onRespond
    }

    func availability() async -> ProviderAvailability { .available }

    func respond(to prompt: String, instructions: String?, history: [ChatTurn]) async throws -> String {
        let index = callCount.values.count
        callCount.append(index)
        onRespond?(prompt, history)
        return try outcomes[min(index, outcomes.count - 1)].get()
    }
}
