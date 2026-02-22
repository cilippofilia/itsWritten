//
//  OnboardingView.swift
//  Written
//
//  Created by Filippo Cilia on 22/02/2026.
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var visibleCount = 1

    private let steps: [OnboardingStep] = [
        .init(
            title: "Welcome to Written",
            detail: "A quiet space to capture your day and notice gentle patterns in your thoughts.",
            systemImage: "book.closed",
            accent: .orange
        ),
        .init(
            title: "Write, then breathe",
            detail: "Share what’s on your mind. Written offers compassionate reflections and gentle prompts.",
            systemImage: "pencil.and.outline",
            accent: .teal
        ),
        .init(
            title: "Guided, not prescriptive",
            detail: "Insights are framed as possibilities to explore, never as instructions.",
            systemImage: "sparkles",
            accent: .pink
        ),
        .init(
            title: "Your pace, your privacy",
            detail: "You stay in control of your entries and how you engage with them. Apple Intelligence runs on your device, and private cloud requests aren’t stored or shared.",
            systemImage: "hand.raised",
            accent: .indigo
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack {
                    ForEach(steps.prefix(visibleCount)) { step in
                        OnboardingStepView(step: step)
                            .id(step.id)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                Spacer(minLength: 100)
            }
            .navigationTitle("Written")
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingFooterView(
                canGoBack: visibleCount > 1,
                isLastStep: visibleCount == steps.count,
                backAction: goBack,
                primaryAction: advanceOrFinish,
                secondaryAction: skipToLast
            )
        }
    }

    private func goBack() {
        guard visibleCount > 1 else { return }
        withAnimation(.easeInOut) {
            visibleCount -= 1
        }
    }

    private func advanceOrFinish() {
        if visibleCount < steps.count {
            withAnimation(.easeInOut) {
                visibleCount += 1
            }
        } else {
            onFinish()
        }
    }

    private func skipToLast() {
        guard visibleCount < steps.count else {
            onFinish()
            return
        }
        withAnimation(.easeInOut) {
            visibleCount = steps.count
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
