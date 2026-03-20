//
//  HomeViewModel.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import FoundationModels
import SwiftUI

@MainActor
@Observable
public class HomeViewModel {
    var placeholderText: String = ""

    init() {
        setRandomPlaceholderText()
    }

    let placeholderOptions: [String] = [
        "Begin writing",
        "Pick a thought and go",
        "Start typing",
        "What's on your mind",
        "Just start",
        "Type your first thought",
        "Start with one sentence",
        "Just say it"
    ]
    
    func setRandomPlaceholderText() {
        let text = placeholderOptions.randomElement() ?? "Begin writing"
        placeholderText = text + "..."
    }
}
