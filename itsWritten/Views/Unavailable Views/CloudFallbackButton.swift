//
//  CloudFallbackButton.swift
//  itsWritten
//

import SwiftUI

/// Lets users without Apple Intelligence add their own cloud API key.
struct CloudFallbackButton: View {
    @State private var showCloudKeys = false

    var body: some View {
        Button("Use Your Own API Key", systemImage: "key") {
            showCloudKeys = true
        }
        .buttonStyle(.bordered)
        .sheet(isPresented: $showCloudKeys) {
            CloudKeysView()
        }
    }
}

#Preview {
    CloudFallbackButton()
        .environment(AIProviderStore())
}
