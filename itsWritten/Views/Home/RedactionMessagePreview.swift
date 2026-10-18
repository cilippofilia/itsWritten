//
//  RedactionMessagePreview.swift
//  itsWritten
//

import SwiftUI

/// The message with its details highlighted, and the details found only in
/// earlier messages.
@available(iOS 26.0, *)
struct RedactionMessagePreview: View {
    let review: RedactionReview

    var body: some View {
        VStack(alignment: .leading) {
            Text(RedactionPreviewFormatter.attributedText(for: review.segments))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                .accessibilityHint(CloudConsentMessage.toggleAccessibilityHint)

            if review.earlierEntities.isEmpty == false {
                Text(CloudConsentMessage.earlierLabel)
                    .font(.subheadline)
                    .bold()
                    .padding(.top)
                Text(RedactionPreviewFormatter.attributedList(of: review.earlierEntities))
                    .accessibilityHint(CloudConsentMessage.toggleAccessibilityHint)
            }
        }
    }
}
