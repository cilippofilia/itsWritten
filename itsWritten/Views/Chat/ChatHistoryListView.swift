//
//  ChatHistoryListView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// The list of saved threads, with swipe-to-delete.
@available(iOS 26.0, *)
struct ChatHistoryListView: View {
    let threads: [ChatThread]
    let onSelect: (ChatThread) -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        List {
            ForEach(threads) { thread in
                Button {
                    onSelect(thread)
                } label: {
                    ChatHistoryRowView(thread: thread)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 4, leading: 8, bottom: 4, trailing: 8))
                .listRowBackground(Color.clear)
            }
            .onDelete(perform: onDelete)
        }
        .listStyle(.plain)
    }
}

@available(iOS 26.0, *)
#Preview {
    ChatHistoryListView(threads: ChatThread.sampleThreads, onSelect: { _ in }, onDelete: { _ in })
}
