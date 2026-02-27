//
//  PrivacyShieldView.swift
//  Written
//
//  Created by Filippo Cilia on 02/27/2026.
//

import SwiftUI

struct PrivacyShieldView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.slash")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .padding()
                .foregroundStyle(.secondary)

            Text("itsWritten")
                .font(.title2)
                .bold()
                .foregroundStyle(.white)

            Text("There is nothing to see here.")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color.black.ignoresSafeArea()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Written content hidden for privacy")
    }
}

#Preview {
    PrivacyShieldView()
}
