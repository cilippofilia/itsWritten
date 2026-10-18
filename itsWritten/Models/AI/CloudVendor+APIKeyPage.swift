//
//  CloudVendor+APIKeyPage.swift
//  itsWritten
//

import Foundation
import VoltaSDK

extension CloudVendor {
    /// The vendor's page for creating an API key, linked from the key settings.
    var apiKeyPageURL: URL? {
        switch self {
        case .openAI:
            URL(string: "https://platform.openai.com/api-keys")
        case .anthropic:
            URL(string: "https://console.anthropic.com/settings/keys")
        case .gemini:
            URL(string: "https://aistudio.google.com/apikey")
        }
    }
}
