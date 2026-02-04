//
//  TypingIndicator.swift
//  Written
//
//  Created by Filippo Cilia on 03/02/2026.
//

import SwiftUI

struct TypingIndicator: View {
    @State private var animatingDots = false

    var body: some View {
        HStack {
            Image(systemName: "ellipsis")
                .symbolEffect(.variableColor, isActive: animatingDots)
                .font(.title)
                .bold()
                .padding()
                .background(Color.secondary.opacity(0.2))
                .clipShape(.capsule)

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
