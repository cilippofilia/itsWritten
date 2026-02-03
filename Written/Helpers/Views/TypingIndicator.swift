//
//  TypingIndicator.swift
//  Written
//
//  Created by Filippo Cilia on 03/02/2026.
//

import SwiftUI

/// An animated indicator showing that the AI is typing a response.
///
/// Displays an ellipsis icon with a variable color animation effect to indicate
/// that a response is being generated.
struct TypingIndicator: View {
    /// Whether the dots animation is active.
    @State private var animatingDots = false

    var body: some View {
        HStack {
            Image(systemName: "ellipsis")
                .symbolEffect(.variableColor, isActive: animatingDots)
                .font(.title)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.2))
                .clipShape(.rect(cornerRadius: 16))

            Spacer(minLength: 60)
        }
        .onAppear {
            animatingDots = true
        }
    }
}

#Preview {
    TypingIndicator()
}
