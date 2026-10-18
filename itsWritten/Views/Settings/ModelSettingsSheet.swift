//
//  ModelSettingsSheet.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

struct ModelSettingsSheet: View {
    @Binding var configuration: ModelConfiguration
    @Binding var responseType: ModelResponseType
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section {
                NavigationLink("Provider", value: SettingsRoute.provider)
                NavigationLink("Instructions", value: SettingsRoute.instructions)
                NavigationLink("Generation", value: SettingsRoute.generation)
            } footer: {
                Text("Changing these settings may result in unexpected, inaccurate, or lower quality responses. Only modify them if you understand the effect each value has on the model's behaviour.")
            }

            AppInfoSection()

            ContactSection()

            Section {
                Button("Reset to Defaults", role: .destructive, action: confirmReset)
            } footer: {
                Text("Restores all model instructions and generation settings to their original values.")
            }
        }
        .navigationTitle("Settings")
        .formStyle(.grouped)
        .navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .provider:
                ProviderView()
            case .instructions:
                InstructionSection(configuration: $configuration)
                    .navigationTitle("Instructions")
                    .navigationBarTitleDisplayMode(.inline)
            case .generation:
                GenerationView(configuration: $configuration, responseType: $responseType)
            }
        }
        .alert("Reset Model Settings", isPresented: $showResetConfirmation) {
            Button("Reset to Defaults", role: .destructive, action: resetToDefaults)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all model instructions and generation settings to their original values.")
        }
    }

    private func confirmReset() {
        showResetConfirmation = true
    }

    private func resetToDefaults() {
        configuration = ModelConfiguration()
        responseType = .standard
    }
}

#Preview {
    NavigationStack {
        ModelSettingsSheet(
            configuration: .constant(ModelConfiguration()),
            responseType: .constant(.streaming)
        )
    }
}
