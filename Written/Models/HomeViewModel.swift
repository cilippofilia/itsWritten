//
//  HomeViewModel.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import FoundationModels
import SwiftUI

@MainActor
@Observable
public class HomeViewModel {
    var placeholderText: String = ""
    var selectedAIModel: AIModel
    var session: LanguageModelSession?
    var history: [HistoryModel] = []
    
    init(selectedPrompt: AIModel? = nil) {
        self.selectedAIModel = selectedPrompt ?? aiModelList.first!
    }

    let placeholderOptions: [String] = [
        "Begin writing",
        "Pick a thought and go",
        "Start typing",
        "What's on your mind",
        "Just start",
        "Type your first thought",
        "Start with one sentence",
        "Just say it"
    ]
    
    let aiModelList: [AIModel] = [
        reflectivePrompt,
        insightfulPrompt,
        actionableSuggestionPrompt,
        validatingPrompt,
        challengingPrompt
    ]

    func setRandomPlaceholderText() {
        let text = placeholderOptions.randomElement() ?? "Begin writing"
        placeholderText = text + "..."
    }
    
    func prepareInitialState(storedModelID: String) {
        setRandomPlaceholderText()

        if let match = aiModelList.first(where: { $0.id == storedModelID }) {
            selectedAIModel = match
        } else if let first = aiModelList.first {
            selectedAIModel = first
        }

        prepareSessionIfNeeded()
    }

    func updateSelection(to prompt: AIModel) {
        selectedAIModel = prompt
        prepareSessionIfNeeded()
    }

    private func prepareSessionIfNeeded() {
        if session == nil {
            session = LanguageModelSession(
                instructions: { selectedAIModel.prompt }
            )
        }
    }
}
