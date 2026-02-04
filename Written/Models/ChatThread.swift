//
//  ChatThread.swift
//  Written
//
//  Created by Filippo Cilia on 04/02/2026.
//

import Foundation

struct ChatThread: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    let title: String
    var messages: [ChatMessage]
    var creationDate = Date()
    var lastUpdated = Date()
}

extension ChatThread {
    static let sampleThreads: [ChatThread] = [
        ChatThread(
            title: "Daily reflection",
            messages: [
                ChatMessage(content: "How do I build a consistent journaling habit?", isUser: true),
                ChatMessage(content: "Start small with a daily two-minute ritual and a fixed trigger.", isUser: false)
            ]
        ),
        ChatThread(
            title: "Creative block",
            messages: [
                ChatMessage(content: "I feel stuck. Any prompts to kickstart writing?", isUser: true),
                ChatMessage(content: "Try a constraint: write a scene using only sensory details.", isUser: false)
            ]
        )
    ]
}
