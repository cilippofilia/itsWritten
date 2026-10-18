//
//  OnboardingDeckTests.swift
//  itsWrittenTests
//
//  Created by Filippo Cilia on 18/10/2026.
//

import XCTest
@testable import itsWritten

final class OnboardingDeckTests: XCTestCase {
    func testStartsOnFirstCardWithNothingPostmarked() {
        let deck = OnboardingDeck(count: 4)

        XCTAssertEqual(deck.currentIndex, 0)
        XCTAssertFalse(deck.canGoBack)
        XCTAssertFalse(deck.isLastCard)
        XCTAssertFalse(deck.isPostmarked(0))
    }

    func testPlacementsAroundCurrentCard() {
        var deck = OnboardingDeck(count: 4)
        deck.sendCurrent()

        XCTAssertEqual(deck.placement(of: 0), .sent)
        XCTAssertEqual(deck.placement(of: 1), .current)
        XCTAssertEqual(deck.placement(of: 2), .waiting(depth: 1))
        XCTAssertEqual(deck.placement(of: 3), .waiting(depth: 2))
    }

    func testPostmarkingThenSendingRevealsNextCard() {
        var deck = OnboardingDeck(count: 4)

        deck.postmarkCurrent()
        XCTAssertTrue(deck.isPostmarked(0))
        XCTAssertEqual(deck.currentIndex, 0)

        deck.sendCurrent()
        XCTAssertEqual(deck.currentIndex, 1)
        XCTAssertTrue(deck.canGoBack)
        XCTAssertFalse(deck.isPostmarked(1))
    }

    func testSendingStopsAtLastCard() {
        var deck = OnboardingDeck(count: 2)
        deck.sendCurrent()
        deck.sendCurrent()

        XCTAssertEqual(deck.currentIndex, 1)
        XCTAssertTrue(deck.isLastCard)
    }

    func testGoingBackRemovesReturnedCardsPostmark() {
        var deck = OnboardingDeck(count: 4)
        deck.postmarkCurrent()
        deck.sendCurrent()
        deck.postmarkCurrent()
        deck.sendCurrent()

        deck.goBack()

        XCTAssertEqual(deck.currentIndex, 1)
        XCTAssertTrue(deck.isPostmarked(0))
        XCTAssertFalse(deck.isPostmarked(1))
    }

    func testGoingBackOnFirstCardDoesNothing() {
        var deck = OnboardingDeck(count: 4)
        deck.goBack()

        XCTAssertEqual(deck.currentIndex, 0)
    }

    func testDragFollowsFingerTowardNextCard() {
        let deck = OnboardingDeck(count: 4)

        XCTAssertEqual(deck.dragOffset(for: -100), -100)
        XCTAssertEqual(deck.dragOffset(for: 100), 25)
    }

    func testDragResistsOnLastCard() {
        var deck = OnboardingDeck(count: 2)
        deck.sendCurrent()

        XCTAssertEqual(deck.dragOffset(for: -100), -25)
    }

    func testSwipePastThresholdSendsCard() {
        let deck = OnboardingDeck(count: 4)

        XCTAssertEqual(deck.swipe(translation: -90, predictedTranslation: -90, threshold: 80), .next)
    }

    func testShortSwipeDoesNothing() {
        let deck = OnboardingDeck(count: 4)

        XCTAssertNil(deck.swipe(translation: -30, predictedTranslation: -40, threshold: 80))
    }

    func testFlickCountsByMomentum() {
        let deck = OnboardingDeck(count: 4)

        XCTAssertEqual(deck.swipe(translation: -30, predictedTranslation: -200, threshold: 80), .next)
    }

    func testSwipeBackOnlyWhenACardWasSent() {
        var deck = OnboardingDeck(count: 4)
        XCTAssertNil(deck.swipe(translation: 120, predictedTranslation: 120, threshold: 80))

        deck.sendCurrent()
        XCTAssertEqual(deck.swipe(translation: 120, predictedTranslation: 120, threshold: 80), .back)
    }

    func testSwipeOnLastCardDoesNotSend() {
        var deck = OnboardingDeck(count: 2)
        deck.sendCurrent()

        XCTAssertNil(deck.swipe(translation: -200, predictedTranslation: -300, threshold: 80))
    }
}
