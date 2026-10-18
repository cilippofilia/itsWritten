//
//  ScreenshotPreventHelperView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 02/28/2026.
//

import SwiftUI

/// Bridges `SecureHostingController` into SwiftUI. A view controller representable (rather
/// than a view representable) lets the hosted SwiftUI content join the view controller
/// hierarchy, so safe areas and bar insets keep propagating as the window resizes,
/// including iPhone Duo's vertical bars.
struct ScreenshotPreventHelperView<Content: View>: UIViewControllerRepresentable {
    let content: Content

    func makeUIViewController(context: Context) -> SecureHostingController<Content> {
        SecureHostingController(rootView: content)
    }

    func updateUIViewController(_ uiViewController: SecureHostingController<Content>, context: Context) {
        uiViewController.hostingController.rootView = content
    }
}
