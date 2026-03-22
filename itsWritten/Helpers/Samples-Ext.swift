//
//  Samples-Ext.swift
//  itsWritten
//
//  Created by Filippo Cilia on 06/02/2026.
//

import Foundation

// MARK: Chat thread samples
extension ChatThread {
    static let sampleThreads: [ChatThread] = [
        ChatThread(
            title: "Morning pages and a gentle start to the day",
            messages: [
                ChatMessage(content: "What should I write in morning pages?", isUser: true),
                ChatMessage(content: "Write whatever is on your mind without editing. Three pages of stream-of-consciousness is the classic approach.", isUser: false),
                ChatMessage(content: "What if I only have five minutes?", isUser: true),
                ChatMessage(content: "Do a single paragraph: how you feel, one intention, one worry. Done.", isUser: false)
            ]
        ),
        ChatThread(
            title: "Daily reflection",
            messages: [
                ChatMessage(content: "How do I build a consistent journaling habit?", isUser: true),
                ChatMessage(content: "Start small with a daily two-minute ritual and a fixed trigger.", isUser: false)
            ]
        ),
        ChatThread(
            title: "Gratitude practice for evenings when I am low energy",
            messages: [
                ChatMessage(content: "Give me a simple gratitude prompt for tonight.", isUser: true),
                ChatMessage(content: "List three small moments from today that felt good, and why they mattered.", isUser: false),
                ChatMessage(content: "Any way to keep it short?", isUser: true),
                ChatMessage(content: "Use the 1-1-1 rule: one person, one place, one tiny win.", isUser: false)
            ]
        ),
        ChatThread(
            title: "Creative block",
            messages: [
                ChatMessage(content: "I feel stuck. Any prompts to kickstart writing?", isUser: true),
                ChatMessage(content: "Try a constraint: write a scene using only sensory details.", isUser: false),
                ChatMessage(content: "Give me two more constraints.", isUser: true),
                ChatMessage(content: "Write in present tense only, and ban the word \"think\".", isUser: false)
            ]
        ),
        ChatThread(
            title: "Short story idea for a quiet, character-driven scene",
            messages: [
                ChatMessage(content: "Can you give me a short story prompt?", isUser: true),
                ChatMessage(content: "A person discovers a voicemail from themselves dated ten years in the future.", isUser: false),
                ChatMessage(content: "Give me a softer version.", isUser: true),
                ChatMessage(content: "Two old friends meet by accident on the last day a small bookstore is open.", isUser: false),
                ChatMessage(content: "And one more with a twist?", isUser: true),
                ChatMessage(content: "The bookstore is in their childhood town, but neither of them remembers living there.", isUser: false)
            ]
        ),
        ChatThread(
            title: "Focus reset",
            messages: [
                ChatMessage(content: "I keep drifting while writing. How do I reset focus?", isUser: true),
                ChatMessage(content: "Use a 5-minute timer, remove all tabs, and write one rough paragraph without stopping.", isUser: false)
            ]
        ),
        ChatThread(
            title: "Dialogue practice",
            messages: [
                ChatMessage(content: "Help me practice dialogue.", isUser: true),
                ChatMessage(content: "Write a conversation between two people who want the same thing but for opposite reasons.", isUser: false)
            ]
        ),
        ChatThread(
            title: "Tone shift from calm to tense without changing the setting",
            messages: [
                ChatMessage(content: "How do I make a scene feel tense?", isUser: true),
                ChatMessage(content: "Shorten sentences, narrow the focus to concrete details, and let silence carry weight.", isUser: false),
                ChatMessage(content: "Any tip on pacing?", isUser: true),
                ChatMessage(content: "Interrupt actions with tiny delays, then compress time once the stakes are clear.", isUser: false)
            ]
        ),
        ChatThread(
            title: "Outline help",
            messages: [
                ChatMessage(content: "I have a topic but no structure. How do I outline quickly?", isUser: true),
                ChatMessage(content: "Write a one-sentence thesis, then three supporting points, then one example each.", isUser: false)
            ]
        ),
        ChatThread(
            title: "Dream log",
            messages: [
                ChatMessage(content: "I want to start a dream journal. Any tips?", isUser: true),
                ChatMessage(content: "Keep a notebook by the bed, write immediately on waking, and note emotions first.", isUser: false)
            ]
        ),
        ChatThread(
            title: "Writer's block on a late chapter with too many loose threads",
            messages: [
                ChatMessage(content: "I'm blocked on this chapter. What's a quick unblocker?", isUser: true),
                ChatMessage(content: "Rewrite the scene from a different character's POV for 10 minutes, no pressure to keep it.", isUser: false),
                ChatMessage(content: "What if I still feel stuck after that?", isUser: true),
                ChatMessage(content: "Write a bad version that only tracks plot beats. Then clean it up.", isUser: false)
            ]
        )
    ]
}
