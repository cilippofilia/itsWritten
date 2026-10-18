//
//  PostcardPlacement.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import Foundation

/// Where an onboarding postcard sits relative to the card being read.
enum PostcardPlacement: Equatable {
    /// Already read and sent off the deck.
    case sent

    /// On top of the deck, being read.
    case current

    /// Still in the deck, `depth` cards below the current one.
    case waiting(depth: Int)
}
