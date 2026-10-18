//
//  ReadyContentView.swift
//  itsWritten
//

import SwiftUI

/// Onboarding or the home screen, shown whenever a model (on-device or cloud) can answer.
@available(iOS 26.0, *)
struct ReadyContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    let homeVM: HomeViewModel
    let countDownVM: CountdownViewModel

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                HomeView()
                    .environment(homeVM)
                    .environment(countDownVM)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                OnboardingView {
                    withAnimation(.easeInOut) {
                        hasCompletedOnboarding = true
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: hasCompletedOnboarding)
    }
}
