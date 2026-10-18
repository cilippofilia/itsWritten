//
//  SensitiveTextDetector.swift
//  itsWritten
//

import Foundation
import NaturalLanguage

/// Finds personal details in free text, entirely on device.
///
/// Names, places and organizations come from `NLTagger`; addresses, phone numbers,
/// links and dates from `NSDataDetector`; everything with a fixed shape (emails,
/// card numbers, IDs, keys…) from patterns. When spans overlap, the longer one
/// wins, so "221B Baker Street, London" is one address rather than an address
/// with a place inside it.
///
/// It errs on the side of hiding: the user can let a word through in the review
/// sheet, but a detail that was sent can't be taken back.
enum SensitiveTextDetector {
    /// Every detected span in `text`, in order, without overlaps.
    static func spans(in text: String) -> [DetectedSpan] {
        guard text.isEmpty == false else { return [] }
        var candidates: [DetectedSpan] = []
        candidates += patternSpans(in: text)
        candidates += dataDetectorSpans(in: text)
        candidates += nameSpans(in: text)
        return resolvingOverlaps(candidates)
    }

    // MARK: - Overlaps

    /// Kinds in order of preference when two spans cover exactly the same text:
    /// the most specific shape first.
    private static let priority: [RedactionKind] = [
        .secret, .email, .card, .iban, .identifier, .coordinates, .ipAddress,
        .link, .handle, .phone, .address, .date, .person, .organization, .place
    ]

