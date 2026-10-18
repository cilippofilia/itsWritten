//
//  CloudConsentReviewTests.swift
//  itsWrittenTests
//

import VoltaSDK
import XCTest
@testable import itsWritten

/// Vendor consent through the outbound filter: redaction, the review sheet's
/// state, and restoring replies.
@available(iOS 26.0, *)
@MainActor
final class CloudConsentReviewTests: XCTestCase {
    private var suiteName = ""
    private var defaults = UserDefaults.standard

    override func setUp() {
        super.setUp()
        suiteName = "CloudConsentReviewTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private let claudeDowngrade = PrivacyDowngrade(from: .onDevice, to: .external, provider: .userAccount(.anthropic))

    /// Yields until the coordinator publishes a pending request, or gives up after a bounded number of yields.
    private func waitForPending(_ coordinator: CloudConsentCoordinator) async {
        for _ in 0..<1_000 where coordinator.pendingRequest == nil {
            await Task.yield()
        }
    }

    /// Answers whatever prompt is currently shown, using its own id.
    private func answerShown(_ coordinator: CloudConsentCoordinator, allow: Bool) throws {
        let request = try XCTUnwrap(coordinator.pendingRequest)
        coordinator.respond(to: request.id, allow: allow)
    }

    private func claudeCall(_ prompt: String, history: [ChatTurn] = []) -> OutboundCall {
        OutboundCall(
            prompt: prompt,
            instructions: "Be brief.",
            history: history,
            provider: .userAccount(.anthropic),
            privacyLevel: .external
        )
    }

    func testVendorDowngradeIsLeftToReview() async {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let allowed = await coordinator.request(claudeDowngrade)
        XCTAssertTrue(allowed)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testOnDeviceAndPrivateCloudCallsPassUnchanged() async {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let onDevice = OutboundCall(prompt: "Hi Marta", instructions: nil, history: [], provider: .onDevice, privacyLevel: .onDevice)
        let appleCloud = OutboundCall(
            prompt: "Hi Marta", instructions: nil, history: [], provider: .privateCloudCompute, privacyLevel: .appleCloud
        )
        let onDeviceResult = await coordinator.review(onDevice)
        let appleCloudResult = await coordinator.review(appleCloud)
        XCTAssertEqual(onDeviceResult, onDevice)
        XCTAssertEqual(appleCloudResult, appleCloud)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testUnknownExternalProviderIsBlocked() async {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let call = OutboundCall(prompt: "hi", instructions: nil, history: [], provider: ProviderIdentifier("x"), privacyLevel: .external)
        let result = await coordinator.review(call)
        XCTAssertNil(result)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testReviewShowsDetailsAndSendsRedacted() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let task = Task { await coordinator.review(self.claudeCall("Email marta.rossi@example.com today")) }
        await waitForPending(coordinator)
        let review = try XCTUnwrap(coordinator.pendingRequest?.review)
        XCTAssertEqual(review.sentText, "Email [EMAIL_1] today")
        XCTAssertEqual(review.segments.compactMap(\.entity?.original), ["marta.rossi@example.com"])

        try answerShown(coordinator, allow: true)
        let sentResult = await task.value
        let sent = try XCTUnwrap(sentResult)
        XCTAssertEqual(sent.prompt, "Email [EMAIL_1] today")
        XCTAssertTrue(sent.instructions?.hasPrefix("Be brief.") == true)
        XCTAssertTrue(sent.instructions?.contains(RedactionSession.placeholderNote) == true)
    }

    func testReviewedDetailsDontAskAgainButNewOnesDo() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let first = Task { await coordinator.review(self.claudeCall("Write to marta@example.com")) }
        await waitForPending(coordinator)
        try answerShown(coordinator, allow: true)
        _ = await first.value

        // Same detail, now in the history too: no prompt.
        let repeated = await coordinator.review(
            claudeCall("And again to marta@example.com", history: [.user("Write to marta@example.com")])
        )
        XCTAssertEqual(repeated?.prompt, "And again to [EMAIL_1]")
        XCTAssertEqual(repeated?.history.map(\.text), ["Write to [EMAIL_1]"])
        XCTAssertNil(coordinator.pendingRequest)

        // A new detail asks again, even though Claude is allowed in this conversation.
        let fresh = Task { await coordinator.review(self.claudeCall("Call +44 20 7946 0958")) }
        await waitForPending(coordinator)
        XCTAssertNotNil(coordinator.pendingRequest?.review)
        try answerShown(coordinator, allow: true)
        let freshResult = await fresh.value
        XCTAssertEqual(freshResult?.prompt, "Call [PHONE_1]")
    }

    func testAlwaysAllowedStillReviewsNewDetails() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        coordinator.setAlwaysAllowed(true, for: .vendor(.anthropic))
        let plain = await coordinator.review(claudeCall("hello"))
        XCTAssertEqual(plain?.prompt, "hello")
        XCTAssertNil(coordinator.pendingRequest)

        let task = Task { await coordinator.review(self.claudeCall("My card is 4111 1111 1111 1111")) }
        await waitForPending(coordinator)
        XCTAssertNotNil(coordinator.pendingRequest?.review)
        try answerShown(coordinator, allow: true)
        let result = await task.value
        XCTAssertEqual(result?.prompt, "My card is [CARD_1]")
    }

    func testRevealedDetailIsSentAsIs() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let task = Task { await coordinator.review(self.claudeCall("Mail marta@example.com and call +44 20 7946 0958")) }
        await waitForPending(coordinator)
        let request = try XCTUnwrap(coordinator.pendingRequest)
        coordinator.toggleReveal("[EMAIL_1]", in: request.id)
        XCTAssertEqual(coordinator.pendingRequest?.id, request.id)
        XCTAssertEqual(coordinator.pendingRequest?.review?.sentText, "Mail marta@example.com and call [PHONE_1]")

        coordinator.respond(to: request.id, allow: true)
        let result = await task.value
        XCTAssertEqual(result?.prompt, "Mail marta@example.com and call [PHONE_1]")
    }

