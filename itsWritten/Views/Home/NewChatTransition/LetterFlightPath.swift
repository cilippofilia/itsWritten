//
//  LetterFlightPath.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import CoreGraphics

/// The curved route a folded letter takes from the conversation to the menu button.
///
/// A quadratic Bézier whose control point sits above the higher of the two ends, so the
/// letter arcs up and over before dropping into the button, like it's being posted.
struct LetterFlightPath: Equatable {
    let start: CGPoint
    let end: CGPoint

    /// How far above the higher endpoint the curve's control point sits.
    var lift: Double = 80

    var control: CGPoint {
        CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - lift)
    }

    /// The point along the curve at `progress`, clamped to 0...1.
    func point(at progress: Double) -> CGPoint {
        let time = min(max(progress, 0), 1)
        let inverse = 1 - time
        let startWeight = inverse * inverse
        let controlWeight = 2 * inverse * time
        let endWeight = time * time
        return CGPoint(
            x: startWeight * start.x + controlWeight * control.x + endWeight * end.x,
            y: startWeight * start.y + controlWeight * control.y + endWeight * end.y
        )
    }
}
