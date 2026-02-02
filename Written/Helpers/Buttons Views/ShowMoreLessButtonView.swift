//
//  ShowMoreLessButtonView.swift
//  Written
//
//  Created by Filippo Cilia on 02/02/2026.
//

import SwiftUI

struct ShowMoreLessButtonView: View {
    @Binding var isPromptExpanded: Bool

    var body: some View {
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

#Preview {
    ShowMoreLessButtonView(isPromptExpanded: .constant(true))
}
