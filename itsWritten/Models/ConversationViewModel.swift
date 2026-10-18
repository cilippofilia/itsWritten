//
//  ConversationViewModel.swift
//  itsWritten
//
//  Created by Filippo Cilia on 09/08/2026.
//

import FoundationModels
import SwiftData
import SwiftUI
import VoltaSDK

/// Owns the state and behavior for a single conversation surface: the composer before
/// a chat starts, and the message thread once it has. Replaces the previous split
/// between `HomeContentView`'s composer state and the sheet-presented `ChatView`'s
/// own state, so both live in one place and the chat can be shown inline instead of
/// modally.
///
/// Model calls go through the app's `AIOrchestrator`. There is no stored session:
/// every send rebuilds the history from `messages` with `ChatHistoryBuilder`.
@MainActor
@Observable
final class ConversationViewModel {
    enum Mode: Equatable {
        case composing
        case chatting
    }

    /// Shown in place of a reply when no on-device answer was possible and the user
    /// declined (or had no) cloud fallback.
    static let stayedOnDeviceMessage = """
        This stayed on your device. Apple Intelligence couldn't answer, and nothing was sent to a cloud model.
        """

    /// Shown when a turn couldn't be answered even after a retry.
    static let recoveryFailureMessage = """
        I couldn't continue with that request. Try rephrasing, shortening the message, or starting a new chat.
        """

    /// Shown when the human-style response fails outright.
    static let genericErrorMessage = "Sorry, I couldn't generate a response."

    /// Total character budget for instructions plus history, matching the previous
    /// transcript compaction.
    private static let contextCharacterBudget = 4000

    /// Context usage above which the history is compacted before sending, so the
    /// on-device model keeps answering instead of the chain falling back to the cloud.
    private static let contextCompactionThreshold = 0.8

    private(set) var mode: Mode = .composing
    private(set) var messages: [ChatMessage] = []
    var title = "New Conversation"
    private(set) var threadId: UUID?
    private(set) var isResponding = false

    /// The response work started by the latest send. Exposed so tests can await it.
    private(set) var responseTask: Task<Void, Never>?

    /// The title work for the current conversation. Cancelled by `reset` and `resume`,
    /// so a superseded conversation's title call can never use the next
    /// conversation's cloud grant.
    private(set) var titleTask: Task<Void, Never>?

    /// Bumped by `reset()` and `resume(thread:config:)`. Captured by in-flight
    /// generation/title work so a stale Task from a superseded conversation can detect
    /// it no longer owns the current state and stop before mutating it.
    private(set) var generation = 0

    private var modelContext: ModelContext?
    private var pubMedStore: PubMedToolStore?
    private var crossPromoSignal: CrossPromoSignal?
    private var aiProvider: AIProviderStore?

    /// Injects the runtime dependencies this view model needs. Must be called once,
    /// from `HomeView.onAppear`, before `startConversation`/`sendMessage`/`resume` are
    /// used — SwiftUI environment values aren't available at `@State` initializer time,
    /// so they can't be passed into `init`. Until it is called, sends do nothing.
    func configure(
        modelContext: ModelContext,
        pubMedStore: PubMedToolStore,
        crossPromoSignal: CrossPromoSignal,
        aiProvider: AIProviderStore
    ) {
        self.modelContext = modelContext
        self.pubMedStore = pubMedStore
        self.crossPromoSignal = crossPromoSignal
        self.aiProvider = aiProvider
    }

    /// Prewarms the first model in the chain for `config`. Call once, from
    /// `HomeView.onAppear`.
    func prewarmIdleSession(config: ModelConfiguration) {
        guard mode == .composing, let orchestrator = aiProvider?.orchestrator else { return }
        // Deferred so prewarming never runs on the synchronous caller's path —
        // otherwise it can stall the MainActor run loop long enough to starve other
        // `.task`s in the view hierarchy (e.g. the cross-promo ad fetch).
        let instructions = Self.instructions(from: config)
        Task {
            await orchestrator.prewarm(instructions: instructions, tools: AppLanguageModel.tools)
        }
    }

