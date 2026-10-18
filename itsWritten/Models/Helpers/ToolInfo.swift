//
//  ToolInfo.swift
//  itsWritten
//
//  Created by Filippo Cilia on 25/05/2026.
//

import Foundation

/// Display details for one model tool, listed in Settings › Generation.
struct ToolInfo: Identifiable {
    let id: String
    let displayName: String
    let summary: String
}