    /// Keeps the longest span wherever spans overlap (the most specific kind on a
    /// tie), returned in text order.
    static func resolvingOverlaps(_ spans: [DetectedSpan]) -> [DetectedSpan] {
        let byPreference = spans.sorted { lhs, rhs in
            if lhs.text.count != rhs.text.count {
                return lhs.text.count > rhs.text.count
            }
            return rank(of: lhs.kind) < rank(of: rhs.kind)
        }
        var kept: [DetectedSpan] = []
        for span in byPreference where kept.allSatisfy({ $0.range.overlaps(span.range) == false }) {
            kept.append(span)
        }
        return kept.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    private static func rank(of kind: RedactionKind) -> Int {
        priority.firstIndex(of: kind) ?? priority.count
    }

    // MARK: - Names, places, organizations

    private static func nameSpans(in text: String) -> [DetectedSpan] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var spans: [DetectedSpan] = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            let kind: RedactionKind? = switch tag {
            case .personalName: .person
            case .placeName: .place
            case .organizationName: .organization
            default: nil
            }
            let word = String(text[range])
            if let kind, word.count >= 2 {
                spans.append(DetectedSpan(range: range, kind: kind, text: word))
            }
            return true
        }
        return spans
    }

    // MARK: - Addresses, phone numbers, links, dates

    private static func dataDetectorSpans(in text: String) -> [DetectedSpan] {
        let types: NSTextCheckingResult.CheckingType = [.address, .phoneNumber, .link, .date]
        guard let detector = try? NSDataDetector(types: types.rawValue) else { return [] }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let matched = String(text[range])
            let kind: RedactionKind? = switch match.resultType {
            case .address: .address
            case .phoneNumber: .phone
            case .link: match.url?.scheme == "mailto" ? .email : .link
            case .date: isSpecificDate(matched) ? .date : nil
            default: nil
            }
            return kind.map { DetectedSpan(range: range, kind: $0, text: matched) }
        }
    }

    /// Whether a detected date pins down a day someone could be found by, such as a
    /// birthdate: it has a year, or is written as numbers ("03/04/90"). Relative
    /// dates like "this weekend" or "tomorrow at 5" stay, so answers stay useful.
    static func isSpecificDate(_ text: String) -> Bool {
        let year = /\b(?:1[89]|20)\d{2}\b/
        let numeric = /\d{1,2}[\/.\-]\d{1,2}[\/.\-]\d{2,4}/
        return text.contains(year) || text.contains(numeric)
    }

    // MARK: - Fixed shapes

    private static func patternSpans(in text: String) -> [DetectedSpan] {
        var spans: [DetectedSpan] = []

        func add(_ range: Range<String.Index>, _ kind: RedactionKind) {
            spans.append(DetectedSpan(range: range, kind: kind, text: String(text[range])))
        }

        for match in text.matches(of: /[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/) {
            add(match.range, .email)
        }
        for match in text.matches(of: /(?:^|[\s(])(@[A-Za-z0-9_]{2,30})\b/) {
            let handle = match.output.1
            add(handle.startIndex..<handle.endIndex, .handle)
        }
        for match in text.matches(of: /\b(?:\d[ \-]?){12,18}\d\b/) where passesLuhn(String(text[match.range])) {
            add(match.range, .card)
        }
        for match in text.matches(of: /\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]){11,30}\b/) {
            add(match.range, .iban)
        }
        identifierSpans(in: text).forEach { add($0, .identifier) }
        for match in text.matches(of: /-?\d{1,2}\.\d{3,},\s*-?\d{1,3}\.\d{3,}/) {
            add(match.range, .coordinates)
        }
        for match in text.matches(of: /\b(?:\d{1,3}\.){3}\d{1,3}\b/) where isIPv4Address(String(text[match.range])) {
            add(match.range, .ipAddress)
        }
        secretSpans(in: text).forEach { add($0, .secret) }
        return spans
    }

    /// Government, health and account numbers.
    private static func identifierSpans(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        // US Social Security number.
        ranges += text.matches(of: /\b\d{3}-\d{2}-\d{4}\b/).map(\.range)
        // Italian codice fiscale.
        ranges += text.matches(of: /\b[A-Za-z]{6}\d{2}[A-Za-z]\d{2}[A-Za-z]\d{3}[A-Za-z]\b/).map(\.range)
        // UK National Insurance number.
        ranges += text.matches(of: /\b[A-Za-z]{2} ?\d{2} ?\d{2} ?\d{2} ?[A-Da-d]\b/).map(\.range)
        // Any number introduced by a label: "MRN 448812", "passport no. YA1234567".
        // swiftlint:disable:next line_length
        let labelled = /(?i)\b(?:mrn|nhs(?: number)?|patient (?:id|number)|passport(?: number| no\.?)?|licen[cs]e(?: number| no\.?)?|account(?: number| no\.?)?|policy(?: number| no\.?)?|member(?:ship)? (?:id|number)|insurance (?:id|number)|tax (?:id|code|number)|id(?: number)?)[\s:#]*(?:is\s+)?([A-Za-z0-9][A-Za-z0-9\-]{3,19})/
        for match in text.matches(of: labelled) {
            let value = match.output.1
            if value.contains(where: \.isNumber) {
                ranges.append(value.startIndex..<value.endIndex)
            }
        }
        return ranges
    }

    /// API keys, tokens, and anything given as a password.
    private static func secretSpans(in text: String) -> [Range<String.Index>] {
        // swiftlint:disable:next line_length
        let keys = /\b(?:sk-(?:ant-)?[A-Za-z0-9_\-]{16,}|AIza[0-9A-Za-z_\-]{30,}|gh[pousr]_[A-Za-z0-9]{30,}|xox[abpr]-[A-Za-z0-9\-]{10,}|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,})/
        var ranges = text.matches(of: keys).map(\.range)
        let password = /(?i)\b(?:password|passcode|passwd|pwd|pin)\s*(?:is|:|=)\s*(\S+)/
        for match in text.matches(of: password) {
            let value = match.output.1
            ranges.append(value.startIndex..<value.endIndex)
        }
        return ranges
    }

    /// The Luhn checksum card numbers carry, so random long numbers aren't hidden as cards.
    static func passesLuhn(_ text: String) -> Bool {
        let digits = text.compactMap(\.wholeNumberValue)
        guard (13...19).contains(digits.count) else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { total, element in
            let (index, digit) = element
            guard index.isMultiple(of: 2) == false else { return total + digit }
            let doubled = digit * 2
            return total + (doubled > 9 ? doubled - 9 : doubled)
        }
        return sum.isMultiple(of: 10)
    }

    private static func isIPv4Address(_ text: String) -> Bool {
        let octets = text.split(separator: ".")
        return octets.count == 4 && octets.allSatisfy { (Int($0) ?? 256) <= 255 }
    }
}
