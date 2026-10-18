//
//  RedactionSegment.swift
//  itsWritten
//

import Foundation

/// A run of a message as the review sheet shows it: plain text, or a detail the
/// user can toggle between hidden and sent as is.
struct RedactionSegment: Equatable, Identifiable, Sendable {
    /// Position in the message.
    let id: Int
    let text: String
    /// The detail this run is, or `nil` for plain text.
    let entity: RedactedEntity?
}
