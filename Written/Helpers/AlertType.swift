//
//  AlertType.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import Foundation

enum AlertType: Identifiable {
    case timeUp
    case aiGeneration(title: String, message: String)

    var id: String {
        switch self {
        case .timeUp:
            return "timeUp"
        case .aiGeneration:
            return "aiGeneration"
        }
    }

    var title: String {
        switch self {
        case .timeUp:
            return "Time's Up!"
        case .aiGeneration(let title, _):
            return title
        }
    }

    var message: String {
        switch self {
        case .timeUp:
            return "Your countdown timer has finished."
        case .aiGeneration(_, let message):
            return message
        }
    }

    var buttonText: String {
        "OK"
    }
}
