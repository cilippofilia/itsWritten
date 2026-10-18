//
//  ToolsView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 25/05/2026.
//

import SwiftUI

struct ToolsView: View {
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
        }
    }
}

#Preview {
    Form {
        ToolsView()
    }
    .formStyle(.grouped)
}
