//
//  AIGeneratedAnswerSheet.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

struct AIGeneratedAnswerSheet: View {
    @Environment(HomeViewModel.self) private var viewModel

    let answer: String

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(.init(answer))
                .padding()
                .foregroundStyle(.primary)
                .scrollBounceBehavior(.basedOnSize)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .leading
                )
                .ignoresSafeArea()
                .padding(.vertical)
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
                .frame(height: 40)

                Rectangle()

                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
            }
        }
    }
}

#Preview {
    AIGeneratedAnswerSheet(answer: loremIpsum)
        .environment(HomeViewModel())
}
