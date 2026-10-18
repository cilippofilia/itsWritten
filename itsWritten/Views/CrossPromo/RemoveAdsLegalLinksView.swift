//
//  RemoveAdsLegalLinksView.swift
//  itsWritten
//

import SwiftUI

/// Terms of Use and Privacy Policy links, separated by a bullet.
struct RemoveAdsLegalLinksView: View {
    var body: some View {
        HStack(spacing: 6) {
            Link("Terms of Use", destination: RemoveAdsLegalLinks.termsOfUse)
            LegalSeparator()
            Link("Privacy Policy", destination: RemoveAdsLegalLinks.privacyPolicy)
        }
    }
}

#Preview {
    RemoveAdsLegalLinksView()
}
