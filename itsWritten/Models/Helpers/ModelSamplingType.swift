//
//  ModelSamplingType.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import Foundation

/// Defines the available sampling strategies for language model generation.
/// The sampling strategy used when generating responses from the language model.
///
/// Different strategies affect how the model selects tokens during generation:
/// - Greedy: Always picks the most likely token
/// - Top K: Samples from the K most likely tokens
/// - Top P: Samples from tokens whose cumulative probability reaches P
enum ModelSamplingType: String, CaseIterable, Identifiable {
    /// Always selects the most probable next token.
    case greedy = "Greedy"

    /// Samples from the top K most probable tokens.
    case topK = "Top K"

    /// Samples from tokens until cumulative probability reaches a threshold.
    case topP = "Top P"

    /// The unique identifier for each sampling type.
    var id: Self { self }
}
