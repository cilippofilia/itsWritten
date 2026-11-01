//
//  CloudConsentMessageTests.swift
//  itsWrittenTests
//

import VoltaSDK
import XCTest
@testable import itsWritten

final class CloudConsentMessageTests: XCTestCase {
    func testVendorMessageNamesVendorAndScopesToConversation() {
        XCTAssertEqual(
            CloudConsentMessage.text(for: .vendor(.anthropic)),
            "Apple Intelligence can't answer this right now. Your message, this conversation, and any research "
                + "results will be sent to Claude using your API key for the rest of this conversation."
        )
    }

    func testPrivateCloudComputeMessageScopesToConversation() {
        XCTAssertEqual(
            CloudConsentMessage.text(for: .privateCloudCompute),
            "Apple Intelligence on this device can't answer this right now. Your message, this conversation, "
                + "and any research results will be sent to Apple Private Cloud Compute for the rest of this "
                + "conversation."
        )
    }
}
