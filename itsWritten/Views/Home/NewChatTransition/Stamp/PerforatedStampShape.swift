//
//  PerforatedStampShape.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// A postage stamp outline: a rectangle with evenly spaced half-circle bites along every
/// edge, like the perforations left when a stamp is torn from its sheet.
struct PerforatedStampShape: Shape {
    /// Radius of each perforation.
    var holeRadius: Double = 2.2

    /// Gap between neighbouring perforations, edge to edge.
    var holeSpacing: Double = 2.6

    func path(in rect: CGRect) -> Path {
        var holes = Path()
        let step = holeRadius * 2 + holeSpacing

        func addHoles(from start: CGPoint, to end: CGPoint) {
            let length = hypot(end.x - start.x, end.y - start.y)
            let count = max(Int(length / step), 1)
            for index in 0...count {
                let fraction = Double(index) / Double(count)
                let center = CGPoint(
                    x: start.x + (end.x - start.x) * fraction,
                    y: start.y + (end.y - start.y) * fraction
                )
                holes.addEllipse(in: CGRect(
                    x: center.x - holeRadius,
                    y: center.y - holeRadius,
                    width: holeRadius * 2,
                    height: holeRadius * 2
                ))
            }
        }

        addHoles(from: CGPoint(x: rect.minX, y: rect.minY), to: CGPoint(x: rect.maxX, y: rect.minY))
        addHoles(from: CGPoint(x: rect.minX, y: rect.maxY), to: CGPoint(x: rect.maxX, y: rect.maxY))
        addHoles(from: CGPoint(x: rect.minX, y: rect.minY), to: CGPoint(x: rect.minX, y: rect.maxY))
        addHoles(from: CGPoint(x: rect.maxX, y: rect.minY), to: CGPoint(x: rect.maxX, y: rect.maxY))

        return Path(rect).subtracting(holes)
    }
}

@available(iOS 26.0, *)
#Preview {
    PerforatedStampShape()
        .fill(.orange)
        .frame(width: 60, height: 74)
}
