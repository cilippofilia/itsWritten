//
//  CloudConsentAlertModifier.swift
//  itsWritten
//

import SwiftUI

/// Presents the coordinator's pending cloud-consent prompt as an alert.
///
/// Every answer goes through `respond(to:allow:)` with the id of the request the alert
/// was presented for, so a stale alert can never answer a newer prompt.
@available(iOS 26.0, *)
struct CloudConsentAlertModifier: ViewModifier {
    let coordinator: CloudConsentCoordinator

    func body(content: Content) -> some View {
        content
            .background {
                CloudConsentAlertHost(coordinator: coordinator, request: coordinator.pendingRequest)
                    // The coordinator can publish the next prompt without `pendingRequest`
                    // ever becoming nil, so key the host on the request to re-present.
                    // Keyed on a background host so the modified content keeps its state.
                    .id(coordinator.pendingRequest?.id)
            }
    }
}

/// Hosts the alert for one specific request.
@available(iOS 26.0, *)
private struct CloudConsentAlertHost: View {
    let coordinator: CloudConsentCoordinator
    let request: ConsentRequest?

    var body: some View {
        Color.clear
            .alert(
                request.map { "Send to \($0.destination.displayName)?" } ?? "",
                isPresented: isPresented,
                presenting: request
            ) { request in
                Button("Send") {
                    coordinator.respond(to: request.id, allow: true)
                }
                Button("Keep on Device", role: .cancel) {
                    coordinator.respond(to: request.id, allow: false)
                }
            } message: { request in
                Text(CloudConsentMessage.text(for: request.destination))
            }
    }

    /// A dismissal without a button counts as a denial of this host's own request.
    private var isPresented: Binding<Bool> {
        let presentedID = request?.id
        return Binding(
            get: { coordinator.pendingRequest != nil && coordinator.pendingRequest?.id == presentedID },
            set: { newValue in
                guard !newValue, let presentedID else { return }
                coordinator.respond(to: presentedID, allow: false)
            }
        )
    }
}

@available(iOS 26.0, *)
extension View {
    /// Shows the cloud-consent prompt published by `coordinator`.
    func cloudConsentAlert(_ coordinator: CloudConsentCoordinator) -> some View {
        modifier(CloudConsentAlertModifier(coordinator: coordinator))
    }
}
