//
//  RedactionSessionTests.swift
//  itsWrittenTests
//

import NaturalLanguage
import VoltaSDK
import XCTest
@testable import itsWritten

final class RedactionSessionTests: XCTestCase {
    private func call(_ prompt: String, instructions: String? = nil, history: [ChatTurn] = []) -> OutboundCall {
        OutboundCall(
            prompt: prompt,
            instructions: instructions,
            history: history,
            provider: .userAccount(.anthropic),
            privacyLevel: .external
        )
    }

    func testRedactsPromptHistoryAndInstructions() {
        var session = RedactionSession(hasNameModel: { _ in true })
        let redacted = session.redact(call(
            "Is marta@example.com still right?",
            instructions: "Sign as luca@example.com.",
            history: [.user("My email is marta@example.com"), .assistant("Noted, marta@example.com.")]
        ))
        XCTAssertEqual(redacted.call.prompt, "Is [EMAIL_1] still right?")
        XCTAssertEqual(redacted.call.history.map(\.text), ["My email is [EMAIL_1]", "Noted, [EMAIL_1]."])
        XCTAssertEqual(redacted.call.history.map(\.role), [.user, .assistant])
        XCTAssertEqual(redacted.call.instructions, "Sign as [EMAIL_2].\n\n\(RedactionSession.placeholderNote)")
        XCTAssertEqual(redacted.entityIDs, ["[EMAIL_1]", "[EMAIL_2]"])
    }

    func testPlaceholdersAreStableAcrossCalls() {
        var session = RedactionSession(hasNameModel: { _ in true })
        _ = session.redact(call("Mail marta@example.com"))
        let second = session.redact(call("Mail luca@example.com, then MARTA@example.com"))
        XCTAssertEqual(second.call.prompt, "Mail [EMAIL_2], then [EMAIL_1]")
    }

    func testKnownDetailIsHiddenWhereTheDetectorWouldMissIt() throws {
        try XCTSkipUnless(
            NLTagger.availableTagSchemes(for: .word, language: .english).contains(.nameType),
            "This runtime has no name-recognition model (the simulator ships without one)."
        )
        var session = RedactionSession(hasNameModel: { _ in true })
        _ = session.redact(call("Yesterday Marta Rossi flew to London to start her new job at Barclays."))
        // Lowercase, the tagger doesn't see a name here, but the session knows it.
        let redacted = session.redact(call("ok", history: [.assistant("say hi to marta rossi")]))
        XCTAssertEqual(redacted.call.history.first?.text, "say hi to [PERSON_1]")
    }

    func testOnlyWholeWordsAreReplaced() {
        var session = RedactionSession(hasNameModel: { _ in true })
        _ = session.redact(call("Yesterday Marta Rossi flew to London to start her new job at Barclays."))
        let redacted = session.redact(call("Martadella and Londoner aren't her, but Marta is."))
        XCTAssertTrue(redacted.call.prompt.contains("Martadella"))
        XCTAssertTrue(redacted.call.prompt.contains("Londoner"))
    }

    func testNothingToHideLeavesInstructionsAlone() {
        var session = RedactionSession(hasNameModel: { _ in true })
        let redacted = session.redact(call("How do I make risotto?", instructions: "Be brief."))
        XCTAssertEqual(redacted.call.prompt, "How do I make risotto?")
        XCTAssertEqual(redacted.call.instructions, "Be brief.")
        XCTAssertTrue(redacted.entityIDs.isEmpty)
    }

    func testRevealedDetailIsSentAsIsWithoutTheNote() {
        var session = RedactionSession(hasNameModel: { _ in true })
        _ = session.redact(call("Mail marta@example.com"))
        session.toggleReveal("[EMAIL_1]")
        let redacted = session.redact(call("Mail marta@example.com"))
        XCTAssertEqual(redacted.call.prompt, "Mail marta@example.com")
        XCTAssertNil(redacted.call.instructions)
        XCTAssertEqual(redacted.entityIDs, ["[EMAIL_1]"])
    }

    func testReviewStateAndDiscard() {
        var session = RedactionSession(hasNameModel: { _ in true })
        let first = session.redact(call("Mail marta@example.com"))
        XCTAssertTrue(session.needsReview(first))
        session.markReviewed(first)
        XCTAssertFalse(session.needsReview(first))

        let second = session.redact(call("Mail luca@example.com"))
        XCTAssertTrue(session.needsReview(second))
        session.discardUnreviewed()
        XCTAssertEqual(session.entities.map(\.original), ["marta@example.com"])
    }

