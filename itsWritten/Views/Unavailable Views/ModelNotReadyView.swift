//
//  ModelNotReadyView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 06/01/2026.
//

import FoundationModels
import SwiftUI

@available(iOS 26.0, *)
struct ModelNotReadyView: View {
    @State private var retryCountdown: Int = 5

    let action: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ProgressView()
                    .controlSize(.large)

                Text("Model Not Ready")
                    .font(.title2)
                    .bold()

                Text("The language model is currently preparing. Please try again in a few moments.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: retry) {
                    Label {
                        Text(retryCountdown > 0 ? "Retry in \(retryCountdown)s" : "Retry")
                            .contentTransition(.numericText(value: Double(retryCountdown)))
                    } icon: {
                        Image(systemName: "arrow.circlepath")
                    }
                    .animation(.easeInOut, value: retryCountdown)
                }
                .buttonStyle(.borderedProminent)
                .disabled(retryCountdown > 0)
                .accessibilityInputLabels(["Retry"])

                CloudFallbackButton()
            }
            .padding()
            .readableContentWidth()
        }
        .defaultScrollAnchor(.center, for: .alignment)
        .scrollBounceBehavior(.basedOnSize)
        .task(id: retryCountdown) {
            guard retryCountdown > 0 else { return }

            try? await Task.sleep(for: .seconds(1))
            if retryCountdown > 0 {
                retryCountdown -= 1
            }
        }
    }

    private func retry() {
        action()
        retryCountdown = 5
    }
}

@available(iOS 26.0, *)
#Preview {
    ModelNotReadyView(action: { })
        .environment(AIProviderStore())
}
