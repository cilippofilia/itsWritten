//
//  OnboardingStep.swift
//  Written
//
//  Created by Filippo Cilia on 22/02/2026.
//

import SwiftUI

struct OnboardingStep: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let accent: Color
}
