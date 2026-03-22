//
//  OnboardingFooterView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 22/02/2026.
//

import SwiftUI

struct OnboardingFooterView: View {
    let canGoBack: Bool
    let isLastStep: Bool
    let backAction: () -> Void
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    var body: some View {
        HStack {
            Button("Back", systemImage: "chevron.left") {
                backAction()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .disabled(!canGoBack)

            Spacer()

            Button("Skip") {
                secondaryAction()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .foregroundStyle(.secondary)
            .disabled(isLastStep)

            Spacer()

            if isLastStep {
                Button("Let's write!") {
                    primaryAction()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } else {
                Button("", systemImage: "chevron.right") {
                    primaryAction()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .tint(.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding([.horizontal, .bottom])
    }
}

#Preview {
    OnboardingFooterView(
        canGoBack: true,
        isLastStep: false,
        backAction: {},
        primaryAction: {},
        secondaryAction: {}
    )
}
