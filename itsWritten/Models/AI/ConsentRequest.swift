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
}
