//
//  LaunchView.swift
//  Written
//
//  Created by Filippo Cilia on 22/02/2026.
//

import SwiftUI

struct LaunchView: View {
    @State private var showsSplash = true

    var body: some View {
        ZStack {
            if showsSplash {
                TypewriterSplashView {
                    withAnimation(.easeInOut) {
                        showsSplash = false
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
                .zIndex(1)
            } else {
                AvailabilityView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(0)
            }
        }
        .background(.background)
        .animation(.easeInOut, value: showsSplash)
    }
}

#Preview {
    LaunchView()
}
