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
    
    #if DEBUG
    private let isEditable = true
    #else
    private let isEditable = false
    #endif

    var body: some View {
        Form {
            Section {
                if isEditable {
                    TextField(
                        "Instructions",
                        text: $configuration.instructions,
                        axis: .vertical
                    )
                    .lineLimit(12, reservesSpace: true)
                    .labelsHidden()
                } else {
                    FormattedMessageText(text: configuration.instructions)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
            } header: {
                Text("Instructions")
                    .padding(.top)
            }

            Section {
                LabeledContent("Temperature: \(configuration.temperature, format: .number.precision(.fractionLength(2)))") {
                    Slider(value: $configuration.temperature, in: 0...1)
                        .disabled(!isEditable)
                }

                if let responseType {
                    Picker("Speed", selection: responseType) {
                        ForEach(ModelResponseType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!isEditable)
                }
            } header: {
                Text("Response")
            } footer: {
                Text("Temperature: Controls response randomness where 0 is random, 1 is deterministic.")
            }

            Section {
                Picker("Method", selection: $configuration.samplingType) {
                    ForEach(ModelSamplingType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!isEditable)

                if configuration.samplingType == .topK {
                    LabeledContent("Top K: \(Int(configuration.topK))") {
                        Slider(value: $configuration.topK, in: 1...100, step: 5)
                            .disabled(!isEditable)
                    }
                }

                if configuration.samplingType == .topP {
                    LabeledContent("Top P: \(configuration.topP, format: .number.precision(.fractionLength(2)))") {
                        Slider(value: $configuration.topP, in: 0...1)
                            .disabled(!isEditable)
                    }
                }
            } header: {
                Text("Sampling")
            } footer: {
                Text("""
                Greedy: Always picks the most likely token
                Top K: Samples from the K most likely tokens
                Top P: Samples from tokens whose cumulative probability reaches P
                """)
            }

            AppInfoSection()
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
