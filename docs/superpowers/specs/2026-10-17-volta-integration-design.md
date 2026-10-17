# VoltaSDK integration (fork-first) — design

Date: 2026-10-17
Status: draft, awaiting approval

## Intent

itsWritten runs entirely on Apple's on-device model today. Users without Apple
Intelligence, or whose on-device model fails (unsupported language, context
window, rate limit), hit a dead end. VoltaSDK (github.com/deruloop/VoltaSDK)
resolves at runtime which model answers a call and walks a fallback chain
(on-device → Private Cloud Compute → third-party cloud) with privacy
disclosure built in.

Volta as published can't carry what itsWritten depends on: its on-device
provider builds bare `LanguageModelSession`s with no tools, no `@Generable`
output, default guardrails, and a single global temperature. Adopting it
unmodified would cost the app its four tools, its permissive guardrails, its
user sampling settings, and the structured-output calls two approved specs
rely on (tool routing extraction, guided-reflection `ThemeExtraction`).

So: **fork VoltaSDK, add what itsWritten needs, ship itsWritten on the fork,
offer the changes upstream later.**

## Goals

1. Every model call in itsWritten goes through Volta with no loss of current
   on-device behavior: tools, `@Generable` structured output, the app's
   guardrails setting, and per-call `GenerationOptions`.
2. Plain chat can fall back to a third-party cloud model (OpenAI / Claude /
   Gemini) using **the user's own API key**, and only after **the user
   consents**.
3. The fork stays close to Volta's style and API (stateless, `ChatTurn`
   history, fallback chain, `PrivacyDisclosure`), with additive,
   source-compatible changes, so it can be proposed upstream.

## Non-goals (for now; these are the upstream roadmap)

- Cloud structured output (`@Generable` → vendor JSON Schema).
- A cloud tool-calling loop.
- iOS 27 `CloudAccountLanguageModel` capabilities (tools / guided generation).
- A developer-paid key. itsWritten ships no API key, ever.
- Personal sign-in (ChatGPT / Claude / Gemini consumer accounts). Volta's
  README documents that all three vendors block this for third-party apps; "the
  user's own account" means an API key.

## Anti-goals (would be failure even if it technically works)

- Any journal text, tool argument, or tool result leaving the device without
  the user having agreed to that destination.
- Content the on-device guardrails blocked being forwarded to the cloud.
  (Volta already treats guardrail violations as terminal; keep it so.)
- A structured-output call (routing, themes) silently answered by a model
  that can't honor the schema.
- Volta's public API breaking for existing Volta users.

## Constraints

- itsWritten deployment target stays iOS 26.0. Volta 1.x builds only with
  Xcode 27 (installed locally: 27.1). Xcode Cloud workflows (being added in
  `itsWritten.xcodeproj/xcshareddata/xcodecloud/`) must select Xcode 27.
- Swift 6 strict concurrency. Volta's `AIOrchestrator` is an actor, and
  everything crossing into it must be `Sendable` (`any Tool` already is;
  structured types need `Generable & Sendable`).
- VoltaSDK has **no license file**. The fork can be built privately, but
  shipping it in the App Store needs a license from the owner first. This is
  a release blocker, not a build blocker.
- Volta's tests use Swift Testing and its `MockProvider`. itsWritten's tests
  use XCTest. Each repo keeps its own style.

## Decisions made with the user

- Fork first, offer upstream later.
- Cloud only with the user's own key. Keys are entered by the user.
- The cloud option is free for everyone, with no purchase gate: it's the
  user's own key. It doesn't interact with Remove Ads or the paywall.
- Ask the user before anything goes to the cloud. Apple's Private Cloud
  Compute (iOS 27) and third-party vendors are separate crossings, each
  needing consent.
- On the cloud, plain chat only. Tools, guided reflection, and routing
  extraction stay on-device.
- If the on-device model is unavailable on a chat message that would
  normally carry tools, and a key is configured, **send it to the cloud as
  plain chat without tools** (after consent).

## Part 1 — Fork changes (VoltaSDK)

### 1.1 On-device passthrough

