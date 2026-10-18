//
//  AppleIntelligenceLink.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// An underlined link to Apple's Apple Intelligence page.
struct AppleIntelligenceLink: View {
    let destination: URL

    var body: some View {
        Link("Apple Intelligence", destination: destination)
            .bold()
            .underline(true, pattern: .solid, color: .secondary)
    }
}

#Preview {
    if let url = URL(string: "https://www.apple.com/apple-intelligence/") {
        AppleIntelligenceLink(destination: url)
    }
}