    func testToggleForStaleRequestIsIgnored() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let task = Task { await coordinator.review(self.claudeCall("Mail marta@example.com")) }
        await waitForPending(coordinator)
        let request = try XCTUnwrap(coordinator.pendingRequest)
        coordinator.toggleReveal("[EMAIL_1]", in: UUID())
        XCTAssertEqual(coordinator.pendingRequest?.review?.sentText, "Mail [EMAIL_1]")
        coordinator.respond(to: request.id, allow: false)
        _ = await task.value
    }

    func testDeclineForgetsNewDetails() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let task = Task { await coordinator.review(self.claudeCall("Mail marta@example.com")) }
        await waitForPending(coordinator)
        try answerShown(coordinator, allow: false)
        let result = await task.value
        XCTAssertNil(result)
        XCTAssertTrue(coordinator.redaction.isEmpty)
    }

    func testCoalescedCallsAreCheckedAgainAfterSend() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let first = Task { await coordinator.review(self.claudeCall("Mail marta@example.com")) }
        await waitForPending(coordinator)
        let firstID = try XCTUnwrap(coordinator.pendingRequest?.id)
        // Waits on the same prompt: same detail, and one the user hasn't seen.
        let same = Task { await coordinator.review(self.claudeCall("Title for marta@example.com")) }
        let other = Task { await coordinator.review(self.claudeCall("Mail luca@example.com")) }
        for _ in 0..<100 { await Task.yield() }

        coordinator.respond(to: firstID, allow: true)
        let firstResult = await first.value
        let sameResult = await same.value
        XCTAssertEqual(firstResult?.prompt, "Mail [EMAIL_1]")
        XCTAssertEqual(sameResult?.prompt, "Title for [EMAIL_1]")

        // The unseen detail gets its own prompt.
        await waitForPending(coordinator)
        let second = try XCTUnwrap(coordinator.pendingRequest)
        XCTAssertNotEqual(second.id, firstID)
        XCTAssertEqual(second.review?.sentText, "Mail [EMAIL_2]")
        coordinator.respond(to: second.id, allow: true)
        let otherResult = await other.value
        XCTAssertEqual(otherResult?.prompt, "Mail [EMAIL_2]")
    }

    func testCancelledReviewIsDeclinedAndForgetsDetails() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let task = Task { await coordinator.review(self.claudeCall("Mail marta@example.com")) }
        await waitForPending(coordinator)
        task.cancel()
        let result = await task.value
        XCTAssertNil(result)
        for _ in 0..<100 { await Task.yield() }
        XCTAssertNil(coordinator.pendingRequest)
        XCTAssertTrue(coordinator.redaction.isEmpty)
    }

    func testResetForgetsDetails() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let task = Task { await coordinator.review(self.claudeCall("Mail marta@example.com")) }
        await waitForPending(coordinator)
        try answerShown(coordinator, allow: true)
        _ = await task.value
        XCTAssertFalse(coordinator.redaction.isEmpty)

        coordinator.resetConversationGrants()
        XCTAssertTrue(coordinator.redaction.isEmpty)
        XCTAssertEqual(coordinator.restore("Hi [EMAIL_1]"), "Hi [EMAIL_1]")
    }

    func testRestorePutsWordsBack() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let task = Task { await coordinator.review(self.claudeCall("Mail marta@example.com")) }
        await waitForPending(coordinator)
        try answerShown(coordinator, allow: true)
        _ = await task.value
        XCTAssertEqual(coordinator.restore("Sent to [EMAIL_1]."), "Sent to marta@example.com.")
        XCTAssertEqual(coordinator.restoreForDisplay("Sent to [EMA"), "Sent to ")
    }
}
