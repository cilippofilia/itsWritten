//
//  PubMedToolStore.swift
//  Written
//
//  Created by Filippo Cilia on 16/03/2026.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class PubMedToolStore {
    static let shared = PubMedToolStore()

    struct Source: Hashable {
        let title: String
        let pmid: String
        let url: String
    }

    private(set) var sources: [Source] = []
    private(set) var wasUsed = false

    func reset() {
        sources = []
        wasUsed = false
    }

    func record(sources: [Source]) {
        self.sources = sources
        wasUsed = sources.isEmpty == false
    }
}
