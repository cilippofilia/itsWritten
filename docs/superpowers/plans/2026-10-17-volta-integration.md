# VoltaSDK Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fork VoltaSDK to carry Foundation Models tools, `@Generable` output, guardrails and per-call options on-device with capability-aware fallback, then move every itsWritten model call onto it, with consent-gated plain-chat fallback to the user's own cloud API key.

**Architecture:** Part 1 (Tasks 1–5) changes a local clone of the VoltaSDK fork: a new `FoundationModelsCapableProvider` protocol adopted by `OnDeviceProvider`, plus a shared gate in the orchestrator that routes each call by what it needs. Part 2 (Tasks 6–12) adds an app-owned `AIProviderStore` (keys → `AIOrchestrator`) and a `CloudConsentCoordinator` (Volta's `.askOnPrivacyChange` → SwiftUI alert), and replaces `ConversationViewModel`'s stored `LanguageModelSession` with `[ChatTurn]` history sent through the orchestrator.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData, FoundationModels, Security (Keychain). Fork tests use Swift Testing (Volta's existing style); itsWritten tests use XCTest (existing style, don't introduce Swift Testing there).

**Spec:** `docs/superpowers/specs/2026-10-17-volta-integration-design.md`

## Global Constraints

- itsWritten deployment target stays iOS 26.0. Build with Xcode 27 (Volta 1.x requires it).
- The fork's package floor stays iOS 18 / macOS 15. Every new API touching FoundationModels types is `@available(iOS 26.0, macOS 26.0, *)`.
- Existing Volta public signatures don't change. New capability arrives as overloads with a **required** `tools:` label.
- Guardrail violations stay terminal in the chain. Blocked content is never forwarded.
- No developer key in itsWritten, ever. Cloud means `AIConfiguration.userAccounts` built from user-entered keys only.
- Structured calls (`generating:`) never reach a provider that isn't `FoundationModelsCapableProvider`, and the privacy handler is never invoked for one.
- Follow `~/.claude/CLAUDE.md`: `@MainActor` on `@Observable` classes, no GCD, `.foregroundStyle`, `Button` over `.onTapGesture`, one type per file, no hard-coded font sizes or padding.
- Fork location: `~/Desktop/Projects/iOS/VoltaSDK`, branch `feature/foundation-models-passthrough`. itsWritten branch: `feature/volta-integration`.
- itsWritten build: `xcodebuild build -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet`
- itsWritten tests: `xcodebuild test -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet -only-testing:itsWrittenTests/<Class>`
- Fork tests: `swift test --package-path ~/Desktop/Projects/iOS/VoltaSDK --filter <SuiteOrTest>`
- Live Foundation Models calls fail in this simulator (known runtime mismatch), so every test goes through Volta mocks. On-device conformance is verified by compiling, plus a manual device run in Task 12.
- SwiftLint must report no errors before each itsWritten commit (`swiftlint` from the repo root).
- Only commit files the task touches. The working tree carries unrelated uncommitted changes (icons, `project.pbxproj`, `ModelConfiguration.swift`). Never `git add -A`.

## Review Focus

1. **Two calls crossing at once** (the title and the chat reply both fall back to Claude) should produce one consent prompt, with both calls getting the same answer. Tested in Task 7 (`testConcurrentRequestsForSameDestinationCoalesce`).
2. **Conversation reset or resume while a consent prompt is open** should dismiss the prompt, resolve the call with "no", and append nothing to the new conversation. Tested in Task 7 (`testResetResolvesPendingWithFalse`) and Task 10 (`testResetDuringPendingConsentAppendsNothing`).
3. **A pasted key with whitespace or a newline** should be trimmed, and an all-whitespace key treated as removal. Tested in Task 8 (`testSetKeyTrimsAndEmptyRemoves`).
4. **A cloud stream that fails after text has appeared** should end with exactly one assistant message: the recovered reply or the failure copy, never duplicated or concatenated text. Tested in Task 10 (`testStreamFailureAfterFragmentsLeavesSingleMessage`).
5. **A user key on iOS 26** must actually produce a chain provider. Volta's `AIConfiguration.userAccounts` doc comment says "ignored on iOS 26", but the code builds `UserAccountRESTProvider` below 27. Pinned in Task 4 (`userAccountsBuildProvidersBelowIOS27`) so a later upstream change can't silently remove the app's cloud tier.

---

## Part 1 — VoltaSDK fork

### Task 1: Fork, clone, baseline

**Files:** none (repository setup)

- [ ] **Step 1: Ask the user to confirm creating the public fork on their GitHub account.** It's outward-facing, so don't run Step 2 without a yes.
- [ ] **Step 2: Fork and clone**

```bash
gh repo fork deruloop/VoltaSDK --clone=false
git clone "https://github.com/$(gh api user --jq .login)/VoltaSDK.git" ~/Desktop/Projects/iOS/VoltaSDK
git -C ~/Desktop/Projects/iOS/VoltaSDK switch -c feature/foundation-models-passthrough
```

- [ ] **Step 3: Baseline**

Run: `swift test --package-path ~/Desktop/Projects/iOS/VoltaSDK`
Expected: all existing suites pass. If anything fails before any change, stop and report it.

### Task 2: Configurable on-device model and tool-aware session cache

**Files (fork):**
- Modify: `Sources/VoltaSDK/AIOrchestrator.swift` (`AIConfiguration`, `buildProviders`)
- Modify: `Sources/VoltaSDK/OnDeviceProvider.swift`
- Modify: `Sources/VoltaSDK/SessionCache.swift`
- Modify: `Sources/VoltaSDK/SessionStreaming.swift` (pass the new cache key through)
- Test: `Tests/VoltaSDKTests/VoltaSDKTests.swift` (new `@Suite("Session cache")`)

**Interfaces:**
- Produces: `AIConfiguration.onDeviceModel: SystemLanguageModel` (iOS 26+, default `.default`, stored type-erased as `_onDeviceModel: (any Sendable)?`, the same pattern as `_customModels`). `OnDeviceProvider.init(model: SystemLanguageModel = .default)`. `SessionCache.checkOut(instructions:history:toolNames:)` and `checkIn(_:instructions:history:toolNames:)`, where `toolNames: [String]` is part of the reuse key.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite("Session cache")
struct SessionCacheTests {
    @Test("A different tool set is a miss")
    func toolSetChangeMisses() {
        let cache = SessionCache()
        cache.checkIn(LanguageModelSession(), instructions: "i", history: [], toolNames: ["echo"])
        #expect(cache.checkOut(instructions: "i", history: [], toolNames: []) == nil)
    }

    @Test("The same tool set is a hit")
    func sameToolSetHits() {
        let cache = SessionCache()
        cache.checkIn(LanguageModelSession(), instructions: "i", history: [], toolNames: ["echo"])
        #expect(cache.checkOut(instructions: "i", history: [], toolNames: ["echo"]) != nil)
    }
}
```

- [ ] **Step 2: Run them** (`--filter SessionCacheTests`). Expected: compile failure, because there is no `toolNames:` label yet.
- [ ] **Step 3: Implement.** Add `toolNames` to `SessionCache.Entry` and to both method signatures. `OnDeviceProvider` stores `model` and uses it in `availability()`, `contextSize`, `tokenCount` and `makeSession`. `makeSession` gains a `tools: [any Tool]` parameter and always uses the `LanguageModelSession(model:tools:instructions:)` / `(model:tools:transcript:)` initializers. Existing plain call sites pass `tools: []`, `toolNames: []`. `buildProviders` passes `config.onDeviceModel`.
- [ ] **Step 4: Run the full fork suite.** Expected: everything passes.
- [ ] **Step 5: Commit** — `git commit -m "Make the on-device model configurable and key the session cache by tool set"`

### Task 3: `FoundationModelsCapableProvider` and the on-device conformance

**Files (fork):**
- Create: `Sources/VoltaSDK/FoundationModelsCapableProvider.swift`
- Modify: `Sources/VoltaSDK/OnDeviceProvider.swift`
- Modify: `Sources/VoltaSDK/SessionStreaming.swift` (`options:` passed to `session.streamResponse(to:options:)`)
- Modify: `Sources/VoltaSDK/FoundationModelsTranscript.swift` (tool definitions in the instructions entry)
- Modify: `Sources/VoltaSDK/Mocks.swift` (add `MockCapableProvider`)
- Test: `Tests/VoltaSDKTests/VoltaSDKTests.swift` (new `@Suite("Foundation Models transcript")`)

**Interfaces:**
- Produces:

```swift
@available(iOS 26.0, macOS 26.0, *)
public protocol FoundationModelsCapableProvider: ModelProvider {
    func respond(to prompt: String, instructions: String?, history: [ChatTurn],
                 tools: [any Tool], options: GenerationOptions) async throws -> String
    func streamResponse(to prompt: String, instructions: String?, history: [ChatTurn],
                        tools: [any Tool], options: GenerationOptions) -> AsyncThrowingStream<String, Error>
    func respond<Content: Generable & Sendable>(to prompt: String, generating type: Content.Type,
                 instructions: String?, history: [ChatTurn],
                 tools: [any Tool], options: GenerationOptions) async throws -> Content
    func tokenCount(prompt: String, instructions: String?, history: [ChatTurn],
                    tools: [any Tool]) async -> Int?
    func prewarm(instructions: String?, tools: [any Tool]) async   // default no-op in an extension
}

// Mocks.swift
@available(iOS 26.0, macOS 26.0, *)
public struct MockCapableProvider: FoundationModelsCapableProvider {
    public struct Call: Sendable, Equatable {
        public let prompt: String
        public let toolNames: [String]
        public let temperature: Double?
        public let generatingTypeName: String?   // String(describing: Content.self), nil for text calls
    }
    public init(identifier: ProviderIdentifier = .onDevice,
                privacyLevel: PrivacyLevel = .onDevice,
                availability: ProviderAvailability = .available,
                outcome: Result<String, ProviderError> = .success(""),
                structuredContent: GeneratedContent? = nil,
                streamFragments: [String]? = nil,
                streamFailure: ProviderError? = nil,
                onCall: (@Sendable (Call) -> Void)? = nil,
                onPrewarm: (@Sendable () -> Void)? = nil)
}
```

- `FoundationModelsTranscript.entries(instructions:history:toolDefinitions:)`, where `toolDefinitions: [Transcript.ToolDefinition] = []`. With non-empty tools and nil instructions it still emits an instructions entry with no segments.

- [ ] **Step 1: Write the failing test**

```swift
@Suite("Foundation Models transcript")
struct FoundationModelsTranscriptTests {
    @Test("Tool definitions land in the instructions entry")
    func toolDefinitionsIncluded() throws {
        let entries = FoundationModelsTranscript.entries(
            instructions: nil, history: [],
            toolDefinitions: [Transcript.ToolDefinition(tool: EchoTool())]
        )
        guard case .instructions(let instructions) = try #require(entries.first) else {
            Issue.record("first entry is not instructions"); return
        }
        #expect(instructions.toolDefinitions.map(\.name) == ["echo"])
    }
}
```

Add test fixtures at the bottom of the test file (Task 4 reuses them):

```swift
struct EchoTool: Tool {
    let name = "echo"
    let description = "Echoes text."
    @Generable struct Arguments { var text: String }
    func call(arguments: Arguments) async throws -> String { arguments.text }
}
@Generable struct Verdict: Sendable, Equatable { var label: String }
```

- [ ] **Step 2: Run** (`--filter FoundationModelsTranscriptTests`). Expected: compile failure.
- [ ] **Step 3: Implement the protocol and conformance.** In `OnDeviceProvider`, the plain `ModelProvider` methods delegate to the new ones with `tools: []`, `options: GenerationOptions()`. The text paths use the cache with `toolNames: tools.map(\.name)`. Structured `respond` always builds a fresh session and never checks in (spec 1.3). `tokenCount(…tools:)` passes `tools.map(Transcript.ToolDefinition.init(tool:))` into the transcript entries. `prewarm` builds the session `makeSession` would build for `(instructions, [], tools)`, calls `session.prewarm()`, and checks it in with `history: []`. Generation errors map through the existing `map(_:)`. `MockCapableProvider` decodes structured output with `try Content(structuredContent)`, throwing `ProviderError.decoding` when it's nil.
- [ ] **Step 4: Run the full fork suite.** Expected: everything passes.
- [ ] **Step 5: Commit** — `git commit -m "Add FoundationModelsCapableProvider and adopt it on-device"`

### Task 4: Capability-aware chain and the new `respond` overloads

**Files (fork):**
- Modify: `Sources/VoltaSDK/AIOrchestrator.swift`
- Modify: `Sources/VoltaSDK/ModelProvider.swift` (`ProviderError.capabilityUnavailable`, not recoverable by fallback)
- Modify: any exhaustive `switch` over `ProviderError` (e.g. `ProviderError+LanguageModel.swift`) the compiler flags
- Test: `Tests/VoltaSDKTests/VoltaSDKTests.swift` (new `@Suite("Capability routing")`)

**Interfaces:**
- Consumes: `FoundationModelsCapableProvider`, `MockCapableProvider` (Task 3).
- Produces (all `@available(iOS 26.0, macOS 26.0, *)`, on `AIOrchestrator`):

```swift
func respond(to prompt: String, instructions: String? = nil, history: [ChatTurn] = [],
             need: ModelNeed? = nil, tools: [any Tool], options: GenerationOptions? = nil) async throws -> String
