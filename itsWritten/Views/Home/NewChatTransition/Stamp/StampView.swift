//
//  StampView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// A small postage stamp bearing the app icon: perforated white paper with the icon as
/// its picture. The fixed light colors read on both light and dark letters.
struct StampView: View {
    var body: some View {
        ZStack {
            PerforatedStampShape()
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)

            Image(.stampIcon)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Matches the icon's own background, which fades from white at the top
                // to a very light gray at the bottom, so the picture has no visible box.
                .background(
                    LinearGradient(
                        colors: [.white, Color(white: 0.967)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(.rect(cornerRadius: 1.5))
                .overlay {
                    RoundedRectangle(cornerRadius: 1.5)
                        .strokeBorder(.black.opacity(0.12), lineWidth: 0.5)
                }
                .padding(5)
        }
        .frame(width: 44, height: 54)
        .accessibilityHidden(true)
    }
}

#Preview {
    StampView()
        .padding()
        .background(.gray.opacity(0.2))
}
