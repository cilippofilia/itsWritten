//
//  GatedProvider.swift
//  itsWrittenTests
//

import Synchronization
import VoltaSDK

/// On-device provider whose availability check waits until the test opens its gate,
/// then reports unavailable so the chain moves on. The wait ignores cancellation, so
/// a test can change state while a call is parked here.
struct GatedProvider: ModelProvider {
    /// Shared open/entered flags.
    final class Gate: Sendable {
        private let state = Mutex<(entered: Bool, isOpen: Bool)>((false, false))

        var wasEntered: Bool { state.withLock { $0.entered } }
        var isOpen: Bool { state.withLock { $0.isOpen } }

        func enter() { state.withLock { $0.entered = true } }
        func open() { state.withLock { $0.isOpen = true } }
    }

    let identifier = ProviderIdentifier.onDevice
    let privacyLevel = PrivacyLevel.onDevice
    let gate: Gate

    func availability() async -> ProviderAvailability {
        gate.enter()
        while gate.isOpen == false {
            do {
                try await Task.sleep(for: .milliseconds(5))
            } catch {
                await Task.yield()
            }
        }
        return .unavailable(reason: "test")
    }

    func respond(to prompt: String, instructions: String?, history: [ChatTurn]) async throws -> String {
        throw ProviderError.noProviderAvailable
    }
}
