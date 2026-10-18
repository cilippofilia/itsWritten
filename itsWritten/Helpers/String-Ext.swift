//
//  String-Ext.swift
//  itsWritten
//
//  Created by Filippo Cilia on 02/02/2026.
//

import Foundation

extension String {
    /// Returns true if the string is empty or contains only whitespace and newlines.
    var isReallyEmpty: Bool {
        trimmed.isEmpty
    }

    /// Returns the string with leading and trailing whitespace and newlines removed.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Converts a snake_case tool name into a human-readable title,
    /// handling known acronyms such as "pubmed" → "PubMed".
    var humanizedToolName: String {
        let acronyms: [String: String] = [
            "pubmed": "PubMed",
            "clinicaltrials": "ClinicalTrials.gov",
            "openfda": "OpenFDA"
        ]
        return split(separator: "_")
            .map { word in
                let lower = word.lowercased()
                return acronyms[lower] ?? word.capitalized
            }
            .joined(separator: " ")
    }
}
