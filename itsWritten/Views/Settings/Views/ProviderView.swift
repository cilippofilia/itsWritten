//
//  ProviderView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 24/05/2026.
//

import FoundationModels
import SwiftUI

struct ProviderView: View {
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL

    var model = AppLanguageModel.model

    /// Supported language names, sorted once per locale rather than on every render.
    @State private var supportedLanguageNames: [String] = []

    private var currentLanguage: Locale.Language {
        locale.language
    }

    var body: some View {
        Form {
            Section {
                Label("Apple Intelligence", systemImage: "apple.intelligence")
                    .symbolRenderingMode(.multicolor)
            } footer: {
                Text("""
                Apple Intelligence runs entirely on your device, keeping your writing private \
                and available even without an internet connection.
                """)
            }

            Section {
                Button(action: openAppSettings) {
                    LabeledContent("Current Language") {
                        Text(currentLanguage.displayName(in: locale))
                    }
                }
                .buttonStyle(.plain)

                if model.supportedLanguages.contains(currentLanguage) {
                    Label("Current language is supported", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Current language is not supported", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Language Support")
            }

            Section("Supported Languages") {
                ForEach(supportedLanguageNames, id: \.self) { name in
                    Text(name)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Provider")
        .task(id: locale) {
            supportedLanguageNames = model.supportedLanguages
                .map { $0.displayName(in: locale) }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }
    }

    private func openAppSettings() {
        if let settingsURL = URL(string: "app-settings:") {
            openURL(settingsURL)
        }
    }
}

#Preview {
    NavigationStack {
        ProviderView()
    }
}
