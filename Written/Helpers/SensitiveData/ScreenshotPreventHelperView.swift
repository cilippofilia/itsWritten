//
//  ScreenshotPreventHelperView.swift
//  Written
//
//  Created by Filippo Cilia on 02/28/2026.
//

import SwiftUI
import UIKit

struct ScreenshotPreventHelperView<Content: View>: UIViewRepresentable {
    let content: Content

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        let secureTextField = SecureContainerTextField()
        secureTextField.isSecureTextEntry = true
        secureTextField.backgroundColor = .clear
        secureTextField.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(secureTextField)
        NSLayoutConstraint.activate([
            secureTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            secureTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            secureTextField.topAnchor.constraint(equalTo: containerView.topAnchor),
            secureTextField.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        guard let secureView = secureTextField.secureContentView else {
            return containerView
        }

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = secureView.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        secureView.addSubview(hostingController.view)

        context.coordinator.hostingController = hostingController

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.hostingController?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

extension ScreenshotPreventHelperView {
    final class Coordinator {
        var hostingController: UIHostingController<Content>?
    }
}

private final class SecureContainerTextField: UITextField {
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
