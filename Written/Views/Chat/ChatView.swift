//
//  ChatView.swift
//  Written
//
//  Created by Filippo Cilia on 03/02/2026.
//

import FoundationModels
import SwiftUI

/// A chat interface demonstrating various response generation strategies.
///
/// This view provides a full chat experience with support for standard responses,
/// streaming responses, and simulated "human-like" typing delays.
struct ChatView: View {
    /// The language model session managing conversation state.
    @State private var session = LanguageModelSession()

    /// The array of chat messages displayed in the conversation.
    @State private var messages = [ChatMessage]()

    /// The current user input text.
    @State private var input = ""

    /// Whether the model is currently generating a response.
    /// This is important because we have "human" response mode,
    /// where we fake a delay in thinking and typing.
    @State private var isResponding = false

    /// Controls whether the settings sheet is presented.
    @State private var showingSettings = false

    /// The configuration for the language model.
    @State private var configuration = ModelConfiguration()

    /// The selected response generation strategy.
    @State private var responseType = ModelResponseType.standard

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(messages: messages, isResponding: isResponding)

            PromptInputView(
                text: $input,
                placeholder: "Message",
                isDisabled: isResponding,
                onSubmit: sendMessage
            )
            .padding()
            .background(.bar)
        }
        .toolbar {
            Button("Settings", systemImage: "gearshape") {
                showingSettings = true
            }
        }
        .sheet(isPresented: $showingSettings) {
            ModelSettingsSheet(
                configuration: $configuration,
                responseType: $responseType
            )
        }
        .onChange(of: configuration.instructions) {
            if configuration.instructions.isReallyEmpty {
                session = LanguageModelSession()
            } else {
                session = LanguageModelSession(instructions: configuration.instructions)
            }
        }
    }

    /// Sends the current input as a message and generates a response.
    ///
    /// This method dispatches to the appropriate generation strategy based on the
    /// current `responseType` setting.
    func sendMessage() {
        guard input.isReallyEmpty == false else { return }

        let prompt = input.trimmed
        messages.append(ChatMessage(content: prompt, isUser: true))
        input = ""

        Task {
            switch responseType {
            case .standard: await generateStandardResponse(for: prompt)
            case .streaming: await generateStreamingResponse(for: prompt)
            case .human: await generateHumanResponse(for: prompt)
            }
        }
    }

    /// Generates a response using the standard (non-streaming) approach.
    ///
    /// The entire response is generated before being displayed. Handles context window
    /// overflow by compacting the session and retrying.
    /// - Parameter prompt: The user's message to respond to.
    func generateStandardResponse(for prompt: String) async {
        isResponding = true
        defer { isResponding = false }

        do {
            let response = try await session.respond(to: prompt, options: configuration.generationOptions)
            messages.append(ChatMessage(content: response.content, isUser: false))
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            session = session.compactedSession(from: session)
            do {
                let response = try await session.respond(to: prompt, options: configuration.generationOptions)
                messages.append(ChatMessage(content: response.content, isUser: false))
            } catch {
                appendErrorMessage()
            }
        } catch {
            appendErrorMessage()
        }
    }

    /// Generates a response using streaming, updating the UI as tokens arrive.
    ///
    /// Creates an empty message placeholder that updates in real-time as the
    /// response is generated. Handles context window overflow by compacting and retrying.
    /// - Parameter prompt: The user's message to respond to.
    func generateStreamingResponse(for prompt: String) async {
        let messageIndex = messages.count
        messages.append(ChatMessage(content: "", isUser: false))

        do {
            for try await partial in session.streamResponse(to: prompt, options: configuration.generationOptions) {
                messages[messageIndex] = ChatMessage(content: partial.content, isUser: false)
            }
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            session = session.compactedSession(from: session)
            do {
                for try await partial in session.streamResponse(to: prompt, options: configuration.generationOptions) {
                    messages[messageIndex] = ChatMessage(content: partial.content, isUser: false)
                }
            } catch {
                messages[messageIndex] = ChatMessage(content: "Sorry, I couldn't generate a response.", isUser: false)
            }
        } catch {
            messages[messageIndex] = ChatMessage(content: "Sorry, I couldn't generate a response.", isUser: false)
        }
    }

    /// Generates a response with simulated human-like typing delays.
    ///
    /// This mode adds artificial delays to simulate a human typing the response,
    /// creating a more natural conversational feel. The response is generated in the
    /// background while initial "thinking" time passes.
    /// - Parameter prompt: The user's message to respond to.
    func generateHumanResponse(for prompt: String) async {
        let startTime = ContinuousClock.now

        async let responseTask = session.respond(to: prompt, options: configuration.generationOptions)

        do {
            try await Task.sleep(for: .seconds(2))
            isResponding = true

            let response = try await responseTask
            let simulatedTime = Duration.seconds(1 + Double(response.content.count) * 0.02)

            if ContinuousClock.now - startTime < simulatedTime {
                try await Task.sleep(for: simulatedTime - (.now - startTime))
            }

            messages.append(ChatMessage(content: response.content, isUser: false))
        } catch {
            appendErrorMessage()
        }

        isResponding = false
    }

    /// Appends a standard error message to the conversation.
    func appendErrorMessage() {
        messages.append(ChatMessage(content: "Sorry, I couldn't generate a response.", isUser: false))
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
