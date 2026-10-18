//
//  SensitiveTextDetectorTests.swift
//  itsWrittenTests
//

import NaturalLanguage
import XCTest
@testable import itsWritten

final class SensitiveTextDetectorTests: XCTestCase {
    /// The detected texts of one kind.
    private func detected(_ kind: RedactionKind, in text: String) -> [String] {
        SensitiveTextDetector.spans(in: text).filter { $0.kind == kind }.map(\.text)
    }

    func testFindsNamesPlacesAndOrganizations() throws {
        try XCTSkipUnless(
            NLTagger.availableTagSchemes(for: .word, language: .english).contains(.nameType),
            "This runtime has no name-recognition model (the simulator ships without one)."
        )
        let text = "Yesterday Marta Rossi flew to London to start her new job at Barclays."
        XCTAssertEqual(detected(.person, in: text), ["Marta Rossi"])
        XCTAssertEqual(detected(.place, in: text), ["London"])
        XCTAssertEqual(detected(.organization, in: text), ["Barclays"])
    }

    func testFindsContactDetails() {
        let text = "Reach me at marta.rossi@example.com, on +44 20 7946 0958, or @marta_r."
        XCTAssertEqual(detected(.email, in: text), ["marta.rossi@example.com"])
        XCTAssertEqual(detected(.phone, in: text), ["+44 20 7946 0958"])
        XCTAssertEqual(detected(.handle, in: text), ["@marta_r"])
    }

    func testEmailIsNotAlsoAHandle() {
        XCTAssertEqual(detected(.handle, in: "write to marta@example.com"), [])
    }

    func testFindsAddressAsOneSpan() {
        let spans = SensitiveTextDetector.spans(in: "I live at 1 Infinite Loop, Cupertino, CA 95014 now.")
        XCTAssertEqual(spans.map(\.kind), [.address])
        XCTAssertTrue(spans.first?.text.hasPrefix("1 Infinite Loop") == true)
    }

    func testCardNumbersNeedAValidChecksum() {
        XCTAssertEqual(detected(.card, in: "card 4111 1111 1111 1111 please"), ["4111 1111 1111 1111"])
        XCTAssertTrue(SensitiveTextDetector.passesLuhn("4111111111111111"))
        XCTAssertFalse(SensitiveTextDetector.passesLuhn("4111111111111112"))
        XCTAssertFalse(SensitiveTextDetector.passesLuhn("1234"))
    }

    func testFindsIBAN() {
        XCTAssertEqual(detected(.iban, in: "Pay GB82 WEST 1234 5698 7654 32 today"), ["GB82 WEST 1234 5698 7654 32"])
    }

    func testFindsIdentifiers() {
        XCTAssertEqual(detected(.identifier, in: "SSN 123-45-6789"), ["123-45-6789"])
        XCTAssertEqual(detected(.identifier, in: "codice fiscale RSSMRA85T10A562S"), ["RSSMRA85T10A562S"])
        XCTAssertEqual(detected(.identifier, in: "NI number QQ 12 34 56 C"), ["QQ 12 34 56 C"])
        XCTAssertEqual(detected(.identifier, in: "My MRN is 448812."), ["448812"])
        XCTAssertEqual(detected(.identifier, in: "passport no. YA1234567"), ["YA1234567"])
    }

    func testLabelledValueWithoutDigitsIsKept() {
        XCTAssertEqual(detected(.identifier, in: "my account is secure"), [])
    }

    func testFindsSecrets() {
        XCTAssertEqual(
            detected(.secret, in: "key sk-ant-abcdefghijklmnop1234 here"),
            ["sk-ant-abcdefghijklmnop1234"]
        )
        XCTAssertEqual(detected(.secret, in: "my password is hunter2!"), ["hunter2!"])
    }

    func testFindsCoordinatesAndIPAddresses() {
        XCTAssertEqual(detected(.coordinates, in: "meet at 51.5074, -0.1278"), ["51.5074, -0.1278"])
        XCTAssertEqual(detected(.ipAddress, in: "my router is 192.168.1.20"), ["192.168.1.20"])
        XCTAssertEqual(detected(.ipAddress, in: "version 1.2.3.999"), [])
    }

