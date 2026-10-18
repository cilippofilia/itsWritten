//
//  RedactionSession.swift
//  itsWritten
//

import Foundation
import NaturalLanguage
import VoltaSDK

/// The personal details of one conversation and the placeholders that stand for
/// them on their way to a third-party model.
///
/// A placeholder stays the same for the whole conversation, so the model can
/// follow it across turns: Marta is `[PERSON_1]` in every message. Stored messages
/// keep the real words (replies are restored as they arrive) and every call is
/// redacted from scratch, so the session only has to live as long as the
/// conversation. Losing it just means the user reviews the words again.
struct RedactionSession: Sendable {
    /// Every detail found so far, in the order it was first found.
    private(set) var entities: [RedactedEntity] = []
    /// Paragraphs whose names couldn't be checked, that the user has seen in a
    /// review sheet and sent anyway.
    private var reviewedUncheckedParagraphs: Set<String> = []
    /// Whether the device can find names in a language. Injected by tests to
    /// stand in for a device, since the simulator has no name model.
    private let hasNameModel: @Sendable (NLLanguage) -> Bool

    init(hasNameModel: @escaping @Sendable (NLLanguage) -> Bool = SensitiveTextDetector.hasNameModel) {
        self.hasNameModel = hasNameModel
    }

    /// Added to the instructions whenever something was replaced, so the model
    /// keeps placeholders intact and the phone can put the words back.
    static let placeholderNote = """
        Some personal details in this conversation were replaced with placeholders such as [PERSON_1] or \
        [PLACE_1]. When you refer to one, write the placeholder exactly as it appears. Don't ask what they \
        stand for.
        """

    /// Whether the session knows no details at all.
    var isEmpty: Bool { entities.isEmpty }

    // MARK: - Redacting

    /// Replaces every detail in `call` that the user hasn't let through. New
    /// details are added to the session as not yet reviewed.
    mutating func redact(_ call: OutboundCall) -> RedactedCall {
        let texts = [call.prompt] + call.history.map(\.text) + [call.instructions].compactMap { $0 }
        for text in texts {
            register(SensitiveTextDetector.spans(in: text))
        }
        // The vendor's own replies only ever held placeholders, so they can't
        // bring in names of the user's; only what the user and the app wrote counts.
        let userTexts = [call.prompt] + call.history.filter { $0.role == .user }.map(\.text)
            + [call.instructions].compactMap { $0 }
        var unchecked = Set<String>()
        for text in userTexts {
            unchecked.formUnion(SensitiveTextDetector.uncheckedParagraphs(in: text, hasNameModel: hasNameModel))
        }

        var found = Set<RedactedEntity.ID>()
        var redacted = call
        redacted.prompt = replacingDetails(in: call.prompt, found: &found)
        redacted.history = call.history.map { turn in
            ChatTurn(role: turn.role, text: replacingDetails(in: turn.text, found: &found))
        }
        let instructions = call.instructions.map { replacingDetails(in: $0, found: &found) }
        let replacedAny = entities.contains { found.contains($0.id) && $0.isRevealed == false }
        if replacedAny {
            redacted.instructions = [instructions, Self.placeholderNote]
                .compactMap { $0 }
                .joined(separator: "\n\n")
        } else {
            redacted.instructions = instructions
        }
        return RedactedCall(call: redacted, entityIDs: found, uncheckedParagraphs: unchecked)
    }

    /// `redact(_:)` without changing the session, for a call whose details are
    /// already registered.
    func redactedCopy(of call: OutboundCall) -> RedactedCall {
        var copy = self
        return copy.redact(call)
    }

    /// Whether `redacted` still needs the user's review: it holds a detail not
    /// reviewed yet, or a paragraph whose names couldn't be checked that the
    /// user hasn't seen.
    func needsReview(_ redacted: RedactedCall) -> Bool {
        let hasNewDetail = entities.contains { redacted.entityIDs.contains($0.id) && $0.isReviewed == false }
        return hasNewDetail || redacted.uncheckedParagraphs.isSubset(of: reviewedUncheckedParagraphs) == false
    }

    /// `text` split into plain runs and details, for the review sheet.
    func segments(of text: String) -> [RedactionSegment] {
        var segments: [RedactionSegment] = []
        var cursor = text.startIndex
        for occurrence in occurrences(in: text) {
            if cursor < occurrence.range.lowerBound {
                segments.append(RedactionSegment(id: segments.count, text: String(text[cursor..<occurrence.range.lowerBound]), entity: nil))
            }
            segments.append(RedactionSegment(id: segments.count, text: String(text[occurrence.range]), entity: occurrence.entity))
            cursor = occurrence.range.upperBound
        }
        if cursor < text.endIndex {
            segments.append(RedactionSegment(id: segments.count, text: String(text[cursor...]), entity: nil))
        }
        return segments
    }

    /// What the review sheet shows for `call`. Doesn't change the session: every
    /// detail in the call must already be registered by `redact(_:)`.
    func review(of call: OutboundCall) -> RedactionReview {
        var copy = self
        let redacted = copy.redact(call)
        let segments = segments(of: call.prompt)
        let inPrompt = Set(segments.compactMap(\.entity?.id))
        let earlier = entities.filter { redacted.entityIDs.contains($0.id) && inPrompt.contains($0.id) == false }
        return RedactionReview(
            segments: segments,
            earlierEntities: earlier,
            sentText: redacted.call.prompt,
            namesUnchecked: redacted.uncheckedParagraphs.isEmpty == false
        )
    }

    // MARK: - Review choices

