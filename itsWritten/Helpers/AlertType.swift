//
//  AlertType.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import Foundation

enum AlertType: String, Identifiable {
    case timeUp

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .timeUp: "Time's Up!"
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .timeUp: "Your countdown timer has finished."
        }
    }

    var buttonText: LocalizedStringResource {
        "OK"
    }
}
