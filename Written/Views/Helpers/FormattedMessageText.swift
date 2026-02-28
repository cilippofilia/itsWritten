//
//  FormattedMessageText.swift
//  Written
//
//  Created by Filippo Cilia on 22/02/2026.
//

import SwiftUI

struct FormattedMessageText: View {
    let text: String

    private var attributedText: AttributedString {
        let normalized = text.replacing("\r\n", with: "\n")
        var result = AttributedString()
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)

        for index in lines.indices {
            let line = String(lines[index])
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let displayLine = normalizedDisplayLine(for: line, trimmed: trimmed)

            if let attributedLine = try? AttributedString(
                markdown: displayLine,
                options: .init(interpretedSyntax: .inlineOnly, failurePolicy: .returnPartiallyParsedIfPossible)
            ) {
                result.append(attributedLine)
            } else {
                result.append(AttributedString(displayLine))
            }

            if index != lines.indices.last {
                result.append(AttributedString("\n"))
            }
        }

        return result
    }

    private func normalizedDisplayLine(for line: String, trimmed: String) -> String {
        if trimmed.hasPrefix("- ") {
            return "- " + trimmed.dropFirst(2)
        }

        if let dotRange = trimmed.range(of: ". "),
           dotRange.lowerBound != trimmed.startIndex,
           trimmed[..<dotRange.lowerBound].allSatisfy({ $0.isNumber }) {
            return trimmed
        }

        return line
    }

    var body: some View {
        Text(attributedText)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        FormattedMessageText(text: "1. **Empathetic Engagement**\n- Use bold and lists.")
        FormattedMessageText(text: "Plain text message.")
    }
    .padding()
}
