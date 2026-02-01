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
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Your conversation history will appear here")
                    )
                } else {
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
                                    .lineLimit(3)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                                .contentShape(.rect(cornerRadius: 12, style: .continuous))
                                .listRowInsets(.init(top: 6, leading: 12, bottom: 6, trailing: 12))
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
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
                    NavigationStack {
                        PromptHistoryDetailView(history: history)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(action: {
                                        showPromptHistory = false
                                    }) {
                                        Label("Done", systemImage: "xmark")
                                    }
                                }
                            }
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }
}

#Preview {
    HistoryView()
        .environment(HomeViewModel())
}
