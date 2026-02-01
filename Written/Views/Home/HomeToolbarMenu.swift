//
//  HomeToolbarMenu.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

struct HomeToolbarMenu: View {
    @Binding var selectedModel: AIModel
    let aiModels: [AIModel]

    @Binding var presentedSheet: SheetType?
    @Binding var showHistoryView: Bool

    var body: some View {
        GlassEffectContainer {
            MenuButtonView(
                selectedModel: $selectedModel,
                aiModels: aiModels,
                showWhyAISheet: .init(
                    get: { presentedSheet == .whyAI },
                    set: { if $0 { presentedSheet = .whyAI } else { presentedSheet = nil } }
                ),
                showLanguageSupportSheet: .init(
                    get: { presentedSheet == .languageSupport },
                    set: { if $0 { presentedSheet = .languageSupport } else { presentedSheet = nil } }
                ),
                showHistoryView: $showHistoryView
            )
        }
    }
}

#Preview {
    HomeToolbarMenu(
        selectedModel: .constant(.init(id: "1234", title: "TEST", prompt: "TEST")),
        aiModels: [],
        presentedSheet: .constant(.whyAI),
        showHistoryView: .constant(false)
    )
}
