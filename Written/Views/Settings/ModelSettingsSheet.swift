//
//  ModelSettingsSheet.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import FoundationModels
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
    var model = SystemLanguageModel.default

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

            Section {
                let currentLanguage = Locale.current.language
                let isSupported = model.supportedLanguages.contains(currentLanguage)

                LabeledContent("Current Language") {
                    Text(displayName(for: currentLanguage))
                }

                if isSupported {
                    Label("Current language is supported", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Current language is not supported", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Language Support")
                    .padding(.top)
            }

            Section("Supported Languages") {
                ForEach(Array(model.supportedLanguages).sorted(by: { displayName(for: $0) < displayName(for: $1) }), id: \.self) { language in
                    Text(displayName(for: language))
                }
            }
        }
        .navigationTitle("Settings")
        .formStyle(.grouped)
    }

    /// Returns a localized display name for a language.
    /// - Parameter language: The language to get a display name for.
    /// - Returns: A human-readable language name in the user's current locale.
    func displayName(for language: Locale.Language) -> String {
        // Only include script for languages that commonly use multiple scripts (e.g., Chinese)
        let scriptsToShow: Set<Locale.Script> = [.hanSimplified, .hanTraditional]
        let scriptToUse = language.script.flatMap { scriptsToShow.contains($0) ? $0 : nil }

        let components = Locale.Components(languageCode: language.languageCode, script: scriptToUse, languageRegion: language.region)
        let locale = Locale(components: components)

        if let name = Locale.current.localizedString(forIdentifier: locale.identifier) {
            return name
        }

        if let code = language.languageCode?.identifier {
            return Locale.current.localizedString(forLanguageCode: code) ?? code
        }

        return "Unknown"
    }
}

#Preview {
    ModelSettingsSheet(
        configuration: .constant(ModelConfiguration()),
        responseType: .constant(.streaming)
    )
}
