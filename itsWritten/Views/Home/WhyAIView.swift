//
//  WhyAIView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/11/2025.
//

import SwiftUI

@available(iOS 26.0, *)
struct WhyAIView: View {
    var body: some View {
        // Keeps the original centered layout whenever it fits, and only scrolls in short
        // windows, such as iPhone Duo's outer display or at large Dynamic Type sizes.
        ViewThatFits(in: .vertical) {
            WhyAIContentView()

            ScrollView {
                WhyAIContentView()
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    WhyAIView()
}
