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
                if hasCompletedOnboarding {
                    HomeView()
                        .environment(homeVM)
                        .environment(countDownVM)
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                }
            case .unavailable(.modelNotReady):
                ModelNotReadyView(action: {
                    model = SystemLanguageModel.default
                })
            case .unavailable(.appleIntelligenceNotEnabled):
                AINotEnabledView()
            case .unavailable(.deviceNotEligible):
                DeviceNotSupportedView()
            case .none:
                CheckingAvailabilityView()
            @unknown default:
                UnknownReasonView(action: {
                    model = SystemLanguageModel.default
                })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            model = SystemLanguageModel.default
        }
    }
}

#Preview {
    AvailabilityView()
}
