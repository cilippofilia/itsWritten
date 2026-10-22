//
//  RemoveAdsLegalLinks.swift
//  itsWritten
//

import Foundation

/// Terms of Use and Privacy Policy links shown on the "Remove Ads" paywall.
enum RemoveAdsLegalLinks {
    /// Apple's Standard EULA — used because no custom End User License Agreement is
    /// configured in App Store Connect.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Keep in sync with the Privacy Policy URL in App Store Connect's App Information.
    static let privacyPolicy = URL(string: "https://cilippofilia.dev/itswritten/privacy-policy")!
}
