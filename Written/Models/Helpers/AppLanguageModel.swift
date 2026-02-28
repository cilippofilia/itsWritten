//
//  AppLanguageModel.swift
//  Written
//
//  Created by Filippo Cilia on 23/02/2026.
//

import FoundationModels

/// Shared app-level configuration for SystemLanguageModel and sessions.
enum AppLanguageModel {
    static let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)

    static func session(instructions: String? = nil) -> LanguageModelSession {
        if let instructions, instructions.isReallyEmpty == false {
            return LanguageModelSession(model: model, instructions: instructions)
        }

        return LanguageModelSession(model: model)
    }

    static func session(transcript: Transcript) -> LanguageModelSession {
        LanguageModelSession(model: model, transcript: transcript)
    }
}
