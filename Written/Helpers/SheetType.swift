//
//  SheetType.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

enum SheetType: Identifiable, Equatable {
    case whyAI
    case languageSupport
    case aiGeneratedAnswer(String)
    case settings(Binding<ModelConfiguration>)

    var id: String {
        switch self {
        case .whyAI:
            return "whyAI"
        case .languageSupport:
            return "languageSupport"
        case .aiGeneratedAnswer:
            return "aiGeneratedAnswer"
        case .settings:
            return "settings"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .whyAI:
            WhyAIView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)

        case .languageSupport:
            LanguageSupportView()
                .background(.ultraThinMaterial)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)

        case .aiGeneratedAnswer(let answer):
            AIGeneratedAnswerSheet(answer: answer)
                .background(.ultraThinMaterial)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)

        case .settings(let config):
            ModelSettingsSheet(configuration: config)
                .background(.ultraThinMaterial)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    static func == (lhs: SheetType, rhs: SheetType) -> Bool {
        return lhs.id == rhs.id
    }
}
