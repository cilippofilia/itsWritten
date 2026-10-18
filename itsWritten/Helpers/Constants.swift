//
//  Constants.swift
//  itsWritten
//
//  Created by Filippo Cilia on 10/09/2025.
//

import SwiftUI

public typealias ActionVoid = () -> Void

/// Shared layout values so every screen uses the same widths, spacing, and rounding.
enum DesignConstants {
    enum Width {
        /// Maximum width for text-heavy content, so lines stay readable when the window
        /// is wide (iPad, iPhone Duo's inner display).
        static let readableContent: Double = 700

        /// Maximum width for a single chat bubble.
        static let chatBubble: Double = 560

        /// Fraction of the container a chat bubble may occupy in narrow windows.
        static let chatBubbleFraction: Double = 0.75

        /// Maximum width for an onboarding postcard, so it keeps a postcard's
        /// proportions in wide windows.
        static let postcard: Double = 520

        /// Width of a postcard's address side, which holds the stamp and address lines.
        static let postcardAddressColumn: Double = 84
    }

    enum Spacing {
        static let small: Double = 8
        static let medium: Double = 12
        static let large: Double = 24
    }

    enum CornerRadius {
        static let card: Double = 24
        static let bubble: Double = 18
        static let panel: Double = 28
        static let postcard: Double = 6
    }
}
