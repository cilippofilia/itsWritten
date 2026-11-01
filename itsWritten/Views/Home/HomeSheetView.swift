//
//  HomeSheetView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

/// Content for each `SheetType` presented from `HomeView`.
struct HomeSheetView: View {
    let sheet: SheetType

    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType

    var body: some View {
        switch sheet {
        case .whyAI:
            WhyAIView()
                .whyAIPresentation()

        case .settings:
            NavigationStack {
                ModelSettingsSheet(
                    configuration: $config,
                    responseType: $responseType
                )
            }
            .background(.ultraThinMaterial)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}
