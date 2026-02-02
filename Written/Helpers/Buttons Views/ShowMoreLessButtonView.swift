//
//  ShowMoreLessButtonView.swift
//  Written
//
//  Created by Filippo Cilia on 02/02/2026.
//

import SwiftUI

struct ShowMoreLessButtonView: View {
    @Binding var isExpanded: Bool

    let action: ActionVoid

    var body: some View {
        Button {
            withAnimation {
                action()
            }
        } label: {
            Text(isExpanded ? "Show less" : "Show more")
                .font(.caption)
                .foregroundStyle(.blue)
        }
    }
}

#Preview {
    ShowMoreLessButtonView(
        isExpanded: .constant(true),
        action: {
        })
}
