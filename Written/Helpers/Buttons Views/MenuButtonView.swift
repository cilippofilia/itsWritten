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
    @Binding var showHistoryView: Bool
    @Binding var showSettings: Bool

    var body: some View {
        Menu {
            // TODO: ideas to implement
            Label("Onboarding", systemImage: "book.pages")

            Button(action: {
                showHistoryView = true
            }) {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            Divider()

            Button(action: {
                showLanguageSupportSheet = true
            }) {
                Label("Language support", systemImage: "translate")
            }

            Button(action: {
                showWhyAISheet = true
            }) {
                Label("Why AI?", systemImage: "sparkles")
            }

            #if DEBUG
            Divider()

            Button("Settings", systemImage: "gearshape") {
                showSettings = true
            }
            #endif
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
        showHistoryView: .constant(false),
        showSettings: .constant(false)
    )
}
