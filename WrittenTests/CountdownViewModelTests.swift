//
//  CountdownViewModelTests.swift
//  WrittenTests
//
//  Created by Filippo Cilia on 22/02/2026.
//

import XCTest
@testable import Written

@MainActor
final class CountdownViewModelTests: XCTestCase {
    func testStartTimerSetsState() {
        let viewModel = CountdownViewModel()

        viewModel.startTimer(duration: 60)

        XCTAssertTrue(viewModel.timerActive)
        XCTAssertFalse(viewModel.timerPaused)
        XCTAssertFalse(viewModel.timerExpired)
        XCTAssertNotNil(viewModel.endTime)
    }

    func testTimeRemainingReturnsZeroWithoutEndTime() {
        let viewModel = CountdownViewModel()

        let remaining = viewModel.timeRemaining(at: .now)

        XCTAssertEqual(remaining, 0, accuracy: 0.01)
    }

    func testPauseAndResumePreservesRemainingTime() async {
        let viewModel = CountdownViewModel()
        viewModel.startTimer(duration: 1)

        try? await Task.sleep(for: .milliseconds(200))
        viewModel.pauseTimer()

        let remaining = viewModel.timeRemaining(at: .now)
        try? await Task.sleep(for: .milliseconds(200))
        let remainingLater = viewModel.timeRemaining(at: .now)

        XCTAssertEqual(remaining, remainingLater, accuracy: 0.05)
        XCTAssertTrue(viewModel.timerPaused)
        XCTAssertTrue(viewModel.timerActive)

        viewModel.resumeTimer()
        XCTAssertFalse(viewModel.timerPaused)

        try? await Task.sleep(for: .milliseconds(150))
        let remainingAfterResume = viewModel.timeRemaining(at: .now)
        XCTAssertLessThan(remainingAfterResume, remaining)
    }

    func testFormattedTimePadsMinutesAndSeconds() {
        let viewModel = CountdownViewModel()

        XCTAssertEqual(viewModel.formattedTime(for: 5), "00:05")
        XCTAssertEqual(viewModel.formattedTime(for: 65), "01:05")
        XCTAssertEqual(viewModel.formattedTime(for: 600), "10:00")
    }

    func testStopTimerResetsState() {
        let viewModel = CountdownViewModel()
        viewModel.startTimer(duration: 60)

        viewModel.stopTimer()

        XCTAssertFalse(viewModel.timerActive)
        XCTAssertFalse(viewModel.timerPaused)
        XCTAssertFalse(viewModel.timerExpired)
        XCTAssertNil(viewModel.endTime)
    }

    func testTimerExpiresStopsTimer() async {
        let viewModel = CountdownViewModel()
        viewModel.startTimer(duration: 0.15)

        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(viewModel.timerActive)
        XCTAssertFalse(viewModel.timerPaused)
        XCTAssertNil(viewModel.endTime)
    }
}
