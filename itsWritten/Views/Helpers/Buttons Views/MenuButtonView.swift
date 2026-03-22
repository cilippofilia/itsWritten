//
//  MenuButtonView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

struct MenuButtonView: View {
    @Binding var showWhyAISheet: Bool
    @Binding var showChatHistoryView: Bool
    @Binding var showSettings: Bool
    let showOnboarding: () -> Void

    var body: some View {
        Menu {
            whyAIButton
            showOnboardingButton
            Divider()
            chatHistoryButton
            settingsButton
        } label: {
            Label("Menu", systemImage: "line.3.horizontal")
                .labelStyle(.iconOnly)
                .frame(width: 50, height: 50)
        }
        .menuOrder(.priority)
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive())
    }
}

private extension MenuButtonView {
    var whyAIButton: some View {
        Button(action: {
            showWhyAISheet = true
        }) {
            Label("Why AI?", systemImage: "sparkles")
        }
    }
    var showOnboardingButton: some View {
        Button(action: {
            showOnboarding()
        }) {
            Label("Onboarding", systemImage: "book.pages")
        }
    }
    var chatHistoryButton: some View {
        Button(action: {
            showChatHistoryView = true
        }) {
            Label("History", systemImage: "clock.arrow.circlepath")
        }
    }
    var settingsButton: some View {
        Button("Settings", systemImage: "gearshape") {
            showSettings = true
        }
    }
}

#Preview {
    MenuButtonView(
        showWhyAISheet: .constant(false),
        showChatHistoryView: .constant(false),
        showSettings: .constant(false),
        showOnboarding: { }
    )
}