    func testOnlySpecificDatesAreHidden() {
        XCTAssertTrue(SensitiveTextDetector.isSpecificDate("12 March 1990"))
        XCTAssertTrue(SensitiveTextDetector.isSpecificDate("03/04/90"))
        XCTAssertFalse(SensitiveTextDetector.isSpecificDate("this weekend"))
        XCTAssertFalse(SensitiveTextDetector.isSpecificDate("tomorrow at 5"))
        XCTAssertEqual(detected(.date, in: "What should we do this weekend?"), [])
    }

    func testOverlapsKeepTheLongestSpan() {
        let text = "abcdef"
        let start = text.startIndex
        let short = DetectedSpan(range: start..<text.index(start, offsetBy: 3), kind: .place, text: "abc")
        let long = DetectedSpan(range: start..<text.endIndex, kind: .address, text: "abcdef")
        let later = DetectedSpan(range: text.index(start, offsetBy: 4)..<text.endIndex, kind: .person, text: "ef")
        XCTAssertEqual(SensitiveTextDetector.resolvingOverlaps([short, later, long]), [long])
    }

    func testNameSpansDropLeadingLowercaseWords() throws {
        let text = "Mia sorella Marta Rossi vive a Mosca"
        let end = try XCTUnwrap(text.range(of: "Marta Rossi")).upperBound
        let tail = SensitiveTextDetector.capitalizedTail(of: text.startIndex..<end, in: text)
        XCTAssertEqual(String(text[tail]), "Marta Rossi")

        let name = "Giovanni Bianchi"
        let whole = name.startIndex..<name.endIndex
        XCTAssertEqual(SensitiveTextDetector.capitalizedTail(of: whole, in: name), whole)
    }

    func testUncheckedParagraphsFollowLanguage() {
        let device: (NLLanguage) -> Bool = { _ in true }
        XCTAssertEqual(SensitiveTextDetector.uncheckedParagraphs(in: "My sister Marta lives in Moscow.", hasNameModel: device), [])
        XCTAssertEqual(SensitiveTextDetector.uncheckedParagraphs(in: "Mia sorella Marta vive a Mosca.", hasNameModel: device), [])
        XCTAssertEqual(
            SensitiveTextDetector.uncheckedParagraphs(in: "姉のマルタはモスクワに住んでいます。", hasNameModel: device),
            ["姉のマルタはモスクワに住んでいます。"]
        )
        XCTAssertEqual(
            SensitiveTextDetector.uncheckedParagraphs(in: "Ma sœur Marta habite à Moscou avec son mari.", hasNameModel: device),
            ["Ma sœur Marta habite à Moscou avec son mari."]
        )
    }

    func testUncheckedParagraphsAreFoundInsideATemplate() {
        let text = "User question:\n姉のマルタはモスクワに住んでいます。\n\nAnswer using only the evidence above for factual claims."
        XCTAssertEqual(
            SensitiveTextDetector.uncheckedParagraphs(in: text, hasNameModel: { _ in true }),
            ["姉のマルタはモスクワに住んでいます。"]
        )
    }

    func testShortUncapitalizedRepliesCountAsChecked() {
        let noModel: (NLLanguage) -> Bool = { _ in false }
        XCTAssertEqual(SensitiveTextDetector.uncheckedParagraphs(in: "ok", hasNameModel: noModel), [])
        XCTAssertEqual(SensitiveTextDetector.uncheckedParagraphs(in: "Thanks so much", hasNameModel: noModel), [])
        XCTAssertEqual(SensitiveTextDetector.uncheckedParagraphs(in: "ask Marta", hasNameModel: noModel), ["ask Marta"])
    }

    func testWithoutANameModelEverythingIsUnchecked() {
        XCTAssertEqual(
            SensitiveTextDetector.uncheckedParagraphs(in: "My sister Marta lives in Moscow.", hasNameModel: { _ in false }),
            ["My sister Marta lives in Moscow."]
        )
    }

    func testPlainTextHasNothingToHide() {
        XCTAssertEqual(SensitiveTextDetector.spans(in: "How do I make a good risotto?"), [])
        XCTAssertEqual(SensitiveTextDetector.spans(in: ""), [])
    }
}
