//
//  CloudConsentCoordinator.swift
//  itsWritten
//

import Foundation
import Observation
import VoltaSDK

/// Bridges Volta's privacy hooks to the consent UI, and hides personal details
/// from third-party vendors.
///
/// Two entry points, one per Volta hook:
/// - `request(_:)`, the `.askOnPrivacyChange` handler, asks about Apple Private
///   Cloud Compute (plain alert). It lets vendor downgrades through, because
///   vendor consent needs the text of the call.
/// - `review(_:)`, the outbound filter, runs right before any provider is
///   called. For a vendor it redacts the call with the conversation's
///   `RedactionSession` and, when the vendor isn't allowed yet or the call holds
///   details the user hasn't reviewed, asks with the review sheet.
///
/// Nothing reaches a vendor without a "yes", and nothing reaches it unredacted.
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
    /// How a waiting call was answered.
    private enum Answer {
        case denied
        /// Allowed. Carries the redacted call for a vendor review; `nil` for a
        /// plain consent ask.
        case allowed(OutboundCall?)
    }

    /// One suspended call. The token lets cancellation find it.
    private struct Waiter {
        let token: UUID
        /// The call to review, for a vendor; `nil` for a plain consent ask.
        let call: OutboundCall?
        let continuation: CheckedContinuation<Answer, Never>
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
    /// The call the shown review sheet describes.
    @ObservationIgnored private var shownCall: OutboundCall?
    /// Prompts for other destinations, in arrival order.
    @ObservationIgnored private var queue: [QueuedPrompt] = []
    /// Destinations the user allowed during this conversation.
    @ObservationIgnored private var conversationGrants: Set<ConsentDestination> = []
    /// This conversation's personal details and their placeholders.
    @ObservationIgnored private(set) var redaction = RedactionSession()
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The Volta outbound filter that sends every call through `review(_:)`.
    var outboundFilter: OutboundFilter {
        { [weak self] call in
            guard let self else { return nil }
            return await self.review(call)
        }
    }

    // MARK: - Volta hooks

    /// Asks whether a privacy downgrade may go ahead.
    ///
    /// Returns `false` without prompting for destinations the app cannot
    /// describe. Returns `true` without prompting for a vendor (`review(_:)`
    /// asks, with the text in front of the user), and for a destination that is
    /// always allowed or was allowed earlier in this conversation. Otherwise
    /// waits for the user's answer. If the calling task is cancelled, before or
    /// while waiting, returns `false`, even for a destination that is allowed:
    /// a superseded call must never ride on a later conversation's grant.
    func request(_ downgrade: PrivacyDowngrade) async -> Bool {
        guard !Task.isCancelled else { return false }
        guard let destination = ConsentDestination(provider: downgrade.provider, privacyLevel: downgrade.to) else {
            return false
        }
        if case .vendor = destination {
            return true
        }
        if isAllowedWithoutPrompt(destination) {
            return true
        }
        guard case .allowed = await wait(for: destination, call: nil) else { return false }
        return true
    }

    /// The call a provider should receive, or `nil` to skip the provider.
    ///
    /// On-device and Private Cloud Compute calls pass unchanged (PCC consent was
    /// asked by `request(_:)`). A call to an external provider the app can't
    /// describe is blocked. A vendor call is redacted; it goes out without a
    /// prompt only when the vendor is allowed and every detail in it was
    /// reviewed. Cancellation before or while waiting returns `nil`.
    func review(_ call: OutboundCall) async -> OutboundCall? {
        guard !Task.isCancelled else { return nil }
        switch call.privacyLevel {
        case .onDevice, .appleCloud:
            return call
        case .external:
            break
        }
        guard let destination = ConsentDestination(provider: call.provider, privacyLevel: call.privacyLevel),
              case .vendor = destination else {
            return nil
        }
        if let ready = readyCall(for: call, to: destination) {
            return ready
        }
        guard case .allowed(let redacted) = await wait(for: destination, call: call) else { return nil }
        return redacted
    }

    // MARK: - Answers

    /// Answers the prompt with the given id. Every call waiting on it gets
    /// `allow`. A "yes" is remembered for the rest of the conversation, and the
    /// details in a review count as reviewed; a "no" is not remembered, and the
    /// details found for it are forgotten.
    ///
    /// After a "yes", each waiting vendor call is checked again and only asks
    /// once more if it holds details still unreviewed.
    ///
    /// Does nothing unless `requestID` is the prompt currently shown, so a
    /// duplicate or stale answer can never answer a prompt the user has not
    /// seen.
    func respond(to requestID: ConsentRequest.ID, allow: Bool) {
        guard let request = pendingRequest, request.id == requestID else { return }
        let waiters = currentWaiters
        currentWaiters = []
        shownCall = nil
        pendingRequest = nil
        if allow {
            conversationGrants.insert(request.destination)
            redaction.markAllReviewed()
            for waiter in waiters {
                guard let call = waiter.call else {
                    waiter.continuation.resume(returning: .allowed(nil))
                    continue
                }
                if let ready = readyCall(for: call, to: request.destination) {
                    waiter.continuation.resume(returning: .allowed(ready))
                } else {
                    enqueue(waiter, for: request.destination)
                }
            }
        } else {
            redaction.discardUnreviewed()
            for waiter in waiters {
                waiter.continuation.resume(returning: .denied)
            }
        }
        showNextPrompt()
    }

    /// Switches a detail in the shown review between hidden and sent as is.
    func toggleReveal(_ entityID: RedactedEntity.ID, in requestID: ConsentRequest.ID) {
        guard let request = pendingRequest, request.id == requestID, let shownCall else { return }
        redaction.toggleReveal(entityID)
        pendingRequest?.review = redaction.review(of: shownCall)
    }

    /// Forgets this conversation's grants and details, and declines every
    /// waiting call.
    func resetConversationGrants() {
        conversationGrants.removeAll()
        redaction = RedactionSession()
        let waiters = currentWaiters + queue.flatMap(\.waiters)
        currentWaiters = []
        shownCall = nil
        queue = []
        pendingRequest = nil
        for waiter in waiters {
            waiter.continuation.resume(returning: .denied)
        }
    }

    // MARK: - Restoring replies

    /// A vendor's reply with the real words put back.
    func restore(_ text: String) -> String {
        redaction.restore(text)
    }

    /// A vendor's reply that is still streaming, with the real words put back
    /// and any half-arrived placeholder held back.
    func restoreForDisplay(_ partial: String) -> String {
        redaction.restoreForDisplay(partial)
    }

    // MARK: - Always allow

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

    /// The redacted call, when it can go out without asking: the vendor is
    /// allowed and every detail in the call was reviewed. Leaves the session
    /// untouched otherwise.
    private func readyCall(for call: OutboundCall, to destination: ConsentDestination) -> OutboundCall? {
        guard isAllowedWithoutPrompt(destination) else { return nil }
        var draft = redaction
        let redacted = draft.redact(call)
        guard draft.hasUnreviewed(in: redacted.entityIDs) == false else { return nil }
        redaction = draft
        return redacted.call
    }

    /// Suspends until the prompt for `destination` is answered.
    private func wait(for destination: ConsentDestination, call: OutboundCall?) async -> Answer {
        let token = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Cancelled before we could enqueue: the handler below has
                // nothing to find, so answer here.
                guard !Task.isCancelled else {
                    continuation.resume(returning: .denied)
                    return
                }
                enqueue(Waiter(token: token, call: call, continuation: continuation), for: destination)
            }
        } onCancel: {
            Task { @MainActor in
                self.cancelWaiter(token)
            }
        }
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
                shownCall = nil
                redaction.discardUnreviewed()
                showNextPrompt()
            }
            waiter.continuation.resume(returning: .denied)
            return
        }
        for queueIndex in queue.indices {
            guard let index = queue[queueIndex].waiters.firstIndex(where: { $0.token == token }) else { continue }
            let waiter = queue[queueIndex].waiters.remove(at: index)
            if queue[queueIndex].waiters.isEmpty {
                queue.remove(at: queueIndex)
            }
            waiter.continuation.resume(returning: .denied)
            return
        }
    }

    /// Publishes the next queued prompt. Calls that became ready while they
    /// waited (allowed, nothing new to review) are answered without prompting.
    private func showNextPrompt() {
        guard pendingRequest == nil else { return }
        while !queue.isEmpty {
            let next = queue.removeFirst()
            let waiting = next.waiters.filter { waiter in
                if let call = waiter.call {
                    guard let ready = readyCall(for: call, to: next.destination) else { return true }
                    waiter.continuation.resume(returning: .allowed(ready))
                    return false
                }
                guard isAllowedWithoutPrompt(next.destination) else { return true }
                waiter.continuation.resume(returning: .allowed(nil))
                return false
            }
            guard let first = waiting.first else { continue }
            currentWaiters = waiting
            var review: RedactionReview?
            if let call = first.call {
                // Registers the call's new details, so the sheet can show them.
                _ = redaction.redact(call)
                shownCall = call
                review = redaction.review(of: call)
            }
            pendingRequest = ConsentRequest(id: UUID(), destination: next.destination, review: review)
            return
        }
    }
}
