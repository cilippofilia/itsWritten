//
//  DetectedSpan.swift
//  itsWritten
//

import Foundation

/// A stretch of text the detector thinks is a personal detail.
struct DetectedSpan: Equatable, Sendable {
    let range: Range<String.Index>
    let kind: RedactionKind
    /// The detected text, as written.
    let text: String
}
