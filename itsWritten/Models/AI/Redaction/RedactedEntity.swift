//
//  RedactedEntity.swift
//  itsWritten
//

import Foundation

/// One personal detail found in a conversation, and the placeholder that
/// stands for it whenever the conversation goes to a third-party model.
struct RedactedEntity: Identifiable, Equatable, Sendable {
    /// The placeholder, e.g. `[PERSON_1]`. Unique within a conversation.
    let id: String
    /// The text as the user first wrote it.
    let original: String
    let kind: RedactionKind
    /// The user chose to send this one as is.
    var isRevealed = false
    /// The user has seen this one in a review sheet and sent.
    var isReviewed = false

    /// The placeholder text, e.g. `[PERSON_1]`.
    var placeholder: String { id }

    /// The key two spellings of the same detail share: "marta" and "Marta" are
    /// one person, and so are "Zoë" and "Zoe".
    static func matchingKey(for text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
