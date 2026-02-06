//
//  ChatModel.swift
//  Written
//
//  Created by Filippo Cilia on 28/01/2026.
//

import Foundation
import SwiftData

struct ChatModel: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    let title: String
    let prompt: String
    let response: String
    var creationDate = Date()
}

/// Represents a single message in a chat conversation.
@Model
final class ChatMessage: Identifiable {
    @Attribute(.unique) var id: UUID
    var content: String
    var isUser: Bool
    var timestamp: Date

    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = .now) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

/// The type of response generation to use.
enum ResponseType: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case streaming = "Streaming"
    case human = "Human"

    var id: Self { self }
}

extension ChatModel {
    static let chatExamples: [ChatModel] = [
        ChatModel(
            title: "Test",
            prompt: "What is the meaning of life?",
            response: loremIpsum
        ),
        ChatModel(
            title: "Test title A",
            prompt: "What do we do when we get cornered? Why life seems so routine that I am forced to think that escaping is the only option?",
            response: loremIpsum
        ),
        ChatModel(
            title: "Test title that should be long enough to wrap on two lines at least",
            prompt: "Why do I feel like I need to like you? What could be wrong with me?",
            response: loremIpsum
        ),
        ChatModel(
            title: "Test title not so long",
            prompt: "Not sure what this prompt is? Probably I need to write a prompt long enough to cover 3 lines and see what happens after that. This prompt might be it. I also need to duplicate these prompts so I can see a longer list of them.",
            response: loremIpsum
        ),
        ChatModel(
            title: "Another Test title",
            prompt: "How can I overcome procrastination and actually start working on my goals?",
            response: loremIpsum
        ),
        ChatModel(
            title: "Somthing a bit funky",
            prompt: "I've been feeling disconnected from my friends lately. Is this normal as we get older?",
            response: loremIpsum
        ),
        ChatModel(
            title: "Test title 3",
            prompt: "What's the best way to deal with imposter syndrome at work?",
            response: loremIpsum
        ),
        ChatModel(
            title: "The return of the test title",
            prompt: "Sometimes I wonder if I'm living the life I actually want or just the life everyone expects me to live. How do I figure this out?",
            response: loremIpsum
        ),
        ChatModel(
            title: "Test title strikes back",
            prompt: "Why is it so hard to break bad habits even when I know they're hurting me?",
            response: loremIpsum
        ),
        ChatModel(
            title: "Test title is not your father",
            prompt: "I feel stuck in my career but scared to make a change. How do you know when it's time to take a leap?",
            response: loremIpsum
        )
    ]
}
