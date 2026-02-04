//
//  ChatHistoryView.swift
//  Written
//
//  Created by Filippo Cilia on 28/01/2026.
//

import FoundationModels
import SwiftUI

struct ChatHistoryView: View {
    @Environment(HomeViewModel.self) private var viewModel

    @Binding var config: ModelConfiguration
    @State private var presentedSheet: SheetType?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.chatThreads.isEmpty {
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
                        viewModel.chatThreads.append(contentsOf: ChatThread.sampleThreads)
                    }) {
                        Label("Add sample data", systemImage: "bubble.left.and.text.bubble.right")
                    }
                }
            }
            #endif
            .sheet(item: $presentedSheet) { sheet in
                sheet.view
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
            ForEach(viewModel.chatThreads.reversed()) { thread in
                Button(action: {
                    let session = buildSession(for: thread)
                    presentedSheet = .chatV2(
                        title: thread.title,
                        seedPrompt: nil,
                        session: session,
                        config: $config,
                        threadId: thread.id,
                        initialMessages: thread.messages
                    )
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(thread.title)
                            .bold()

                        Text(firstUserPrompt(in: thread) ?? "")
                            .frame(maxWidth: .infinity, alignment: .leading)
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

    private func firstUserPrompt(in thread: ChatThread) -> String? {
        thread.messages.first(where: { $0.isUser })?.content
    }
}

#Preview {
    ChatHistoryView(config: .constant(ModelConfiguration()))
        .environment(HomeViewModel())
}