func respondDetailed(to prompt: String, instructions: String? = nil, history: [ChatTurn] = [],
                     need: ModelNeed? = nil, tools: [any Tool], options: GenerationOptions? = nil) async throws -> AIResponse
func respond<Content: Generable & Sendable>(to prompt: String, generating type: Content.Type,
             instructions: String? = nil, history: [ChatTurn] = [], tools: [any Tool] = [],
             options: GenerationOptions? = nil, need: ModelNeed? = nil) async throws -> Content
```

- Internal: `enum CallRequirement { case plain, prefersFoundationModels, requiresFoundationModels }` and one static gate shared by the buffered and streaming loops, in this order: availability (skip, no error recorded) → capability (`requiresFoundationModels` and not capable → skip, record `.capabilityUnavailable`) → token pre-flight (capable providers count with tools) → privacy gate. The existing `respondDetailed(to:instructions:history:need:)` calls the same walk with `.plain`, so its behavior is unchanged.

- [ ] **Step 1: Write the failing tests** (each builds `AIOrchestrator(providers:privacyDisclosure:)`, collects calls in a `Mutex<[…]>`, and uses `EchoTool` / `Verdict` from Task 3):

```swift
@Suite("Capability routing")
struct CapabilityRoutingTests {
    @Test func toolsReachCapableProvider()          // Call.toolNames == ["echo"]
    @Test func optionsReachCapableProvider()        // GenerationOptions(temperature: 0.9) → Call.temperature == 0.9
    @Test func toolsDroppedOnPlainFallback()        // [capable .unavailable, MockProvider(.userAccount(.anthropic), .external, .success("cloud"))]
                                                    // → returns "cloud"; plain onRespond called once
    @Test func structuredUsesCapableProvider()      // structuredContent = GeneratedContent(properties: ["label": "ok"]) → Verdict(label: "ok")
    @Test func structuredSkipsPlainWithoutAsking()  // [capable .unavailable, plain external], .askOnPrivacyChange counter
                                                    // → throws ProviderError.capabilityUnavailable; counter == 0; plain onRespond never called
    @Test func structuredWithOnlyUnavailableCapableThrowsNoProvider()  // [capable .unavailable] → .noProviderAvailable
    @Test func userAccountsBuildProvidersBelowIOS27() // AIConfiguration(userAccounts: [UserAccount(vendor: .anthropic, apiKey: "sk-ant-x")])
                                                      // → buildUserAccountProviders(from:).count == 1, privacyLevel == .external
}
```

- [ ] **Step 2: Run** (`--filter CapabilityRoutingTests`). Expected: compile failure.
- [ ] **Step 3: Implement** the gate, the overloads and the error case. In the plain fallback branch, call the provider's plain `respond(to:instructions:history:)` (tools and options dropped, spec 1.2).
- [ ] **Step 4: Run the full fork suite.** Expected: everything passes, including all pre-existing `OrchestratorFallbackTests`.
- [ ] **Step 5: Commit** — `git commit -m "Route calls by capability and add tools/structured respond overloads"`

### Task 5: Streaming overloads, prewarm, docs

**Files (fork):**
- Modify: `Sources/VoltaSDK/AIOrchestrator.swift` (`runStream` uses the Task 4 gate)
- Modify: `README.md` (new section "Tools, structured output, and options (iOS 26+)"), `CHANGELOG.md` (Unreleased entry)
- Test: `Tests/VoltaSDKTests/VoltaSDKTests.swift` (extend `CapabilityRoutingTests`)

**Interfaces:**
- Produces (`@available(iOS 26.0, macOS 26.0, *)`):

```swift
func streamResponse(to:instructions:history:need:tools: [any Tool], options: GenerationOptions? = nil) -> AsyncThrowingStream<String, Error>
func streamDetailed(to:instructions:history:need:tools: [any Tool], options: GenerationOptions? = nil) -> AsyncThrowingStream<AIStreamEvent, Error>
func prewarm(instructions: String?, tools: [any Tool]) async   // prewarms the first available provider if it's capable; else no-op
```

- [ ] **Step 1: Write the failing tests**

```swift
@Test func streamWithToolsUsesCapablePath()          // streamFragments ["Hel", "lo"] → .began(.onDevice, .onDevice), .text("Hel"), .text("lo"); Call.toolNames == ["echo"]
@Test func streamToolsDroppedOnPlainFallback()       // capable unavailable → plain external fragments delivered; .began names the plain provider
@Test func streamFailureAfterFragmentSurfaces()      // capable streamFragments ["a"], streamFailure .network(code: 500), plain behind it
                                                     // → error thrown after "a"; plain never called (D16 rule unchanged)
