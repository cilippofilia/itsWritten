//
//  CloudConsentMessage.swift
//  itsWritten
//

/// Copy for the cloud-consent alert and the vendor review sheet. A "Send" covers
/// the rest of the current conversation, so both variants say so.
@available(iOS 26.0, *)
enum CloudConsentMessage {
    /// Explains the highlighted words in the review sheet.
    static let redactionHint = String(
        localized: "Highlighted words are replaced with placeholders before sending, and put back when the answer arrives. Tap one to send it as is."
    )

    /// Heading for details found only in earlier messages.
    static let earlierLabel = String(localized: "Also hidden from this chat")

    /// VoiceOver hint for the toggleable words.
    static let toggleAccessibilityHint = String(
        localized: "Activate a highlighted word to switch it between hidden and sent as is."
    )

    /// The prompt's title, e.g. "Send to Claude?".
    static func title(for destination: ConsentDestination) -> String {
        String(localized: "Send to \(destination.displayName)?")
    }

    /// Heading above the exact text the vendor receives.
    static func receivesLabel(for destination: ConsentDestination) -> String {
        String(localized: "What \(destination.displayName) receives")
    }

    /// The alert message for `destination`.
    static func text(for destination: ConsentDestination) -> String {
        switch destination {
        case .privateCloudCompute:
            """
            Apple Intelligence on this device can't answer this right now. Your message, this conversation, \
            and any research results will be sent to Apple Private Cloud Compute for the rest of this \
            conversation.
            """
        case .vendor:
            """
            Apple Intelligence can't answer this right now. Your message, this conversation, and any research \
            results will be sent to \(destination.displayName) using your API key for the rest of this \
            conversation.
            """
        }
    }
}
