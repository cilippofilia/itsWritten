//
//  CloudKeysView.swift
//  itsWritten
//

import SwiftUI

/// `CloudModelsView` presented on its own, e.g. from the unavailable screen.
struct CloudKeysView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CloudModelsView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    CloudKeysView()
        .environment(AIProviderStore())
}
