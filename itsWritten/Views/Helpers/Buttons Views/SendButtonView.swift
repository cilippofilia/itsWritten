//
//  SendButtonView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

@available(iOS 26.0, *)
struct SendButtonView: View {
    let isResponding: Bool
    let isInputEmpty: Bool
    let sendAction: () -> Void

    var body: some View {
        GlassEffectContainer {
            Button(action: sendAction) {
                Group {
                    if isResponding {
                        ProgressView()
                            .accessibilityLabel("Responding")
                    } else {
                        Label("Send", systemImage: "paperplane")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 55)
                .contentShape(.rect)
            }
            .keyboardShortcut(.return, modifiers: .command)
            .padding(.horizontal)
            .foregroundStyle(.white)
            .glassEffect(.regular.tint(isResponding || isInputEmpty ? .secondary : .blue).interactive())
            .animation(.easeInOut, value: isResponding)
            .animation(.easeInOut, value: isInputEmpty)
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    SendButtonView(isResponding: true, isInputEmpty: true, sendAction: { })
}
