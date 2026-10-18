//
//  RestorePurchaseButton.swift
//  itsWritten
//

import SwiftUI

/// "Restore Purchase", replaced by a spinner while a restore is in flight.
struct RestorePurchaseButton: View {
    let isRestoring: Bool
    let onRestore: () -> Void

    var body: some View {
        if isRestoring {
            ProgressView()
                .controlSize(.mini)
                .accessibilityLabel("Restoring purchase")
        } else {
            Button("Restore Purchase", action: onRestore)
        }
    }
}

#Preview {
    RestorePurchaseButton(isRestoring: false, onRestore: {})
}
