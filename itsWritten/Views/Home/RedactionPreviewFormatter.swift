//
//  RedactionPreviewFormatter.swift
//  itsWritten
//

import SwiftUI

/// Builds the review sheet's message text: hidden details highlighted, details
/// the user let through underlined with dashes, each one a link that toggles it.
///
/// The toggles are links inside one `Text` so the message wraps like prose;
/// `RedactionReviewSheet` handles them with an `OpenURLAction`.
enum RedactionPreviewFormatter {
    private static let scheme = "itswritten-redaction"

    /// The attributed message for `segments`.
    static func attributedText(for segments: [RedactionSegment]) -> AttributedString {
        segments.reduce(into: AttributedString()) { text, segment in
            text += piece(segment.text, entity: segment.entity)
        }
    }

    /// The details as a list separated by middle dots.
    static func attributedList(of entities: [RedactedEntity]) -> AttributedString {
        var text = AttributedString()
        for (index, entity) in entities.enumerated() {
            if index > 0 {
                text += AttributedString(" · ")
            }
            text += piece(entity.original, entity: entity)
        }
        return text
    }

    /// The link that toggles `entityID`.
    static func toggleURL(for entityID: RedactedEntity.ID) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "toggle"
        components.queryItems = [URLQueryItem(name: "id", value: entityID)]
        return components.url
    }

    /// The detail a toggle link names, or `nil` for any other URL.
    static func entityID(from url: URL) -> RedactedEntity.ID? {
        guard url.scheme == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == "toggle" else { return nil }
        return components.queryItems?.first { $0.name == "id" }?.value
    }

    private static func piece(_ string: String, entity: RedactedEntity?) -> AttributedString {
        var piece = AttributedString(string)
        guard let entity else { return piece }
        piece.link = toggleURL(for: entity.id)
        piece.foregroundColor = .primary
        if entity.isRevealed {
            piece.underlineStyle = Text.LineStyle(pattern: .dash)
        } else {
            piece.backgroundColor = .yellow.opacity(0.35)
            piece.inlinePresentationIntent = .stronglyEmphasized
        }
        return piece
    }
}
