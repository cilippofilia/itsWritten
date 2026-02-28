//
//  MenuButtonView.swift
//  written
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

struct MenuButtonView: View {
    @Binding var showWhyAISheet: Bool
    @Binding var showLanguageSupportSheet: Bool
    @Binding var showChatHistoryView: Bool
    @Binding var showSettings: Bool
    let showOnboarding: () -> Void

    var body: some View {
        Menu {
            Button(action: {
                showWhyAISheet = true
            }) {
                Label("Why AI?", systemImage: "sparkles")
            }

            Button(action: {
                showOnboarding()
            }) {
                Label("Onboarding", systemImage: "book.pages")
            }

            Divider()

            Button(action: {
                showChatHistoryView = true
            }) {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            Button("Settings", systemImage: "gearshape") {
                showSettings = true
            }
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

#Preview {
    MenuButtonView(
        showWhyAISheet: .constant(false),
        showLanguageSupportSheet: .constant(false),
        showChatHistoryView: .constant(false),
        showSettings: .constant(false),
        showOnboarding: {}
    )
}
