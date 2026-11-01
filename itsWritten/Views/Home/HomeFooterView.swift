//
//  HomeFooterView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

struct HomeFooterView: View {
    let text: String
    let isResponding: Bool
    let sendAction: () -> Void

    private var isInputEmpty: Bool {
        text.isReallyEmpty
    }

    var body: some View {
        HStack {
            SendButtonView(
                isResponding: isResponding,
                isInputEmpty: isInputEmpty,
                sendAction: sendAction
            )
            .disabled(isResponding || isInputEmpty)

            TimerMenuButtonView()
        }
        .padding(.horizontal)
        .padding(.bottom, DesignConstants.Spacing.small)
    }
}

#Preview {
    HomeFooterView(text: "Footer", isResponding: false, sendAction: { })
}
