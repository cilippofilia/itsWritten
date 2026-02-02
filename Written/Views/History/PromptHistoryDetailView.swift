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

                VStack(alignment: .trailing, spacing: 8) {
                    Text(history.prompt)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue.gradient)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 18))
                        .containerRelativeFrame(.horizontal, alignment: .trailing) { size, axis in
                            size * 0.85
                        }
                        .lineLimit(isPromptExpanded ? nil : previewLineLimit)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    if history.prompt.count > 120 {
                        Button {
                            withAnimation {
                                isPromptExpanded.toggle()
                            }
                        } label: {
                            Text(isPromptExpanded ? "Show less" : "Show more")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(history.response)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.gray.gradient.opacity(0.3))
                        .foregroundStyle(.primary)
                        .clipShape(.rect(cornerRadius: 18))
                        .containerRelativeFrame(.horizontal, alignment: .leading) { size, axis in
                            size * 0.85
                        }
                        .lineLimit(isResponseExpanded ? nil : previewLineLimit)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if history.response.count > 150 {
                        Button {
                            withAnimation {
                                isResponseExpanded.toggle()
                            }
                        } label: {
                            Text(isResponseExpanded ? "Show less" : "Show more")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    PromptHistoryDetailView(history: .historyExamples.first!)
}
