//
//  AvailabilityView.swift
//  written
//
//  Created by Filippo Cilia on 25/10/2025.
//

import FoundationModels
import SwiftUI

struct AvailabilityView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var homeVM = HomeViewModel()
    @State private var countDownVM = CountdownViewModel()
    @State private var model: SystemLanguageModel?

    var body: some View {
        Group {
            switch model?.availability {
            case .available:
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
            case .unavailable(.modelNotReady):
                ModelNotReadyView(action: {
                    model = AppLanguageModel.model
                })
            case .unavailable(.appleIntelligenceNotEnabled):
                AINotEnabledView()
            case .unavailable(.deviceNotEligible):
                DeviceNotSupportedView()
            case .none:
                CheckingAvailabilityView()
            @unknown default:
                UnknownReasonView(action: {
                    model = AppLanguageModel.model
                })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            model = AppLanguageModel.model
        }
    }
}

#Preview {
    AvailabilityView()
}
