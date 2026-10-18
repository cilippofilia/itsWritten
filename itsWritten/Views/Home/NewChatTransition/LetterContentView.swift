//
//  LetterContentView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// The front of the letter: the conversation title as a header, then the messages, on a
/// plain paper background.
///
/// Matches the screen it replaces so the swap is invisible: a short conversation sits at
/// the top, and a long one shows its latest messages anchored to the bottom.
@available(iOS 26.0, *)
struct LetterContentView: View {
    let face: LetterFace

    var body: some View {
        VStack(spacing: 0) {
            LetterHeaderView(title: face.title, alignment: face.headerAlignment)
                .frame(height: face.headerHeight)

            ViewThatFits(in: .vertical) {
                LetterMessagesView(messages: face.messages)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                LetterMessagesView(messages: face.messages)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .clipped()
        }
        .background(.background)
    }
}
