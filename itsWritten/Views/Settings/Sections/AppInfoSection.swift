//
//  AppInfoSection.swift
//  itsWritten
//
//  Created by Filippo Cilia on 22/02/2026.
//

import SwiftUI

@available(iOS 26.0, *)
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
            LabeledContent("iOS", value: osVersion)
        } header: {
            Text("App Info")
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    Form {
        AppInfoSection()
    }
    .formStyle(.grouped)
}
