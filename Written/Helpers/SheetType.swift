//
//  SheetType.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import Foundation
import FoundationModels
import SwiftUI

enum SheetType: Identifiable, Equatable {
    case whyAI
    case languageSupport
    case chatV2(
        title: String,
        seedPrompt: String?,
        session: LanguageModelSession,
        config: Binding<ModelConfiguration>,
        threadId: UUID?,
        initialMessages: [ChatMessage]
    )
    case chat(title: String, prompt: String, answer: String)
    case settings(Binding<ModelConfiguration>)

    var id: String {
        switch self {
        case .whyAI:
            return "whyAI"
        case .languageSupport:
            return "languageSupport"
        case .chat:
            return "chat"
        case .chatV2:
            return "chatV2"
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

        case .chat(let title, let prompt, let answer):
            ChatSheet(title: title, prompt: prompt, answer: answer)
                .background(.ultraThinMaterial)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)

        case .chatV2(
            let title,
            let seedPrompt,
            let session,
            let config,
            let threadId,
            let initialMessages
        ):
            NavigationStack {
                ChatView(
                    title: title,
                    seedPrompt: seedPrompt,
                    session: session,
                    configuration: config,
                    threadId: threadId,
                    initialMessages: initialMessages
                )
            }
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
