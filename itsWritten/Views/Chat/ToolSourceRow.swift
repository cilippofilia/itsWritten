//
//  ToolSourceRow.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/02/2026.
//

import SwiftUI

/// One cited source (title, PMID, and link) listed under a response's "Tools used".
struct ToolSourceRow: View {
    let source: ChatMessageSource

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(source.title)
                .font(.footnote)
                .bold()

            Text("PMID: \(source.pmid)")
                .font(.footnote)

            if let url = URL(string: source.url) {
                Link(source.url, destination: url)
                    .font(.footnote)
            }
        }
        .foregroundStyle(.secondary)
    }
}

#Preview {
    ToolSourceRow(
        source: ChatMessageSource(
            title: "Sleep Quality and Adolescents",
            pmid: "12345678",
            url: "https://pubmed.ncbi.nlm.nih.gov/12345678/"
        )
    )
}
