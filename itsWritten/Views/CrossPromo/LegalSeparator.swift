//
//  LegalSeparator.swift
//  itsWritten
//

import SwiftUI

/// The decorative bullet between legal footer items.
struct LegalSeparator: View {
    var body: some View {
        Text(verbatim: "•")
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

#Preview {
    LegalSeparator()
}
