//
//  ConsentDestination.swift
//  itsWritten
//

import Foundation
import VoltaSDK

/// Where journal text would go if the user allows an off-device answer.
///
/// Consent is granted per destination: saying yes to Claude says nothing
/// about Apple Private Cloud Compute, and vice versa.
enum ConsentDestination: Hashable, Sendable {
    case privateCloudCompute
    case vendor(CloudVendor)

    /// Maps a Volta provider to a consent destination.
    ///
    /// Returns `nil` for anything that stays on the device or that the app
    /// does not know how to describe to the user.
    init?(provider: ProviderIdentifier, privacyLevel: PrivacyLevel) {
        switch privacyLevel {
        case .appleCloud:
            guard provider == .privateCloudCompute else { return nil }
            self = .privateCloudCompute
        case .external:
            let vendor = CloudVendor.allCases.first { vendor in
                provider == .userAccount(vendor) || provider == vendor.providerIdentifier
            }
            guard let vendor else { return nil }
            self = .vendor(vendor)
        case .onDevice:
            return nil
        }
    }

    /// The name shown to the user, e.g. in the consent alert.
    var displayName: String {
        switch self {
        case .privateCloudCompute:
            String(localized: "Apple Private Cloud Compute")
        case .vendor(.openAI):
            String(localized: "OpenAI")
        case .vendor(.anthropic):
            String(localized: "Claude")
        case .vendor(.gemini):
            String(localized: "Gemini")
        }
    }

    /// The `UserDefaults` key holding the "always allow" choice.
    ///
    /// Uses fixed identifiers so the key never changes if a vendor's
    /// display or raw value does.
    var storageKey: String {
        let suffix = switch self {
        case .privateCloudCompute: "privateCloudCompute"
        case .vendor(.openAI): "openAI"
        case .vendor(.anthropic): "anthropic"
        case .vendor(.gemini): "gemini"
        }
        return "cloudConsent.alwaysAllow.\(suffix)"
    }
}
