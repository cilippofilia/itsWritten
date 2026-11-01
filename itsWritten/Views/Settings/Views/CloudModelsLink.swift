//
//  CloudModelsLink.swift
//  itsWritten
//

import SwiftUI

/// The Settings row for cloud models, showing which ones have a key.
struct CloudModelsLink: View {
    @Environment(AIProviderStore.self) private var aiProvider

    var body: some View {
        NavigationLink(value: SettingsRoute.cloudModels) {
            LabeledContent("Cloud Models", value: CloudModelsSummary.text(for: aiProvider.configuredVendors))
        }
    }
}
