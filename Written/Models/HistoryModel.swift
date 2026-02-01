//
//  HistoryModel.swift
//  Written
//
//  Created by Filippo Cilia on 28/01/2026.
//

import Foundation

struct HistoryModel: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    let prompt: String
    let response: String
    var creationDate = Date()

    static let historyExamples: [HistoryModel] = [
        HistoryModel(
            prompt: "What is the meaning of life?",
            response: loremIpsum
        ),
        HistoryModel(
            prompt: "What do we do when we get cornered? Why life seems so routine that I am forced to think that escaping is the only option?",
            response: loremIpsum
        ),
        HistoryModel(
            prompt: "Why do I feel like I need to like you? What could be wrong with me?",
            response: loremIpsum
        ),
        HistoryModel(
            prompt: "Not sure what this prompt is? Probably I need to write a prompt long enough to cover 3 lines and see what happens after that. This prompt might be it. I also need to duplicate these prompts so I can see a longer list of them.",
            response: loremIpsum
        ),
        HistoryModel(
            prompt: "How can I overcome procrastination and actually start working on my goals?",
            response: loremIpsum
        ),
        HistoryModel(
            prompt: "I've been feeling disconnected from my friends lately. Is this normal as we get older?",
            response: loremIpsum
        ),
        HistoryModel(
            prompt: "What's the best way to deal with imposter syndrome at work?",
            response: loremIpsum
        ),
        HistoryModel(
            prompt: "Sometimes I wonder if I'm living the life I actually want or just the life everyone expects me to live. How do I figure this out?",
            response: loremIpsum
        ),
        HistoryModel(
            prompt: "Why is it so hard to break bad habits even when I know they're hurting me?",
            response: loremIpsum
        ),
        HistoryModel(
            prompt: "I feel stuck in my career but scared to make a change. How do you know when it's time to take a leap?",
            response: loremIpsum
        )
    ]
}
