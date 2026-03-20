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

    func testEqualityConsidersIdentifier() {
        let creationDate = Date(timeIntervalSince1970: 1_706_000_000)
        let modelA = ChatModel(
            id: UUID(uuidString: "3F1E6A7D-2E0A-42F0-8F49-BA0D79B5F8D2")!,
            title: "Title",
            prompt: "Prompt",
            response: "Response",
            creationDate: creationDate
        )
        let modelB = ChatModel(
            id: UUID(uuidString: "B0F7C2D4-5D87-4C3B-9B1C-9B9E35E7A1A4")!,
            title: "Title",
            prompt: "Prompt",
            response: "Response",
            creationDate: creationDate
        )

        XCTAssertNotEqual(modelA, modelB)
    }
}
