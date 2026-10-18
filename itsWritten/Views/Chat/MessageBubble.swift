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
/// Bubbles take up to three quarters of the container in narrow windows and are
/// capped in wide windows so lines stay readable.
@available(iOS 26.0, *)
struct MessageBubble: View {
    @State private var discloseToolsUsed: Bool = false

    let message: ChatMessage

    private var showsToolDisclosure: Bool {
        message.isUser == false && (message.toolNames.isEmpty == false || message.toolSources.isEmpty == false)
    }

    var body: some View {
        let frameAlignment = message.isUser ? Alignment.trailing : .leading
        let contentAlignment = message.isUser ? HorizontalAlignment.trailing : .leading

        VStack(alignment: contentAlignment, spacing: 6) {
            FormattedMessageText(text: message.content)
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .background(message.isUser ? Color.blue.gradient : Color.gray.opacity(0.2).gradient)
                .foregroundStyle(message.isUser ? Color.white : Color.primary)
                .clipShape(.rect(cornerRadius: DesignConstants.CornerRadius.bubble))

            if message.isUser == false, let providerName = message.providerName {
                Text("Answered by \(providerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showsToolDisclosure {
                Button(action: toggleToolsDisclosure) {
                    Label {
                        Text("Tools used")
                    } icon: {
                        Image(systemName: "chevron.forward")
                            .imageScale(.small)
                            .rotationEffect(.degrees(discloseToolsUsed ? 90 : 0), anchor: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .font(.footnote)
                .accessibilityValue(discloseToolsUsed ? "Expanded" : "Collapsed")

                if discloseToolsUsed {
                    VStack(alignment: .leading, spacing: 8) {
                        if message.toolNames.isEmpty == false {
                            Text(message.toolNames.formatted())
                                .font(.footnote)
                                .bold()
                        }

                        ForEach(message.toolSources) { source in
                            ToolSourceRow(source: source)
                        }
                    }
                }
            }
        }
        .containerRelativeFrame(.horizontal, alignment: frameAlignment) { size, _ in
            min(size * DesignConstants.Width.chatBubbleFraction, DesignConstants.Width.chatBubble)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private func toggleToolsDisclosure() {
        discloseToolsUsed.toggle()
    }
}

@available(iOS 26.0, *)
#Preview("User message - Light") {
    MessageBubble(message: ChatMessage(content: "This is my message as a response to the previous one.", isUser: true))
}
@available(iOS 26.0, *)
#Preview("AI response - Light") {
    MessageBubble(message: ChatMessage(content: "This is my message as a response to the previous one.", isUser: false))
}
@available(iOS 26.0, *)
#Preview("User message - Dark") {
    MessageBubble(message: ChatMessage(content: "This is my message as a response to the previous one.", isUser: true))
        .preferredColorScheme(.dark)
}
@available(iOS 26.0, *)
#Preview("AI response - Dark") {
    MessageBubble(
        message: ChatMessage(
            content: String(repeating: "This is my message as a response to the previous one. ", count: 8),
            isUser: false,
            toolNames: ["PubMed"],
            toolSources: [
                ChatMessageSource(
                    title: "Sleep Quality and Adolescents",
                    pmid: "12345678",
                    url: "https://pubmed.ncbi.nlm.nih.gov/12345678/"
                )
            ]
        )
    )
    .preferredColorScheme(.dark)
}
