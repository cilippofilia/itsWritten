//
//  SheetType.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import Foundation

/// Sheets presented from `HomeView`. Holds no data: `HomeSheetView` reads the settings it
/// edits from bindings supplied when the sheet is built.
enum SheetType: String, Identifiable {
    case whyAI
    case settings

    var id: String { rawValue }
}
