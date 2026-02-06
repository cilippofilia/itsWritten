//
//  ChatThread.swift
//  Written
//
//  Created by Filippo Cilia on 04/02/2026.
//

import Foundation
import SwiftData

@Model
final class ChatThread: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    @Relationship(deleteRule: .cascade) var messages: [ChatMessage]
    var creationDate: Date
    var lastUpdated: Date

    init(
        id: UUID = UUID(),
        title: String,
        messages: [ChatMessage],
        creationDate: Date = .now,
        lastUpdated: Date = .now
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.creationDate = creationDate
        self.lastUpdated = lastUpdated
    }
}
