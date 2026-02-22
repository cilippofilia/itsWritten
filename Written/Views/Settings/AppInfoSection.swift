//
//  AppInfoSection.swift
//  Written
//
//  Created by Filippo Cilia on 22/02/2026.
//

import SwiftUI

struct AppInfoSection: View {
    private let bundleIdentifier = Bundle.main.bundleIdentifier
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    private let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

    private var resolvedVersion: String {
        version ?? "Unknown"
    }

    var body: some View {
        Section {
            LabeledContent("Version", value: resolvedVersion)
            LabeledContent("Model", value: "Apple Intelligence")
            LabeledContent("iOS", value: osVersion)
        } header: {
            Text("App Info")
        }
    }
}

#Preview {
    Form {
        AppInfoSection()
    }
    .formStyle(.grouped)
}
