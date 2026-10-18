//
//  CloudKeysView.swift
//  itsWritten
//

import SwiftUI

/// Standalone screen for managing cloud API keys.
@available(iOS 26.0, *)
struct CloudKeysView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                CloudKeysSection()
            }
            .formStyle(.grouped)
            .navigationTitle("Cloud Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    CloudKeysView()
        .environment(AIProviderStore())
}
