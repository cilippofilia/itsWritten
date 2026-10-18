//
//  LetterFlightModifier.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// Moves the folded letter along `path`, shrinking and tilting it as it drops into the
/// menu button, then fading it out on arrival.
@Animatable
struct LetterFlightModifier: ViewModifier {
    /// 0 at the conversation, 1 inside the menu button.
    var progress: Double

    @AnimatableIgnored var path: LetterFlightPath
    @AnimatableIgnored var landingScale: Double

    func body(content: Content) -> some View {
        let point = path.point(at: progress)
        let scale = 1 - (1 - landingScale) * progress

        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(-12 * progress))
            .offset(x: point.x - path.start.x, y: point.y - path.start.y)
            .opacity(progress < 0.85 ? 1 : (1 - progress) / 0.15)
    }
}
