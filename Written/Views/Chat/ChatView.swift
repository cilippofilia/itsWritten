//
//  ChatView.swift
//  Written
//
//  Created by Filippo Cilia on 03/02/2026.
//

import FoundationModels
import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(PubMedToolStore.self) private var pubMedStore

    @Binding var configuration: ModelConfiguration

    @State private var session: LanguageModelSession
    @State private var messages: [ChatMessage]
    @State private var input = ""
    @State private var isResponding = false
    @State private var showingSettings = false
    @State private var hasSeeded = false
    @Binding var responseType: ModelResponseType
    @State private var threadId: UUID?

    let title: String
    let seedPrompt: String?

    init(
        title: String,
        seedPrompt: String?,
        session: LanguageModelSession,
        configuration: Binding<ModelConfiguration>,
        responseType: Binding<ModelResponseType>,
        threadId: UUID?,
        initialMessages: [ChatMessage]
    ) {
        self.title = title
        self.seedPrompt = seedPrompt
        self._configuration = configuration
        self._session = State(initialValue: session)
        self._messages = State(initialValue: initialMessages)
        self._responseType = responseType
        self._threadId = State(initialValue: threadId)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.title2)
                .bold()
                .padding(8)
                .padding(.top)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            MessageListView(messages: messages, isResponding: isResponding)

            PromptInputView(
                text: $input,
                placeholder: viewModel.placeholderText,
                isDisabled: isResponding,
                onSubmit: sendMessage
            )
        }
        .onChange(of: configuration.instructions) {
            if configuration.instructions.isReallyEmpty {
                session = AppLanguageModel.session()
            } else {
                session = AppLanguageModel.session(instructions: configuration.instructions)
            }
        }
        .onAppear {
            seedConversationIfNeeded()
        }
        .onDisappear {
            saveThreadOnDismiss()
        }
    }

    /// Sends the current input as a message and generates a response.
    ///
    /// This method dispatches to the appropriate generation strategy based on the
    /// current `responseType` setting.
    @MainActor
    func sendMessage() {
        guard input.isReallyEmpty == false else { return }
        pubMedStore.reset()
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
    @MainActor
    func generateStandardResponse(for prompt: String) async {
        isResponding = true
        defer { isResponding = false }

        do {
            let response = try await session.respond(to: prompt, options: configuration.generationOptions)
            let content = appendSourcesIfNeeded(to: sanitizedResponse(response.content))
            messages.append(ChatMessage(content: content, isUser: false))
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            session = session.compactedSession(from: session)
            do {
                let response = try await session.respond(to: prompt, options: configuration.generationOptions)
                let content = appendSourcesIfNeeded(to: sanitizedResponse(response.content))
                messages.append(ChatMessage(content: content, isUser: false))
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
    @MainActor
    func generateStreamingResponse(for prompt: String) async {
        isResponding = true
        defer { isResponding = false }

        let messageIndex = messages.count
        messages.append(ChatMessage(content: "", isUser: false))
        let messageId = messages[messageIndex].id
        let timestamp = messages[messageIndex].timestamp

        do {
            for try await partial in session.streamResponse(to: prompt, options: configuration.generationOptions) {
                withAnimation(.default) {
                    messages[messageIndex] = ChatMessage(
                        id: messageId,
                        content: partial.content,
                        isUser: false,
                        timestamp: timestamp
                    )
                }
            }
            let finalContent = appendSourcesIfNeeded(to: sanitizedResponse(messages[messageIndex].content))
            messages[messageIndex] = ChatMessage(
                id: messageId,
                content: finalContent,
                isUser: false,
                timestamp: timestamp
            )
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            session = session.compactedSession(from: session)
            do {
                for try await partial in session.streamResponse(to: prompt, options: configuration.generationOptions) {
                    withAnimation(.default) {
                        messages[messageIndex] = ChatMessage(
                            id: messageId,
                            content: partial.content,
                            isUser: false,
                            timestamp: timestamp
                        )
                    }
                }
                let finalContent = appendSourcesIfNeeded(to: sanitizedResponse(messages[messageIndex].content))
                messages[messageIndex] = ChatMessage(
                    id: messageId,
                    content: finalContent,
                    isUser: false,
                    timestamp: timestamp
                )
            } catch {
                messages[messageIndex] = ChatMessage(
                    id: messageId,
                    content: "Sorry, I couldn't generate a response.",
                    isUser: false,
                    timestamp: timestamp
                )
            }
        } catch {
            messages[messageIndex] = ChatMessage(
                id: messageId,
                content: "Sorry, I couldn't generate a response.",
                isUser: false,
                timestamp: timestamp
            )
        }
    }

    /// Generates a response with simulated human-like typing delays.
    ///
    /// This mode adds artificial delays to simulate a human typing the response,
    /// creating a more natural conversational feel. The response is generated in the
    /// background while initial "thinking" time passes.
    /// - Parameter prompt: The user's message to respond to.
    @MainActor
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

            let content = appendSourcesIfNeeded(to: sanitizedResponse(response.content))
            messages.append(ChatMessage(content: content, isUser: false))
        } catch {
            appendErrorMessage()
        }

        isResponding = false
    }

    /// Appends a standard error message to the conversation.
    @MainActor
    func appendErrorMessage() {
        messages.append(ChatMessage(content: "Sorry, I couldn't generate a response.", isUser: false))
    }

    @MainActor
    private func sanitizedResponse(_ response: String) -> String {
        response
            .split(whereSeparator: \.isNewline)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Sources:") == false }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func appendSourcesIfNeeded(to response: String) -> String {
        guard pubMedStore.wasUsed, pubMedStore.sources.isEmpty == false else {
            return response
        }

        let sources = pubMedStore.sources.prefix(2).map { source in
            let safeTitle = source.title.replacing("\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(safeTitle) - PMID: \(source.pmid) - \(source.url)"
        }

        let sourcesLine = "Sources: " + sources.joined(separator: "; ")
        return response.isEmpty ? sourcesLine : "\(response)\n\n\(sourcesLine)"
    }

    @MainActor
    private func seedConversationIfNeeded() {
        guard hasSeeded == false, let prompt = seedPrompt, messages.isEmpty else { return }
        hasSeeded = true
        messages.append(ChatMessage(content: prompt, isUser: true))
        Task {
            await generateStreamingResponse(for: prompt)
        }
    }

    @MainActor
    private func saveThreadOnDismiss() {
        guard messages.isEmpty == false else { return }

        var messagesToSave = messages
        if isResponding, let last = messagesToSave.last, last.isUser == false {
            messagesToSave.removeLast()
        }

        guard messagesToSave.isEmpty == false else { return }

        let id = threadId ?? UUID()
        threadId = id
        let fetch = FetchDescriptor<ChatThread>(
            predicate: #Predicate { $0.id == id }
        )
        let existing = (try? modelContext.fetch(fetch))?.first
        if let existing {
            existing.title = title
            existing.messages = messagesToSave
            existing.lastUpdated = Date()
        } else {
            let thread = ChatThread(
                id: id,
                title: title,
                messages: messagesToSave,
                creationDate: Date(),
                lastUpdated: Date()
            )
            modelContext.insert(thread)
        }
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        ChatView(
            title: "Preview",
            seedPrompt: nil,
            session: AppLanguageModel.session(),
            configuration: .constant(ModelConfiguration()),
            responseType: .constant(.standard),
            threadId: nil,
            initialMessages: []
        )
    }
    .environment(HomeViewModel())
    .environment(PubMedToolStore.shared)
    .modelContainer(for: [ChatThread.self, ChatMessage.self], inMemory: true)
}
