//
//  CloudConsentCoordinator.swift
//  itsWritten
//

import Foundation
import Observation
import VoltaSDK

/// Bridges Volta's `.askOnPrivacyChange` handler to a SwiftUI alert.
///
/// A model call that would leave the device suspends in `request(_:)` until
/// the user answers the prompt published in `pendingRequest`. Nothing is
/// sent anywhere without a "yes".
///
/// Bookkeeping: every suspended call is a `CheckedContinuation` that lives in
/// exactly one place, either `currentWaiters` (the prompt on screen) or one
/// entry of `queue` (destinations waiting their turn, FIFO). A continuation is
/// always removed from storage before it is resumed, so each one is resumed
/// exactly once.
@MainActor
@Observable
final class CloudConsentCoordinator {
    /// A destination waiting for its turn, with every call asking for it.
    private struct QueuedPrompt {
        let destination: ConsentDestination
        var waiters: [CheckedContinuation<Bool, Never>]
    }

    /// The prompt the UI should show, or `nil` when nothing is waiting.
    private(set) var pendingRequest: ConsentRequest?

    /// Calls waiting on `pendingRequest`.
    @ObservationIgnored private var currentWaiters: [CheckedContinuation<Bool, Never>] = []
    /// Prompts for other destinations, in arrival order.
    @ObservationIgnored private var queue: [QueuedPrompt] = []
    /// Destinations the user allowed during this conversation.
    @ObservationIgnored private var conversationGrants: Set<ConsentDestination> = []
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Asks whether the downgrade may go ahead.
    ///
    /// Returns `false` without prompting for destinations the app cannot
    /// describe, and `true` without prompting when the destination is always
    /// allowed or was allowed earlier in this conversation. Otherwise waits
    /// for the user's answer.
    func request(_ downgrade: PrivacyDowngrade) async -> Bool {
        guard let destination = ConsentDestination(provider: downgrade.provider, privacyLevel: downgrade.to) else {
            return false
        }
        if isAllowedWithoutPrompt(destination) {
            return true
        }
        return await withCheckedContinuation { continuation in
            enqueue(continuation, for: destination)
        }
    }

    /// Answers the current prompt. Every call waiting on it gets `allow`.
    /// A "yes" is remembered for the rest of the conversation; a "no" is not.
    func respond(allow: Bool) {
        guard let request = pendingRequest else { return }
        let waiters = currentWaiters
        currentWaiters = []
        pendingRequest = nil
        if allow {
            conversationGrants.insert(request.destination)
        }
        for waiter in waiters {
            waiter.resume(returning: allow)
        }
        showNextPrompt()
    }

    /// Forgets this conversation's grants and declines every waiting call.
    func resetConversationGrants() {
        conversationGrants.removeAll()
        let waiters = currentWaiters + queue.flatMap(\.waiters)
        currentWaiters = []
        queue = []
        pendingRequest = nil
        for waiter in waiters {
            waiter.resume(returning: false)
        }
    }

    /// Whether the user chose to always allow this destination.
    func isAlwaysAllowed(_ destination: ConsentDestination) -> Bool {
        defaults.bool(forKey: destination.storageKey)
    }

    /// Stores the user's "always allow" choice for a destination.
    func setAlwaysAllowed(_ allowed: Bool, for destination: ConsentDestination) {
        defaults.set(allowed, forKey: destination.storageKey)
    }

    // MARK: - Private

    private func isAllowedWithoutPrompt(_ destination: ConsentDestination) -> Bool {
        isAlwaysAllowed(destination) || conversationGrants.contains(destination)
    }

    /// Adds a waiter to the prompt for its destination, creating one if needed.
    private func enqueue(_ continuation: CheckedContinuation<Bool, Never>, for destination: ConsentDestination) {
        if pendingRequest?.destination == destination {
            currentWaiters.append(continuation)
        } else if let index = queue.firstIndex(where: { $0.destination == destination }) {
            queue[index].waiters.append(continuation)
        } else {
            queue.append(QueuedPrompt(destination: destination, waiters: [continuation]))
            if pendingRequest == nil {
                showNextPrompt()
            }
        }
    }

    /// Publishes the next queued prompt. Destinations that became allowed
    /// while they waited are resolved with `true` without prompting.
    private func showNextPrompt() {
        guard pendingRequest == nil else { return }
        while !queue.isEmpty {
            let next = queue.removeFirst()
            if isAllowedWithoutPrompt(next.destination) {
                for waiter in next.waiters {
                    waiter.resume(returning: true)
                }
                continue
            }
            currentWaiters = next.waiters
            pendingRequest = ConsentRequest(id: UUID(), destination: next.destination)
            return
        }
    }
}
