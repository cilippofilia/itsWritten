//
//  RemoveAdsBadge.swift
//  itsWritten
//

import SwiftUI

/// Decorative "no ads" badge shown at the top of the Remove Ads paywall. It scales with
/// Dynamic Type and is hidden from VoiceOver because the paywall title already says
/// "Remove Ads".
struct RemoveAdsBadge: View {
    var body: some View {
        ZStack {
            Text("Ads")
                .foregroundStyle(.black)
            Image(systemName: "nosign")
                .font(.largeTitle.scaled(by: 1.3))
                .foregroundStyle(.red)
        }
        .background {
            Rectangle().fill(.white)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    RemoveAdsBadge()
}
