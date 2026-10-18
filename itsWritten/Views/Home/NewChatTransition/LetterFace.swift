//
//  LetterFace.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// Everything drawn on the front of the letter.
struct LetterFace {
    let title: String
    let messages: [ChatMessage]
    let headerHeight: Double
    let headerAlignment: HorizontalAlignment
}
