//
//  OnboardingStepView.swift
//  Written
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
                    .font(.system(.largeTitle))
                    .foregroundStyle(step.accent)
                    .symbolRenderingMode(.hierarchical)

                Text(step.title)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)
            }
            .padding(.bottom, 8)

            Text(step.detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background {
            GlassEffectContainer {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(step.accent.opacity(0.25))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(step.accent.opacity(0.25), lineWidth: 2)
                    }
            }
        }
        .clipShape(.rect(cornerRadius: 28))
        .padding(.horizontal)
        .padding(.top, 8)
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
