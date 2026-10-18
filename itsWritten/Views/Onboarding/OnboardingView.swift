//
//  OnboardingView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 22/02/2026.
//

import SwiftUI

@available(iOS 26.0, *)
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var visibleCount = 1

    /// Static so each step's `id` stays stable when SwiftUI rebuilds this view.
    private static let steps: [OnboardingStep] = [
        .init(
            title: "Welcome to itsWritten",
            detail: "A quiet space to capture your day and notice gentle patterns in your thoughts.",
            systemImage: "book.closed",
            accent: .orange
        ),
        .init(
            title: "Write with a timer",
            detail: "Set a focused session and let the timer hold your pace, with gentle breaks when you need them.",
            systemImage: "timer",
            accent: .mint
        ),
        .init(
            title: "Guided, not prescriptive",
            detail: "Insights are framed as possibilities to explore, never as instructions.",
            systemImage: "sparkles",
            accent: .pink
        ),
        .init(
            title: "Your pace, your privacy",
            detail: """
                You stay in control of your entries and how you engage with them. Apple Intelligence runs on \
                your device, and Apple’s Private Cloud Compute doesn’t store or share what you write.
                """,
            systemImage: "hand.raised",
            accent: .indigo
        ),
        .init(
            title: "Your words stay yours",
            detail: """
                Cloud models like Claude, OpenAI or Gemini are optional and use your own key. You’re asked \
                first, and names, places and other personal details are hidden before anything is sent.
                """,
            systemImage: "eye.slash",
            accent: .teal
        )
    ]

    @State private var deck = OnboardingDeck(count: OnboardingView.steps.count)

    /// True while a card is being postmarked and sent, so taps can't stack up.
    @State private var isSending = false

    /// How far the current card has been dragged horizontally.
    @State private var dragOffset = 0.0

    /// How far a swipe must travel, or be flung, to change cards.
    private let swipeThreshold = 80.0

    var body: some View {
        NavigationStack {
            ScrollView {
                OnboardingDeckView(steps: Self.steps, deck: deck, dragOffset: dragOffset)
                    .contentShape(.rect)
                    .gesture(swipeGesture)
                    .frame(maxWidth: DesignConstants.Width.postcard)
                    .padding()
                    // Room for the waiting cards peeking out below.
                    .padding(.bottom, DesignConstants.Spacing.large)
                    .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.center, for: .alignment)
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .top) {
                OnboardingProgressView(current: deck.currentIndex + 1, total: deck.count)
                    .padding(.horizontal)
                    .readableContentWidth()
            }
            .navigationTitle("itsWritten")
            .sensoryFeedback(.impact(weight: .medium), trigger: deck.postmarkedCount) { old, new in
                new > old
            }
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingFooterView(
                canGoBack: deck.canGoBack,
                isLastStep: deck.isLastCard,
                backAction: goBack,
                primaryAction: primaryAction
            )
            .disabled(isSending)
            .readableContentWidth()
        }
    }

    /// Drags the current card sideways; letting go far or fast enough sends it on or
    /// brings the previous card back, otherwise it springs back into place.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard !isSending else { return }
                dragOffset = deck.dragOffset(for: value.translation.width)
            }
            .onEnded { value in
                guard !isSending else { return }

                let swipe = deck.swipe(
                    translation: value.translation.width,
                    predictedTranslation: value.predictedEndTranslation.width,
                    threshold: swipeThreshold
                )

                switch swipe {
                case .next:
                    primaryAction()
                case .back:
                    goBack()
                case nil:
                    withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func goBack() {
        withAnimation(.smooth) {
            dragOffset = 0
            deck.goBack()
        }
    }

    /// Postmarks the current card, then sends it off, or finishes after the last one. A
    /// swiped card stays where it was let go while the postmark lands.
    private func primaryAction() {
        guard !isSending else { return }
        isSending = true

        withAnimation(.spring(duration: 0.3, bounce: 0.35)) {
            deck.postmarkCurrent()
        } completion: {
            if deck.isLastCard {
                finish()
            } else {
                sendCurrent()
            }
        }
    }

    private func sendCurrent() {
        withAnimation(.smooth(duration: 0.5)) {
            dragOffset = 0
            deck.sendCurrent()
        } completion: {
            isSending = false
        }
    }

    /// Lets the final postmark settle for a beat before leaving onboarding.
    private func finish() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            onFinish()
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    OnboardingView(onFinish: {})
}
