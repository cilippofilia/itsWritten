//
//  SamplingSection.swift
//  Written
//
//  Created by Filippo Cilia on 28/02/2026.
//

import SwiftUI

struct SamplingSection: View {
    @Binding var configuration: ModelConfiguration
    
    var body: some View {
        Section {
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
        } header: {
            Text("Sampling")
        } footer: {
            Text("""
            Greedy: Always picks the most likely token
            Top K: Samples from the K most likely tokens
            Top P: Samples from tokens whose cumulative probability reaches P
            """)
        }
    }
}
