//
//  ChatSheet.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

struct ChatSheet: View {
    @Environment(HomeViewModel.self) private var viewModel

    let title: String
    let prompt: String
    let answer: String

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ChatDetailView(
                history: ChatModel(
                    title: title,
                    prompt: prompt,
                    response: answer
                )
            )
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .mask {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 30)

                Rectangle()

                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 30)
            }
        }
    }
}

#Preview {
    ChatSheet(title: "Test title a bit long", prompt: "test prompt?", answer: loremIpsum)
        .environment(HomeViewModel())
}
