//
//  OnboardingProgressView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// A thin bar under the title showing how far through the onboarding cards the reader is.
@available(iOS 26.0, *)
struct OnboardingProgressView: View {
    /// The card being read, counting from 1.
    let current: Int
    let total: Int

    var body: some View {
        ProgressView(value: Double(current), total: Double(total))
            .tint(.blue)
            .animation(.smooth, value: current)
            .accessibilityLabel("Onboarding progress")
            .accessibilityValue("Card \(current) of \(total)")
    }
}

@available(iOS 26.0, *)
#Preview {
    OnboardingProgressView(current: 2, total: 4)
        .padding()
}
