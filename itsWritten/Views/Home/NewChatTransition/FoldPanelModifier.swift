//
//  FoldPanelModifier.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// Rotates one third of the letter around a crease. Past 90° the panel shows the plain
/// back of the paper, and a shadow deepens toward the crease mid-fold.
@Animatable
struct FoldPanelModifier: ViewModifier {
    /// 0 (flat) to 180 (folded over the middle third).
    var angle: Double

    /// The crease: `.top` for the bottom panel, `.bottom` for the top panel.
    @AnimatableIgnored var crease: UnitPoint

    /// +1 or -1, so the two flaps swing in mirrored directions.
    @AnimatableIgnored var direction: Double

    private var showsBack: Bool {
        angle > 90
    }

    func body(content: Content) -> some View {
        content
            .opacity(showsBack ? 0 : 1)
            .overlay {
                PaperBackView()
                    .opacity(showsBack ? 1 : 0)
            }
            .overlay {
                // Light catching the crease: darkest when the flap stands upright.
                LinearGradient(
                    colors: [.black.opacity(0.3), .clear],
                    startPoint: crease,
                    endPoint: crease == .top ? .bottom : .top
                )
                .opacity(sin(angle * .pi / 180))
            }
            .rotation3DEffect(
                .degrees(angle * direction),
                axis: (x: 1, y: 0, z: 0),
                anchor: crease,
                perspective: 0.4
            )
    }
}
