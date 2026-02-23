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

    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType
    let session: LanguageModelSession

    var body: some View {
        VStack {
            HomeTextEditor(
                text: $text,
                isFocused: $isFocused,
                placeholderText: viewModel.placeholderText,
                isResponding: session.isResponding
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
                isResponding: session.isResponding,
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
        defer { showOverlayView = false }

        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            showOverlayView = false
            return
        }

        isFocused = false
        activeAlert = nil

        do {
            let title = try await generateTitle(from: prompt)
            presentedSheet = .chatV2(
                title: title,
                seedPrompt: prompt,
                session: session,
                config: $config,
                responseType: $responseType,
                threadId: nil,
                initialMessages: []
            )
            text = ""
        } catch let error as LanguageModelSession.GenerationError {
            activeAlert = createAlert(from: error)
        } catch {
            activeAlert = .aiGeneration(
                title: "Response Error",
                message: error.localizedDescription
            )
        }
    }

    @MainActor
    private func generateTitle(from input: String) async throws -> String {
        let titleSession = AppLanguageModel.session(instructions: "Summarize the prompt in a few words withot changing the overall meaning of it. Please return the summarized title directly.")
        var title = ""
        for try await partial in titleSession.streamResponse(to: input) {
            title = partial.content
        }

        return title.trimmingCharacters(in: .whitespacesAndNewlines)
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
    HomeContentView(
        shouldSend: .constant(false),
        config: .constant(ModelConfiguration()),
        responseType: .constant(.standard),
        session: AppLanguageModel.session()
    )
    .environment(HomeViewModel())
    .environment(CountdownViewModel())
}
