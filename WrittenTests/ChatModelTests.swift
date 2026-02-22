//
//  ChatModelTests.swift
//  WrittenTests
//
//  Created by Filippo Cilia on 22/02/2026.
//

import XCTest
@testable import Written

final class ChatModelTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let id = UUID(uuidString: "A8A6D8B1-75D6-4F9F-8A2A-2168C1F1E5F1")!
        let creationDate = Date(timeIntervalSince1970: 1_706_000_000)
        let model = ChatModel(
            id: id,
            title: "Test Title",
            prompt: "Test prompt",
            response: "Test response",
            creationDate: creationDate
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(model)
        let decoded = try decoder.decode(ChatModel.self, from: data)

        XCTAssertEqual(decoded, model)
    }
}
