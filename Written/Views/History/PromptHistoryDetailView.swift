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
                Text("Prompt \(history.id) Summary")
                    .font(.title)
                    .bold()
                    .padding(.bottom)

                Text("\(history.prompt)")
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(.red)
                    .padding([.bottom, .leading])

                Text("\(history.response)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.blue)
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
