//
//  AppLanguageModel.swift
//  itsWritten
//
//  Created by Filippo Cilia on 23/02/2026.
//

import FoundationModels

/// Shared app-level configuration for the on-device model and its tools.
enum AppLanguageModel {
    static let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
    static let tools: [any Tool] = [
        PubMedSearchTool(),
        ClinicalTrialsSearchTool(),
        OpenFDADrugTool(),
        MedicalCalculatorTool()
    ]
}
