//
//  ScreenshotPreventView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 02/28/2026.
//

import SwiftUI

struct ScreenshotPreventView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScreenshotPreventHelperView(content: content)
    }
}
