//
//  OnboardingSwipe.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import Foundation

/// What a finished swipe on the onboarding deck asks for.
enum OnboardingSwipe: Equatable {
    /// Send the current card away (swiped toward the leading edge).
    case next

    /// Bring the last sent card back (swiped toward the trailing edge).
    case back
}
