//
//  ChatHistoryView.swift
//  Written
//
//  Created by Filippo Cilia on 28/01/2026.
//

import SwiftUI

struct ChatHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeViewModel.self) private var viewModel
    
    @State private var showPromptHistory: Bool = false
    @State private var selectedHistory: ChatModel?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.chatHistory.isEmpty {
                    unavailableView
                } else {
                    availableView
                }
            }
            .navigationTitle("History")
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        viewModel.chatHistory.append(contentsOf: ChatModel.chatExamples)
                    }) {
                        Label("Add sample data", systemImage: "bubble.left.and.text.bubble.right")
                    }
                }
            }
            #endif
            .sheet(isPresented: $showPromptHistory) {
                if let history = selectedHistory {
                    ChatDetailView(history: history)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    var unavailableView: some View {
        ContentUnavailableView(
            "No History",
            systemImage: "clock.arrow.circlepath",
            description: Text("Your conversation history will appear here")
        )
    }

    var availableView: some View {
        List {
            ForEach(viewModel.chatHistory.reversed()) { convo in
                Button(action: {
                    selectedHistory = convo
                    showPromptHistory = true
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt \(convo.id)")
                            .bold()

                        Group {
                            Text(convo.prompt)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .bold()
                                .padding(.leading)

                            Text(convo.response)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing)
                        }
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
                    .contentShape(.rect(cornerRadius: 12, style: .continuous))
                }
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 8, leading: 8, bottom: 0, trailing: 8))
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    ChatHistoryView()
        .environment(HomeViewModel())
}
