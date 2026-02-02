//
//  PromptHistoryDetailView.swift
//  Written
//
//  Created by Filippo Cilia on 28/01/2026.
//

import SwiftUI

struct PromptHistoryDetailView: View {
    let history: HistoryModel

    @State private var isPromptExpanded = false
    @State private var isResponseExpanded = false

    private let previewLineLimit = 3

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

                    VStack(alignment: .trailing, spacing: 8) {
                        Text(history.prompt)
                            .bold()
                            .lineLimit(isPromptExpanded ? nil : previewLineLimit)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        if history.prompt.count > 150 {
                            ShowMoreLessButtonView(isExpanded: $isPromptExpanded) {
                                isPromptExpanded.toggle()
                            }
                        }
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .trailing
                )
                .padding([.bottom, .leading])

                VStack(alignment: .leading) {
                    Text("The response you received:")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(history.response)
                            .lineLimit(isResponseExpanded ? nil : previewLineLimit)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if history.response.count > 150 {
                            ShowMoreLessButtonView(isExpanded: $isResponseExpanded) {
                                isResponseExpanded.toggle()
                            }
                        }
                    }
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
