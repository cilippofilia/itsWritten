//
//  ExpandableText.swift
//  Written
//
//  Created by Filippo Cilia on 04/02/2026.
//

import SwiftUI

struct ExpandableText: View {
    let text: String
    let lineLimit: Int
    let threshold: Int
    let isUser: Bool

    @State private var isExpanded = false

    var body: some View {
        if text.count <= threshold {
            Text(text)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .lineLimit(isExpanded ? nil : lineLimit)

                Button(isExpanded ? "Show less" : "Show more") {
                    isExpanded.toggle()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(isUser ? .white.opacity(0.85) : .secondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ExpandableText(
            text: String(repeating: "Long message example. ", count: 12),
            lineLimit: 3,
            threshold: 120,
            isUser: false
        )
        ExpandableText(
            text: "Short message.",
            lineLimit: 3,
            threshold: 120,
            isUser: true
        )
    }
    .padding()
}
