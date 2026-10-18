//
//  RemoveAdsLegalFooterView.swift
//  itsWritten
//

import SwiftUI

/// The Restore Purchase / Terms of Use / Privacy Policy row, pinned to the bottom of
/// `CrossPromoRemoveAdsInfoView` via `.safeAreaInset(edge: .bottom)` so it stays on screen
/// rather than scrolling away with the rest of the paywall.
///
/// Falls back to a stacked layout when the single row doesn't fit, such as in narrow
/// windows or at large Dynamic Type sizes, instead of shrinking the text.
struct RemoveAdsLegalFooterView: View {
    let isRestoring: Bool
    let onRestore: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                RestorePurchaseButton(isRestoring: isRestoring, onRestore: onRestore)
                LegalSeparator()
                RemoveAdsLegalLinksView()
            }

            VStack(spacing: DesignConstants.Spacing.small) {
                RestorePurchaseButton(isRestoring: isRestoring, onRestore: onRestore)
                RemoveAdsLegalLinksView()
            }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack {
        Spacer()
        RemoveAdsLegalFooterView(isRestoring: false, onRestore: {})
    }
}
