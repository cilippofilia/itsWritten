//
//  OnboardingBackgroundView.swift
//  Written
//
//  Created by Filippo Cilia on 22/02/2026.
//

import SwiftUI

struct OnboardingBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(white: 0.98),
                    Color(white: 0.95),
                    Color(white: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.orange.opacity(0.12))
                .frame(width: 260, height: 260)
                .offset(x: -120, y: -180)

            Circle()
                .fill(.teal.opacity(0.12))
                .frame(width: 220, height: 220)
                .offset(x: 140, y: -60)

            Circle()
                .fill(.pink.opacity(0.12))
                .frame(width: 300, height: 300)
                .offset(x: 80, y: 220)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    OnboardingBackgroundView()
}
