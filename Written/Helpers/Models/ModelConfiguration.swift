//
//  ModelConfiguration.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import Foundation
import FoundationModels

/// A shared configuration struct for language model generation settings.
struct ModelConfiguration: Equatable {
    /// System instructions for the language model.
    var instructions: String = ""

    /// The temperature parameter controlling response randomness.
    var temperature: Double = 0.7

    /// The selected sampling strategy type.
    var samplingType: ModelSamplingType = .topP

    /// The top-K value for sampling when using top-K strategy.
    var topK: Double = 20.0

    /// The probability threshold for sampling when using top-P strategy.
    var topP: Double = 0.5

    /// Computed generation options based on current settings.
    var generationOptions: GenerationOptions {
        switch samplingType {
        case .greedy:
            .init(sampling: .greedy, temperature: temperature)
        case .topK:
            .init(sampling: .random(top: Int(topK)), temperature: temperature)
        case .topP:
            .init(sampling: .random(probabilityThreshold: topP), temperature: temperature)
        }
    }
}
