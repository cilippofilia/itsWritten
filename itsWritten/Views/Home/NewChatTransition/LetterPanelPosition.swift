//
//  LetterPanelPosition.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import Foundation

/// Which third of the letter a panel is. Only the letter's outer edges are rounded and
/// outlined, so the creases between panels stay seamless while the letter is flat.
enum LetterPanelPosition: Int {
    case top
    case middle
    case bottom
}
