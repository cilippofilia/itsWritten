//
//  CrossPromoBannerView.swift
//  itsWritten
//

import PrivateAds
import SwiftUI

/// A persistent ambient banner ad for Filippo Cilia's other apps, refreshed each time this view
/// appears.
@available(iOS 26.0, *)
struct CrossPromoBannerView: View {
    @Environment(RemoveAdsStore.self) private var removeAdsStore

    @State private var ad: Ad?
    @State private var showRemoveAdsPaywall = false

    var body: some View {
        Group {
            if removeAdsStore.isAdsRemoved == false, let ad {
                AdBannerView(
                    advert: ad,
                    config: .crossPromo,
                    hideDismissButtonAndTimer: true,
                    cornerButton: .init(label: "Remove Ads") {
                        showRemoveAdsPaywall = true
                    }
                )
                .padding()
            }
        }
        .task {
            await refreshAd()
        }
        .sheet(isPresented: $showRemoveAdsPaywall) {
            CrossPromoRemoveAdsInfoView()
                .presentationDetents([.medium, .large])
        }
    }

    private func refreshAd() async {
        guard removeAdsStore.isAdsRemoved == false else { return }
        guard let url = AdConfiguration.crossPromo.adsJSONURL else { return }
        ad = try? await AdStore.fetchRandomAd(
            from: url,
            excludedIDs: AdConfiguration.crossPromo.excludedIDs
        )
    }
}

@available(iOS 26.0, *)
#Preview {
    CrossPromoBannerView()
        .environment(RemoveAdsStore())
}
