//
//  HistoryView.swift
//  Written
//
//  Created by Filippo Cilia on 28/01/2026.
//

import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeViewModel.self) private var viewModel
    
    @State private var showPromptHistory: Bool = false
    @State private var selectedHistory: HistoryModel?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.history.isEmpty {
                    unavailableView
                } else {
                    availableView
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        viewModel.history = HistoryModel.historyExamples
                    }) {
                        Label("Add sample data", systemImage: "book.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showPromptHistory) {
                if let history = selectedHistory {
                    PromptHistoryDetailView(history: history)
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
            ForEach(viewModel.history.reversed()) { convo in
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
                    .listRowInsets(.init(top: 6, leading: 6, bottom: 0, trailing: 6))
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    HistoryView()
        .environment(HomeViewModel())
}
