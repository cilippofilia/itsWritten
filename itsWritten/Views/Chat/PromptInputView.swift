//
//  PromptInputView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/02/2026.
//

import SwiftUI

/// A reusable input field for entering prompts with a send button.
///
/// This view provides a text field with automatic vertical expansion and a circular
/// send button that becomes disabled when the input is empty or the view is disabled.
@available(iOS 26.0, *)
struct PromptInputView: View {
    @Binding var text: String

    let placeholder: String
    let isDisabled: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .onSubmit(onSubmit)

            Button("Send", systemImage: "arrow.up.circle.fill", action: onSubmit)
                .keyboardShortcut(.return, modifiers: .command)
                .imageScale(.large)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .blue.gradient)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .font(.title)
                .disabled(text.isReallyEmpty || isDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal)
        .padding(.vertical, DesignConstants.Spacing.small)
        .readableContentWidth()
    }
}

#if DEBUG
@available(iOS 26.0, *)
private struct PromptInputPreviewWrapper: View {
    @State private var text = "Txt"

    let colorScheme: ColorScheme?

    var body: some View {
        PromptInputView(
            text: $text,
            placeholder: "Placeholder",
            isDisabled: false,
            onSubmit: { }
        )
        .preferredColorScheme(colorScheme)
    }
}

@available(iOS 26.0, *)
#Preview("Dark") {
    PromptInputPreviewWrapper(colorScheme: .dark)
}

@available(iOS 26.0, *)
#Preview("Light") {
    PromptInputPreviewWrapper(colorScheme: .light)
}
#endif
