//
//  TimerDuration.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import Foundation

/// The writing-timer lengths offered in the timer menu.
enum TimerDuration: Int, CaseIterable, Identifiable {
    case fiveMinutes = 300
    case tenMinutes = 600
    case fifteenMinutes = 900
    case twentyMinutes = 1200
    case twentyFiveMinutes = 1500
    case thirtyMinutes = 1800

    var id: Int { rawValue }

    var seconds: Int { rawValue }
}
