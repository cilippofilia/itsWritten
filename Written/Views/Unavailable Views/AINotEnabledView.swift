//
//  AINotEnabledView.swift
//  Written
//
//  Created by Filippo Cilia on 06/01/2026.
//

import SwiftUI

struct AINotEnabledView: View {
    @State private var showWhyAISheet: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "apple.intelligence")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 60))

                Text("Apple Intelligence Required")
                    .font(.title2)
                    .bold()

                Text("This app requires Apple Intelligence to be enabled. Please enable it in Settings to continue.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Open Settings", systemImage: "gear")
                }
                .buttonStyle(.borderedProminent)
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
    AINotEnabledView()
}
