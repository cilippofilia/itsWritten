//
//  LetterPanelView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// One third of the letter: the full letter, clipped to its slice. Only the letter's outer
/// corners are rounded and only its outer edges outlined, so the flat letter reads as one
/// sheet, with an edge that stands out against dark backgrounds.
@available(iOS 26.0, *)
struct LetterPanelView: View {
    let face: LetterFace
    let size: CGSize
    let position: LetterPanelPosition
    let cornerRadius: Double

    /// 0 = no edge (matches the chat exactly); 1 = fully visible edge.
    let borderOpacity: Double

    private var clipShape: UnevenRoundedRectangle {
        let top = position == .top ? cornerRadius : 0
        let bottom = position == .bottom ? cornerRadius : 0
        return UnevenRoundedRectangle(
            topLeadingRadius: top,
            bottomLeadingRadius: bottom,
            bottomTrailingRadius: bottom,
            topTrailingRadius: top
        )
    }

    var body: some View {
        LetterContentView(face: face)
            .frame(width: size.width, height: size.height)
            .offset(y: -Double(position.rawValue) * size.height / 3)
            .frame(width: size.width, height: size.height / 3, alignment: .top)
            .clipShape(clipShape)
            .overlay {
                LetterPanelOutline(position: position, cornerRadius: cornerRadius)
                    .stroke(.primary.opacity(0.3 * borderOpacity), lineWidth: 1)
            }
    }
}
