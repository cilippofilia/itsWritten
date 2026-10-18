//
//  DebugFallbackSection.swift
//  itsWritten
//

#if DEBUG
import SwiftUI
import VoltaSDK

/// Debug only: forces fallback past the on-device model and shows what each
/// provider in the chain reports, e.g. whether PCC has its entitlement.
@available(iOS 26.0, *)
struct DebugFallbackSection: View {
    @Environment(AIProviderStore.self) private var aiProvider
    @State private var statuses: [ProviderStatus] = []

    var body: some View {
        @Bindable var aiProvider = aiProvider
        Section {
            Toggle("Simulate On-Device Unavailable", isOn: $aiProvider.simulatesOnDeviceUnavailable)
            ForEach(statuses) { status in
                LabeledContent(status.identifier.rawValue) {
                    switch status.availability {
                    case .available:
                        Text("Available")
                    case .unavailable(let reason):
                        Text(reason)
                    }
                }
            }
        } header: {
            Text("Debug")
        } footer: {
            Text("""
                Chat messages skip Apple Intelligence and fall back to Private Cloud Compute or a cloud key. \
                Guided reflection and other on-device-only features stop working while this is on.
                """)
        }
        .task(id: ObjectIdentifier(aiProvider.orchestrator)) {
            statuses = await aiProvider.orchestrator.providerStatuses()
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    Form {
        DebugFallbackSection()
    }
    .formStyle(.grouped)
    .environment(AIProviderStore())
}
#endif