`OnDeviceProvider` gains:

- **Configurable model.** `AIConfiguration.onDeviceModel: SystemLanguageModel`
  (default `.default`). Used for availability *and* sessions, so itsWritten
  can pass `SystemLanguageModel(guardrails: .permissiveContentTransformations)`.
- **Tools.** Sessions are built with the call's tools
  (`LanguageModelSession(model:tools:instructions:)` /
  `(model:tools:transcript:)`). Foundation Models runs the tool loop itself.
- **Options.** The call's `GenerationOptions` are passed to
  `respond`/`streamResponse`.
- **Structured output.** `respond(to:generating:…)` returns `Content` via
  `session.respond(to:generating:options:)`. Non-streaming only: no current
  caller needs streamed structured output.
- **Warm-session cache key.** Today it's (instructions, history). It must also
  include the model identity and the tool set (by tool `name`; tools aren't
  `Equatable`), so a cached tool-free session is never reused for a tool call
  and the reverse never happens either. Options aren't session state and
  don't affect the key.
- **Prewarm.** `AIOrchestrator.prewarm(instructions:tools:)` prewarms the
  on-device session it would check out next (itsWritten prewarms today).
  No-op if on-device isn't first available.

### 1.2 Capabilities and capability-aware fallback

A new optional protocol, so existing `ModelProvider` conformers are untouched:

```swift
public protocol FoundationModelsCapableProvider: ModelProvider {
    func respond(to:instructions:history:tools:options:) async throws -> String
    func streamResponse(to:instructions:history:tools:options:) -> AsyncThrowingStream<String, Error>
    func respond<Content: Generable & Sendable>(
        to:generating:instructions:history:tools:options:
    ) async throws -> Content
}
```

`OnDeviceProvider` adopts it. (Builder's call whether `PrivateCloudComputeProvider`
can adopt it too: it's Foundation Models-backed on iOS 27. If it can, it
must. Otherwise leave it plain.)

Orchestrator rules, applied inside the existing loops (`respondDetailed`,
`runStream`) before the token pre-flight and privacy gate:

