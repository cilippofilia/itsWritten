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
}
