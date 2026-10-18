//
//  OnboardingPostcardView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// One onboarding step written as a postcard: the message on the left and, past the
/// divider, the address side with a stamp that gets postmarked when the card is sent.
@available(iOS 26.0, *)
struct OnboardingPostcardView: View {
    let step: OnboardingStep
    let ink: PostmarkInk

    /// Picks the postmark's pattern of worn ink.
    let wearSeed: UInt64

    let isPostmarked: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignConstants.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
                Text(step.title)
                    .font(.title3)
                    .bold()

                Text(step.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .fontDesign(.serif)
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(.primary.opacity(0.15))
                .frame(width: 1)
                .accessibilityHidden(true)

            VStack(alignment: .trailing, spacing: DesignConstants.Spacing.large) {
                PostcardStampView(step: step)
                    .overlay(alignment: .leading) {
                        PostmarkView(ink: ink, wearSeed: wearSeed)
                            .offset(x: -30)
                            .opacity(isPostmarked ? 0.85 : 0)
                            .scaleEffect(isPostmarked ? 1 : 1.4)
                    }
                    .rotationEffect(.degrees(2))

                Spacer(minLength: 0)

                PostcardAddressLinesView()
            }
            .frame(width: DesignConstants.Width.postcardAddressColumn)
        }
        .padding(DesignConstants.Spacing.large)
        .frame(maxHeight: .infinity, alignment: .top)
        // The shadow sits on the paper alone, so it doesn't haze the writing.
        .background {
            RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.postcard)
                .fill(Color(.postcardPaper))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.postcard)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

@available(iOS 26.0, *)
#Preview {
    OnboardingPostcardView(
        step: .init(
            title: "Write with a timer",
            detail: "Set a focused session and let the timer hold your pace, with gentle breaks when you need them.",
            systemImage: "timer",
            accent: .mint
        ),
        ink: .red,
        wearSeed: 3,
        isPostmarked: true
    )
    .padding()
}