    /// Loads a previously saved thread into the conversation and switches to chat mode.
    func resume(thread: ChatThread, config: ModelConfiguration) {
        generation += 1
        responseTask?.cancel()
        titleTask?.cancel()
        titleTask = nil
        aiProvider?.consent.resetConversationGrants()
        messages = Self.orderedMessages(from: thread.messages)
        title = thread.title
        threadId = thread.id
        isResponding = false
        mode = .chatting
    }

    /// Clears the current conversation and returns to the composer.
    func reset(config: ModelConfiguration) {
        generation += 1
        responseTask?.cancel()
        titleTask?.cancel()
        titleTask = nil
        aiProvider?.consent.resetConversationGrants()
        messages = []
        title = "New Conversation"
        threadId = nil
        isResponding = false
        mode = .composing
    }

    static func orderedMessages(from messages: [ChatMessage]) -> [ChatMessage] {
        messages.sorted {
            if $0.timestamp != $1.timestamp {
                return $0.timestamp < $1.timestamp
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    /// The instructions to send, or `nil` when the user cleared them.
    private static func instructions(from config: ModelConfiguration) -> String? {
        config.instructions.isReallyEmpty ? nil : config.instructions
    }
}

// MARK: - Sending Messages

extension ConversationViewModel {
    /// Starts a brand-new conversation from the composer's first message. Switches to
    /// chat mode immediately — the caller does not wait on this before showing the
    /// chat surface.
    func startConversation(with prompt: String, config: ModelConfiguration, responseType: ModelResponseType) {
        mode = .chatting
        send(prompt, config: config, responseType: responseType)
    }

    /// Sends a follow-up message within the current conversation.
    func sendMessage(_ prompt: String, config: ModelConfiguration, responseType: ModelResponseType) {
        send(prompt, config: config, responseType: responseType)
    }

    /// Generates a short title in the background and applies it once ready. Failures
    /// are swallowed on purpose: this runs after the conversation is already visible,
    /// so an error here should not interrupt the user — it just leaves the
    /// "New Conversation" placeholder.
    ///
    /// The work runs in `titleTask`, which `reset` and `resume` cancel; this method
    /// waits for it.
    func generateAndSetTitle(from prompt: String) async {
        titleTask?.cancel()
        let task = Task { await performTitleGeneration(from: prompt) }
        titleTask = task
        await task.value
    }

    private func performTitleGeneration(from prompt: String) async {
        guard let orchestrator = aiProvider?.orchestrator else { return }
        let myGeneration = generation
        let instructions = """
        Summarize the prompt into a short title of 5 to 8 words.
        DO NOT use tools, lists, markdown, numbering, or quotes.
        Return only the title text.
        """

        guard let generated = try? await orchestrator.respond(
            to: prompt,
            instructions: instructions,
            need: .lightweight
        ) else { return }
        guard myGeneration == generation, Task.isCancelled == false else { return }

        let normalized = generated
            .replacing("\n", with: " ")
            .replacing("#", with: "")
            .replacing("-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let words = normalized.split(whereSeparator: \.isWhitespace)
        let clipped = words.prefix(8).joined(separator: " ")
        guard clipped.isEmpty == false else { return }

        title = clipped
        persistCurrentTurn()
    }

    private func send(_ prompt: String, config: ModelConfiguration, responseType: ModelResponseType) {
        guard prompt.isReallyEmpty == false, aiProvider != nil else { return }
        pubMedStore?.reset()
        let trimmedPrompt = prompt.trimmed
        let userMessage = ChatMessage(content: trimmedPrompt, isUser: true)
        append(userMessage)

        let resolvedPrompt = resolvedMedicalPrompt(for: trimmedPrompt)

        if let clarifyingQuestion = MedicalPromptAnalyzer.clarifyingQuestion(for: resolvedPrompt) {
            append(ChatMessage(content: clarifyingQuestion, isUser: false))
            return
        }

        let instructions = Self.instructions(from: config)
        let request = ModelRequest(
            instructions: instructions,
            options: config.generationOptions,
            userMessage: userMessage,
            snapshot: Self.orderedMessages(from: messages),
            characterBudget: max(0, Self.contextCharacterBudget - (instructions?.count ?? 0))
        )

        // Set before any suspension so a second send can't start a parallel response.
        isResponding = true
        let sendGeneration = generation
        responseTask = Task {
            defer { if sendGeneration == generation { isResponding = false } }
            var request = request
            await compactIfNeeded(&request, prompt: resolvedPrompt)
            guard sendGeneration == generation else { return }
            switch responseType {
            case .standard: await generateStandardResponse(for: resolvedPrompt, request: request, generation: sendGeneration)
            case .streaming: await generateStreamingResponse(for: resolvedPrompt, request: request, generation: sendGeneration)
            case .human: await generateHumanResponse(for: resolvedPrompt, request: request, generation: sendGeneration)
            }
        }
    }

    /// On iOS 26.4+, halves the history budget when the history plus the prompt
    /// already fill most of the first model's context window.
    private func compactIfNeeded(_ request: inout ModelRequest, prompt: String) async {
        guard #available(iOS 26.4, macOS 26.4, *) else { return }
        guard let orchestrator = aiProvider?.orchestrator else { return }
        // `contextUsage` has no prompt parameter; a trailing user turn is counted as
        // the same transcript prompt entry the real call sends.
        let usage = await orchestrator.contextUsage(
            instructions: request.instructions,
            history: request.history(isExcluded: isExcludedFromHistory) + [.user(prompt)]
        )
        guard (usage?.fraction ?? 0) >= Self.contextCompactionThreshold else { return }
        request.characterBudget /= 2
    }

    /// Generates a response using the standard (non-streaming) approach. Handles
    /// context window overflow by compacting the history and retrying.
    private func generateStandardResponse(for prompt: String, request: ModelRequest, generation: Int) async {
        guard generation == self.generation else { return }
        isResponding = true
        defer { if generation == self.generation { isResponding = false } }

        let response = await generateResponseWithRecovery(for: prompt, request: request)
        guard generation == self.generation else { return }
        if let response {
            finish(response, for: request)
            append(makeAssistantMessage(from: response))
        } else {
            appendRecoveryFailureMessage()
        }
    }

    /// Generates a response using streaming, updating the UI as tokens arrive. Handles
    /// failures by compacting the history and retrying without streaming.
    private func generateStreamingResponse(for prompt: String, request: ModelRequest, generation: Int) async {
        guard generation == self.generation else { return }
        isResponding = true
        defer { if generation == self.generation { isResponding = false } }

        let messageId = UUID()
        let timestamp = Date()
        var messageIndex: Int?

        do {
            let preparedRequest = await prepareModelRequest(for: prompt)
            guard generation == self.generation else { return }
            switch preparedRequest {
            case .assistantResponse(let response):
                append(makeAssistantMessage(from: response, id: messageId, timestamp: timestamp))
            case .prompt(let preparedPrompt):
                guard let reply = try await streamReply(
                    to: preparedPrompt,
                    request: request,
                    generation: generation,
                    placeholder: (messageId, timestamp),
                    messageIndex: &messageIndex
                ) else { return }
                let response = buildAssistantResponse(from: reply.content, providerName: reply.providerName)
                var final = response
                if isRefusalMessage(response.content) {
                    let recovered = await recoverAfterFailure(for: prompt, request: request)
                    guard generation == self.generation else { return }
                    final = recovered ?? recoveryFailureResponse
                }
                finish(final, for: request)
                replaceStreamedMessage(
                    at: &messageIndex,
                    with: makeAssistantMessage(from: final, id: messageId, timestamp: timestamp)
                )
            }
        } catch {
            guard generation == self.generation else { return }
            let recovered = await response(afterFailure: error, for: prompt, request: request, retriesOther: true)
            guard generation == self.generation else { return }
            let final = recovered ?? recoveryFailureResponse
            finish(final, for: request)
            replaceStreamedMessage(
                at: &messageIndex,
                with: makeAssistantMessage(from: final, id: messageId, timestamp: timestamp)
            )
        }
    }

    /// Streams the reply into a placeholder assistant message, appending each text
    /// delta. Returns the full text and its provenance, or `nil` if the conversation
    /// was superseded mid-stream.
    private func streamReply(
        to prompt: String,
        request: ModelRequest,
        generation: Int,
        placeholder: (id: UUID, timestamp: Date),
        messageIndex: inout Int?
    ) async throws -> StreamedReply? {
        guard let orchestrator = aiProvider?.orchestrator else { return nil }
        var content = ""
        var providerName: String?
        let stream = await orchestrator.streamDetailed(
            to: prompt,
            instructions: request.instructions,
            history: request.history(isExcluded: isExcludedFromHistory),
            tools: AppLanguageModel.tools,
            options: request.options
        )

        for try await event in stream {
            guard generation == self.generation else { return nil }
            switch event {
            case .began(let provider, let privacyLevel):
                providerName = Self.providerName(provider: provider, privacyLevel: privacyLevel)
            case .text(let delta):
                content += delta
                let message = ChatMessage(
                    id: placeholder.id,
                    content: content,
                    isUser: false,
                    timestamp: placeholder.timestamp,
                    providerName: providerName
                )
                withAnimation(.default) {
                    if let messageIndex {
                        messages[messageIndex] = message
                    } else {
                        messages.append(message)
                        messageIndex = messages.endIndex - 1
                    }
                }
            }
        }
        guard generation == self.generation else { return nil }
        return StreamedReply(content: content, providerName: providerName)
    }

    private func replaceStreamedMessage(at messageIndex: inout Int?, with message: ChatMessage) {
        if let messageIndex {
            messages[messageIndex] = message
        } else {
            messages.append(message)
        }
        persistCurrentTurn()
    }

    /// Generates a response with simulated human-like typing delays.
    private func generateHumanResponse(for prompt: String, request: ModelRequest, generation: Int) async {
        guard generation == self.generation else { return }
        let startTime = ContinuousClock.now

        do {
            try await Task.sleep(for: .seconds(2))
            guard generation == self.generation else { return }
            isResponding = true

            guard let response = await generateResponseWithRecovery(for: prompt, request: request) else {
                guard generation == self.generation else { return }
                appendRecoveryFailureMessage()
                isResponding = false
                return
            }
            guard generation == self.generation else { return }
            let simulatedTime = Duration.seconds(1 + Double(response.content.count) * 0.02)

            if ContinuousClock.now - startTime < simulatedTime {
                try await Task.sleep(for: simulatedTime - (.now - startTime))
            }

            guard generation == self.generation else { return }
            finish(response, for: request)
            append(makeAssistantMessage(from: response))
        } catch {
            guard generation == self.generation else { return }
            appendErrorMessage()
        }

        if generation == self.generation {
            isResponding = false
        }
    }

    private func appendErrorMessage() {
        append(ChatMessage(content: Self.genericErrorMessage, isUser: false))
    }

    private func appendRecoveryFailureMessage() {
        append(ChatMessage(content: Self.recoveryFailureMessage, isUser: false))
    }

    private func sanitizedResponse(_ response: String) -> String {
        response
            .split(whereSeparator: \.isNewline)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Sources:") == false }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Answers `prompt` without streaming. Refusals, guardrail violations and context
    /// overflow retry once with a compacted history. Returns `nil` when no answer could
    /// be produced.
    private func generateResponseWithRecovery(for prompt: String, request: ModelRequest) async -> AssistantResponse? {
        guard let orchestrator = aiProvider?.orchestrator else { return nil }
        do {
            let preparedRequest = await prepareModelRequest(for: prompt)
            switch preparedRequest {
            case .assistantResponse(let response):
                return response
            case .prompt(let preparedPrompt):
                let response = try await orchestrator.respondDetailed(
                    to: preparedPrompt,
                    instructions: request.instructions,
                    history: request.history(isExcluded: isExcludedFromHistory),
                    tools: AppLanguageModel.tools,
                    options: request.options
                )
                let assistantResponse = buildAssistantResponse(from: response)
                if isRefusalMessage(assistantResponse.content) {
                    return await recoverAfterFailure(for: prompt, request: request)
                }
                return assistantResponse
            }
        } catch {
            return await response(afterFailure: error, for: prompt, request: request, retriesOther: false)
        }
    }

    /// Reacts to the error that ended the first attempt at a turn. Returns the reply
    /// to show, or `nil` for the generic recovery-failure copy.
    ///
    /// - Guardrail violations retry once on device only, so blocked content never
    ///   reaches the cloud.
    /// - Context overflow retries once through the full chain.
    /// - When nothing could answer on device and no cloud model was allowed, retries
    ///   once on device with half the history before saying so.
    /// - A rejected cloud key or request never retries.
    /// - Anything else retries only when `retriesOther` is set (streaming).
    private func response(
        afterFailure error: any Error,
        for prompt: String,
        request: ModelRequest,
        retriesOther: Bool
    ) async -> AssistantResponse? {
        let kind = Self.failureKind(of: error)
        switch kind {
        case .guardrailViolation:
            markBlocked(request)
            return await recoverAfterFailure(for: prompt, request: request, onDeviceOnly: true)
        case .contextWindowExceeded:
            return await recoverAfterFailure(for: prompt, request: request)
        case .staysOnDevice:
            return await retryOnDeviceCompacted(for: prompt, request: request)
        case .keyRejected, .requestRejected:
            return cloudRejectionResponse(for: kind)
        case .other:
            guard retriesOther else { return nil }
            return await recoverAfterFailure(for: prompt, request: request)
        }
    }

    /// The last resort before telling the user a request stayed on device: one retry on
    /// the on-device model with the history rebuilt at half the character budget. This
    /// keeps on-device compaction ahead of the cloud even when the user declined the
    /// cloud prompt. Returns the stayed-on-device copy if the retry fails too.
    private func retryOnDeviceCompacted(for prompt: String, request: ModelRequest) async -> AssistantResponse {
        var compacted = request
        compacted.characterBudget /= 2
        let recovered = await recoverAfterFailure(
            for: prompt,
            request: compacted,
            onDeviceOnly: true,
            excludingLastAssistant: false
        )
        return recovered ?? stayedOnDeviceResponse
    }

    /// Retries once with a compacted history that, by default, also drops the last
    /// assistant turn. `onDeviceOnly` retries on the on-device orchestrator, so content
    /// the on-device guardrails blocked is never forwarded to a cloud model.
    private func recoverAfterFailure(
        for prompt: String,
        request: ModelRequest,
        onDeviceOnly: Bool = false,
        excludingLastAssistant: Bool = true
    ) async -> AssistantResponse? {
        guard let aiProvider else { return nil }
        let orchestrator = onDeviceOnly ? aiProvider.onDeviceOrchestrator : aiProvider.orchestrator
        do {
            let preparedRequest = await prepareModelRequest(for: prompt)
            switch preparedRequest {
            case .assistantResponse(let response):
                return response
            case .prompt(let preparedPrompt):
                let response = try await orchestrator.respondDetailed(
                    to: preparedPrompt,
                    instructions: request.instructions,
                    history: request.history(
                        excludingLastAssistant: excludingLastAssistant,
                        isExcluded: isExcludedFromHistory
                    ),
                    tools: AppLanguageModel.tools,
                    options: request.options
                )
                let assistantResponse = buildAssistantResponse(from: response)
                return isRefusalMessage(assistantResponse.content) ? nil : assistantResponse
            }
        } catch {
            let kind = Self.failureKind(of: error)
            switch kind {
            case .guardrailViolation:
                markBlocked(request)
                return nil
            case .staysOnDevice:
                // The on-device retry is terminal; a full-chain retry gets one compacted
                // on-device attempt, like the first try.
                if onDeviceOnly {
                    return stayedOnDeviceResponse
                }
                return await retryOnDeviceCompacted(for: prompt, request: request)
            case .keyRejected, .requestRejected:
                return cloudRejectionResponse(for: kind)
            case .contextWindowExceeded, .other:
                return nil
            }
        }
    }

    /// Sorts a model error into how the conversation should react to it.
    private static func failureKind(of error: any Error) -> FailureKind {
        switch error as? ProviderError {
        case .guardrailViolation:
            .guardrailViolation
        case .contextWindowExceeded:
            .contextWindowExceeded
        case .privacyRestricted, .noProviderAvailable, .capabilityUnavailable:
            .staysOnDevice
        case .unauthorized:
            .keyRejected
        case .api:
            .requestRejected
        default:
            .other
        }
    }

    /// The cloud model's display name when it answered, or `nil` for on-device answers.
    private static func providerName(provider: ProviderIdentifier, privacyLevel: PrivacyLevel) -> String? {
        guard privacyLevel != .onDevice else { return nil }
        return ConsentDestination(provider: provider, privacyLevel: privacyLevel)?.displayName
    }

    /// Pure string matching against known refusal phrasing — no model call
    /// involved, kept `internal` (not `private`) so it's directly unit-testable.
    func isRefusalMessage(_ content: String) -> Bool {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Self.refusalPhrases.contains { normalized.localizedStandardContains($0) }
    }

    private var recoveryFailureResponse: AssistantResponse {
        Self.appCopyResponse(Self.recoveryFailureMessage)
    }

    private var stayedOnDeviceResponse: AssistantResponse {
        Self.appCopyResponse(Self.stayedOnDeviceMessage)
    }

    private static func appCopyResponse(_ content: String) -> AssistantResponse {
        AssistantResponse(content: content, toolNames: [], toolSources: [], providerName: nil, isAppCopy: true)
    }

    /// Whether `content` is copy the app shows in place of an answer. Such replies
    /// carry no conversation content, so they are left out of the history.
    static func isAppGeneratedCopy(_ content: String) -> Bool {
        appGeneratedCopy.contains(content)
    }

    private static var appGeneratedCopy: Set<String> {
        let vendorNames = CloudVendor.allCases.map { Optional(ConsentDestination.vendor($0).displayName) } + [nil]
        let cloudCopy = vendorNames.flatMap { name in
            [keyRejectedMessage(vendorName: name), requestRejectedMessage(vendorName: name)]
        }
        return Set([stayedOnDeviceMessage, recoveryFailureMessage, genericErrorMessage] + cloudCopy)
    }

    /// Shown when a cloud provider rejects the API key. Names the vendor when known.
    static func keyRejectedMessage(vendorName: String?) -> String {
        let name = vendorName ?? String(localized: "The cloud model")
        return String(localized: "\(name) didn't accept your API key. Check it in Settings › Provider.")
    }

    /// Shown when a cloud provider's API refuses the request. Names the vendor when known.
    static func requestRejectedMessage(vendorName: String?) -> String {
        let name = vendorName ?? String(localized: "The cloud model")
        return String(localized: "\(name) couldn't take this request. Check your API key in Settings › Provider.")
    }

    /// The cloud vendor that most likely failed: the only one with a key, if exactly
    /// one is configured. Volta's errors don't say which provider threw them.
    private var likelyCloudVendorName: String? {
        guard let vendors = aiProvider?.configuredVendors, vendors.count == 1, let vendor = vendors.first else {
            return nil
        }
        return ConsentDestination.vendor(vendor).displayName
    }

    private func cloudRejectionResponse(for kind: FailureKind) -> AssistantResponse {
        let message = kind == .keyRejected
            ? Self.keyRejectedMessage(vendorName: likelyCloudVendorName)
            : Self.requestRejectedMessage(vendorName: likelyCloudVendorName)
        return Self.appCopyResponse(message)
    }

    /// Assistant replies to leave out of the history: model refusals and app copy.
    private func isExcludedFromHistory(_ content: String) -> Bool {
        isRefusalMessage(content) || Self.isAppGeneratedCopy(content)
    }

    /// Records that the on-device guardrails blocked this turn. Cleared again if the
    /// turn still ends in a model answer (see `finish(_:for:)`).
    private func markBlocked(_ request: ModelRequest) {
        request.userMessage.wasBlocked = true
    }

    /// Clears a guardrail mark when the turn ended in a real answer after all.
    private func finish(_ response: AssistantResponse, for request: ModelRequest) {
        if response.isAppCopy == false {
            request.userMessage.wasBlocked = false
        }
    }

    private func buildAssistantResponse(from response: AIResponse) -> AssistantResponse {
        buildAssistantResponse(
            from: response.text,
            providerName: Self.providerName(provider: response.provider, privacyLevel: response.privacyLevel)
        )
    }

    private func buildAssistantResponse(from content: String, providerName: String?) -> AssistantResponse {
        AssistantResponse(
            content: sanitizedResponse(content),
            toolNames: currentToolNames(),
            toolSources: currentToolSources(),
            providerName: providerName
        )
    }

    private func prepareModelRequest(for prompt: String) async -> PreparedModelRequest {
        pubMedStore?.reset()

        guard let searchRequest = MedicalPromptAnalyzer.searchRequest(for: prompt) else {
            return .prompt(prompt)
        }

        do {
            let bundle = try await PubMedSearchTool.search(request: searchRequest)
            pubMedStore?.record(sources: bundle.sources)
            return .prompt(synthesisPrompt(for: prompt, bundle: bundle))
        } catch PubMedSearchError.noResults {
            return .assistantResponse(
                AssistantResponse(
                    content: "I couldn't find relevant human PubMed evidence for that question. Try being more specific about the condition, treatment, or outcome you want to check.",
                    toolNames: [],
                    toolSources: [],
                    providerName: nil,
                    isAppCopy: true
                )
            )
        } catch PubMedSearchError.rateLimited {
            return .assistantResponse(
                AssistantResponse(
                    content: "PubMed is temporarily rate-limiting requests, so I couldn't verify that with research right now. Try again in a moment.",
                    toolNames: [],
                    toolSources: [],
                    providerName: nil,
                    isAppCopy: true
                )
            )
        } catch {
            return .assistantResponse(
                AssistantResponse(
                    content: "I couldn't retrieve PubMed evidence right now, so I don't want to guess. Try again in a moment or rephrase the question more specifically.",
                    toolNames: [],
                    toolSources: [],
                    providerName: nil,
                    isAppCopy: true
                )
            )
        }
    }

    private func synthesisPrompt(for prompt: String, bundle: PubMedEvidenceBundle) -> String {
        """
        User question:
        \(prompt)

        PubMed evidence:
        \(PubMedSearchTool.evidenceSummary(for: bundle))

        Instructions:
        - Answer the user's question using only the evidence above for factual medical claims.
        - If the evidence is limited, mixed, indirect, or does not fully answer the question, say so plainly.
        - Do not mention search queries or URLs in the body of the answer.
        """
    }

    private func resolvedMedicalPrompt(for prompt: String) -> String {
        guard MedicalPromptAnalyzer.isMedicalPromptText(prompt) == false else {
            return prompt
        }
        guard messages.count >= 3 else { return prompt }

        let assistantIndex = messages.count - 2
        let assistantMessage = messages[assistantIndex]
        guard assistantMessage.isUser == false, MedicalPromptAnalyzer.isClarifyingQuestion(assistantMessage.content) else {
            return prompt
        }

        for index in stride(from: assistantIndex - 1, through: 0, by: -1) {
            let candidate = messages[index]
            guard candidate.isUser else { continue }
            if MedicalPromptAnalyzer.isMedicalPromptText(candidate.content) {
                return "\(candidate.content) \(prompt)"
            }
        }

        return prompt
    }

    private func currentToolNames() -> [String] {
        (pubMedStore?.wasUsed ?? false) ? ["PubMed"] : []
    }

    private func currentToolSources() -> [ChatMessageSource] {
        (pubMedStore?.sources ?? []).map { source in
            ChatMessageSource(
                title: source.title.replacing("\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines),
                pmid: source.pmid,
                url: source.url
            )
        }
    }

    private func makeAssistantMessage(
        from response: AssistantResponse,
        id: UUID = UUID(),
        timestamp: Date = .now
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            content: response.content,
            isUser: false,
            timestamp: timestamp,
            toolNames: response.toolNames,
            toolSources: response.toolSources,
            providerName: response.providerName
        )
    }

    /// Appends a message to the conversation and persists it immediately. `internal`
    /// (not `private`) so autosave behavior can be driven directly from tests without
    /// requiring a live model call.
    func append(_ message: ChatMessage) {
        messages.append(message)
        persistCurrentTurn()
    }

    /// Inserts the `ChatThread` on the first message of a new conversation, or updates
    /// the existing one on every message after that. Called after every `append` and
    /// after every finalized streamed message, so the conversation is durable as it
    /// happens rather than only when the screen is dismissed.
    func persistCurrentTurn() {
        guard let modelContext, messages.isEmpty == false else { return }

        if let threadId {
            let fetch = FetchDescriptor<ChatThread>(predicate: #Predicate { $0.id == threadId })
            guard let existing = (try? modelContext.fetch(fetch))?.first else { return }
            existing.title = title
            existing.messages = Self.orderedMessages(from: messages)
            existing.lastUpdated = .now
        } else {
            let id = UUID()
            threadId = id
            let thread = ChatThread(
                id: id,
                title: title,
                messages: Self.orderedMessages(from: messages),
                creationDate: .now,
                lastUpdated: .now
            )
            modelContext.insert(thread)
            crossPromoSignal?.bump()
        }

        try? modelContext.save()
    }

    private static let refusalPhrases = [
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
}

private struct AssistantResponse {
    let content: String
    let toolNames: [String]
    let toolSources: [ChatMessageSource]
    /// Display name of the cloud model that answered; `nil` on device.
    let providerName: String?
    /// `true` for copy the app wrote in place of a model answer.
    var isAppCopy = false
}

/// The full text of a streamed reply and who wrote it.
private struct StreamedReply {
    let content: String
    let providerName: String?
}

/// How a send reacts to a model error.
private enum FailureKind {
    /// Retry once with a compacted history, on device only.
    case guardrailViolation
    /// Retry once with a compacted history through the full chain.
    case contextWindowExceeded
    /// Nothing could answer without leaving the device. Retry once on device with a
    /// compacted history, then tell the user.
    case staysOnDevice
    /// The cloud provider didn't accept the API key (`.unauthorized`). Never retried.
    case keyRejected
    /// The cloud provider's API refused the request (`.api`), for example an invalid
    /// key some vendors report this way. Never retried.
    case requestRejected
    /// Show the generic failure copy.
    case other
}

/// Everything a single send needs to call the model, captured when the user sends.
private struct ModelRequest {
    let instructions: String?
    let options: GenerationOptions
    /// The in-flight user message. Marked `wasBlocked` when its turn ends in a
    /// guardrail failure.
    let userMessage: ChatMessage
    /// The ordered conversation at send time, ending with the in-flight user message.
    let snapshot: [ChatMessage]
    /// Character budget for history turns; halved when the context is nearly full.
    var characterBudget: Int

    /// The history to send, without the in-flight user message (it is the prompt).
    func history(excludingLastAssistant: Bool = false, isExcluded: (String) -> Bool) -> [ChatTurn] {
        ChatHistoryBuilder.turns(
            from: snapshot,
            excludingLastAssistant: excludingLastAssistant,
            excludingTrailingUser: true,
            isExcluded: isExcluded,
            characterBudget: characterBudget
        )
    }
}

private enum PreparedModelRequest {
    case prompt(String)
    case assistantResponse(AssistantResponse)
}
