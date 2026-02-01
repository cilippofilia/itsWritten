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
                    .font(.title2)
                    .bold()
                    .padding(.vertical)

                VStack(alignment: .trailing) {
                    Text("You asked:")
                        .foregroundStyle(.secondary)
                    Text(history.prompt)
                        .bold()
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .trailing
                )
                .padding([.bottom, .leading])

                VStack(alignment: .leading) {
                    Text("The response:")
                        .foregroundStyle(.secondary)
                    Text(.init(history.response))
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(.trailing)
            }
            .padding()
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
    PromptHistoryDetailView(history: .historyExamples.first!)
}
