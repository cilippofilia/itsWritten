//
//  KeychainAPIKeyStoreTests.swift
//  itsWrittenTests
//

import VoltaSDK
import XCTest
@testable import itsWritten

@available(iOS 26.0, *)
final class KeychainAPIKeyStoreTests: XCTestCase {
    private var store = KeychainAPIKeyStore(service: "itsWrittenTests.\(UUID())")

    override func setUp() {
        super.setUp()
        store = KeychainAPIKeyStore(service: "itsWrittenTests.\(UUID())")
    }

    override func tearDown() {
        for vendor in CloudVendor.allCases {
            try? store.setKey(nil, for: vendor)
        }
        super.tearDown()
    }

    func testRoundTrip() throws {
        try store.setKey("sk-ant-1", for: .anthropic)
        XCTAssertEqual(store.key(for: .anthropic), "sk-ant-1")
    }

    func testOverwrite() throws {
        try store.setKey("a", for: .openAI)
        try store.setKey("b", for: .openAI)
        XCTAssertEqual(store.key(for: .openAI), "b")
    }

    func testNilDeletes() throws {
        try store.setKey("a", for: .gemini)
        try store.setKey(nil, for: .gemini)
        XCTAssertNil(store.key(for: .gemini))
    }

    func testVendorsAreSeparate() throws {
        try store.setKey("a", for: .openAI)
        XCTAssertNil(store.key(for: .gemini))
    }
}
