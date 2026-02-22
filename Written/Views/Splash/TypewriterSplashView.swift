//
//  TypewriterSplashView.swift
//  Written
//
//  Created by Filippo Cilia on 22/02/2026.
//

import SwiftUI

struct TypewriterSplashView: View {
    let onFinish: () -> Void

    @State private var isBlinking = false
    @State private var displayedText = ""

    private let brandText = "Written"

    var body: some View {
        HStack(spacing: 0) {
            if !displayedText.isEmpty {
                Text(displayedText)
                    .font(.largeTitle)
                    .bold()
            }
            Image("WrittenAppIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20)
                .opacity(isBlinking ? 0.25 : 1)
//                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isBlinking)
//                .animation(.snappy(duration: 0.5).repeatForever(autoreverses: true), value: isBlinking)
                .animation(.default.repeatForever(autoreverses: true), value: isBlinking)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            isBlinking = true
            await runSequence()
        }
    }

    @MainActor
    private func runSequence() async {
        do {
            try await Task.sleep(for: .seconds(2))
            for character in brandText {
                displayedText.append(character)
                try await Task.sleep(for: .milliseconds(150))
            }
            try await Task.sleep(for: .milliseconds(30))
            onFinish()
        } catch {
            return
        }
    }
}

#Preview("Light") {
    TypewriterSplashView(onFinish: { })
}

#Preview("Dark") {
    TypewriterSplashView(onFinish: { })
        .preferredColorScheme(.dark)
}
