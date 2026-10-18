//
//  OnboardingDeckView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// The onboarding postcards stacked as a deck, every card sized to the tallest so the
/// stack stays even.
@available(iOS 26.0, *)
struct OnboardingDeckView: View {
    let steps: [OnboardingStep]
    let deck: OnboardingDeck

    /// How far the current card has been dragged horizontally.
    let dragOffset: Double

    /// Resting angles, in degrees, repeated across the deck.
    private static let tilts: [Double] = [-1.5, 1.2, -0.8, 1.6]

    var body: some View {
        // Invisible copies of every card size the deck to the tallest one; the visible
        // cards are then stretched to that size.
        ZStack {
            ForEach(steps.enumerated(), id: \.element.id) { index, step in
                postcard(for: step, at: index)
            }
        }
        .hidden()
        .accessibilityHidden(true)
        .overlay {
            ZStack {
                ForEach(steps.enumerated(), id: \.element.id) { index, step in
                    let placement = deck.placement(of: index)

                    let isCurrent = placement == .current

                    postcard(for: step, at: index)
                        // The dragged card tips a little, pivoting near its bottom edge
                        // like a card pushed across a table.
                        .offset(x: isCurrent ? dragOffset : 0)
                        .rotationEffect(.degrees(isCurrent ? dragOffset / 30 : 0), anchor: .bottom)
                        .modifier(
                            PostcardPlacementModifier(
                                placement: placement,
                                tilt: Self.tilts[index % Self.tilts.count]
                            )
                        )
                        .zIndex(zIndex(for: placement))
                        .accessibilityHidden(placement != .current)
                }
            }
        }
    }

    private func postcard(for step: OnboardingStep, at index: Int) -> OnboardingPostcardView {
        OnboardingPostcardView(
            step: step,
            ink: index.isMultiple(of: 2) ? .red : .blue,
            wearSeed: UInt64(index + 3),
            isPostmarked: deck.isPostmarked(index)
        )
    }

    /// Sent cards stay above the deck so one coming back lands on top.
    private func zIndex(for placement: PostcardPlacement) -> Double {
        switch placement {
        case .sent: Double(steps.count + 1)
        case .current: Double(steps.count)
        case .waiting(let depth): Double(steps.count - depth)
        }
    }
}
