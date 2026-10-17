//
//  CloudConsentCoordinatorTests.swift
//  itsWrittenTests
//

import VoltaSDK
import XCTest
@testable import itsWritten

@MainActor
final class CloudConsentCoordinatorTests: XCTestCase {
    private var defaults = UserDefaults(suiteName: UUID().uuidString)!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: UUID().uuidString)!
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
    }

    func testRequestPublishesPendingAndResolves() async {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let task = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .vendor(.anthropic))

        coordinator.respond(allow: true)
        let allowed = await task.value
        XCTAssertTrue(allowed)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testGrantIsRememberedForConversation() async {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let task = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        coordinator.respond(allow: true)
        _ = await task.value

        let second = await coordinator.request(claudeDowngrade)
        XCTAssertTrue(second)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testDeclineIsNotRemembered() async {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let first = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        let firstID = coordinator.pendingRequest?.id
        coordinator.respond(allow: false)
        let firstResult = await first.value
        XCTAssertFalse(firstResult)
        XCTAssertNil(coordinator.pendingRequest)

        let second = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .vendor(.anthropic))
        XCTAssertNotEqual(coordinator.pendingRequest?.id, firstID)
        coordinator.respond(allow: false)
        _ = await second.value
    }

    func testAlwaysAllowSkipsPrompt() async {
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

    func testDestinationsAreSeparate() async {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let claude = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        coordinator.respond(allow: true)
        _ = await claude.value

        let apple = Task { await coordinator.request(appleCloudDowngrade) }
        await waitForPending(coordinator)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .privateCloudCompute)
        coordinator.respond(allow: false)
        let appleResult = await apple.value
        XCTAssertFalse(appleResult)
    }

    func testConcurrentRequestsForSameDestinationCoalesce() async {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let first = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        let pendingID = coordinator.pendingRequest?.id
        let second = Task { await coordinator.request(claudeDowngrade) }
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(coordinator.pendingRequest?.id, pendingID)

        coordinator.respond(allow: true)
        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertTrue(firstResult)
        XCTAssertTrue(secondResult)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testDifferentDestinationWaitsForCurrentPrompt() async {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let claude = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        let apple = Task { await coordinator.request(appleCloudDowngrade) }
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(coordinator.pendingRequest?.destination, .vendor(.anthropic))

        coordinator.respond(allow: true)
        let claudeResult = await claude.value
        XCTAssertTrue(claudeResult)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .privateCloudCompute)

        coordinator.respond(allow: false)
        let appleResult = await apple.value
        XCTAssertFalse(appleResult)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testResetResolvesPendingWithFalse() async {
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
        coordinator.respond(allow: false)
        _ = await next.value
    }

    func testResetClearsGrants() async {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        let first = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        coordinator.respond(allow: true)
        _ = await first.value

        coordinator.resetConversationGrants()
        let second = Task { await coordinator.request(claudeDowngrade) }
        await waitForPending(coordinator)
        XCTAssertEqual(coordinator.pendingRequest?.destination, .vendor(.anthropic))
        coordinator.respond(allow: false)
        _ = await second.value
    }

    func testRespondWithoutPendingIsNoOp() {
        let coordinator = CloudConsentCoordinator(defaults: defaults)
        coordinator.respond(allow: true)
        XCTAssertNil(coordinator.pendingRequest)
    }
}