@Test func prewarmHitsFirstAvailableCapable()        // onPrewarm called once
@Test func prewarmSkipsWhenFirstAvailableIsPlain()   // [capable .unavailable, plain] → onPrewarm never called
```

- [ ] **Step 2: Run.** Expected: compile failure.
- [ ] **Step 3: Implement.** Write the README section from spec 1.1–1.4 and the routing table, and add the CHANGELOG entry.
- [ ] **Step 4: Run the full fork suite.** Expected: everything passes.
- [ ] **Step 5: Commit** — `git commit -m "Add tool-aware streaming and prewarm; document passthrough"`. Don't push (the user decides when the fork goes public, spec 1.6).

## Part 2 — itsWritten (branch `feature/volta-integration`)

### Task 6: Package dependency and the Keychain key store

**Files:**
- Modify: `itsWritten.xcodeproj/project.pbxproj` (done by the user in Xcode)
- Create: `itsWritten/Models/AI/APIKeyStoring.swift`
- Create: `itsWritten/Models/AI/KeychainAPIKeyStore.swift`
- Test: `itsWrittenTests/KeychainAPIKeyStoreTests.swift`

**Interfaces:**
- Produces:

```swift
protocol APIKeyStoring: Sendable {
    func key(for vendor: CloudVendor) -> String?
    func setKey(_ key: String?, for vendor: CloudVendor) throws   // nil deletes
}
struct KeychainAPIKeyStore: APIKeyStoring {
    init(service: String = "itsWritten.cloudAPIKeys")   // kSecClassGenericPassword, account = vendor.rawValue,
}                                                      // kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
```

- [ ] **Step 1: Ask the user to add the local package in Xcode.** File › Add Package Dependencies… › Add Local… › `~/Desktop/Projects/iOS/VoltaSDK`, product **VoltaSDK** → target **itsWritten**. Hand-editing the pbxproj is fragile, and it already carries the user's uncommitted edits.
- [ ] **Step 2: Build** (Global Constraints build command). Expected: success.
- [ ] **Step 3: Write the failing tests** (each uses `KeychainAPIKeyStore(service: "itsWrittenTests.\(UUID())")` and deletes in `tearDown`):

```swift
func testRoundTrip()          // setKey("sk-ant-1", .anthropic) → key(.anthropic) == "sk-ant-1"
func testOverwrite()          // set "a" then "b" → "b"
func testNilDeletes()         // set "a", set nil → nil
func testVendorsAreSeparate() // set .openAI only → key(.gemini) == nil
```

- [ ] **Step 4: Run** (`-only-testing:itsWrittenTests/KeychainAPIKeyStoreTests`). Expected: compile failure.
- [ ] **Step 5: Implement**, then run again. Expected: PASS. If `import VoltaSDK` fails in the test target, ask the user to add the product to `itsWrittenTests` as well.
- [ ] **Step 6: Commit** — run `swiftlint`, `git add` only the new files plus the pbxproj hunk that adds the package (check with `git diff itsWritten.xcodeproj/project.pbxproj` and stage it with `git add -p`, leaving the user's other pbxproj edits unstaged), then `git commit -m "Add VoltaSDK fork dependency and Keychain API key store"`.

### Task 7: Consent destination and coordinator

**Files:**
- Create: `itsWritten/Models/AI/ConsentDestination.swift`
- Create: `itsWritten/Models/AI/ConsentRequest.swift`
- Create: `itsWritten/Models/AI/CloudConsentCoordinator.swift`
- Test: `itsWrittenTests/CloudConsentCoordinatorTests.swift`

**Interfaces:**
- Produces:

```swift
enum ConsentDestination: Hashable, Sendable {
    case privateCloudCompute
    case vendor(CloudVendor)
    init?(provider: ProviderIdentifier, privacyLevel: PrivacyLevel)
    // .appleCloud → .privateCloudCompute; .external + provider == .userAccount(v) or v.providerIdentifier → .vendor(v); else nil
    var displayName: String   // "Apple Private Cloud Compute", "OpenAI", "Claude", "Gemini"
    var storageKey: String    // "cloudConsent.alwaysAllow.\(...)"
}
struct ConsentRequest: Identifiable, Equatable { let id: UUID; let destination: ConsentDestination }

