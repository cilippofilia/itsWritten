//
//  MenuButtonView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

/// The app menu in `HomeView`'s toolbar. A plain system `Menu` with a title and symbol,
/// so the toolbar supplies its glass, overflow, and vertical-bar placement.
@available(iOS 26.0, *)
struct MenuButtonView: View {
    let showWhyAI: () -> Void
    let showOnboarding: () -> Void
    let showHistory: () -> Void
    let showSettings: () -> Void

    /// Bumped each time a new-chat letter lands in this button.
    var deliveryCount = 0

    var body: some View {
        Menu("Menu", systemImage: "line.3.horizontal") {
            Button("Why AI?", systemImage: "sparkles", action: showWhyAI)
            Button("Onboarding", systemImage: "book.pages", action: showOnboarding)
            Divider()
            Button("History", systemImage: "clock.arrow.circlepath", action: showHistory)
            Button("Settings", systemImage: "gearshape", action: showSettings)
        }
        .menuOrder(.priority)
        .symbolEffect(.bounce, value: deliveryCount)
        .sensoryFeedback(.impact(weight: .light), trigger: deliveryCount)
    }
}

@available(iOS 26.0, *)
#Preview {
    MenuButtonView(
        showWhyAI: { },
        showOnboarding: { },
        showHistory: { },
        showSettings: { }
    )
}