    func testRestoreToleratesRewrittenPlaceholders() {
        var session = RedactionSession(hasNameModel: { _ in true })
        _ = session.redact(call("Mail marta@example.com"))
        XCTAssertEqual(session.restore("Sent to [EMAIL_1]."), "Sent to marta@example.com.")
        XCTAssertEqual(session.restore("[email_1]'s inbox"), "marta@example.com's inbox")
        XCTAssertEqual(session.restore("[EMAIL 1] and EMAIL_1"), "marta@example.com and marta@example.com")
        XCTAssertEqual(session.restore("Unknown [EMAIL_9] stays"), "Unknown [EMAIL_9] stays")
    }

    func testEveryKindCanBeRestored() {
        for kind in RedactionKind.allCases {
            XCTAssertEqual(RedactionKind(placeholderPrefix: kind.placeholderPrefix.lowercased()), kind)
        }
        var session = RedactionSession(hasNameModel: { _ in true })
        _ = session.redact(call(
            "marta@example.com +44 20 7946 0958 4111 1111 1111 1111 192.168.1.20 51.5074, -0.1278 SSN 123-45-6789"
        ))
        let placeholders = session.entities.map(\.placeholder).joined(separator: " ")
        let originals = session.entities.map(\.original).joined(separator: " ")
        XCTAssertFalse(session.entities.isEmpty)
        XCTAssertEqual(session.restore(placeholders), originals)
    }

    func testRestoreForDisplayHoldsBackPartialPlaceholders() {
        var session = RedactionSession(hasNameModel: { _ in true })
        _ = session.redact(call("Mail marta@example.com"))
        XCTAssertEqual(session.restoreForDisplay("Sent to [EMA"), "Sent to ")
        XCTAssertEqual(session.restoreForDisplay("Sent to [EMAIL_"), "Sent to ")
        XCTAssertEqual(session.restoreForDisplay("Sent to EMAIL_"), "Sent to ")
        XCTAssertEqual(session.restoreForDisplay("Sent to [EMAIL_1]"), "Sent to marta@example.com")
        XCTAssertEqual(session.restoreForDisplay("All done."), "All done.")
    }

    func testEmptySessionChangesNothing() {
        let session = RedactionSession(hasNameModel: { _ in true })
        XCTAssertEqual(session.restore("[PERSON_1]"), "[PERSON_1]")
        XCTAssertEqual(session.restoreForDisplay("Look at [this"), "Look at [this")
    }

    func testReviewSplitsPromptAndListsEarlierDetails() {
        var session = RedactionSession(hasNameModel: { _ in true })
        let request = call("Mail marta@example.com today", history: [.user("Or luca@example.com")])
        _ = session.redact(request)
        let review = session.review(of: request)
        XCTAssertEqual(review.segments.map(\.text), ["Mail ", "marta@example.com", " today"])
        XCTAssertEqual(review.segments.map(\.entity?.id), [nil, "[EMAIL_1]", nil])
        XCTAssertEqual(review.earlierEntities.map(\.original), ["luca@example.com"])
        XCTAssertEqual(review.sentText, "Mail [EMAIL_1] today")
        XCTAssertTrue(review.hasEntities)
    }

    func testUncheckedUserTextNeedsReviewOnce() {
        var session = RedactionSession(hasNameModel: { _ in true })
        let japanese = "姉のマルタはモスクワに住んでいます。"
        let first = session.redact(call(japanese))
        XCTAssertEqual(first.uncheckedParagraphs, [japanese])
        XCTAssertTrue(session.needsReview(first))
        XCTAssertTrue(session.review(of: call(japanese)).namesUnchecked)

        session.markReviewed(first)
        let again = session.redact(call("Make it shorter", history: [.user(japanese)]))
        XCTAssertFalse(session.needsReview(again))
    }

    func testVendorRepliesDontCountAsUnchecked() {
        var session = RedactionSession(hasNameModel: { _ in true })
        let redacted = session.redact(call("Make it shorter", history: [.assistant("姉のマルタはモスクワに住んでいます。")]))
        XCTAssertTrue(redacted.uncheckedParagraphs.isEmpty)
        XCTAssertFalse(session.needsReview(redacted))
    }
}
