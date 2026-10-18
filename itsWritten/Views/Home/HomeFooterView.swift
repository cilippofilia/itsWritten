//
//  HomeFooterView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

@available(iOS 26.0, *)
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

@available(iOS 26.0, *)
#Preview {
    HomeFooterView(text: "Footer", isResponding: false, sendAction: { })
}
