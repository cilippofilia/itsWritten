//
//  UnknownReasonView.swift
//  Written
//
//  Created by Filippo Cilia on 06/01/2026.
//

import SwiftUI

struct UnknownReasonView: View {
    @State private var showWhyAISheet: Bool = false
    let action: ActionVoid

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.gray)

                Text("Unknown Status")
                    .font(.title2)
                    .bold()

                Text("An unexpected status was encountered. Please try restarting the app.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GlassEffectContainer {
                        Button(action: {
                            showWhyAISheet = true
                        }) {
                            Label("Why AI?", systemImage: "sparkles")
                        }
                    }
                }
            }
            .sheet(isPresented: $showWhyAISheet) {
                WhyAIView(action: { showWhyAISheet = false })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    UnknownReasonView(action: { })
}
