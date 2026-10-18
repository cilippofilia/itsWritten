//
//  WhyAIView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/11/2025.
//

import SwiftUI

@available(iOS 26.0, *)
struct WhyAIView: View {
    private let appleIntelligenceURL = URL(string: "https://www.apple.com/apple-intelligence/")

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
        // Scrolls so the content stays reachable in short windows, such as a medium
        // detent on iPhone Duo's outer display or at large Dynamic Type sizes.
        ScrollView {
            VStack(spacing: DesignConstants.Spacing.medium) {
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
            .padding()
            .readableContentWidth()
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

@available(iOS 26.0, *)
#Preview {
    WhyAIView()
}
