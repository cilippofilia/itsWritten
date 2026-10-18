//
//  GenerationView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 24/05/2026.
//

import SwiftUI

@available(iOS 26.0, *)
struct GenerationView: View {
    @Binding var configuration: ModelConfiguration
    @Binding var responseType: ModelResponseType

    var body: some View {
        Form {
            SamplingSection(configuration: $configuration)
            ResponseSection(configuration: $configuration, responseType: $responseType)
            ToolsView()
        }
        .formStyle(.grouped)
        .navigationTitle("Generation")
    }
}
