//
//  ModelResponseType.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

/// The type of response generation to use.
enum ModelResponseType: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case streaming = "Streaming"
    case human = "Human"

    var id: Self { self }
}
