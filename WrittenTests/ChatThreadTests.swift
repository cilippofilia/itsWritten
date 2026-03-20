//
//  ChatThreadTests.swift
//  WrittenTests
//
//  Created by Filippo Cilia on 22/02/2026.
//

import SwiftData
import XCTest
@testable import Written

@MainActor
final class ChatThreadTests: XCTestCase {
    func testThreadInitialization() {
        let message = ChatMessage(content: "Hello", isUser: true, timestamp: .distantPast)
        let thread = ChatThread(
            title: "Daily Reflection",
            messages: [message],
            creationDate: .distantPast,
            lastUpdated: .distantFuture
        )

        XCTAssertEqual(thread.title, "Daily Reflection")
        XCTAssertEqual(thread.messages.count, 1)
        XCTAssertEqual(thread.messages.first?.content, "Hello")
        XCTAssertEqual(thread.creationDate, .distantPast)
        XCTAssertEqual(thread.lastUpdated, .distantFuture)
    }

    func testThreadPersistsWithMessages() throws {
        let schema = Schema([ChatThread.self, ChatMessage.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let timestampA = Date(timeIntervalSince1970: 1_706_000_100)
        let timestampB = Date(timeIntervalSince1970: 1_706_000_200)
        let messageA = ChatMessage(content: "Hello", isUser: true, timestamp: timestampA)
        let messageB = ChatMessage(content: "Hi there", isUser: false, timestamp: timestampB)
        let thread = ChatThread(title: "Test Thread", messages: [messageA, messageB])

        context.insert(thread)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ChatThread>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.messages.count, 2)
        let contents = fetched.first?.messages.map(\.content) ?? []
        XCTAssertEqual(Set(contents), Set(["Hello", "Hi there"]))
        let timestamps = fetched.first?.messages.map(\.timestamp) ?? []
        XCTAssertEqual(Set(timestamps), Set([timestampA, timestampB]))
    }
}
