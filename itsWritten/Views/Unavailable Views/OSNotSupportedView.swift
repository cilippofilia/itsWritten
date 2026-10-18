//
//  OSNotSupportedView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// Shown on systems older than iOS 26, where Foundation Models isn't available.
struct OSNotSupportedView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Update Required", systemImage: "arrow.down.app")
        } description: {
            Text("itsWritten requires iOS 26 or later. Update your device in Settings to start writing.")
        }
    }
}

#Preview {
    OSNotSupportedView()
}
