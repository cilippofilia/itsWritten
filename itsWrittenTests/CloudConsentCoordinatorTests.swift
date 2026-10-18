//
//  CloudConsentCoordinatorTests.swift
//  itsWrittenTests
//

import VoltaSDK
import XCTest
@testable import itsWritten

@available(iOS 26.0, *)
@MainActor
final class CloudConsentCoordinatorTests: XCTestCase {
    /// Records whether a request has resolved, readable from the test body.
    @MainActor
    private final class ResolutionFlag {
        var isResolved = false
    }

    private var suiteName = ""
    private var defaults = UserDefaults.standard

    override func setUp() {
        super.setUp()
        suiteName = "CloudConsentCoordinatorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private let claudeDowngrade = PrivacyDowngrade(from: .onDevice, to: .external, provider: .userAccount(.anthropic))
    private let appleCloudDowngrade = PrivacyDowngrade(
        from: .onDevice,
        to: .appleCloud,
        provider: .privateCloudCompute
    )

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

    func testDestinationMapping() {
        let claude = ConsentDestination(provider: .userAccount(.anthropic), privacyLevel: .external)
        XCTAssertEqual(claude, .vendor(.anthropic))
        XCTAssertEqual(claude?.displayName, "Claude")
        XCTAssertEqual(ConsentDestination(provider: .anthropic, privacyLevel: .external), .vendor(.anthropic))
        XCTAssertEqual(
            ConsentDestination(provider: .privateCloudCompute, privacyLevel: .appleCloud),
            .privateCloudCompute
        )
        XCTAssertNil(ConsentDestination(provider: .onDevice, privacyLevel: .onDevice))
        XCTAssertNil(ConsentDestination(provider: ProviderIdentifier("x"), privacyLevel: .external))
        XCTAssertNil(ConsentDestination(provider: .privateCloudCompute, privacyLevel: .external))
        XCTAssertNil(ConsentDestination(provider: .userAccount(.anthropic), privacyLevel: .appleCloud))
    }

    func testRequestPublishesPendingAndResolves() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let task = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .vendor(.anthropic))

        try answerShown(coordinator, allow: true)
        let allowed = await task.value
        XCTAssertTrue(allowed)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testGrantIsRememberedForConversation() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let task = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        try answerShown(coordinator, allow: true)
        _ = await task.value

        let second = await coordinator.request(claudeDowngrade)
        XCTAssertTrue(second)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testDeclineIsNotRemembered() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let first = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        let firstID = coordinator.pendingRequest?.id
        try answerShown(coordinator, allow: false)
        let firstResult = await first.value
        XCTAssertFalse(firstResult)
        XCTAssertNil(coordinator.pendingRequest)

