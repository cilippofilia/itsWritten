//
//  PromptHistoryDetailView.swift
//  Written
//
//  Created by Filippo Cilia on 28/01/2026.
//

import SwiftUI

struct PromptHistoryDetailView: View {
    let history: HistoryModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // TODO: summarize prompt with AI
                Text("Prompt \(history.id) Summary")
                    .font(.title)
                    .bold()
                    .padding(.bottom)

                VStack(alignment: .trailing) {
                    Text("You asked:")
                        .foregroundStyle(.secondary)
                    Text("\(history.prompt)")
                        .bold()
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .trailing
                )
                .padding([.bottom, .leading])

                VStack(alignment: .leading) {
                    Text("The response you received:")
                        .foregroundStyle(.secondary)
                    Text("\(history.response)")
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding([.bottom, .trailing])
            }
            .padding()

            Spacer().frame(height: 120)
        }
    }
}

#Preview {
    PromptHistoryDetailView(history: .historyExamples.first!)
}
