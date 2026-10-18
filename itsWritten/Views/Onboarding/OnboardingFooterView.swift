//
//  OnboardingFooterView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 22/02/2026.
//

import SwiftUI

@available(iOS 26.0, *)
struct OnboardingFooterView: View {
    let canGoBack: Bool
    let isLastStep: Bool
    let backAction: () -> Void
    let primaryAction: () -> Void

    var body: some View {
        HStack {
            Button("Back", systemImage: "chevron.left", action: backAction)
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .disabled(!canGoBack)

            Spacer()

            if isLastStep {
                Button("Let's write!", action: primaryAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
            } else {
                Button("Next", systemImage: "chevron.right", action: primaryAction)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glassProminent)
                    .tint(.blue)
            }
        }
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding([.horizontal, .bottom])
    }
}

@available(iOS 26.0, *)
#Preview {
    OnboardingFooterView(
        canGoBack: true,
        isLastStep: false,
        backAction: {},
        primaryAction: {}
    )
}
