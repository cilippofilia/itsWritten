//
//  AINotEnabledView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 06/01/2026.
//

import SwiftUI

struct AINotEnabledView: View {
    @Environment(\.openURL) private var openURL
    @State private var showWhyAISheet: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "apple.intelligence")
                        .symbolRenderingMode(.multicolor)
                        .font(.largeTitle.scaled(by: 1.8))
                        .accessibilityHidden(true)

                    Text("Apple Intelligence Required")
                        .font(.title2)
                        .bold()

                    Text("This app requires Apple Intelligence to be enabled. Please enable it in Settings to continue.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Open Settings", systemImage: "gear", action: openSettings)
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .readableContentWidth()
            }
            // Centered when it fits, scrollable when the window is short (iPhone Duo's
            // outer display in landscape, large Dynamic Type).
            .defaultScrollAnchor(.center, for: .alignment)
            .scrollBounceBehavior(.basedOnSize)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Why AI?", systemImage: "sparkles", action: presentWhyAI)
                }
            }
            .whyAISheet(isPresented: $showWhyAISheet)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func presentWhyAI() {
        showWhyAISheet = true
    }
}

#Preview {
    AINotEnabledView()
}
