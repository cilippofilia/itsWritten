//
//  NewChatTransition.swift
//  itsWritten
//
//  Created by Filippo Cilia on 18/10/2026.
//

import SwiftUI

/// Drives the "send the letter" animation shown when the user starts a new chat.
///
/// The conversation turns into a sheet of paper, folds in thirds like a letter, then flies
/// along a curve into the menu button (where History lives). `HomeView` resets the
/// conversation as the paper appears, so the empty composer is revealed behind it.
///
/// `start` puts the letter on screen; `FoldingLetterView` calls `run` once it appears. The
/// steps are chained through animation completions, which only wait for an animation that
/// something on screen is actually showing.
@MainActor
@Observable
final class NewChatTransition {
    enum Phase: Equatable {
        case idle
        case paper
        case foldingBottom
        case foldingTop
        case pressing
        case flying
    }

    private(set) var phase: Phase = .idle

    /// The messages drawn on the letter, captured before the conversation is reset.
    private(set) var snapshot: [ChatMessage] = []

    /// The conversation title, drawn as the letter's header.
    private(set) var snapshotTitle = ""

    /// Where `HomeView` sits on screen, measured globally.
    var containerFrame: CGRect = .zero

    /// Where the conversation's messages sit on screen, measured globally.
    var sourceGlobalFrame: CGRect = .zero

    /// `HomeView`'s safe-area insets. When iPhone Duo shows a vertical toolbar, the bar
    /// occupies the inset on its side.
    var containerSafeAreaInsets = EdgeInsets()

    /// Which side iPhone Duo's vertical toolbar is on, or `nil` for a horizontal bar.
    var toolbarVerticalEdge: HorizontalEdge?

    /// Mirrors the landing spot for right-to-left languages.
    var layoutDirection: LayoutDirection = .leftToRight

    /// The conversation's messages, in `HomeView`'s coordinate space.
    var sourceFrame: CGRect {
        sourceGlobalFrame.offsetBy(dx: -containerFrame.minX, dy: -containerFrame.minY)
    }

    /// Height of the header strip above the messages, where the title sits.
    var headerHeight: Double {
        max(sourceFrame.minY, 0)
    }

    /// The whole letter: the header strip plus the messages below it.
    var letterFrame: CGRect {
        CGRect(x: sourceFrame.minX, y: 0, width: sourceFrame.width, height: sourceFrame.maxY)
    }

    /// The title lines up with the screen's own: leading beside iPhone Duo's vertical bar,
    /// centered in a horizontal navigation bar.
    var headerAlignment: HorizontalAlignment {
        toolbarVerticalEdge == nil ? .center : .leading
    }

    /// Where the menu button sits, in `HomeView`'s coordinate space.
    ///
    /// The system draws toolbar menus itself, so SwiftUI can't measure the button. With a
    /// horizontal bar, this is the standard top-trailing slot: a 44 pt button inset 16 pt
    /// from the trailing edge. With iPhone Duo's vertical bar, it's the bar's first slot,
    /// below the status items, on whichever side the bar is.
    var targetFrame: CGRect {
        let size = 44.0

        if let toolbarVerticalEdge {
            // Measured on the iOS 27.1 iPhone Duo simulator's outer display: the menu's
            // center sits 48 pt in from the screen edge and 194 pt down.
            let centerX = toolbarVerticalEdge == .trailing
                ? containerFrame.width + containerSafeAreaInsets.trailing - 48
                : -containerSafeAreaInsets.leading + 48
            return CGRect(x: centerX - size / 2, y: 194 - size / 2, width: size, height: size)
        }

        let inset = 16.0
        let minX = layoutDirection == .rightToLeft ? inset : containerFrame.width - inset - size
        return CGRect(x: minX, y: 5, width: size, height: size)
    }

    var flightPath: LetterFlightPath {
        LetterFlightPath(
            start: CGPoint(x: letterFrame.midX, y: letterFrame.midY),
            end: CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        )
    }

