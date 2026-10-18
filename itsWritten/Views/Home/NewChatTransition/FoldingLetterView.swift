//
//  FoldingLetterView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// The animated letter drawn over `HomeView` while a new chat starts: the conversation,
/// folded in thirds, then flown into the menu button. Driven entirely by `transition`.
struct FoldingLetterView: View {
    let transition: NewChatTransition

    var body: some View {
        let frame = transition.letterFrame
        let paper = transition.paperProgress
        let press = transition.pressProgress
        let cornerRadius = 8 * paper
        let face = LetterFace(
            title: transition.snapshotTitle,
            messages: transition.snapshot,
            headerHeight: transition.headerHeight,
            headerAlignment: transition.headerAlignment
        )

        VStack(spacing: 0) {
            LetterPanelView(face: face, size: frame.size, position: .top, cornerRadius: cornerRadius, borderOpacity: paper)
                .modifier(FoldPanelModifier(angle: transition.topFoldAngle, crease: .bottom, direction: -1))
                .zIndex(2)

            LetterPanelView(face: face, size: frame.size, position: .middle, cornerRadius: cornerRadius, borderOpacity: paper)
                .zIndex(0)

            LetterPanelView(face: face, size: frame.size, position: .bottom, cornerRadius: cornerRadius, borderOpacity: paper)
                .modifier(FoldPanelModifier(angle: transition.bottomFoldAngle, crease: .top, direction: 1))
                .zIndex(1)
        }
        // The stamp sits in the top-trailing corner of the folded letter (the middle third).
        .overlay(alignment: .topTrailing) {
            PostedStampView(progress: transition.stampProgress)
                .padding(.top, frame.height / 3 + 14)
                .padding(.trailing, 16)
        }
        // Pressing flat squashes the letter slightly and spreads its shadow.
        .scaleEffect(1 - 0.15 * paper - 0.03 * press)
        .shadow(
            color: .black.opacity(0.25 * paper + 0.2 * press),
            radius: 16 * paper + 10 * press,
            y: 8 * paper + 6 * press
        )
        .modifier(
            LetterFlightModifier(
                progress: transition.flightProgress,
                path: transition.flightPath,
                landingScale: transition.landingScale
            )
        )
        .position(x: frame.midX, y: frame.midY)
        .accessibilityHidden(true)
        .sensoryFeedback(.impact(weight: .medium), trigger: transition.stampCount)
        // Animations start only once the letter is on screen; otherwise their
        // completions fire immediately and the whole sequence is skipped.
        .onAppear(perform: transition.run)
    }
}
