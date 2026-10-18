//
//  ChatHistoryRowView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 06/02/2026.
//

import SwiftUI

struct ChatHistoryRowView: View {
    let thread: ChatThread

    private var firstUserPrompt: String {
        thread.messages.first(where: \.isUser)?.content ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            Text(thread.title)
                .bold()

            Text(firstUserPrompt)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(.background.secondary)
        .clipShape(.rect(cornerRadius: DesignConstants.CornerRadius.card))
        .contentShape(.rect)
        .padding(.bottom)
        .overlay(alignment: .bottomTrailing) {
            Text(thread.lastUpdated, format: .dateTime.day().month(.twoDigits).year(.twoDigits).hour().minute())
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }
}

#Preview {
    if let thread = ChatThread.sampleThreads.first {
        ChatHistoryRowView(thread: thread)
    }
}
