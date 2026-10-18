//
//  RedactionReview.swift
//  itsWritten
//

import Foundation

/// What the review sheet shows for one outgoing call.
struct RedactionReview: Equatable, Sendable {
    /// The message being sent, split so each detail can be toggled.
    let segments: [RedactionSegment]
    /// Details found only in earlier messages of the conversation.
    let earlierEntities: [RedactedEntity]
    /// The message exactly as the model receives it.
    let sentText: String

    /// Whether anything in the call is hidden or could be.
    var hasEntities: Bool {
        segments.contains { $0.entity != nil } || earlierEntities.isEmpty == false
    }
}
