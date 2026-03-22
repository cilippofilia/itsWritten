//
//  InstructionSection.swift
//  itsWritten
//
//  Created by Filippo Cilia on 28/02/2026.
//

import SwiftUI

struct InstructionSection: View {
    @Binding var configuration: ModelConfiguration

    var body: some View {
        Section {
            TextField(
                "Instructions",
                text: $configuration.instructions,
                axis: .vertical
            )
            .lineLimit(12, reservesSpace: true)
            .labelsHidden()
        } header: {
            Text("Instructions")
                .padding(.top)
        }
    }
}
