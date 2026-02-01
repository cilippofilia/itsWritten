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

    func compactedSession(
        from previousSession:
        LanguageModelSession,
        maxCharacters: Int = 4000
    ) -> LanguageModelSession {
        let entries = previousSession.transcript
        // Bail out if there's nothing to compact
        guard let first = entries.first else { return previousSession }
        var selected = [first]
        var totalInstructionLength = String(describing: first).count
        var recentEntries: [Transcript.Entry] = []

        // Count backwards, because the most recent entries
        // are the most relevant ones to the user.
        for entry in entries.dropFirst().reversed() {
            let entryEstimatelength = String(describing: entry).count
            // Bail out if adding this would push us over our limit.
            guard totalInstructionLength + entryEstimatelength <= maxCharacters else { break }
            // Add this to the *start* of recentEntries,
            // because we're working backwards.
            recentEntries.insert(entry, at: 0)
            // Add its length to our length tracker.
            totalInstructionLength += entryEstimatelength
        }
        selected.append(contentsOf: recentEntries)

        // Return new session from the compacted transcript.
        return LanguageModelSession(transcript: Transcript(entries: selected))
    }
}
