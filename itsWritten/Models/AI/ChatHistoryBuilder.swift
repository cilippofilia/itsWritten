import VoltaSDK

/// Maps stored chat messages to the `[ChatTurn]` history that VoltaSDK expects.
enum ChatHistoryBuilder {
    /// Builds a compacted history from `messages`.
    ///
    /// `messages` must already be ordered (`ConversationViewModel.orderedMessages`).
    /// Exclusions are applied in this order: the trailing user message, the last
    /// assistant message, then refusal assistant messages. The most recent turns whose
    /// summed `text.count` fits `characterBudget` are kept; collection stops at the
    /// first turn that does not fit.
    static func turns(
        from messages: [ChatMessage],
        excludingLastAssistant: Bool,
        excludingTrailingUser: Bool,
        isRefusal: (String) -> Bool,
        characterBudget: Int
    ) -> [ChatTurn] {
        var remaining = messages[...]
        if excludingTrailingUser, let last = remaining.last, last.isUser {
            remaining = remaining.dropLast()
        }
        if excludingLastAssistant, let last = remaining.last, last.isUser == false {
            remaining = remaining.dropLast()
        }

        let candidates = remaining
            .filter { $0.isUser || isRefusal($0.content) == false }
            .map { $0.isUser ? ChatTurn.user($0.content) : ChatTurn.assistant($0.content) }

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
