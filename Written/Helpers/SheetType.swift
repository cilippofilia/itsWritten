//
//  SheetType.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

enum SheetType: Equatable, Identifiable {
    case whyAI
    case languageSupport
    case aiGeneratedAnswer(String)

    var id: String {
        switch self {
        case .whyAI:
            return "whyAI"
        case .languageSupport:
            return "languageSupport"
        case .aiGeneratedAnswer:
            return "aiGeneratedAnswer"
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)

        case .aiGeneratedAnswer(let answer):
            AIGeneratedAnswerSheet(answer: answer)
        }
    }
}
