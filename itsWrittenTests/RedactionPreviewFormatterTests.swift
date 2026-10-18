//
//  RedactionPreviewFormatterTests.swift
//  itsWrittenTests
//

import SwiftUI
import XCTest
@testable import itsWritten

@available(iOS 26.0, *)
final class RedactionPreviewFormatterTests: XCTestCase {
    func testToggleURLRoundTrips() throws {
        let url = try XCTUnwrap(RedactionPreviewFormatter.toggleURL(for: "[PERSON_1]"))
        XCTAssertEqual(RedactionPreviewFormatter.entityID(from: url), "[PERSON_1]")
        XCTAssertNil(RedactionPreviewFormatter.entityID(from: try XCTUnwrap(URL(string: "https://example.com"))))
    }

    func testOnlyDetailsAreLinks() {
        let entity = RedactedEntity(id: "[PERSON_1]", original: "Marta", kind: .person)
        let segments = [
            RedactionSegment(id: 0, text: "Hi ", entity: nil),
            RedactionSegment(id: 1, text: "Marta", entity: entity)
        ]
        let text = RedactionPreviewFormatter.attributedText(for: segments)
        XCTAssertEqual(String(text.characters), "Hi Marta")
        let links = text.runs.compactMap { run in run.link.map { _ in String(text[run.range].characters) } }
        XCTAssertEqual(links, ["Marta"])
    }

    func testListSeparatesDetails() {
        let entities = [
            RedactedEntity(id: "[PERSON_1]", original: "Marta", kind: .person),
            RedactedEntity(id: "[PLACE_1]", original: "London", kind: .place, isRevealed: true)
        ]
        let text = RedactionPreviewFormatter.attributedList(of: entities)
        XCTAssertEqual(String(text.characters), "Marta · London")
    }
}
