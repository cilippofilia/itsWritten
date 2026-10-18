//
//  RedactionKind.swift
//  itsWritten
//

import Foundation

/// A kind of personal detail that is replaced before text reaches a third-party
/// cloud model. Each kind has its own placeholder prefix, e.g. `[PERSON_1]`.
enum RedactionKind: String, CaseIterable, Sendable {
    case person
    case place
    case organization
    case address
    case phone
    case link
    case email
    case handle
    case card
    case iban
    case identifier
    case date
    case coordinates
    case ipAddress
    case secret

    /// The uppercase prefix used in placeholders. Fixed strings, so a placeholder
    /// written in one release is still restored by the next.
    var placeholderPrefix: String {
        switch self {
        case .person: "PERSON"
        case .place: "PLACE"
        case .organization: "ORG"
        case .address: "ADDRESS"
        case .phone: "PHONE"
        case .link: "LINK"
        case .email: "EMAIL"
        case .handle: "HANDLE"
        case .card: "CARD"
        case .iban: "IBAN"
        case .identifier: "ID"
        case .date: "DATE"
        case .coordinates: "COORDINATES"
        case .ipAddress: "IP"
        case .secret: "SECRET"
        }
    }

    /// The kind as shown to the user, e.g. in the review sheet.
    var displayName: String {
        switch self {
        case .person: String(localized: "Name")
        case .place: String(localized: "Place")
        case .organization: String(localized: "Organization")
        case .address: String(localized: "Address")
        case .phone: String(localized: "Phone number")
        case .link: String(localized: "Link")
        case .email: String(localized: "Email")
        case .handle: String(localized: "Username")
        case .card: String(localized: "Card number")
        case .iban: String(localized: "Bank account")
        case .identifier: String(localized: "ID number")
        case .date: String(localized: "Date")
        case .coordinates: String(localized: "Location")
        case .ipAddress: String(localized: "IP address")
        case .secret: String(localized: "Password or key")
        }
    }

    /// The kind whose placeholder prefix is `prefix`, ignoring case.
    init?(placeholderPrefix prefix: String) {
        let uppercased = prefix.uppercased()
        guard let kind = Self.allCases.first(where: { $0.placeholderPrefix == uppercased }) else { return nil }
        self = kind
    }
}
