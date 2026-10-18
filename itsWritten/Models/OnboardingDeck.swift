//
//  OnboardingDeck.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import Foundation

/// The onboarding postcards as a deck: one card is read at a time, postmarked when the
/// reader moves on, then sent off the top of the deck.
struct OnboardingDeck {
    let count: Int

    /// The card on top of the deck.
    private(set) var currentIndex = 0

    /// How many cards, from the first, carry a postmark.
    private(set) var postmarkedCount = 0

    var canGoBack: Bool {
        currentIndex > 0
    }

    var isLastCard: Bool {
        currentIndex == count - 1
    }

    func placement(of index: Int) -> PostcardPlacement {
        if index < currentIndex {
            .sent
        } else if index == currentIndex {
            .current
        } else {
            .waiting(depth: index - currentIndex)
        }
    }

    func isPostmarked(_ index: Int) -> Bool {
        index < postmarkedCount
    }

    /// Postmarks the card on top of the deck.
    mutating func postmarkCurrent() {
        postmarkedCount = max(postmarkedCount, currentIndex + 1)
    }

    /// Sends the card on top of the deck away, revealing the next one.
    mutating func sendCurrent() {
        guard !isLastCard else { return }
        currentIndex += 1
    }

    /// Brings the last sent card back to the top, without its postmark.
    mutating func goBack() {
        guard canGoBack else { return }
        currentIndex -= 1
        postmarkedCount = currentIndex
    }

    /// How far the current card follows a horizontal drag. It moves freely toward the
    /// leading edge while there's a next card, and only resists otherwise, hinting that
    /// the swipe won't send it.
    func dragOffset(for translation: Double) -> Double {
        if translation < 0, !isLastCard {
            translation
        } else {
            translation * 0.25
        }
    }

    /// Decides what a finished drag does: it counts once it passes `threshold`, either
    /// where it was let go or where its momentum would carry it.
    func swipe(translation: Double, predictedTranslation: Double, threshold: Double) -> OnboardingSwipe? {
        let distance = abs(translation) > abs(predictedTranslation) ? translation : predictedTranslation

        if distance <= -threshold, !isLastCard {
            return .next
        } else if distance >= threshold, canGoBack {
            return .back
        } else {
            return nil
        }
    }
}
