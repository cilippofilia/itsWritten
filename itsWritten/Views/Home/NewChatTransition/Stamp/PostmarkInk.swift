//
//  PostmarkInk.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// The ink a postmark is printed in. Each letter picks one at random, as post offices use
/// both.
enum PostmarkInk: CaseIterable {
    case red
    case blue

    var color: Color {
        switch self {
        case .red: Color(red: 0.78, green: 0.14, blue: 0.16)
        case .blue: Color(red: 0.14, green: 0.28, blue: 0.64)
        }
    }
}
