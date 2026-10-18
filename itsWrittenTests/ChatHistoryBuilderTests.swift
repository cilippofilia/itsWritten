import XCTest
import VoltaSDK
@testable import itsWritten

@available(iOS 26.0, *)
@MainActor
final class ChatHistoryBuilderTests: XCTestCase {
    private func user(_ text: String) -> ChatMessage { ChatMessage(content: text, isUser: true) }
    private func assistant(_ text: String) -> ChatMessage { ChatMessage(content: text, isUser: false) }

    private func build(
        _ messages: [ChatMessage],
        excludingLastAssistant: Bool = false,
        excludingTrailingUser: Bool = false,
        isExcluded: @escaping (String) -> Bool = { _ in false },
        budget: Int = 4000
    ) -> [ChatTurn] {
        ChatHistoryBuilder.turns(
            from: messages,
            excludingLastAssistant: excludingLastAssistant,
            excludingTrailingUser: excludingTrailingUser,
            isExcluded: isExcluded,
            characterBudget: budget
        )
    }

    func testMapsRolesInOrder() {
        XCTAssertEqual(build([user("a"), assistant("b")]), [.user("a"), .assistant("b")])
    }

    func testDropsTrailingUserWhenAsked() {
        let messages = [user("a"), assistant("b"), user("c")]
        XCTAssertEqual(build(messages, excludingTrailingUser: true), [.user("a"), .assistant("b")])
    }

    func testDropsLastAssistantWhenAsked() {
        XCTAssertEqual(build([user("a"), assistant("b")], excludingLastAssistant: true), [.user("a")])
    }

    func testSkipsRefusals() {
        XCTAssertEqual(build([user("a"), assistant("no")], isExcluded: { $0 == "no" }), [.user("a")])
    }

    func testBudgetKeepsMostRecent() {
        let messages = [user("aaaa"), assistant("bbbb"), user("cc")]
        XCTAssertEqual(build(messages, budget: 6), [.assistant("bbbb"), .user("cc")])
    }

    func testBudgetStopsAtFirstTurnThatDoesNotFit() {
        let messages = [user("a"), assistant("bbbbbb"), user("cc")]
        XCTAssertEqual(build(messages, budget: 5), [.user("cc")])
    }

    func testZeroBudgetIsEmpty() {
        XCTAssertEqual(build([user("a"), assistant("b")], budget: 0), [])
    }

    func testSkipsBlockedUserTurnAndItsReply() {
        let blocked = ChatMessage(content: "blocked", isUser: true, wasBlocked: true)
        let messages = [user("a"), assistant("b"), blocked, assistant("failure copy"), user("c"), assistant("d")]
        XCTAssertEqual(build(messages), [.user("a"), .assistant("b"), .user("c"), .assistant("d")])
    }

    func testBlockedTrailingTurnLeavesEarlierTurnsIntact() {
        let blocked = ChatMessage(content: "blocked", isUser: true, wasBlocked: true)
        XCTAssertEqual(build([user("a"), assistant("b"), blocked]), [.user("a"), .assistant("b")])
    }

    func testSkipsExcludedAppCopy() {
        let copy = ConversationViewModel.stayedOnDeviceMessage
        let messages = [user("a"), assistant(copy), user("c")]
        XCTAssertEqual(
            build(messages, isExcluded: ConversationViewModel.isAppGeneratedCopy),
            [.user("a"), .user("c")]
        )
    }
}
