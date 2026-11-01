//
//  CloudModelsView.swift
//  itsWritten
//

import SwiftUI

/// How cloud models protect what the user writes, and the user's API keys.
struct CloudModelsView: View {
    var body: some View {
        Form {
            CloudPrivacySection()
            CloudKeysSection()
            #if DEBUG
            DebugFallbackSection()
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle("Cloud Models")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CloudModelsView()
    }
    .environment(AIProviderStore())
}
