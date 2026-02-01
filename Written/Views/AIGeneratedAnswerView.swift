//
//  AIGeneratedAnswerView.swift
//  written
//
//  Created by Filippo Cilia on 05/01/2026.
//

import SwiftUI

struct AIGeneratedAnswerView: View {
    let answer: String

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(answer)
                .padding()
                .padding(.vertical, 50)
                .foregroundStyle(.primary)
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    AIGeneratedAnswerView(answer: loremIpsum)
}
