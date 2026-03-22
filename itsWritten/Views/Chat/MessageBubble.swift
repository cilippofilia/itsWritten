//
//  MessageBubble.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/02/2026.
//

import SwiftUI

/// Displays a single chat message in a bubble style.
///
/// User messages appear with a blue background aligned to the trailing edge,
/// while AI responses appear with a gray background aligned to the leading edge.
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        let alignment = message.isUser ? Alignment.trailing : .leading

        FormattedMessageText(text: message.content)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(message.isUser ? Color.blue.gradient : Color.gray.opacity(0.2).gradient)
            .foregroundStyle(message.isUser ? Color.white : Color.primary)
            .clipShape(.rect(cornerRadius: 18))
            .containerRelativeFrame(.horizontal, alignment: alignment) { size, axis in
                size * 0.75
            }
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

#Preview("User message - Light") {
    MessageBubble(message: ChatMessage(content: "This is my message as a response to the previous one.", isUser: true))
}
#Preview("AI response - Light") {
    MessageBubble(message: ChatMessage(content: "This is my message as a response to the previous one.", isUser: false))
}
#Preview("User message - Dark") {
    MessageBubble(message: ChatMessage(content: "This is my message as a response to the previous one.", isUser: true))
        .preferredColorScheme(.dark)
}
#Preview("AI response - Dark") {
    MessageBubble(message: ChatMessage(content: "This is my message as a response to the previous one.This is my message as a response to the previous one.This is my message as a response to the previous one.This is my message as a response to the previous one.This is my message as a response to the previous one.This is my message as a response to the previous one.This is my message as a response to the previous one.This is my message as a response to the previous one.", isUser: false))
        .preferredColorScheme(.dark)
}
