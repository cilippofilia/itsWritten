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
        .scaleEffect(1 - 0.15 * paper)
        .shadow(color: .black.opacity(0.25 * paper), radius: 16 * paper, y: 8 * paper)
        .modifier(
            LetterFlightModifier(
                progress: transition.flightProgress,
                path: transition.flightPath,
                landingScale: transition.landingScale
            )
        )
        .position(x: frame.midX, y: frame.midY)
        .accessibilityHidden(true)
        // Animations start only once the letter is on screen; otherwise their
        // completions fire immediately and the whole sequence is skipped.
        .onAppear(perform: transition.run)
    }
}
