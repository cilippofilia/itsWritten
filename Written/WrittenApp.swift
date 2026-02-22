//
//  WrittenApp.swift
//  Written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import SwiftUI
import SwiftData

@main
struct WrittenApp: App {
    var body: some Scene {
        WindowGroup {
            LaunchView()
        }
        .modelContainer(for: [ChatThread.self, ChatMessage.self])
    }
}