@MainActor @Observable final class CloudConsentCoordinator {
    init(defaults: UserDefaults = .standard)
    private(set) var pendingRequest: ConsentRequest?
    func request(_ downgrade: PrivacyDowngrade) async -> Bool
    func respond(allow: Bool)
    func resetConversationGrants()           // clears grants AND resolves every waiter with false
    func isAlwaysAllowed(_ destination: ConsentDestination) -> Bool
    func setAlwaysAllowed(_ allowed: Bool, for destination: ConsentDestination)
}
```

- Rules for `request`: unmappable destination → `false`, no prompt. Always-allowed or already granted this conversation → `true`, no prompt. Otherwise wait. Waiters for the same destination share one prompt. A different destination waits FIFO until the current prompt resolves. `respond(allow: true)` records a grant for the conversation. A decline is not remembered (spec 2.5: a "yes" is what's scoped).

- [ ] **Step 1: Write the failing tests** (`UserDefaults(suiteName: UUID().uuidString)!`; downgrade helper `PrivacyDowngrade(from: .onDevice, to: .external, provider: .userAccount(.anthropic))`):

```swift
func testDestinationMapping()                 // .userAccount(.anthropic)/.external → .vendor(.anthropic), displayName "Claude"; .privateCloudCompute/.appleCloud → .privateCloudCompute; .onDevice → nil
func testRequestPublishesPendingAndResolves() // start request in Task; pendingRequest?.destination == .vendor(.anthropic); respond(allow: true) → true; pendingRequest == nil
func testGrantIsRememberedForConversation()   // after allow, second request returns true with pendingRequest staying nil
func testDeclineIsNotRemembered()             // respond(false) → false; next request publishes a new pending
func testAlwaysAllowSkipsPrompt()             // setAlwaysAllowed(true, .vendor(.anthropic)) → true, no pending; survives a new coordinator on the same defaults
func testDestinationsAreSeparate()            // grant Claude; request .appleCloud still prompts
func testConcurrentRequestsForSameDestinationCoalesce()  // two requests, one pending, one respond(true) → both true
func testResetResolvesPendingWithFalse()      // pending request; resetConversationGrants() → false, pendingRequest nil; next request prompts again
```

- [ ] **Step 2: Run** (`-only-testing:itsWrittenTests/CloudConsentCoordinatorTests`). Expected: compile failure.
- [ ] **Step 3: Implement** with `CheckedContinuation<Bool, Never>` waiters. Every continuation is resumed exactly once.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** — `swiftlint`, then `git commit -m "Add cloud consent coordinator"`

### Task 8: `AIProviderStore` and app wiring

**Files:**
- Create: `itsWritten/Models/AI/AIProviderStore.swift`
- Modify: `itsWritten/Models/Helpers/AppLanguageModel.swift` (keep `model` and `tools`; the session builders are removed in Task 10)
- Modify: `itsWritten/itsWrittenApp.swift` (`@State private var aiProvider = AIProviderStore()`, `.environment(aiProvider)`)
- Test: `itsWrittenTests/AIProviderStoreTests.swift` (+ `itsWrittenTests/InMemoryAPIKeyStore.swift`, a `final class … : APIKeyStoring, @unchecked Sendable` backed by a dictionary)

**Interfaces:**
- Consumes: `APIKeyStoring` (Task 6), `CloudConsentCoordinator` (Task 7), the fork's `AIConfiguration.onDeviceModel`.
- Produces:

```swift
@MainActor @Observable final class AIProviderStore {
    let consent: CloudConsentCoordinator
    private(set) var orchestrator: AIOrchestrator
    private(set) var configuredVendors: Set<CloudVendor>
    var hasCloudFallback: Bool { !configuredVendors.isEmpty }
    init(keyStore: any APIKeyStoring = KeychainAPIKeyStore(), consent: CloudConsentCoordinator = CloudConsentCoordinator())
    init(orchestrator: AIOrchestrator, consent: CloudConsentCoordinator)   // tests: no key store, setKey throws
    func setKey(_ key: String, for vendor: CloudVendor) throws   // trims whitespace/newlines; empty → removal
    func removeKey(for vendor: CloudVendor) throws
    func hasKey(for vendor: CloudVendor) -> Bool
    static func configuration(keys: [CloudVendor: String], consent: CloudConsentCoordinator) -> AIConfiguration
}
```

- `configuration` sets `enableOnDevice = true`, `onDeviceModel = AppLanguageModel.model`, `enablePrivateCloudCompute = true`, `preference = .preferOnDevice`, `developerKey = nil`, `userAccounts` in `CloudVendor.allCases` order, and `privacyDisclosure = .askOnPrivacyChange { await consent.request($0) }`. Any key change rebuilds `orchestrator` (spec 2.2: explicit instance, no `AIOrchestrator.configure`).

- [ ] **Step 1: Write the failing tests**

```swift
func testConfigurationHasNoDeveloperKeyAndPrefersOnDevice()  // developerKey == nil; preference == .preferOnDevice; enableOnDevice
func testConfigurationAsksOnPrivacyChange()                  // if case .askOnPrivacyChange = config.privacyDisclosure
func testUserAccountsFollowVendorOrder()                     // keys [.gemini, .openAI] → userAccounts.map(\.vendor) == [.openAI, .gemini]
func testSetKeyTrimsAndEmptyRemoves()                        // setKey("  sk-1\n", .openAI) → stored "sk-1"; setKey("   ", .openAI) → hasKey false
func testSetKeyRebuildsOrchestrator()                        // let before = store.orchestrator; setKey(...) → store.orchestrator !== before
func testConfiguredVendorsLoadFromStoreAtInit()              // seeded .anthropic → configuredVendors == [.anthropic], hasCloudFallback
```

- [ ] **Step 2: Run** (`-only-testing:itsWrittenTests/AIProviderStoreTests`). Expected: compile failure.
- [ ] **Step 3: Implement** and wire `itsWrittenApp`.
- [ ] **Step 4: Run the tests, then build.** Expected: PASS and build success.
- [ ] **Step 5: Commit** — `swiftlint`, then `git commit -m "Add AIProviderStore and inject it at launch"`

### Task 9: History builder

**Files:**
- Create: `itsWritten/Models/AI/ChatHistoryBuilder.swift`
- Test: `itsWrittenTests/ChatHistoryBuilderTests.swift`

**Interfaces:**
- Produces:

```swift
enum ChatHistoryBuilder {
    /// `messages` must already be ordered (`ConversationViewModel.orderedMessages`).
    static func turns(
        from messages: [ChatMessage],
        excludingLastAssistant: Bool,
        excludingTrailingUser: Bool,
        isRefusal: (String) -> Bool,
        characterBudget: Int
    ) -> [ChatTurn]
}
```

- Same policy as today's `compactedSessionFromMessages`: drop refusal assistant messages, then keep the most recent turns whose summed `text.count` fits `characterBudget`. Callers pass `max(0, 4000 - config.instructions.count)`, which preserves today's 4000-character total that counted the instructions. `excludingTrailingUser` drops the in-flight user message, since Volta takes it as `prompt` (today it was in the transcript *and* sent as the prompt).

- [ ] **Step 1: Write the failing tests**

```swift
func testMapsRolesInOrder()                 // [u"a", a"b"] → [.user("a"), .assistant("b")]
func testDropsTrailingUserWhenAsked()       // [u"a", a"b", u"c"], excludingTrailingUser → [.user("a"), .assistant("b")]
func testDropsLastAssistantWhenAsked()      // [u"a", a"b"], excludingLastAssistant → [.user("a")]
func testSkipsRefusals()                    // isRefusal: { $0 == "no" }; [u"a", a"no"] → [.user("a")]
func testBudgetKeepsMostRecent()            // [u"aaaa", a"bbbb", u"cc"], budget 6 → [.assistant("bbbb"), .user("cc")]
func testZeroBudgetIsEmpty()
```

- [ ] **Step 2: Run** (`-only-testing:itsWrittenTests/ChatHistoryBuilderTests`). Expected: compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** — `swiftlint`, then `git commit -m "Add ChatHistoryBuilder"`

### Task 10: Move `ConversationViewModel` onto the orchestrator, with provenance

**Files:**
- Modify: `itsWritten/Models/ConversationViewModel.swift`
- Modify: `itsWritten/Models/ChatModel.swift` (`ChatMessage.providerName: String? = nil`, plus an init parameter with default `nil`)
- Modify: `itsWritten/Views/Chat/MessageBubble.swift` (caption below assistant content when `providerName != nil`)
- Modify: `itsWritten/Views/Home/HomeView.swift` (pass `aiProvider` into `configure`)
- Modify: `itsWritten/Models/Helpers/AppLanguageModel.swift` (delete the four session builders once nothing references them)
- Test: `itsWrittenTests/ConversationViewModelTests.swift` (extend), `itsWrittenTests/ChatModelTests.swift` (default `providerName` is nil)

**Interfaces:**
- Consumes: `AIProviderStore` (Task 8), `ChatHistoryBuilder` (Task 9), `ConsentDestination.init(provider:privacyLevel:)` (Task 7), the fork's overloads (Tasks 4–5).
- Produces:
  - `configure(modelContext:pubMedStore:crossPromoSignal:aiProvider:)`
  - `private(set) var responseTask: Task<Void, Never>?`, the task `send` starts, so tests can `await viewModel.responseTask?.value`
  - `static let stayedOnDeviceMessage = "This stayed on your device. Apple Intelligence couldn't answer, and nothing was sent to a cloud model."`

Behavior (spec 2.3–2.4, 2.8):
- `session` is removed. Each send builds history with `ChatHistoryBuilder` (`excludingTrailingUser: true`). On 26.4+, if `contextUsage(instructions:history:)?.fraction ?? 0 >= 0.8`, rebuild with half the budget before sending.
- Standard/human → `respondDetailed(to:instructions:history:tools: AppLanguageModel.tools, options: config.generationOptions)`. Streaming → `streamDetailed(…same…)`, appending `.text` deltas and capturing `.began` for provenance.
- `providerName = ConsentDestination(provider:privacyLevel:)?.displayName` when `privacyLevel != .onDevice`, otherwise nil.
- Errors: `ProviderError.guardrailViolation` / `.contextWindowExceeded` → existing `recoverAfterFailure` (history built with `excludingLastAssistant: true`). `.privacyRestricted` / `.noProviderAvailable` / `.capabilityUnavailable` → append `stayedOnDeviceMessage`, no recovery. Anything else → existing recovery-failure copy.
- Title → `respond(to:instructions:need: .lightweight)` (plain overload, no tools). Any throw keeps "New Conversation".
- `reset` and `resume` call `aiProvider.consent.resetConversationGrants()`.
- Prewarm → `await orchestrator.prewarm(instructions:tools:)` inside the existing deferred `Task`.

- [ ] **Step 1: Write the failing tests.** Helper: `makeViewModel(providers: [any ModelProvider], consentAnswer: Bool?)` builds `AIProviderStore(orchestrator: AIOrchestrator(providers: providers, privacyDisclosure: .askOnPrivacyChange { await consent.request($0) }), consent:)`, and a `Task` answers `consent.pendingRequest` with `consentAnswer`. On-device = `MockCapableProvider(...)`, cloud = `MockProvider(identifier: .userAccount(.anthropic), privacyLevel: .external, ...)`. Use non-medical prompts ("I had a long day") so the PubMed pre-fetch never runs.

```swift
func testOnDeviceReplyHasNoProviderName()                // capable .success("ok") → last message "ok", providerName nil
func testToolsAndOptionsReachOnDevice()                  // Call.toolNames == AppLanguageModel.tools.map(\.name); temperature == config.temperature
func testCloudFallbackAfterConsentStoresProviderName()   // capable .unavailable, cloud "hi", answer true → content "hi", providerName "Claude"
func testDeclinedConsentAppendsStayedOnDeviceMessage()   // answer false → last content == ConversationViewModel.stayedOnDeviceMessage; cloud never called
func testStreamingAccumulatesDeltas()                    // .streaming, fragments ["Hel", "lo"] → single assistant message "Hello"
func testStreamFailureAfterFragmentsLeavesSingleMessage() // fragments ["Hel"], streamFailure .network(code: 500), recovery outcome .success("recovered")
                                                          // → exactly one assistant message after the user message, content "recovered"
