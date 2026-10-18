//
//  PostmarkWavesShape.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// Three parallel wavy lines, as printed beside a postmark ring.
struct PostmarkWavesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waveCount = 3
        let waveWidth = rect.width / 3

        for line in 0..<waveCount {
            let baseline = rect.minY + rect.height * (Double(line) + 0.5) / Double(waveCount)
            path.move(to: CGPoint(x: rect.minX, y: baseline))
            for segment in 0..<3 {
                let startX = rect.minX + Double(segment) * waveWidth
                path.addQuadCurve(
                    to: CGPoint(x: startX + waveWidth, y: baseline),
                    control: CGPoint(x: startX + waveWidth / 2, y: baseline + (segment.isMultiple(of: 2) ? -3 : 3))
                )
            }
        }

        return path
    }
}

#Preview {
    PostmarkWavesShape()
        .stroke(.secondary)
        .frame(width: 40, height: 24)
}
