//
//  NewChatTransitionTests.swift
//  itsWrittenTests
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI
import XCTest
@testable import itsWritten

@MainActor
final class NewChatTransitionTests: XCTestCase {
    func testFlightPathStartsAndEndsAtEndpoints() {
        let path = LetterFlightPath(start: CGPoint(x: 100, y: 400), end: CGPoint(x: 350, y: 60))

        XCTAssertEqual(path.point(at: 0), path.start)
        XCTAssertEqual(path.point(at: 1), path.end)
    }

    func testFlightPathArcsAboveTheHigherEndpoint() {
        let path = LetterFlightPath(start: CGPoint(x: 100, y: 400), end: CGPoint(x: 350, y: 60))

        XCTAssertLessThan(path.control.y, 60)
        XCTAssertLessThan(path.point(at: 0.9).y, path.end.y, "The letter should drop into the button from above")
    }

    func testFlightPathClampsProgress() {
        let path = LetterFlightPath(start: .zero, end: CGPoint(x: 10, y: 10))

        XCTAssertEqual(path.point(at: -1), path.start)
        XCTAssertEqual(path.point(at: 2), path.end)
    }

    func testSourceFrameIsConvertedIntoContainerSpace() {
        let transition = NewChatTransition()
        transition.containerFrame = CGRect(x: 20, y: 50, width: 400, height: 800)
        transition.sourceGlobalFrame = CGRect(x: 20, y: 150, width: 400, height: 500)

        XCTAssertEqual(transition.sourceFrame, CGRect(x: 0, y: 100, width: 400, height: 500))
        XCTAssertEqual(transition.landingScale, 44 / 400, accuracy: 0.0001)
    }

    func testTargetIsTheTopTrailingToolbarSlot() {
        let transition = NewChatTransition()
        transition.containerFrame = CGRect(x: 0, y: 0, width: 400, height: 800)

        XCTAssertEqual(transition.targetFrame, CGRect(x: 340, y: 5, width: 44, height: 44))

        transition.layoutDirection = .rightToLeft
        XCTAssertEqual(transition.targetFrame.minX, 16, "Trailing is on the left in right-to-left layouts")
    }

    func testReduceMotionResetsImmediatelyWithoutAnimating() {
        let transition = makeMeasuredTransition()
        var didReset = false

        transition.start(messages: [], reduceMotion: true) { didReset = true }

        XCTAssertTrue(didReset)
        XCTAssertFalse(transition.isActive)
    }

    func testMissingGeometryFallsBackToImmediateReset() {
        let transition = NewChatTransition()
        var didReset = false

        transition.start(messages: [], reduceMotion: false) { didReset = true }

        XCTAssertTrue(didReset)
        XCTAssertFalse(transition.isActive)
    }

    func testTargetFollowsIPhoneDuoVerticalBar() {
        let transition = NewChatTransition()
        transition.containerFrame = CGRect(x: 0, y: 0, width: 382, height: 644)
        transition.containerSafeAreaInsets = EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84)
        transition.toolbarVerticalEdge = .trailing

        XCTAssertEqual(transition.targetFrame.midX, 418, accuracy: 0.001, "48 pt in from the screen's trailing edge")
        XCTAssertEqual(transition.targetFrame.midY, 194, accuracy: 0.001)
        XCTAssertEqual(transition.headerAlignment, .leading)

        transition.containerSafeAreaInsets = EdgeInsets(top: 0, leading: 84, bottom: 34, trailing: 0)
        transition.toolbarVerticalEdge = .leading
        XCTAssertEqual(transition.targetFrame.midX, -36, accuracy: 0.001, "48 pt in from the screen's leading edge")
    }

    func testLetterIncludesTheHeaderAboveTheMessages() {
        let transition = NewChatTransition()
        transition.containerFrame = CGRect(x: 0, y: 62, width: 402, height: 778)
        transition.sourceGlobalFrame = CGRect(x: 0, y: 116, width: 402, height: 638)

        XCTAssertEqual(transition.headerHeight, 54)
        XCTAssertEqual(transition.letterFrame, CGRect(x: 0, y: 0, width: 402, height: 692))
        XCTAssertEqual(transition.headerAlignment, .center)
    }

    func testStartShowsTheLetterWithoutResettingYet() {
        let transition = makeMeasuredTransition()
        var didReset = false

        transition.start(messages: [ChatMessage(content: "Hi", isUser: true)], reduceMotion: false) {
            didReset = true
        }

        XCTAssertEqual(transition.phase, .paper)
        XCTAssertTrue(transition.isActive)
        XCTAssertFalse(didReset, "The conversation resets only once the paper covers it")
    }

    func testStartIsIgnoredWhileAlreadyRunning() {
        let transition = makeMeasuredTransition()
        var resetCount = 0

        transition.start(messages: [], reduceMotion: false) { resetCount += 1 }
        transition.start(messages: [], reduceMotion: true) { resetCount += 1 }

        XCTAssertEqual(resetCount, 0, "A second tap mid-animation must not reset again")
    }

    // Outside a rendered view hierarchy, SwiftUI runs `withAnimation` completions
    // immediately, so `run` plays the whole sequence synchronously here.

    func testStartCapturesTheLatestMessagesBeforeResetting() {
        let transition = makeMeasuredTransition()
        let messages = (0..<20).map { ChatMessage(content: "Message \($0)", isUser: $0.isMultiple(of: 2)) }
        var snapshotAtReset: [ChatMessage] = []

        var titleAtReset = ""

        transition.start(messages: messages, title: "Morning Pages", reduceMotion: false) {
            snapshotAtReset = transition.snapshot
            titleAtReset = transition.snapshotTitle
        }
        transition.run()

        XCTAssertEqual(snapshotAtReset.count, 12)
        XCTAssertEqual(snapshotAtReset.last?.content, "Message 19")
        XCTAssertEqual(titleAtReset, "Morning Pages")
    }

    func testFullSequenceResetsOnceDeliversAndReturnsToIdle() {
        let transition = makeMeasuredTransition()
        var resetCount = 0

        transition.start(messages: [ChatMessage(content: "Hi", isUser: true)], reduceMotion: false) {
            resetCount += 1
        }
        transition.run()

        XCTAssertEqual(resetCount, 1)
        XCTAssertEqual(transition.deliveryCount, 1)
        XCTAssertEqual(transition.phase, .idle)
    }

    func testFinishReturnsToIdle() {
        let transition = makeMeasuredTransition()
        transition.start(messages: [ChatMessage(content: "Hi", isUser: true)], reduceMotion: false) {}

        transition.finish()

        XCTAssertEqual(transition.phase, .idle)
        XCTAssertTrue(transition.snapshot.isEmpty)
        XCTAssertEqual(transition.bottomFoldAngle, 0)
        XCTAssertEqual(transition.flightProgress, 0)
    }

    private func makeMeasuredTransition() -> NewChatTransition {
        let transition = NewChatTransition()
        transition.containerFrame = CGRect(x: 0, y: 0, width: 400, height: 800)
        transition.sourceGlobalFrame = CGRect(x: 0, y: 100, width: 400, height: 600)
        return transition
    }
}
