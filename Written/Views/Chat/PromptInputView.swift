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
    /// The text entered by the user.
    @Binding var text: String

    /// The placeholder text displayed when the field is empty.
    let placeholder: String

    /// Whether the input should be disabled.
    let isDisabled: Bool

    /// The action to perform when the user submits the input.
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
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .font(.title)
                .disabled(text.isReallyEmpty || isDisabled)
                .foregroundStyle(text.isReallyEmpty || isDisabled ? .secondary : Color.accentColor)
        }
    }
}

#Preview {
    PromptInputView(text: .constant("Txt"), placeholder: "Placeholder", isDisabled: false, onSubmit: { })
}
