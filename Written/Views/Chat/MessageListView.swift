//
//  MessageListView.swift
//  Written
//
//  Created by Filippo Cilia on 03/02/2026.
//

import SwiftUI

/// Displays the scrollable list of chat messages with automatic scrolling.
///
/// This view automatically scrolls to show new messages and displays a typing
/// indicator when the AI is generating a response.
struct MessageListView: View {
    /// The array of chat messages to display.
    let messages: [ChatMessage]

    /// Whether the AI is currently generating a response.
    let isResponding: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if isResponding {
                        TypingIndicator()
                            .id("typing")
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .onChange(of: messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: messages.last?.content) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isResponding) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    /// Scrolls the view to show the most recent content.
    /// - Parameter proxy: The scroll view proxy used to perform the scroll.
    func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if isResponding {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let lastMessage = messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

#Preview {
    MessageListView(messages: [], isResponding: false)
}
