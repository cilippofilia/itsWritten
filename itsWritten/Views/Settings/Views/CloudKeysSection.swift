//
//  CloudKeysSection.swift
//  itsWritten
//

import SwiftUI
import VoltaSDK

/// Settings section where users add their own cloud API keys.
struct CloudKeysSection: View {
    var body: some View {
        ForEach(CloudVendor.allCases, id: \.self) { vendor in
            Section {
                CloudKeyRow(vendor: vendor)
            } header: {
                if vendor == CloudVendor.allCases.first {
                    Text("Cloud Models (Optional)")
                }
            } footer: {
                if vendor == CloudVendor.allCases.last {
                    Text("Use your own API key. Usage is billed to your account with that provider. Keys are stored in your Keychain on this device.")
                }
            }
        }
    }
}

#Preview {
    Form {
        CloudKeysSection()
    }
    .formStyle(.grouped)
    .environment(AIProviderStore())
}
