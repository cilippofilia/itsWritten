//
//  PostedStampView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// The stamp as it lands on the folded letter: it drops in from slightly larger and
/// transparent, then the postmark fades in over its leading edge.
struct PostedStampView: View {
    /// 0 = not yet stamped; 1 = stamped and postmarked.
    let progress: Double

    let ink: PostmarkInk
    let wearSeed: UInt64

    var body: some View {
        StampView()
            .overlay(alignment: .leading) {
                PostmarkView(ink: ink, wearSeed: wearSeed)
                    .offset(x: -30)
                    .opacity(0.85 * progress)
            }
            .rotationEffect(.degrees(3))
            .scaleEffect(1.6 - 0.6 * progress)
            .opacity(progress)
    }
}

#Preview {
    PostedStampView(progress: 1, ink: .red, wearSeed: 7)
        .padding(40)
}
