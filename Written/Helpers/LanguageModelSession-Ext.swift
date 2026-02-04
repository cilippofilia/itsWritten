//
//  LanguageModelSession-Ext.swift
//  Written
//
//  Created by Filippo Cilia on 03/02/2026.
//

import FoundationModels

extension LanguageModelSession {
    func compactedSession(
        from previousSession: LanguageModelSession,
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