func testHistoryExcludesInFlightUserMessage()            // second send: recorded history last turn is the previous assistant, prompt is the new text
func testTitleDeclinedKeepsPlaceholder()                 // capable unavailable, answer false → title == "New Conversation"
func testResetDuringPendingConsentAppendsNothing()       // consentAnswer nil (never answered); reset(config:) → await responseTask; messages.isEmpty
```

- [ ] **Step 2: Run** (`-only-testing:itsWrittenTests/ConversationViewModelTests`). Expected: compile failure.
- [ ] **Step 3: Implement.** The `MessageBubble` caption is `Text("Answered by \(providerName)")` with `.font(.caption)` and `.foregroundStyle(.secondary)`.
- [ ] **Step 4: Run** `ConversationViewModelTests` and `ChatModelTests`, then build. Expected: PASS and build success. `grep -rn "AppLanguageModel.session" itsWritten` returns nothing.
- [ ] **Step 5: Commit** — `swiftlint`, then `git commit -m "Route conversations through VoltaSDK with provenance"`

### Task 11: Consent alert and Settings keys

**Files:**
- Create: `itsWritten/Views/Settings/Views/CloudKeysSection.swift`
- Create: `itsWritten/Views/Settings/Views/CloudKeysView.swift` (a `NavigationStack { Form { CloudKeysSection() } }` with a Done button, used by Task 12)
- Create: `itsWritten/Views/Home/CloudConsentAlertModifier.swift` (`ViewModifier` + `func cloudConsentAlert(_ coordinator: CloudConsentCoordinator) -> some View`)
- Modify: `itsWritten/Views/Home/HomeView.swift` (apply `.cloudConsentAlert(aiProvider.consent)`)
- Modify: `itsWritten/Views/Settings/Views/ProviderView.swift` (embed `CloudKeysSection`, new footer)
- Modify: `itsWritten/Views/Settings/Views/ToolsView.swift` (footer note)

**Interfaces:**
- Consumes: `AIProviderStore` from the environment, `CloudConsentCoordinator`, `ConsentDestination`.

Exact copy (spec 2.5–2.6):
- Alert title: `"Send to \(destination.displayName)?"`
- Alert message, vendor: `"Apple Intelligence can't answer this right now. Your message, this conversation, and any research results will be sent to \(name) using your API key."`
- Alert message, Private Cloud Compute: `"Apple Intelligence on this device can't answer this right now. Your message, this conversation, and any research results will be sent to Apple Private Cloud Compute."`
- Buttons: `"Send"` → `respond(allow: true)`. `"Keep on Device"` (cancel role) → `respond(allow: false)`.
- ProviderView footer: `"Apple Intelligence runs on your device by default. If it can't answer and you've added your own API key, itsWritten asks before sending anything to a cloud model."`
- CloudKeysSection header `"Cloud Models (Optional)"`, footer `"Use your own API key. Usage is billed to your account with that provider. Keys are stored in your Keychain on this device."` Per vendor: a `SecureField("API Key", …)`, `"Save"` / `"Remove"` buttons, `Link("Find model names", destination: vendor.modelDocumentationURL)`, and an `"Always Allow"` toggle bound to `consent.setAlwaysAllowed(_:for: .vendor(vendor))`, shown only when a key exists.
- ToolsView footer, appended: `"Tools need Apple Intelligence. Cloud models answer without them."`

- [ ] **Step 1: Implement** the views. The alert binds `isPresented` to `coordinator.pendingRequest != nil` and uses `presenting: coordinator.pendingRequest`. A dismissal without a button counts as `respond(allow: false)`.
- [ ] **Step 2: Run the `writing-for-interfaces` skill** over the copy above. Apply only changes that keep the meaning (destination named, what is sent, whose key).
- [ ] **Step 3: Build.** Expected: success. Update affected `#Preview`s with `.environment(AIProviderStore())`.
- [ ] **Step 4: Manual check in the simulator.** Settings › Provider shows the section, Save stores a key, Remove clears it, and the toggle appears only with a key.
- [ ] **Step 5: Commit** — `swiftlint`, then `git commit -m "Add consent alert and cloud key settings"`

