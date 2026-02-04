//
//  ModelSettingsSheet.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

/// A common settings sheet for configuring language model generation parameters,
/// used in various places here.
///
/// This view provides controls for adjusting instructions, temperature, response type,
/// and sampling strategy (greedy, top-K, or top-P).
struct ModelSettingsSheet: View {
    /// The shared configuration for language model settings.
    @Binding var configuration: ModelConfiguration

    /// Optional binding for response type selection (standard, streaming, or human-like).
    var responseType: Binding<ModelResponseType>? = nil

    var body: some View {
        Form {
            Section {
                TextField(
                    "Instructions",
                    text: $configuration.instructions,
                    axis: .vertical
                )
                .lineLimit(12, reservesSpace: true)
                .labelsHidden()
            } header: {
                Text("Instructions")
                    .padding(.top)
            } footer: {
                VStack(alignment: .leading) {
                    Text("⚠️ DO NOT DELETE THESE INSTRUCTIONS.⚠️")
                    Text("Feel free to modify and refine them as needed. If you find better responses with different settings please share them with me.\nLots of love, Filippo")
                }
            }

            Section("Response") {
                LabeledContent("Temperature: \(configuration.temperature, format: .number.precision(.fractionLength(2)))") {
                    Slider(value: $configuration.temperature, in: 0...1)
                }

                if let responseType {
                    Picker("Speed", selection: responseType) {
                        ForEach(ModelResponseType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section("Sampling") {
                Picker("Method", selection: $configuration.samplingType) {
                    ForEach(ModelSamplingType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if configuration.samplingType == .topK {
                    LabeledContent("Top K: \(Int(configuration.topK))") {
                        Slider(value: $configuration.topK, in: 1...100, step: 5)
                    }
                }

                if configuration.samplingType == .topP {
                    LabeledContent("Top P: \(configuration.topP, format: .number.precision(.fractionLength(2)))") {
                        Slider(value: $configuration.topP, in: 0...1)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .formStyle(.grouped)
    }
}

#Preview {
    ModelSettingsSheet(
        configuration: .constant(ModelConfiguration()),
        responseType: .constant(.streaming)
    )
}
