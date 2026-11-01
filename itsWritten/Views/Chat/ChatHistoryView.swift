//
//  ChatHistoryView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 28/01/2026.
//

import SwiftData
import SwiftUI

/// Saved conversations. Shown as the sidebar of `HomeView`'s split view: beside the
/// conversation in wide windows, and as the screen behind it in narrow ones.
struct ChatHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatThread.lastUpdated, order: .reverse) private var chatThreads: [ChatThread]

    /// Called when the user picks a thread to resume.
    let onSelect: (ChatThread) -> Void

    @State private var showingDeleteAllConfirmation = false
    @State private var saveErrorMessage: String?

    var body: some View {
        Group {
            if chatThreads.isEmpty {
                ContentUnavailableView {
                    Label("No History", systemImage: "bubble.left.and.exclamationmark.bubble.right")
                } description: {
                    Text("You don't have any conversation history yet")
                }
            } else {
                ChatHistoryListView(
                    threads: chatThreads,
                    onSelect: onSelect,
                    onDelete: deleteThreads
                )
                #if !DEBUG
                .hideSensitiveData()
                #endif
            }
        }
        .safeAreaInset(edge: .bottom) {
            CrossPromoBannerView()
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Delete All", systemImage: "trash", role: .destructive, action: confirmDeleteAll)
                    .disabled(chatThreads.isEmpty)
                    .confirmationDialog(
                        "Delete all history?",
                        isPresented: $showingDeleteAllConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete All", role: .destructive, action: deleteAllThreads)
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently remove all saved conversations.")
                    }
            }
        }
        .alert("Couldn't Delete", item: $saveErrorMessage) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
    }

    private func confirmDeleteAll() {
        showingDeleteAllConfirmation = true
    }

    private func deleteAllThreads() {
        withAnimation(.easeInOut) {
            for thread in chatThreads {
                modelContext.delete(thread)
            }
            save()
        }
    }

    private func deleteThreads(at offsets: IndexSet) {
        withAnimation(.easeInOut) {
            for index in offsets {
                modelContext.delete(chatThreads[index])
            }
            save()
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ChatHistoryView(onSelect: { _ in })
    }
    .environment(RemoveAdsStore())
    .modelContainer(for: [ChatThread.self, ChatMessage.self], inMemory: true)
}
