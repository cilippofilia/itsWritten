//
//  PostcardPlacementModifier.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// Positions a postcard in the onboarding deck. Waiting cards sit lower and smaller so their
/// edges peek out below the current one; sent cards fly off to the leading side and fade.
/// Reduce Motion keeps sent cards in place and only fades them.
@available(iOS 26.0, *)
struct PostcardPlacementModifier: ViewModifier {
    let placement: PostcardPlacement

    /// The card's resting angle, in degrees, so the deck looks hand-stacked.
    let tilt: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Waiting cards deeper than this are hidden behind the visible stack.
    private let visibleDepth = 2

    private var isSent: Bool {
        placement == .sent
    }

    private var depth: Int {
        if case .waiting(let depth) = placement { depth } else { 0 }
    }

    private var rotation: Double {
        isSent && !reduceMotion ? -12 : tilt
    }

    private var opacity: Double {
        isSent || depth > visibleDepth ? 0 : 1
    }

    func body(content: Content) -> some View {
        let flyAway = isSent && !reduceMotion

        content
            .scaleEffect(1 - 0.04 * Double(depth))
            .offset(y: 12 * Double(depth))
            .rotationEffect(.degrees(rotation))
            .visualEffect { content, proxy in
                content.offset(x: flyAway ? -proxy.size.width * 1.2 : 0)
            }
            .opacity(opacity)
    }
}
