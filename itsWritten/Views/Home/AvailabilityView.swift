//
//  AvailabilityView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 25/10/2025.
//

import FoundationModels
import SwiftUI

struct AvailabilityView: View {
    @Environment(AIProviderStore.self) private var aiProvider
    @State private var homeVM = HomeViewModel()
    @State private var countDownVM = CountdownViewModel()
    @State private var model: SystemLanguageModel?

    var body: some View {
        Group {
            switch model?.availability {
            case .available:
                ReadyContentView(homeVM: homeVM, countDownVM: countDownVM)
            case .unavailable(let reason):
                if aiProvider.hasCloudFallback {
                    // No on-device model, but a cloud key can answer.
                    ReadyContentView(homeVM: homeVM, countDownVM: countDownVM)
                } else {
                    switch reason {
                    case .modelNotReady:
                        ModelNotReadyView(action: {
                            model = AppLanguageModel.model
                        })
                    case .appleIntelligenceNotEnabled:
                        AINotEnabledView()
                    case .deviceNotEligible:
                        DeviceNotSupportedView()
                    @unknown default:
                        UnknownReasonView(action: {
                            model = AppLanguageModel.model
                        })
                    }
                }
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
        .environment(AIProviderStore())
}
