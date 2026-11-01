//
//  PostmarkView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// A cancellation mark: a double ring with wavy lines trailing off to one side,
/// overlapping the stamp's leading edge, printed in worn red or blue ink.
struct PostmarkView: View {
    let ink: PostmarkInk

    /// Picks this mark's pattern of worn ink.
    let wearSeed: UInt64

    var body: some View {
        HStack(spacing: -6) {
            PostmarkWavesShape()
                .stroke(ink.color, lineWidth: 1.1)
                .frame(width: 34, height: 22)

            ZStack {
                Circle()
                    .stroke(ink.color, lineWidth: 1.1)
                Circle()
                    .stroke(ink.color, lineWidth: 0.8)
                    .padding(4)
            }
            .frame(width: 34, height: 34)
        }
        .mask { InkWearMask(seed: wearSeed) }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 20) {
        PostmarkView(ink: .red, wearSeed: 1)
        PostmarkView(ink: .blue, wearSeed: 2)
    }
    .padding()
}
