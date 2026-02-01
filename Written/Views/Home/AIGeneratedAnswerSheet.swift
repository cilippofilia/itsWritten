//
//  AIGeneratedAnswerSheet.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

struct AIGeneratedAnswerSheet: View {
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let answer: String

    var body: some View {
        NavigationStack {
            AIGeneratedAnswerView(answer: answer)
                .background(.ultraThinMaterial)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done", systemImage: "xmark") {
                            dismiss()
                        }
                    }
                }
                .onDisappear {
                    viewModel.session = nil
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    AIGeneratedAnswerSheet(answer: loremIpsum)
        .environment(HomeViewModel())
}
