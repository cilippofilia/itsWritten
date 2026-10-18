//
//  ToolsView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 25/05/2026.
//

import SwiftUI

@available(iOS 26.0, *)
struct ToolsView: View {
    private struct ToolInfo: Identifiable {
        let id: String
        let displayName: String
        let summary: String
    }

    private let tools: [ToolInfo] = AppLanguageModel.tools.map {
        ToolInfo(id: $0.name, displayName: $0.name.humanizedToolName, summary: $0.description)
    }

    var body: some View {
        Section {
            ForEach(tools) { tool in
                Text(tool.displayName)
            }
        } header: {
            Text("Tools")
        } footer: {
            ForEach(tools) { tool in
                Text(tool.summary)
            }
            Text("Tools need Apple Intelligence. Cloud models answer without them.")
        }
    }
}

@available(iOS 26.0, *)
private extension String {
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

@available(iOS 26.0, *)
#Preview {
    Form {
        ToolsView()
    }
    .formStyle(.grouped)
}
