//
//  RedactionReviewSheet.swift
//  itsWritten
//

import SwiftUI

/// Asks before a message goes to a third-party vendor, and shows what will be
/// hidden. Tapping a highlighted word switches it between hidden and sent as is.
@available(iOS 26.0, *)
struct RedactionReviewSheet: View {
    let request: ConsentRequest
    let review: RedactionReview
    let coordinator: CloudConsentCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Text(CloudConsentMessage.text(for: request.destination))
                    if review.hasEntities {
                        Text(CloudConsentMessage.redactionHint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    RedactionMessagePreview(review: review)
                        .padding(.vertical)

                    Text(CloudConsentMessage.receivesLabel(for: request.destination))
                        .font(.subheadline)
                        .bold()
                    Text(review.sentText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle(CloudConsentMessage.title(for: request.destination))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                RedactionReviewButtons(requestID: request.id, coordinator: coordinator)
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            guard let entityID = RedactionPreviewFormatter.entityID(from: url) else { return .discarded }
            coordinator.toggleReveal(entityID, in: request.id)
            return .handled
        })
        .presentationDetents([.medium, .large])
    }
}
