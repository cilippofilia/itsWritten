//
//  PaperBackView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// The blank reverse side of the letter, seen once a flap has folded over.
@available(iOS 26.0, *)
struct PaperBackView: View {
    var body: some View {
        Rectangle()
            .fill(.background.secondary)
            .overlay {
                Rectangle()
                    .strokeBorder(.primary.opacity(0.3), lineWidth: 1)
            }
    }
}

@available(iOS 26.0, *)
#Preview {
    PaperBackView()
        .frame(width: 300, height: 120)
}
