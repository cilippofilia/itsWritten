//
//  RedactedCall.swift
//  itsWritten
//

import VoltaSDK

/// A call with its personal details replaced, plus which details it contains.
struct RedactedCall: Equatable, Sendable {
    /// What the third-party model receives.
    let call: OutboundCall
    /// Placeholders of every known detail that appears in the call, hidden or
    /// let through.
    let entityIDs: Set<RedactedEntity.ID>
    /// Paragraphs of the call whose names couldn't be checked automatically.
    /// Whatever names they hold go out as written.
    var uncheckedParagraphs: Set<String> = []
}
