//
//  CloudKeyRow.swift
//  itsWritten
//

import SwiftUI
import VoltaSDK

/// Key entry for a single cloud vendor.
struct CloudKeyRow: View {
    let vendor: CloudVendor

    @Environment(AIProviderStore.self) private var aiProvider

    /// Held only until Save; cleared afterwards and never stored elsewhere.
    @State private var draftKey = ""
    @State private var errorMessage: String?

    var body: some View {
        let destination = ConsentDestination.vendor(vendor)
        let hasKey = aiProvider.hasKey(for: vendor)

        LabeledContent(destination.displayName) {
            Text(hasKey ? "Key saved" : "No key")
                .foregroundStyle(.secondary)
        }

        SecureField("API Key", text: $draftKey)
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

        Button("Save", action: save)
            .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if hasKey {
            Button("Remove", role: .destructive, action: remove)
        }

        if let errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
        }

        Link("Find model names", destination: vendor.modelDocumentationURL)

        if hasKey {
            Toggle("Always Allow", isOn: alwaysAllowed(for: destination))
        }
    }

    private func save() {
        do {
            try aiProvider.setKey(draftKey, for: vendor)
            draftKey = ""
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't save the key. Try again."
        }
    }

    private func remove() {
        do {
            try aiProvider.removeKey(for: vendor)
            draftKey = ""
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't remove the key. Try again."
        }
    }

    private func alwaysAllowed(for destination: ConsentDestination) -> Binding<Bool> {
        Binding(
            get: { aiProvider.consent.isAlwaysAllowed(destination) },
            set: { aiProvider.consent.setAlwaysAllowed($0, for: destination) }
        )
    }
}

#Preview {
    Form {
        CloudKeyRow(vendor: .openAI)
    }
    .environment(AIProviderStore())
}
