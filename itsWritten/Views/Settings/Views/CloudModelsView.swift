//
//  CloudModelsView.swift
//  itsWritten
//

import SwiftUI

/// How cloud models protect what the user writes, and the user's API keys.
@available(iOS 26.0, *)
struct CloudModelsView: View {
    var body: some View {
        Form {
            CloudPrivacySection()
            CloudKeysSection()
        }
        .formStyle(.grouped)
        .navigationTitle("Cloud Models")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 26.0, *)
#Preview {
    NavigationStack {
        CloudModelsView()
    }
    .environment(AIProviderStore())
}
