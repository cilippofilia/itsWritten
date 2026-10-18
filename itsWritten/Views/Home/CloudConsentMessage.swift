//
//  CloudConsentMessage.swift
//  itsWritten
//

/// Copy for the cloud-consent alert.
enum CloudConsentMessage {
    /// The alert message for `destination`.
    static func text(for destination: ConsentDestination) -> String {
        switch destination {
        case .privateCloudCompute:
            "Apple Intelligence on this device can't answer this right now. Your message, this conversation, and any research results will be sent to Apple Private Cloud Compute."
        case .vendor:
            "Apple Intelligence can't answer this right now. Your message, this conversation, and any research results will be sent to \(destination.displayName) using your API key."
        }
    }
}
