//
//  PostcardStampView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// A perforated stamp bearing an onboarding step's symbol on a wash of its accent color.
/// The paper stays white so the stamp reads on both light and dark postcards.
@available(iOS 26.0, *)
struct PostcardStampView: View {
    let step: OnboardingStep

    var body: some View {
        ZStack {
            PerforatedStampShape()
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(step.accent.opacity(0.18))
                .overlay {
                    Image(systemName: step.systemImage)
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(step.accent)
                }
                .padding(5)
        }
        .frame(width: 50, height: 62)
        // The stamp has a fixed size, so its symbol stops growing before it overflows.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .accessibilityHidden(true)
    }
}

@available(iOS 26.0, *)
#Preview {
    PostcardStampView(
        step: .init(title: "Write with a timer", detail: "", systemImage: "timer", accent: .mint)
    )
    .padding()
}
