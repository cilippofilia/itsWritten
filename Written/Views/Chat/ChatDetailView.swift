//
//  ChatDetailView.swift
//  Written
//
//  Created by Filippo Cilia on 28/01/2026.
//

import SwiftUI

struct ChatDetailView: View {
    let history: ChatModel

    @State private var isPromptExpanded = false
    @State private var isResponseExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(history.title)
                    .font(.title)
                    .bold()
                    .padding(.bottom)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(history.prompt)
                        .lineLimit(isPromptExpanded ? nil : 3)
                        .promptBubble()

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
                        .lineLimit(isResponseExpanded ? nil : 6)
                        .responseBubble()

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
            .padding(.vertical)
        }
    }
}

#Preview {
    ChatDetailView(history: .chatExamples.first!)
}
