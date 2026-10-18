//
//  OnboardingStepView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 22/02/2026.
//

import SwiftUI

struct OnboardingStepView: View {
    let step: OnboardingStep

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Image(systemName: step.systemImage)
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                    .foregroundStyle(step.accent)
                    .symbolRenderingMode(.hierarchical)

                Text(step.title)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)
            }
            .padding(.bottom, DesignConstants.Spacing.small)

            Text(step.detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.panel)
                .fill(step.accent.opacity(0.25))
                .stroke(step.accent.opacity(0.25), lineWidth: 2)
        }
        .clipShape(.rect(cornerRadius: DesignConstants.CornerRadius.panel))
        .accessibilityElement(children: .combine)
        .padding(.horizontal)
        .padding(.top, DesignConstants.Spacing.small)
    }
}

#Preview {
    OnboardingStepView(
        step: .init(
            title: "Write with intention",
            detail: "Capture how you feel and get compassionate reflections tailored to your day.",
            systemImage: "pencil.and.outline",
            accent: .orange
        )
    )
    .padding()
}
