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
/// Bookkeeping: every suspended call is a `CheckedContinuation`, tagged with a
/// token, that lives in exactly one place: either `currentWaiters` (the prompt
/// on screen) or one entry of `queue` (destinations waiting their turn, FIFO).
/// Answers, resets and cancellations all remove a continuation from storage
/// before resuming it, and only resume what they removed, so each one is
/// resumed exactly once.
@MainActor
@Observable
final class CloudConsentCoordinator {
    /// One suspended `request(_:)` call. The token lets cancellation find it.
    private struct Waiter {
        let token: UUID
        let continuation: CheckedContinuation<Bool, Never>
    }

    /// A destination waiting for its turn, with every call asking for it.
    private struct QueuedPrompt {
        let destination: ConsentDestination
        var waiters: [Waiter]
    }

    /// The prompt the UI should show, or `nil` when nothing is waiting.
    private(set) var pendingRequest: ConsentRequest?

    /// Calls waiting on `pendingRequest`.
    @ObservationIgnored private var currentWaiters: [Waiter] = []
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
    /// for the user's answer. If the calling task is cancelled while waiting,
    /// returns `false`.
    func request(_ downgrade: PrivacyDowngrade) async -> Bool {
        guard let destination = ConsentDestination(provider: downgrade.provider, privacyLevel: downgrade.to) else {
            return false
        }
        if isAllowedWithoutPrompt(destination) {
            return true
        }
        let token = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Cancelled before we could enqueue: the handler below has
                // nothing to find, so answer here.
                guard !Task.isCancelled else {
                    continuation.resume(returning: false)
                    return
                }
                enqueue(Waiter(token: token, continuation: continuation), for: destination)
            }
        } onCancel: {
            Task { @MainActor in
                self.cancelWaiter(token)
            }
        }
    }

    /// Answers the prompt with the given id. Every call waiting on it gets
    /// `allow`. A "yes" is remembered for the rest of the conversation; a
    /// "no" is not.
    ///
    /// Does nothing unless `requestID` is the prompt currently shown, so a
    /// duplicate or stale answer can never answer a prompt the user has not
    /// seen.
    func respond(to requestID: ConsentRequest.ID, allow: Bool) {
        guard let request = pendingRequest, request.id == requestID else { return }
        let waiters = currentWaiters
        currentWaiters = []
        pendingRequest = nil
        if allow {
            conversationGrants.insert(request.destination)
        }
        for waiter in waiters {
            waiter.continuation.resume(returning: allow)
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
            waiter.continuation.resume(returning: false)
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
    private func enqueue(_ waiter: Waiter, for destination: ConsentDestination) {
        if pendingRequest?.destination == destination {
            currentWaiters.append(waiter)
        } else if let index = queue.firstIndex(where: { $0.destination == destination }) {
            queue[index].waiters.append(waiter)
        } else {
            queue.append(QueuedPrompt(destination: destination, waiters: [waiter]))
            if pendingRequest == nil {
                showNextPrompt()
            }
        }
    }

    /// Declines one cancelled call, if it is still waiting. A call that was
    /// already answered is no longer stored, so it is never resumed twice.
    private func cancelWaiter(_ token: UUID) {
        if let index = currentWaiters.firstIndex(where: { $0.token == token }) {
            let waiter = currentWaiters.remove(at: index)
            if currentWaiters.isEmpty {
                // Nobody is waiting on the shown prompt any more.
                pendingRequest = nil
                showNextPrompt()
            }
            waiter.continuation.resume(returning: false)
            return
        }
        for queueIndex in queue.indices {
            guard let index = queue[queueIndex].waiters.firstIndex(where: { $0.token == token }) else { continue }
            let waiter = queue[queueIndex].waiters.remove(at: index)
            if queue[queueIndex].waiters.isEmpty {
                queue.remove(at: queueIndex)
            }
            waiter.continuation.resume(returning: false)
            return
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
                    waiter.continuation.resume(returning: true)
                }
                continue
            }
            currentWaiters = next.waiters
            pendingRequest = ConsentRequest(id: UUID(), destination: next.destination)
            return
        }
    }
}
