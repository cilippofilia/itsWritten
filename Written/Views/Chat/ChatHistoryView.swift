//
//  ChatHistoryView.swift
//  Written
//
//  Created by Filippo Cilia on 28/01/2026.
//

import FoundationModels
import SwiftUI
import SwiftData

struct ChatHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatThread.lastUpdated, order: .reverse) private var chatThreads: [ChatThread]

    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType
    @State private var presentedSheet: SheetType?
    @State private var showingDeleteAllConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if chatThreads.isEmpty {
                    unavailableView
                } else {
                    availableView
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete All") {
                        showingDeleteAllConfirmation = true
                    }
                    .disabled(chatThreads.isEmpty)
                    .confirmationDialog(
                        "Delete all history?",
                        isPresented: $showingDeleteAllConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete All", role: .destructive) {
                            withAnimation(.easeInOut) {
                                for thread in chatThreads {
                                    modelContext.delete(thread)
                                }
                                try? modelContext.save()
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently remove all saved conversations.")
                    }
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                sheet.view
            }
        }
    }

    var unavailableView: some View {
        ContentUnavailableView {
            Label("No History", systemImage: "bubble.left.and.exclamationmark.bubble.right")
        } description: {
            Text("You don't have any conversation history yet")
        }
    }

    var availableView: some View {
        List {
            ForEach(chatThreads) { thread in
                Button(action: {
                    let session = buildSession(for: thread)
                    presentedSheet = .chatV2(
                        title: thread.title,
                        seedPrompt: nil,
                        session: session,
                        config: $config,
                        responseType: $responseType,
                        threadId: thread.id,
                        initialMessages: thread.messages
                    )
                }) {
                    ChatHistoryRowView(thread: thread)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 4, leading: 8, bottom: 4, trailing: 8))
                .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteThreads)
        }
        .listStyle(.plain)
    }

    private func buildSession(for thread: ChatThread) -> LanguageModelSession {
        var entries: [Transcript.Entry] = []

        if config.instructions.isReallyEmpty == false {
            let instructionSegment = Transcript.Segment.text(.init(content: config.instructions))
            let instructions = Transcript.Instructions(
                segments: [instructionSegment],
                toolDefinitions: []
            )
            entries.append(.instructions(instructions))
        }

        for message in thread.messages {
            let segment = Transcript.Segment.text(.init(content: message.content))
            if message.isUser {
                let prompt = Transcript.Prompt(segments: [segment])
                entries.append(.prompt(prompt))
            } else {
                let response = Transcript.Response(assetIDs: [], segments: [segment])
                entries.append(.response(response))
            }
        }

        return LanguageModelSession(transcript: Transcript(entries: entries))
    }

    private func deleteThreads(at offsets: IndexSet) {
        withAnimation(.easeInOut) {
            for index in offsets {
                modelContext.delete(chatThreads[index])
            }
            try? modelContext.save()
        }
    }
}

#Preview {
    ChatHistoryView(
        config: .constant(ModelConfiguration()),
        responseType: .constant(.standard)
    )
    .modelContainer(for: [ChatThread.self, ChatMessage.self], inMemory: true)
}
