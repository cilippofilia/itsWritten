//
//  String-Ext.swift
//  Written
//
//  Created by Filippo Cilia on 02/02/2026.
//

import Foundation

extension String {
    /// Returns true if the string is empty or contains only whitespace and newlines.
    var isReallyEmpty: Bool {
        trimmed.isEmpty
    }

    /// Returns the string with leading and trailing whitespace and newlines removed.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
