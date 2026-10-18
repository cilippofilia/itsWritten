//
//  InkWearMask.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// A mask that makes printed ink look hand-stamped: scattered specks where the ink didn't
/// take, and a few broad patches where it ran thin. The same `seed` always produces the
/// same wear, so the mark doesn't flicker as the letter animates.
@available(iOS 26.0, *)
struct InkWearMask: View {
    let seed: UInt64

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            context.blendMode = .destinationOut

            var generator = SeededRandomNumberGenerator(seed: seed)

            // Broad, faint patches where the stamp was pressed unevenly.
            for _ in 0..<4 {
                let radius = Double.random(in: 6...11, using: &generator)
                let center = CGPoint(
                    x: Double.random(in: 0...size.width, using: &generator),
                    y: Double.random(in: 0...size.height, using: &generator)
                )
                let alpha = Double.random(in: 0.3...0.6, using: &generator)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(.white.opacity(alpha))
                )
            }

            // Small specks where the ink is missing entirely.
            for _ in 0..<45 {
                let radius = Double.random(in: 0.5...2.2, using: &generator)
                let center = CGPoint(
                    x: Double.random(in: 0...size.width, using: &generator),
                    y: Double.random(in: 0...size.height, using: &generator)
                )
                let alpha = Double.random(in: 0.6...1, using: &generator)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(.white.opacity(alpha))
                )
            }
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    Rectangle()
        .fill(.red)
        .frame(width: 70, height: 40)
        .mask { InkWearMask(seed: 42) }
}
