//
//  MessageBubble.swift
//  Written
//
//  Created by Filippo Cilia on 03/02/2026.
//

import SwiftUI

/// Displays a single chat message in a bubble style.
///
/// User messages appear with a blue background aligned to the trailing edge,
/// while AI responses appear with a gray background aligned to the leading edge.
struct MessageBubble: View {
    /// The chat message to display.
    let message: ChatMessage

    var body: some View {
        let alignment = message.isUser ? Alignment.trailing : .leading

        FormattedMessageText(text: message.content)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(message.isUser ? Color.blue : .gray.opacity(0.2))
            .foregroundStyle(message.isUser ? .white : .primary)
            .clipShape(.rect(cornerRadius: 18))
            .containerRelativeFrame(.horizontal, alignment: alignment) { size, axis in
                size * 0.75
            }
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

#Preview {
    MessageBubble(message: ChatMessage(content: "", isUser: true))
}
