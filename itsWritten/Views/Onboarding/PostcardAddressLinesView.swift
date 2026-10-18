//
//  PostcardAddressLinesView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// The empty ruled lines on a postcard's address side.
@available(iOS 26.0, *)
struct PostcardAddressLinesView: View {
    var body: some View {
        VStack(spacing: DesignConstants.Spacing.large) {
            ForEach(0..<3, id: \.self) { _ in
                Rectangle()
                    .fill(.primary.opacity(0.15))
                    .frame(height: 1)
            }
        }
        .accessibilityHidden(true)
    }
}

@available(iOS 26.0, *)
#Preview {
    PostcardAddressLinesView()
        .frame(width: 84)
        .padding()
}
