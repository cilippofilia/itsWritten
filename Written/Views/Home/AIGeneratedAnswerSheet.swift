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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.vertical)
        }
    }
}

#Preview {
    AIGeneratedAnswerSheet(answer: loremIpsum)
        .environment(HomeViewModel())
}
