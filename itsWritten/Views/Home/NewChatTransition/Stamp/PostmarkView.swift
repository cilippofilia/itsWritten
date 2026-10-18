//
//  PostmarkView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// A faint cancellation mark: a double ring with wavy lines trailing off to one side,
/// overlapping the stamp's leading edge.
struct PostmarkView: View {
    var body: some View {
        HStack(spacing: -6) {
            PostmarkWavesShape()
                .stroke(.secondary, lineWidth: 1)
                .frame(width: 34, height: 22)

            ZStack {
                Circle()
                    .stroke(.secondary, lineWidth: 1)
                Circle()
                    .stroke(.secondary, lineWidth: 0.75)
                    .padding(4)
            }
            .frame(width: 34, height: 34)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    PostmarkView()
        .padding()
}
