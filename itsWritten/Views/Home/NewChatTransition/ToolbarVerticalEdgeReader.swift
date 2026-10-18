//
//  ToolbarVerticalEdgeReader.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// Reports which side iPhone Duo's vertical toolbar is on, or `nil` when the toolbar is
/// horizontal. Lives in its own view because `toolbarVerticalEdge` needs iOS 27.1.
@available(iOS 27.1, *)
struct ToolbarVerticalEdgeReader: View {
    @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge

    let onChange: (HorizontalEdge?) -> Void

    var body: some View {
        Color.clear
            .onChange(of: toolbarVerticalEdge, initial: true) { _, edge in
                onChange(edge)
            }
    }
}
