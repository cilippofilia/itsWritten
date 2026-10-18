//
//  RedactionReviewButtons.swift
//  itsWritten
//

import SwiftUI

/// Send and Keep on Device.
@available(iOS 26.0, *)
struct RedactionReviewButtons: View {
    let requestID: ConsentRequest.ID
    let coordinator: CloudConsentCoordinator

    var body: some View {
        VStack {
            Button {
                coordinator.respond(to: requestID, allow: true)
            } label: {
                Text("Send")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                coordinator.respond(to: requestID, allow: false)
            } label: {
                Text("Keep on Device")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .padding()
        .background(.bar)
    }
}