| Call carries | Capable provider | Plain provider |
|---|---|---|
| nothing extra | plain path | plain path |
| `tools` and/or `options` | capable path | **plain path, tools and options dropped** (the cloud keeps Volta's configured temperature) |
| `generating:` type | capable path | **skipped** (never asked, never sent data); if nothing capable remains, throw a new `ProviderError.capabilityUnavailable` |

Skipping happens *before* the privacy gate, the same way the context
pre-flight already does, so the user is never asked about a provider that
can't serve the call.

### 1.3 Public API (additive overloads)

Volta's package floor is iOS 18, so the existing methods can't take
FoundationModels types. Instead, new `@available(iOS 26.0, macOS 26.0, *)`
overloads take a **required** `tools:` label (which also avoids overload
ambiguity with the existing methods) and a defaulted `options:`:

```swift
respond(to:instructions:history:need:tools: [any Tool], options: GenerationOptions? = nil)
respondDetailed(…same…)
streamResponse(…same…)
streamDetailed(…same…)
```

Plus one new method:

```swift
func respond<Content: Generable & Sendable>(
    to prompt: String,
    generating type: Content.Type,
    instructions: String? = nil,
    history: [ChatTurn] = [],
    tools: [any Tool] = [],
    options: GenerationOptions? = nil,
    need: ModelNeed? = nil
) async throws -> Content
```

Structured calls always build a fresh on-device session and never use the
warm-session cache: their output isn't chat text, so there's no history to
continue.

All of this is `@available(iOS 26.0, macOS 26.0, *)` where it touches
FoundationModels types, consistent with Volta's gating.

### 1.4 Token pre-flight

On 26.4+, `tokenCount` must include the tool definitions when the call
carries tools (tool schemas take real space in the on-device window). If
there's no API to count them, add a conservative estimate and document it.

### 1.5 Tests (in the fork, Swift Testing)

- Capable vs plain routing for each row of the table, using mocks
  (extend `MockProvider` or add a `MockCapableProvider`).
- A structured call skips a plain provider, and the privacy handler is never
  invoked for it.
- `capabilityUnavailable` when only plain providers are available.
- Tools dropped on the plain path (the mock records it received none).
- Cache key: a tool call never reuses a tool-free cached session.
- Existing tests pass unchanged (API compatibility).

### 1.6 Upstream shape

Prepare it as one PR, or two if the owner prefers: (a) 1.1 + 1.3 passthrough,
(b) 1.2 capability-aware fallback. Include a CHANGELOG entry and a README
section. Proposing it is a separate, later step.

## Part 2 — itsWritten integration

### 2.1 Dependency

The fork is made from upstream `main` (1.1.0) on the user's GitHub account
and cloned next to this repo (`~/Desktop/Projects/iOS/VoltaSDK`). During
development itsWritten references it as a **local package** so fork and app
changes iterate together. Before merge or release it switches to the fork's
git URL, pinned to a branch or tag until upstream merges. Product
`VoltaSDK` only (`VoltaSDKUI` isn't needed, see 2.6). *(My call.)* Creating
the fork on GitHub is outward-facing: confirm with the user at that step.

itsWritten work happens on branch `feature/volta-integration`. Fork work
happens on a branch in the fork, not on its `main`, so the upstream PR stays
clean.

### 2.2 Configuration (`AppLanguageModel`)

`AppLanguageModel` becomes the single place that configures Volta at launch:

- `enableOnDevice = true`, `onDeviceModel = SystemLanguageModel(guardrails: .permissiveContentTransformations)`
- `preference = .preferOnDevice`
- `userAccounts` built from keys in the Keychain (zero or more vendors)
- `privacyDisclosure = .askOnPrivacyChange { await consent.request($0) }`
- `enablePrivateCloudCompute`: on (it only appears on iOS 27 with the
  entitlement; consent still applies)
- no `developerKey`

`AppLanguageModel.tools` stays the tool list. `AppLanguageModel.model` stays
for `ProviderView`'s supported-language list and `AvailabilityView`.

When the user adds or removes a key, the orchestrator is reconfigured.
Builder: confirm that `configure` can be called more than once safely, or
switch to an explicit `AIOrchestrator` instance (README §7) owned by the app.

### 2.3 Conversation (`ConversationViewModel`)

- Replace the stored `LanguageModelSession` with history derived from
  `messages`: a pure, unit-tested `[ChatMessage] → [ChatTurn]` mapper. This
  replaces both `buildSession(from:config:)` and the transcript half of
  `compactedSessionFromMessages`. The compaction policy (which messages to
  keep) stays as it is; only its output type changes.
- Chat calls use `streamDetailed`/`respondDetailed` with
  `tools: AppLanguageModel.tools` and `options: config.generationOptions`.
  Volta streams **deltas**, not cumulative snapshots like
  `LanguageModelSession.streamResponse`. The streaming path appends them.
- Context overflow. On 26.4+, before each send, check
  `contextUsage(instructions:history:)`. Above a threshold *(my call: 0.8)*,
  compact the history first, so on-device compaction is preferred over
  falling back to the cloud. Below 26.4, or if counting returns `nil`,
  behavior is whatever the chain does (fallback if a key exists, otherwise
  the existing `.contextWindowExceeded` → compact-and-retry path, now catching
  `ProviderError.contextWindowExceeded`).
- Error mapping. `ProviderError.guardrailViolation` → existing guardrail
  handling. `.privacyRestricted` / `.noProviderAvailable` (user declined, or
  no provider) → a clear in-chat message that the entry stayed on the
  device. Builder writes the copy; use the `writing-for-interfaces` skill.
- Tool sources keep working unchanged: they're recorded through the tool
  stores (`PubMedToolStore` etc.), not read from the transcript.
- The PubMed pre-fetch path (`prepareModelRequest`) stays as it is. Its
  synthesis prompt is plain text, so it works on the cloud too.
- All three response types (standard, streaming, human) move over. Human
  follows whichever of the other two it's built on today.
- The instructions still mention the PubMed tool when a cloud model answers
  without tools. That's acceptable: the PubMed path is pre-fetched app-side
  anyway. *(My call.)*
- Prewarm calls `AIOrchestrator.prewarm`.

### 2.4 Structured and title calls

- Title generation → `respond(to:instructions:need: .lightweight)`, no tools.
  Plain text, so it may go to the cloud under the same consent.
- Routing extraction (tool-routing spec) and `ThemeExtraction` (guided
  reflection) → `respond(to:generating:…)`. On-device only by construction
  (1.2). If those specs are implemented before this one, their call sites move
  over here. If after, they're written against Volta directly. When
  `capabilityUnavailable` is thrown, they fall back the way their own specs
  define for model failure.

### 2.5 Consent (`CloudConsentCoordinator`)

`@MainActor @Observable` class that bridges Volta's async handler to UI:

- `request(_ downgrade: PrivacyDowngrade) async -> Bool` suspends on a
  continuation and publishes a pending request. The view presents a
  confirmation naming the **destination** ("Send to Claude?" / "Send to
  Apple Private Cloud Compute?") and saying what is sent: the message, the
  conversation so far, and research results if any.
- Destination comes from `downgrade.provider` and `downgrade.to`
  (`.external` = third party, `.appleCloud` = PCC). These are separate
  consents.
- **Scope of a "yes":** the current conversation, per destination. *(My
  call; the user didn't object when it was proposed.)* Settings offers
  "Always allow" per destination, off by default.
- Reset or resume of a conversation clears the per-conversation grants.
- Cancellation (view dismissed, conversation reset) resumes the continuation
  with `false`. It must never leak.
- Unit-tested: grant memory, per-destination separation, cancellation.

### 2.6 Settings and provider UI

- `ProviderView`: add a "Cloud models (optional)" section to enter, replace,
  or remove an API key per vendor, stored in the Keychain *(my call: a small
  app-side Keychain wrapper; the builder can reuse `VoltaSDKAuth`'s
  `KeychainTokenStore` if it fits without pulling in OAuth)*. Include each
  vendor's key link (`CloudVendor` has documentation URLs) and the "Always
  allow" toggles.
- Update the footer copy ("runs entirely on your device…"): on-device is
  the default, and the cloud is used only with the user's key and permission.
- Volta's `ModelSelector` / `ProviderStatusList` are **not** used. The app's
  own Form fits its design. *(My call.)*

### 2.7 Availability

`AvailabilityView` / `ModelNotReadyView`: when on-device is unavailable but
a key exists, chat is allowed. Tool-dependent and structured features
(guided reflection) show they need Apple Intelligence. With no key, behavior
stays as it is today, plus a pointer to the cloud option in Settings.

### 2.8 Provenance

`ChatMessage` gains `var providerName: String? = nil` (optional, so existing
stores migrate automatically), set from `AIResponse.provider` /
`.began(provider:)` when a non-on-device provider answered. The chat bubble
shows a small "Answered by Claude" label. *(My call: in a privacy-first app,
users should be able to see when the cloud answered.)*

### 2.9 Tests (itsWritten, XCTest)

- `[ChatMessage] → [ChatTurn]` mapping, including ordering and the
  compaction output.
- Consent coordinator (2.5).
- `ConversationViewModel` with an explicit `AIOrchestrator(providers:)`
  built from Volta's `MockProvider`. This is new testability: today the tests
  can't exercise generation without a live model. Cover: on-device answers,
  fallback to a mock external provider after consent, declined consent →
  stayed-on-device message, provenance stored.

## Left to the builder

- Exact names for the new protocol, error case, and parameters, following
  the Swift API Design Guidelines and Volta's existing naming.
- Whether PCC adopts the capable protocol (1.2).
- Tool-definition token counting method (1.4).
- Reconfiguring vs an explicit instance (2.2).
- UI copy, via `writing-for-interfaces`.

## Open items outside the build

- **License** from the VoltaSDK owner before App Store release.
- **App Store privacy labels and review notes**: data can go to a third
  party chosen by the user, with consent. Update before release.
- Xcode Cloud: select Xcode 27.
