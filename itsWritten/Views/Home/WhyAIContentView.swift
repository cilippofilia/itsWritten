//
//  WhyAIContentView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/11/2025.
//

import SwiftUI

/// The "Why AI?" explanation itself, shown by `WhyAIView`.
@available(iOS 26.0, *)
struct WhyAIContentView: View {
    private let appleIntelligenceURL = URL(string: "https://www.apple.com/apple-intelligence/")

    // The blank first and last lines space the analogy out from the title and explanation.
    private let analogy = """

    Think of most AI services like mailing a letter - once you send it, the post office has a copy \
    and can read it. Apple's AI is like whispering to yourself (on-device) or using a secure vault \
    that destroys the contents immediately after reading it to you (Private Cloud Compute). \
    Not even Apple keeps a copy.

    """

    private let explanation = """
    This makes Apple's foundation model uniquely privacy-focused compared to competitors who \
    typically retain and may use your data for model training or other purposes.
    """

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Why using ")

                Image(systemName: "apple.intelligence")
                    .symbolRenderingMode(.multicolor)
                    .accessibilityHidden(true)

                if let appleIntelligenceURL {
                    Link("Apple Intelligence", destination: appleIntelligenceURL)
                        .tint(.primary)
                        .bold()
                        .underline(true, color: .secondary)
                }

                Text("?")
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text(analogy)
            Text(explanation)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .readableContentWidth()
    }
}