### Task 12: Availability gating and the end-to-end check

**Files:**
- Modify: `itsWritten/Views/Home/AvailabilityView.swift`
- Create: `itsWritten/Views/Unavailable Views/CloudFallbackButton.swift` (`Button("Use Your Own API Key", systemImage: "key")` presenting `CloudKeysView` as a sheet)
- Modify: each view in `itsWritten/Views/Unavailable Views/` reached from `AvailabilityView` (`ModelNotReadyView`, `AINotEnabledView`, `DeviceNotSupportedView`, `UnknownReasonView`): add `CloudFallbackButton()`

**Interfaces:**
- Consumes: `AIProviderStore.hasCloudFallback` (Task 8), `CloudKeysView` (Task 11).

Behavior (spec 2.7):
- When `model?.availability` is `.unavailable(_)` and `aiProvider.hasCloudFallback`, `AvailabilityView` takes the same path as `.available` (onboarding or `HomeView`). Extract that branch into a `ReadyContentView` struct so both cases share it. Don't use a computed view property.
- With no key, the unavailable screens show as today, plus `CloudFallbackButton`. Saving a key flips `hasCloudFallback`, and the view re-renders into `ReadyContentView`.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Build and run the full itsWritten test suite** (Global Constraints test command without `-only-testing`). Expected: build success and all tests passing. Run `swift test` for the fork as well; everything should pass.
- [ ] **Step 3: Manual end-to-end check** (needs the user's own test key; ask the user, never commit a key):
  1. Simulator (on-device fails here): with no key → the unavailable screen and its button; add a Claude key → Home; send "I had a long day" → "Send to Claude?" alert; **Keep on Device** → stayed-on-device message; send again → **Send** → reply with "Answered by Claude"; a follow-up in the same conversation → no prompt; new conversation → prompt again.
  2. Device with Apple Intelligence: chat replies with no caption, and a medical question still shows PubMed sources (tools intact on-device).
- [ ] **Step 4: Commit** — `swiftlint`, then `git commit -m "Allow chat without Apple Intelligence when a cloud key exists"`

## Before merge (not tasks; report status to the user)

- The fork is still a local package. Switching to the fork's git URL needs it pushed, which is the user's call (spec 2.1).
- License from the VoltaSDK owner, App Store privacy labels, and Xcode Cloud on Xcode 27 (spec, "Open items").
- The tool-routing and guided-reflection specs are still unimplemented. When built, their structured calls use `respond(to:generating:…)` (spec 2.4).
