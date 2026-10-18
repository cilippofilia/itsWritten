//
//  SecureContainerTextField.swift
//  itsWritten
//
//  Created by Filippo Cilia on 02/28/2026.
//

import UIKit

/// A secure text field used only for its screenshot-proof canvas. Touches pass through to
/// the hosted content instead of focusing the field.
final class SecureContainerTextField: UITextField {
    var secureContentView: UIView? {
        subviews.first { subview in
            String(describing: subview).contains("UITextLayoutCanvasView")
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in subviews.reversed() {
            let convertedPoint = subview.convert(point, from: self)
            if let hitView = subview.hitTest(convertedPoint, with: event) {
                return hitView
            }
        }

        return nil
    }
}
