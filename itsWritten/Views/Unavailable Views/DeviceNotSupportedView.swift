//
//  DeviceNotSupportedView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 06/01/2026.
//

import SwiftUI

struct DeviceNotSupportedView: View {
    @State private var showWhyAISheet: Bool = false

    private let appleIntelligenceURL = URL(string: "https://www.apple.com/apple-intelligence/")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle.scaled(by: 1.8))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)

                    Text("Device Not Supported")
                        .font(.title2)
                        .bold()

                    Text("""
                    This device does not support Apple Intelligence. \
                    This feature requires a compatible device with an A17 Pro chip or later.
                    """)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                    Text("Compatible devices include iPhone 15 Pro, iPhone 15 Pro Max, and later models.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if let appleIntelligenceURL {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 2) {
                                Text("For more info:")
                                AppleIntelligenceLink(destination: appleIntelligenceURL)
                            }

                            VStack(spacing: 2) {
                                Text("For more info:")
                                AppleIntelligenceLink(destination: appleIntelligenceURL)
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .readableContentWidth()
            }
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

    private func presentWhyAI() {
        showWhyAISheet = true
    }
}

#Preview {
    DeviceNotSupportedView()
}
