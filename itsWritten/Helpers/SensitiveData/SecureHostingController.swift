//
//  SecureHostingController.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI
import UIKit

/// Hosts SwiftUI content inside a secure text field's canvas, which the system blanks out
/// in screenshots and screen recordings. The hosting controller is added as a proper child
/// so it receives safe-area and trait updates from its parent.
final class SecureHostingController<Content: View>: UIViewController {
    let hostingController: UIHostingController<Content>
    private let secureTextField = SecureContainerTextField()

    init(rootView: Content) {
        hostingController = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        secureTextField.isSecureTextEntry = true
        secureTextField.backgroundColor = .clear
        secureTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(secureTextField)
        pin(secureTextField, to: view)

        // Fail closed: without the secure canvas (private API that may change), show
        // nothing rather than unprotected content.
        guard let secureView = secureTextField.secureContentView else { return }

        addChild(hostingController)
        let hostedView: UIView = hostingController.view
        hostedView.backgroundColor = .clear
        hostedView.frame = secureView.bounds
        hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        secureView.addSubview(hostedView)
        hostingController.didMove(toParent: self)
    }

    private func pin(_ subview: UIView, to container: UIView) {
        NSLayoutConstraint.activate([
            subview.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            subview.topAnchor.constraint(equalTo: container.topAnchor),
            subview.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}
