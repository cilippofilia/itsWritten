//
//  LetterHeaderView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// The conversation title at the top of the letter, placed where the screen shows it.
@available(iOS 26.0, *)
struct LetterHeaderView: View {
    let title: String
    let alignment: HorizontalAlignment

    var body: some View {
        Text(title)
            .font(.headline)
            .lineLimit(1)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }
}

@available(iOS 26.0, *)
#Preview {
    LetterHeaderView(title: "Morning pages", alignment: .center)
        .frame(height: 54)
}
