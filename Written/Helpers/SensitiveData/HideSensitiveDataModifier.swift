//
//  HideSensitiveDataModifier.swift
//  Written
//
//  Created by Filippo Cilia on 02/28/2026.
//

import SwiftUI

struct HideSensitiveDataModifier: ViewModifier {
    func body(content: Content) -> some View {
        ScreenshotPreventView {
            content
        }
    }
}
