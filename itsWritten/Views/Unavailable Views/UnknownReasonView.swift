//
//  UnknownReasonView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 06/01/2026.
//

import SwiftUI

struct UnknownReasonView: View {
    @State private var showWhyAISheet: Bool = false
    let action: ActionVoid

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "questionmark.circle")
                        .font(.largeTitle.scaled(by: 1.8))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text("Unknown Status")
                        .font(.title2)
                        .bold()

                    Text("An unexpected status was encountered. Please try restarting the app.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
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
    UnknownReasonView(action: { })
}
