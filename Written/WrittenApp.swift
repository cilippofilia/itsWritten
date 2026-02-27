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
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPrivacyShieldVisible = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                LaunchView()
                    .privacySensitive()

                if isPrivacyShieldVisible {
                    PrivacyShieldView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isPrivacyShieldVisible)
            .onChange(of: scenePhase) { _, newValue in
                isPrivacyShieldVisible = newValue != .active
            }
        }
        .modelContainer(for: [ChatThread.self, ChatMessage.self])
    }
}
