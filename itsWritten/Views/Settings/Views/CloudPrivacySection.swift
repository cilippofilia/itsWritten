//
//  CloudPrivacySection.swift
//  itsWritten
//

import SwiftUI

/// Explains, above the API keys, what happens before anything reaches a cloud model.
@available(iOS 26.0, *)
struct CloudPrivacySection: View {
    @Environment(\.locale) private var locale

    var body: some View {
        Section {
            Label("Answers come from your device first.", systemImage: "iphone")
            Label("You're asked before anything is sent to a cloud model.", systemImage: "hand.raised")
            Label(
                "Names, places and other personal details are hidden before sending. You see what's hidden and can let any word through.",
                systemImage: "eye.slash"
            )
            Label(CloudPrivacyCopy.nameLanguagesText(locale: locale), systemImage: "character.bubble")
        } header: {
            Text("How your privacy is protected")
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    Form {
        CloudPrivacySection()
    }
    .formStyle(.grouped)
}
