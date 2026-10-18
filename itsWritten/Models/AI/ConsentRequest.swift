//
//  ConsentRequest.swift
//  itsWritten
//

import Foundation

/// One consent prompt shown to the user. A new prompt gets a new `id`,
/// even for a destination that was asked about before.
struct ConsentRequest: Identifiable, Equatable {
    let id: UUID
    let destination: ConsentDestination
    /// For third-party vendors, the message as it will be sent, with its hidden
    /// details. `nil` for Apple Private Cloud Compute, which gets the plain alert.
    var review: RedactionReview?
}