    /// 0 = looks exactly like the chat; 1 = a rounded, edged, shadowed sheet of paper.
    private(set) var paperProgress: Double = 0

    /// Fold angles in degrees, 0 (flat) to 180 (folded over the middle third).
    private(set) var bottomFoldAngle: Double = 0
    private(set) var topFoldAngle: Double = 0

    /// Briefly 1 right after the last fold, as if the letter is being pressed flat.
    private(set) var pressProgress: Double = 0

    /// 0 = unstamped; 1 = the stamp has landed and been postmarked.
    private(set) var stampProgress: Double = 0

    /// Incremented when the stamp lands, to play a firmer haptic than the menu's tap.
    private(set) var stampCount = 0

    /// 0 at the conversation, 1 inside the menu button.
    private(set) var flightProgress: Double = 0

    /// Incremented each time a letter lands, to bounce the menu button and play a haptic.
    private(set) var deliveryCount = 0

    var isActive: Bool {
        phase != .idle
    }

    /// The scale the folded letter shrinks to so it fits inside the menu button.
    var landingScale: Double {
        guard sourceFrame.width > 0 else { return 0.1 }
        return max(targetFrame.width / sourceFrame.width, 0.02)
    }

    private var pendingReset: (() -> Void)?

    /// Puts the letter on screen, ready for `run`.
    ///
    /// - Parameters:
    ///   - messages: The conversation to draw on the letter.
    ///   - title: The conversation title, drawn as the letter's header.
    ///   - reduceMotion: When true, skips the letter entirely and just runs `reset`
    ///     inside a cross-fade.
    ///   - reset: Clears the conversation. Called once the paper covers the chat.
    func start(messages: [ChatMessage], title: String = "", reduceMotion: Bool, reset: @escaping () -> Void) {
        guard phase == .idle else { return }

        guard reduceMotion == false, sourceFrame.isEmpty == false, containerFrame.isEmpty == false else {
            withAnimation(.easeInOut) {
                reset()
            }
            return
        }

        // Only the bottom of the conversation is visible on the letter.
        snapshot = Array(messages.suffix(12))
        snapshotTitle = title
        pendingReset = reset
        phase = .paper
    }

    /// Plays the sequence. Called by `FoldingLetterView` once the letter is on screen.
    func run() {
        guard phase == .paper, paperProgress == 0 else { return }

        withAnimation(.easeOut(duration: 0.25)) {
            paperProgress = 1
        } completion: {
            self.pendingReset?()
            self.pendingReset = nil
            self.foldBottom()
        }
    }

    private func foldBottom() {
        phase = .foldingBottom
        // A little bounce: the flap overshoots the fold slightly, then settles.
        withAnimation(.spring(duration: 0.4, bounce: 0.25)) {
            bottomFoldAngle = 180
        } completion: {
            self.foldTop()
        }
    }

    private func foldTop() {
        phase = .foldingTop
        withAnimation(.spring(duration: 0.4, bounce: 0.25)) {
            topFoldAngle = 180
        } completion: {
            self.pressFlat()
        }
    }

    /// Presses the folded letter down for a beat while the stamp thumps on, then lets it
    /// lift off.
    private func pressFlat() {
        phase = .pressing
        stampCount += 1
        withAnimation(.spring(duration: 0.25, bounce: 0.35)) {
            pressProgress = 1
            stampProgress = 1
        } completion: {
            withAnimation(.easeIn(duration: 0.15)) {
                self.pressProgress = 0
            } completion: {
                self.fly()
            }
        }
    }

    private func fly() {
        phase = .flying
        withAnimation(.easeIn(duration: 0.5)) {
            flightProgress = 1
        } completion: {
            self.deliveryCount += 1
            self.finish()
        }
    }

    /// Returns to idle, ready for the next new chat.
    func finish() {
        phase = .idle
        pendingReset = nil
        snapshot = []
        snapshotTitle = ""
        paperProgress = 0
        bottomFoldAngle = 0
        topFoldAngle = 0
        pressProgress = 0
        stampProgress = 0
        flightProgress = 0
    }
}
