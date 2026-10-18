//
//  ChatConversationView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 09/08/2026.
//

import SwiftUI

@available(iOS 26.0, *)
struct ChatConversationView: View {
    @Environment(ConversationViewModel.self) private var viewModel
    @Environment(HomeViewModel.self) private var homeViewModel
    @Environment(NewChatTransition.self) private var newChatTransition

    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType

    @State private var input = ""

    var body: some View {
        MessageListView(
            messages: viewModel.messages,
            isResponding: viewModel.isResponding
        )
        // The new-chat letter starts exactly where the messages are.
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            newChatTransition.sourceGlobalFrame = frame
        }
        .safeAreaInset(edge: .bottom) {
            PromptInputView(
                text: $input,
                placeholder: homeViewModel.placeholderText,
                isDisabled: viewModel.isResponding,
                onSubmit: sendMessage
            )
        }
        #if !DEBUG
        .hideSensitiveData()
        #endif
        .navigationTitle(viewModel.title)
    }

    private func sendMessage() {
        guard input.isReallyEmpty == false else { return }
        let prompt = input
        input = ""
        viewModel.sendMessage(prompt, config: config, responseType: responseType)
    }
}

@available(iOS 26.0, *)
#Preview {
    NavigationStack {
        ChatConversationView(
            config: .constant(ModelConfiguration()),
            responseType: .constant(.standard)
        )
    }
    .environment(ConversationViewModel())
    .environment(HomeViewModel())
    .environment(NewChatTransition())
}
