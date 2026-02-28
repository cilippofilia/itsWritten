//
//  ChatBubbleModifier.swift
//  Written
//
//  Created by Filippo Cilia on 02/02/2026.
//

import SwiftUI

struct ChatBubbleModifier: ViewModifier {
    let alignment: HorizontalAlignment
    let backgroundColor: AnyShapeStyle
    let foregroundColor: Color
    let widthMultiplier: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(.rect(cornerRadius: 18))
            .containerRelativeFrame(.horizontal, alignment: alignment == .leading ? .leading : .trailing) { size, axis in
                size * widthMultiplier
            }
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

extension View {
    func chatBubble(
        alignment: HorizontalAlignment = .leading,
        backgroundColor: AnyShapeStyle = AnyShapeStyle(Color.gray.gradient.opacity(0.3)),
        foregroundColor: Color = .primary,
        widthMultiplier: CGFloat = 0.85
    ) -> some View {
        modifier(ChatBubbleModifier(
            alignment: alignment,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            widthMultiplier: widthMultiplier
        ))
    }

    func promptBubble() -> some View {
        chatBubble(
            alignment: .trailing,
            backgroundColor: AnyShapeStyle(Color.blue.gradient),
            foregroundColor: .white
        )
    }

    func responseBubble() -> some View {
        chatBubble(
            alignment: .leading,
            backgroundColor: AnyShapeStyle(Color.gray.gradient.opacity(0.3)),
            foregroundColor: .primary
        )
    }
}
