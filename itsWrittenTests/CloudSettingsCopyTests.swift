//
//  CloudSettingsCopyTests.swift
//  itsWrittenTests
//

import VoltaSDK
import XCTest
@testable import itsWritten

final class CloudSettingsCopyTests: XCTestCase {
    func testSummaryNamesTheVendors() {
        XCTAssertEqual(CloudModelsSummary.text(for: []), "Off")
        XCTAssertEqual(CloudModelsSummary.text(for: [.anthropic]), "Claude")
        XCTAssertEqual(CloudModelsSummary.text(for: [.anthropic, .gemini]), "2 models")
    }

    func testNameLanguagesFollowTheDetector() {
        let text = CloudPrivacyCopy.nameLanguagesText(locale: Locale(identifier: "en_US"))
        XCTAssertEqual(
            text,
            "Names are checked automatically in English, Italian, and Spanish. In other languages, they're sent as written."
        )
    }
}
