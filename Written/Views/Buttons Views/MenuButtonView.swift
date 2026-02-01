//
//  MenuButtonView.swift
//  written
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

struct MenuButtonView: View {
    @Binding var selectedModel: AIModel
    let aiModels: [AIModel]
    @Binding var showWhyAISheet: Bool
    @Binding var showHistoryView: Bool

    var body: some View {
        Menu {
            // TODO: ideas to implement
            Label("Onboarding", systemImage: "book.pages")

            Menu {
                Picker("", selection: $selectedModel) {
                    ForEach(aiModels, id: \.self) { model in
                        Text(model.title)
                    }
                }
            } label: {
                Label("Model types", systemImage: "brain")
            }

            Button(action: {
                showHistoryView = true
            }) {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            Divider()

            Button(action: {
                showWhyAISheet = true
            }) {
                Label("Why AI?", systemImage: "sparkles")
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
        selectedModel: .constant(AIModel(id: "", title: "", prompt: "")),
        aiModels: [],
        showWhyAISheet: .constant(false),
        showHistoryView: .constant(false)
    )
}
