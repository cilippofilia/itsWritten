//
//  HomeContentView.swift
//  Written
//
//  Created by Filippo Cilia on 01/02/2026.
//

import FoundationModels
import SwiftUI

struct HomeContentView: View {
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel

    @FocusState private var isFocused: Bool
    @State private var text = ""
    @State private var activeAlert: AlertType?
    @State private var presentedSheet: SheetType?
    @State private var showOverlayView = false

    @Binding var shouldSend: Bool

    var body: some View {
        VStack {
            HomeTextEditor(
                text: $text,
                isFocused: $isFocused,
                placeholderText: viewModel.placeholderText,
                isResponding: viewModel.session?.isResponding ?? false
            )

            if countDownViewModel.timerActive || countDownViewModel.timerPaused {
                CountdownView()
            }
        }
        .overlay {
            if showOverlayView {
                RespondingIndicator()
            }
        }
        .safeAreaInset(edge: .bottom) {
            HomeFooterView(
                text: text,
                isResponding: viewModel.session?.isResponding ?? false,
                sendAction: {
                    shouldSend = true
                }
            )
        }
        .sheet(item: $presentedSheet) { sheet in
            sheet.view
        }
        .alert(activeAlert?.title ?? "", isPresented: .init(
            get: { activeAlert != nil },
            set: { if !$0 { activeAlert = nil } }
        )) {
            Button(activeAlert?.buttonText ?? "OK") {
                activeAlert = nil
            }
        } message: {
            Text(activeAlert?.message ?? "")
        }
        .task(id: shouldSend) {
            guard shouldSend else { return }
            await performSend()
            shouldSend = false
        }
        .onChange(of: countDownViewModel.timerExpired) { _, expired in
            if expired {
                activeAlert = .timeUp
            }
        }
    }
}

// MARK: - Send Logic
extension HomeContentView {
    @MainActor
    private func performSend() async {
        showOverlayView = true

        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            showOverlayView = false
            return
        }

        isFocused = false
        activeAlert = nil

        guard let session = viewModel.session else {
            showOverlayView = false
            return
        }

        do {
            let answer = try await streamResponse(from: session, input: input)
            let history = HistoryModel(prompt: input, response: .init(answer))
            viewModel.history.append(history)
            text = ""
        } catch let error as LanguageModelSession.GenerationError {
            activeAlert = createAlert(from: error)
        } catch {
            activeAlert = .aiGeneration(
                title: "Response Error",
                message: error.localizedDescription
            )
        }

        showOverlayView = false
    }

    @MainActor
    private func streamResponse(from session: LanguageModelSession, input: String) async throws -> String {
        let stream = session.streamResponse(to: input)
        var fullAnswer = ""

        for try await partial in stream {
            fullAnswer = partial.content
            presentedSheet = .aiGeneratedAnswer(partial.content)
        }

        return fullAnswer
    }

    @MainActor
    private func createAlert(from error: LanguageModelSession.GenerationError) -> AlertType {
        var title = "Response Error"
        var message = error.localizedDescription

        switch error {
        case .guardrailViolation(let context):
            title = "Guardrail Violation"
            message = context.debugDescription
        case .decodingFailure(let context):
            title = "Decoding Failure"
            message = context.debugDescription
        case .rateLimited(let context):
            title = "Rate Limited"
            message = context.debugDescription
        default:
            break
        }

        if let recoverySuggestion = error.recoverySuggestion {
            message += "\n\n\(recoverySuggestion)"
            if let helpAnchor = error.helpAnchor {
                message += "\(helpAnchor)"
            }
        }

        return .aiGeneration(title: title, message: message)
    }
}

#Preview {
    HomeContentView(shouldSend: .constant(false))
        .environment(HomeViewModel())
        .environment(CountdownViewModel())
}
