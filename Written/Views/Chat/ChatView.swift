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
        self._messages = State(initialValue: Self.orderedMessages(from: initialMessages))
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
        session = compactedSessionFromMessages(excludingLastAssistant: false)

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

        let content = await generateResponseWithRecovery(for: prompt)
        if let content {
            messages.append(ChatMessage(content: content, isUser: false))
        } else {
            appendRecoveryFailureMessage()
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
            let sanitized = sanitizedResponse(messages[messageIndex].content)
            if isRefusalMessage(sanitized), let recovered = await recoverAfterFailure(for: prompt) {
                messages[messageIndex] = ChatMessage(
                    id: messageId,
                    content: recovered,
                    isUser: false,
                    timestamp: timestamp
                )
            } else if isRefusalMessage(sanitized) {
                messages[messageIndex] = ChatMessage(
                    id: messageId,
                    content: recoveryFailureMessage,
                    isUser: false,
                    timestamp: timestamp
                )
            } else {
                let finalContent = appendSourcesIfNeeded(to: sanitized)
                messages[messageIndex] = ChatMessage(
                    id: messageId,
                    content: finalContent,
                    isUser: false,
                    timestamp: timestamp
                )
            }
        } catch {
            if let recovered = await recoverAfterFailure(for: prompt) {
                messages[messageIndex] = ChatMessage(
                    id: messageId,
                    content: recovered,
                    isUser: false,
                    timestamp: timestamp
                )
            } else {
                messages[messageIndex] = ChatMessage(
                    id: messageId,
                    content: recoveryFailureMessage,
                    isUser: false,
                    timestamp: timestamp
                )
            }
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

        do {
            try await Task.sleep(for: .seconds(2))
            isResponding = true

            guard let content = await generateResponseWithRecovery(for: prompt) else {
                appendRecoveryFailureMessage()
                isResponding = false
                return
            }
            let simulatedTime = Duration.seconds(1 + Double(content.count) * 0.02)

            if ContinuousClock.now - startTime < simulatedTime {
                try await Task.sleep(for: simulatedTime - (.now - startTime))
            }

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
    private func appendRecoveryFailureMessage() {
        messages.append(ChatMessage(content: recoveryFailureMessage, isUser: false))
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
    private func generateResponseWithRecovery(for prompt: String) async -> String? {
        do {
            let response = try await session.respond(to: prompt, options: configuration.generationOptions)
            let content = appendSourcesIfNeeded(to: sanitizedResponse(response.content))
            if isRefusalMessage(content) {
                return await recoverAfterFailure(for: prompt)
            }
            return content
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            return await recoverAfterFailure(for: prompt)
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            return await recoverAfterFailure(for: prompt)
        } catch {
            return nil
        }
    }

    @MainActor
    private func recoverAfterFailure(for prompt: String) async -> String? {
        session = compactedSessionFromMessages(excludingLastAssistant: true)
        do {
            let response = try await session.respond(to: prompt, options: configuration.generationOptions)
            let content = appendSourcesIfNeeded(to: sanitizedResponse(response.content))
            return isRefusalMessage(content) ? nil : content
        } catch {
            return nil
        }
    }

    @MainActor
    private func compactedSessionFromMessages(
        excludingLastAssistant: Bool,
        maxCharacters: Int = 4000
    ) -> LanguageModelSession {
        var entries: [Transcript.Entry] = []

        if configuration.instructions.isReallyEmpty == false {
            let instructionSegment = Transcript.Segment.text(.init(content: configuration.instructions))
            let instructions = Transcript.Instructions(
                segments: [instructionSegment],
                toolDefinitions: []
            )
            entries.append(.instructions(instructions))
        }

        var ordered = Self.orderedMessages(from: messages)
        if excludingLastAssistant, let last = ordered.last, last.isUser == false {
            ordered.removeLast()
        }

        for message in ordered {
            if message.isUser == false, isRefusalMessage(message.content) {
                continue
            }
            let segment = Transcript.Segment.text(.init(content: message.content))
            if message.isUser {
                let prompt = Transcript.Prompt(segments: [segment])
                entries.append(.prompt(prompt))
            } else {
                let response = Transcript.Response(assetIDs: [], segments: [segment])
                entries.append(.response(response))
            }
        }

        guard let first = entries.first else {
            return session
        }

        var selected = [first]
        var totalInstructionLength = String(describing: first).count
        var recentEntries: [Transcript.Entry] = []

        for entry in entries.dropFirst().reversed() {
            let entryEstimateLength = String(describing: entry).count
            guard totalInstructionLength + entryEstimateLength <= maxCharacters else { break }
            recentEntries.insert(entry, at: 0)
            totalInstructionLength += entryEstimateLength
        }

        selected.append(contentsOf: recentEntries)
        return AppLanguageModel.session(transcript: Transcript(entries: selected))
    }

    @MainActor
    private func isRefusalMessage(_ content: String) -> Bool {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let refusalPhrases = [
            "i can't help",
            "i cannot help",
            "i can't assist",
            "i cannot assist",
            "i'm sorry, but i can't",
            "i'm sorry, but i cannot",
            "i'm sorry, i can't",
            "i'm sorry, i cannot",
            "i'm sorry, but i can't assist",
            "i'm sorry, but i cannot assist",
            "i can't provide that",
            "i cannot provide that",
            "i can't help with that",
            "i cannot help with that"
        ]
        return refusalPhrases.contains { normalized.localizedStandardContains($0) }
    }

    private var recoveryFailureMessage: String {
        "I couldn't continue with that request. Try rephrasing, shortening the message, or starting a new chat."
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
            let orderedExisting = Self.orderedMessages(from: existing.messages)
            let orderedNew = Self.orderedMessages(from: messagesToSave)
            let hasNewMessage = orderedNew.count > orderedExisting.count
                || orderedNew.last?.id != orderedExisting.last?.id
            guard hasNewMessage else { return }
            existing.title = title
            existing.messages = orderedNew
            existing.lastUpdated = Date()
        } else {
            let orderedNew = Self.orderedMessages(from: messagesToSave)
            let thread = ChatThread(
                id: id,
                title: title,
                messages: orderedNew,
                creationDate: Date(),
                lastUpdated: Date()
            )
            modelContext.insert(thread)
        }
        try? modelContext.save()
    }

    private static func orderedMessages(from messages: [ChatMessage]) -> [ChatMessage] {
        messages.sorted {
            if $0.timestamp != $1.timestamp {
                return $0.timestamp < $1.timestamp
            }
            return $0.id.uuidString < $1.id.uuidString
        }
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
