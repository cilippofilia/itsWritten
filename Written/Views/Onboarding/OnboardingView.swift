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
            detail: "A calm space to capture your day and uncover gentle patterns in your thoughts.",
            systemImage: "book.closed",
            accent: .orange
        ),
        .init(
            title: "Write, then breathe",
            detail: "Share what is on your mind. Written responds with compassionate reflections and prompts.",
            systemImage: "pencil.and.outline",
            accent: .teal
        ),
        .init(
            title: "Guided, not prescriptive",
            detail: "Insights are framed as possibilities to help you explore, never as instructions.",
            systemImage: "sparkles",
            accent: .pink
        ),
        .init(
            title: "Your pace, your privacy",
            detail: "You stay in control of your entries and how you engage with them.",
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
