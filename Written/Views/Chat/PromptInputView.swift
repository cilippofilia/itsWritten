//
//  PromptInputView.swift
//  Written
//
//  Created by Filippo Cilia on 03/02/2026.
//

import SwiftUI

/// A reusable input field for entering prompts with a send button.
///
/// This view provides a text field with automatic vertical expansion and a circular
/// send button that becomes disabled when the input is empty or the view is disabled.
struct PromptInputView: View {
    @Binding var text: String

    let placeholder: String
    let isDisabled: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(.rect(cornerRadius: 20))
                .lineLimit(1...5)
                .onSubmit(onSubmit)

            Button("Send", systemImage: "arrow.up.circle.fill", action: onSubmit)
                .imageScale(.large)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .blue.gradient)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .font(.title)
                .disabled(text.isReallyEmpty || isDisabled)
        }
        .padding()
        .background(Color.clear)
    }
}

#Preview("Dark") {
    PromptInputView(text: .constant("Txt"), placeholder: "Placeholder", isDisabled: false, onSubmit: { })
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    PromptInputView(text: .constant("Txt"), placeholder: "Placeholder", isDisabled: false, onSubmit: { })
}
