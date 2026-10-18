//
//  CloudKeysView.swift
//  itsWritten
//

import SwiftUI

/// `CloudModelsView` presented on its own, e.g. from the unavailable screen.
@available(iOS 26.0, *)
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

@available(iOS 26.0, *)
#Preview {
    CloudKeysView()
        .environment(AIProviderStore())
}
