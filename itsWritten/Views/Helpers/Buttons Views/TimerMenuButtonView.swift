//
//  TimerMenuButtonView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

/// Starts a writing timer from a menu of durations, then swaps to pause/resume and stop
/// controls while one is running.
struct TimerMenuButtonView: View {
    @Environment(CountdownViewModel.self) private var viewModel

    var body: some View {
        if viewModel.timerActive || viewModel.timerPaused {
            HStack(spacing: DesignConstants.Spacing.medium) {
                if viewModel.timerPaused {
                    TimerControlButton(title: "Resume Timer", systemImage: "play.circle", action: viewModel.resumeTimer)
                } else {
                    TimerControlButton(title: "Pause Timer", systemImage: "pause.circle", action: viewModel.pauseTimer)
                }

                TimerControlButton(title: "Stop Timer", systemImage: "stop.circle", action: viewModel.stopTimer)
            }
        } else {
            Menu {
                ForEach(TimerDuration.allCases) { duration in
                    Button(viewModel.formattedTime(for: duration.seconds)) {
                        viewModel.startTimer(duration: TimeInterval(duration.seconds))
                    }
                }

                Divider()

                Text("How long for?")
            } label: {
                Label("Start Timer", systemImage: "timer")
                    .labelStyle(.iconOnly)
                    .padding()
                    .frame(minWidth: 50, minHeight: 50)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .menuOrder(.priority)
            .glassEffect(.regular.interactive())
        }
    }
}

#Preview {
    TimerMenuButtonView()
        .environment(CountdownViewModel())
}
