//
//  View-Ext.swift
//  itsWritten
//
//  Created by Filippo Cilia on 02/28/2026.
//

import SwiftUI

extension View {
    func hideSensitiveData() -> some View {
        modifier(HideSensitiveDataModifier())
    }

    /// Caps the view at a comfortable reading width and centers it, so wide windows
    /// don't produce overly long lines.
    func readableContentWidth() -> some View {
        frame(maxWidth: DesignConstants.Width.readableContent)
            .frame(maxWidth: .infinity)
    }

    /// Presents the "Why AI?" explanation as a sheet.
    @available(iOS 26.0, *)
    func whyAISheet(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            WhyAIView()
                .whyAIPresentation()
        }
    }

    /// Presentation styling shared by every "Why AI?" sheet.
    func whyAIPresentation() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
    }
}
