//
//  TimerControlButton.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// A round glass control for the running timer. Shows only its symbol, but keeps its
/// title for VoiceOver and Voice Control.
struct TimerControlButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .padding()
                .frame(minWidth: 50, minHeight: 50)
                .foregroundStyle(.primary)
                .glassEffect(.regular.interactive())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TimerControlButton(title: "Pause Timer", systemImage: "pause.circle", action: {})
}