    /// Switches a detail between hidden and sent as is.
    mutating func toggleReveal(_ id: RedactedEntity.ID) {
        guard let index = entities.firstIndex(where: { $0.id == id }) else { return }
        entities[index].isRevealed.toggle()
    }

    /// Marks every detail as reviewed, and `call`'s unchecked paragraphs as
    /// seen, after the user sent.
    mutating func markReviewed(_ call: RedactedCall) {
        for index in entities.indices {
            entities[index].isReviewed = true
        }
        reviewedUncheckedParagraphs.formUnion(call.uncheckedParagraphs)
    }

    /// Forgets details the user never sent, after "Keep on Device".
    mutating func discardUnreviewed() {
        entities.removeAll { $0.isReviewed == false }
    }

    // MARK: - Restoring

    /// Puts the real words back into a reply. Tolerates the ways models rewrite
    /// placeholders: any letter case, `[PERSON 1]` with a space, and `PERSON_1`
    /// without brackets. Unknown placeholders are left as written.
    func restore(_ text: String) -> String {
        guard entities.isEmpty == false else { return text }
        // swiftlint:disable:next line_length
        let placeholder = #/\[(PERSON|PLACE|ORG|ADDRESS|PHONE|LINK|EMAIL|HANDLE|CARD|IBAN|ID|DATE|COORDINATES|IP|SECRET)[ _](\d{1,3})\]|\b(PERSON|PLACE|ORG|ADDRESS|PHONE|LINK|EMAIL|HANDLE|CARD|IBAN|ID|DATE|COORDINATES|IP|SECRET)_(\d{1,3})\b/#
            .ignoresCase()
        return text.replacing(placeholder) { match in
            let prefix = match.output.1 ?? match.output.3
            let number = match.output.2 ?? match.output.4
            guard let prefix, let number, let kind = RedactionKind(placeholderPrefix: String(prefix)), let value = Int(number),
                  let entity = entities.first(where: { $0.id == Self.placeholder(for: kind, number: value) }) else {
                return String(match.output.0)
            }
            return entity.original
        }
    }

    /// `restore(_:)` for a reply that is still streaming: also holds back a
    /// placeholder that has only partly arrived (`[PERS`), so it never flashes
    /// on screen. The final reply goes through `restore(_:)`.
    func restoreForDisplay(_ partial: String) -> String {
        let restored = restore(partial)
        guard entities.isEmpty == false,
              let match = restored.firstMatch(of: #/(?:\[[A-Za-z]{0,11}(?:[ _]\d{0,3})?|\b[A-Z]{2,11}_\d{0,3})$/#) else {
            return restored
        }
        return String(restored[..<match.range.lowerBound])
    }

    // MARK: - Private

    /// Adds every span that isn't a known detail yet.
    private mutating func register(_ spans: [DetectedSpan]) {
        for span in spans {
            let text = span.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 2, entity(matching: text) == nil else { continue }
            let next = (entities.filter { $0.kind == span.kind }.compactMap { Self.number(of: $0.id) }.max() ?? 0) + 1
            entities.append(RedactedEntity(id: Self.placeholder(for: span.kind, number: next), original: text, kind: span.kind))
        }
    }

    private func entity(matching text: String) -> RedactedEntity? {
        let key = RedactedEntity.matchingKey(for: text)
        return entities.first { RedactedEntity.matchingKey(for: $0.original) == key }
    }

    /// `text` with hidden details replaced. Adds every detail found, hidden or
    /// not, to `found`.
    private func replacingDetails(in text: String, found: inout Set<RedactedEntity.ID>) -> String {
        var result = ""
        var cursor = text.startIndex
        for occurrence in occurrences(in: text) {
            found.insert(occurrence.entity.id)
            result += text[cursor..<occurrence.range.lowerBound]
            result += occurrence.entity.isRevealed ? String(text[occurrence.range]) : occurrence.entity.placeholder
            cursor = occurrence.range.upperBound
        }
        result += text[cursor...]
        return result
    }

    /// Every whole-word occurrence of a known detail in `text`, in order and
    /// without overlaps. Longer details claim text first, so "Marta Rossi" wins
    /// over "Marta". Matches any letter case and accents, so a detail the detector
    /// found once is hidden everywhere, even where the detector would miss it.
    private func occurrences(in text: String) -> [(range: Range<String.Index>, entity: RedactedEntity)] {
        var claimed: [(range: Range<String.Index>, entity: RedactedEntity)] = []
        for entity in entities.sorted(by: { $0.original.count > $1.original.count }) {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(
                    of: entity.original,
                    options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                    range: searchStart..<text.endIndex
                  ) {
                searchStart = range.upperBound
                guard Self.isWholeWord(range, in: text),
                      claimed.allSatisfy({ $0.range.overlaps(range) == false }) else { continue }
                claimed.append((range, entity))
            }
        }
        return claimed.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    private static func isWholeWord(_ range: Range<String.Index>, in text: String) -> Bool {
        let isWordCharacter: (Character) -> Bool = { $0.isLetter || $0.isNumber }
        if range.lowerBound > text.startIndex, isWordCharacter(text[text.index(before: range.lowerBound)]) {
            return false
        }
        if range.upperBound < text.endIndex, isWordCharacter(text[range.upperBound]) {
            return false
        }
        return true
    }

    private static func placeholder(for kind: RedactionKind, number: Int) -> String {
        "[\(kind.placeholderPrefix)_\(number)]"
    }

    private static func number(of placeholder: String) -> Int? {
        placeholder.split(separator: "_").last.flatMap { Int($0.dropLast()) }
    }
}
