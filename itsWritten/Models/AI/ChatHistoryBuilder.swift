import VoltaSDK

/// Maps stored chat messages to the `[ChatTurn]` history that VoltaSDK expects.
enum ChatHistoryBuilder {
    /// Builds a compacted history from `messages`.
    ///
    /// `messages` must already be ordered (`ConversationViewModel.orderedMessages`).
    /// Exclusions are applied in this order: the trailing user message, the last
    /// assistant message, then blocked user messages (`wasBlocked`) together with the
    /// assistant reply right after each, then assistant messages `isExcluded` matches
    /// (refusals and app-generated copy). The most recent turns whose summed
    /// `text.count` fits `characterBudget` are kept; collection stops at the first turn
    /// that does not fit.
    static func turns(
        from messages: [ChatMessage],
        excludingLastAssistant: Bool,
        excludingTrailingUser: Bool,
        isExcluded: (String) -> Bool,
        characterBudget: Int
    ) -> [ChatTurn] {
        var remaining = messages[...]
        if excludingTrailingUser, let last = remaining.last, last.isUser {
            remaining = remaining.dropLast()
        }
        if excludingLastAssistant, let last = remaining.last, last.isUser == false {
            remaining = remaining.dropLast()
        }

        var candidates: [ChatTurn] = []
        var skipsNextReply = false
        for message in remaining {
            if message.isUser {
                skipsNextReply = message.wasBlocked
                if message.wasBlocked == false {
                    candidates.append(.user(message.content))
                }
            } else if skipsNextReply {
                // The failure reply to a blocked turn goes with it.
                skipsNextReply = false
            } else if isExcluded(message.content) == false {
                candidates.append(.assistant(message.content))
            }
        }

        var kept: [ChatTurn] = []
        var total = 0
        for turn in candidates.reversed() {
            total += turn.text.count
            guard total <= characterBudget else { break }
            kept.append(turn)
        }
        return kept.reversed()
    }
}