        let second = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .vendor(.anthropic))
        XCTAssertNotEqual(coordinator.pendingRequest?.id, firstID)
        try answerShown(coordinator, allow: false)
        _ = await second.value
    }

    func testAlwaysAllowSkipsPrompt() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        coordinator.setAlwaysAllowed(true, for: .vendor(.anthropic))
        XCTAssertTrue(coordinator.isAlwaysAllowed(.vendor(.anthropic)))

        let allowed = await coordinator.request(claudeDowngrade)
        XCTAssertTrue(allowed)
        XCTAssertNil(coordinator.pendingRequest)

        let fresh = CloudConsentCoordinator(defaults: defaults)
        XCTAssertTrue(fresh.isAlwaysAllowed(.vendor(.anthropic)))
        let freshAllowed = await fresh.request(claudeDowngrade)
        XCTAssertTrue(freshAllowed)
        XCTAssertNil(fresh.pendingRequest)

        fresh.setAlwaysAllowed(false, for: .vendor(.anthropic))
        XCTAssertFalse(fresh.isAlwaysAllowed(.vendor(.anthropic)))
    }

    func testDestinationsAreSeparate() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let claude = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        try answerShown(coordinator, allow: true)
        _ = await claude.value

        let apple = Task { await coordinator.request(appleCloudDowngrade) }
        await waitForPending(coordinator)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .privateCloudCompute)
        try answerShown(coordinator, allow: false)
        let appleResult = await apple.value
        XCTAssertFalse(appleResult)
    }

    func testConcurrentRequestsForSameDestinationCoalesce() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let first = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        let pendingID = coordinator.pendingRequest?.id
        let second = Task { await coordinator.request(claudeDowngrade) }
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(coordinator.pendingRequest?.id, pendingID)

        try answerShown(coordinator, allow: true)
        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertTrue(firstResult)
        XCTAssertTrue(secondResult)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testDifferentDestinationWaitsForCurrentPrompt() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let claude = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        let apple = Task { await coordinator.request(appleCloudDowngrade) }
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(coordinator.pendingRequest?.destination, .vendor(.anthropic))

        try answerShown(coordinator, allow: true)
        let claudeResult = await claude.value
        XCTAssertTrue(claudeResult)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .privateCloudCompute)

        try answerShown(coordinator, allow: false)
        let appleResult = await apple.value
        XCTAssertFalse(appleResult)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testResetResolvesPendingWithFalse() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let claude = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        let apple = Task { await coordinator.request(appleCloudDowngrade) }
        for _ in 0..<100 { await Task.yield() }

        coordinator.resetConversationGrants()
        let claudeResult = await claude.value
        let appleResult = await apple.value
        XCTAssertFalse(claudeResult)
        XCTAssertFalse(appleResult)
        XCTAssertNil(coordinator.pendingRequest)

        let next = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .vendor(.anthropic))
        try answerShown(coordinator, allow: false)
        _ = await next.value
    }

    func testResetClearsGrants() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let first = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        try answerShown(coordinator, allow: true)
        _ = await first.value

        coordinator.resetConversationGrants()
        let second = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .vendor(.anthropic))
        try answerShown(coordinator, allow: false)
        _ = await second.value
    }

    func testRespondWithoutPendingIsNoOp() {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        coordinator.respond(to: UUID(), allow: true)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testStaleAnswerDoesNotAnswerNextPrompt() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let claude = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        let claudeID = try XCTUnwrap(coordinator.pendingRequest?.id)

        let appleFlag = ResolutionFlag()
        let apple = Task {
            let result = await coordinator.request(appleCloudDowngrade)
            appleFlag.isResolved = true
            return result
        }
        for _ in 0..<100 { await Task.yield() }

        coordinator.respond(to: claudeID, allow: true)
        coordinator.respond(to: claudeID, allow: true)
        let claudeResult = await claude.value
        XCTAssertTrue(claudeResult)
        for _ in 0..<100 { await Task.yield() }

        let applePending = try XCTUnwrap(coordinator.pendingRequest)
        XCTAssertEqual(applePending.destination, .privateCloudCompute)
        XCTAssertNotEqual(applePending.id, claudeID)
        XCTAssertFalse(appleFlag.isResolved)

        coordinator.respond(to: applePending.id, allow: false)
        let appleResult = await apple.value
        XCTAssertFalse(appleResult)
        XCTAssertTrue(appleFlag.isResolved)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testCancelledRequestResolvesFalseAndClearsPrompt() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let claude = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .vendor(.anthropic))

        claude.cancel()
        let claudeResult = await claude.value
        XCTAssertFalse(claudeResult)
        XCTAssertNil(coordinator.pendingRequest)

        // A cancelled waiter for the shown prompt hands over to the next queued destination.
        let first = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        let apple = Task { await coordinator.request(appleCloudDowngrade) }
        for _ in 0..<100 { await Task.yield() }

        first.cancel()
        let firstResult = await first.value
        XCTAssertFalse(firstResult)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .privateCloudCompute)

        // Cancelling a queued waiter resolves it without touching the shown prompt.
        let queuedClaude = Task { await coordinator.request(claudeDowngrade) }
        for _ in 0..<100 { await Task.yield() }
        queuedClaude.cancel()
        let queuedResult = await queuedClaude.value
        XCTAssertFalse(queuedResult)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .privateCloudCompute)

        try answerShown(coordinator, allow: false)
        let appleResult = await apple.value
        XCTAssertFalse(appleResult)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testCancellationAfterAnswerKeepsAnswer() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let claude = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        try answerShown(coordinator, allow: true)
        claude.cancel()
        let result = await claude.value
        XCTAssertTrue(result)
        for _ in 0..<100 { await Task.yield() }
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testCancelledTaskIsDeclinedEvenWhenAlwaysAllowed() async {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        coordinator.setAlwaysAllowed(true, for: .vendor(.anthropic))
        let task = Task {
            try? await Task.sleep(for: .seconds(10))
            return await coordinator.request(claudeDowngrade)
        }
        task.cancel()

        let allowed = await task.value
        XCTAssertFalse(allowed)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testCancelledTaskIsDeclinedEvenWithConversationGrant() async throws {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let first = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        try answerShown(coordinator, allow: true)
        let firstAllowed = await first.value
        XCTAssertTrue(firstAllowed)

        let task = Task {
            try? await Task.sleep(for: .seconds(10))
            return await coordinator.request(claudeDowngrade)
        }
        task.cancel()

        let allowed = await task.value
        XCTAssertFalse(allowed)
        XCTAssertNil(coordinator.pendingRequest)
    }
}
