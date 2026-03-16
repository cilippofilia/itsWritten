//
//  TypingIndicatorView.swift
//  Written
//
//  Created by Codex on 16/03/2026.
//

import SwiftUI

struct TypingIndicatorView: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .frame(width: 8, height: 8)
                    .padding(4)
                    .foregroundStyle(.secondary)
                    .opacity(phase == index ? 1 : 0.3)
                    .animation(.bouncy, value: phase)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.secondary.opacity(0.12))
        .clipShape(.capsule)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            while Task.isCancelled == false {
                for index in 0..<3 {
                    phase = index
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }
        }
    }
}

#Preview {
    TypingIndicatorView()
        .padding()
}
