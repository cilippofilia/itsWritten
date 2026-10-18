//
//  LetterMessagesView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// The letter's message bubbles, laid out like `MessageListView`.
@available(iOS 26.0, *)
struct LetterMessagesView: View {
    let messages: [ChatMessage]

    var body: some View {
        VStack(spacing: DesignConstants.Spacing.small) {
            ForEach(messages) { message in
                MessageBubble(message: message)
            }
        }
        .padding()
        .readableContentWidth()
    }
}
