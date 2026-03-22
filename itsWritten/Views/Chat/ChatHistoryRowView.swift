//
//  ChatHistoryRowView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 06/02/2026.
//

import SwiftUI

struct ChatHistoryRowView: View {
    let thread: ChatThread

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                Text(thread.title)
                    .bold()

                Text(firstUserPrompt(in: thread) ?? "")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 12, style: .continuous))
            .contentShape(.rect)
        }
        .padding(.bottom)
        .overlay(alignment: .bottomTrailing) {
            HStack {
                Spacer()
                Text(thread.lastUpdated, formatter: Self.timestampFormatter)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy '@' HH:mm"
        return formatter
    }()

    private func firstUserPrompt(in thread: ChatThread) -> String? {
        thread.messages.first(where: { $0.isUser })?.content
    }
}

#Preview {
    ChatHistoryRowView(thread: .sampleThreads.first!)
}
