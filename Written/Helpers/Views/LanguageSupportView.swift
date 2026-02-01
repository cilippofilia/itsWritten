//
//  LanguageSupportView.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import FoundationModels
import SwiftUI

struct LanguageSupportView: View {
    var model = SystemLanguageModel.default

    var body: some View {
        Form {
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
        .navigationTitle("Availability")
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
    LanguageSupportView()
}
