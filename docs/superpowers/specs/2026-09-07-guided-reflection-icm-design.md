# Guided Reflection (ICM-Staged Pipeline) — Design

**Date:** 2026-09-07
**Status:** Approved in brainstorming; pending spec review
**Source:** *Interpretable Context Methodology: Folder Structure as Agentic Architecture* (Van Clief & McDermott, arXiv:2603.16021), adapted to iOS idioms — the essence, not the folder layout.

## Problem

The app's AI reflection is a single monolithic call: entry in, response out. The user cannot see or steer the intermediate reasoning, and every call carries the whole conversation context to a small on-device model that degrades with context size (the app already fights this with `compactedSessionFromMessages`).

ICM's answer, translated to the app: decompose reflection into stages with one job each, give every stage a small scoped context, and put a human review gate between stages where the output is directly editable.

## ICM principles → app mechanisms

| ICM principle | itsWritten mechanism |
|---|---|
| One stage, one job | Fixed 3-stage pipeline: Themes → Reflection → Takeaways |
| Layered, scoped context | Per-stage prompt assembly (`ReflectionContextBuilder`); fresh tool-free session per stage |
| Every output is an edit surface | Review gate UI: editable stage output before the next stage runs |
| Configure the factory, not the product | Layer 3 = the user's `ModelConfiguration` instructions/tone, reused every run |
| Plain text interface / observability | Artifacts are plain strings, persisted as `ChatMessage`s in the existing `ChatThread` |
| Incremental re-run | Regenerate re-runs only the current stage; accepted artifacts untouched |

## Decisions made during brainstorming

- Target is the **guided reflection flow** (not a weekly review, not plumbing-only).
- Guided reflection is an **optional mode**; the existing instant reflection flow is untouched.
- Native implementation (SwiftData + SwiftUI), **not** a literal filesystem workspace.
- No tools in the pipeline; the tool-routing redesign (2026-09-07 spec) stays independent.

## Section A — Pipeline model

### Stages

`Models/Reflection/ReflectionStage.swift` — a value type describing one stage's contract:

```swift
struct ReflectionStage: Identifiable, Equatable {
    let id: String              // "themes", "reflection", "takeaways"
    let name: String            // "Themes", "Reflection", "Takeaways"
    let systemImage: String
    let contract: String        // Layer 2: this stage's instructions
    let includesToneConfig: Bool // whether Layer 3 (user tone) is loaded
    static let pipeline: [ReflectionStage] // the fixed 3-stage sequence
}
```

Stage contracts (final wording during implementation):

1. **Themes** (`includesToneConfig: false`) — read the journal entry, extract 2–4 dominant themes/emotions with a one-line note each. Uses `@Generable ThemeExtraction` (array of `Theme { name, note }`) so structure is guaranteed; rendered to editable plain text (`- Name: note` lines) for the gate.
2. **Reflection** (`includesToneConfig: true`) — write the reflective response to the entry, guided by the accepted themes text. Free text.
3. **Takeaways** (`includesToneConfig: true`) — distill 2–3 gentle insights or questions from the entry + accepted reflection. Free text.

### Context assembly (the five layers)

`Models/Reflection/ReflectionContextBuilder.swift` — pure, stateless, fully unit-testable. Builds the instructions and prompt for a stage:

- **Layers 0–2 (structural):** one fixed identity sentence ("You are the <stage name> step of a private journaling reflection…") + the stage `contract`. Constant strings, ~200–400 tokens.
- **Layer 3 (reference, "internalize as rules"):** the user's `ModelConfiguration.instructions`, included only when `includesToneConfig`, under a "Rules to follow:" heading.
- **Layer 4 (working, "process as input"):** the journal entry, plus each *accepted* prior artifact under its stage name, under an "Input:" heading.

Layer 3 and Layer 4 are structurally separated in the prompt (the paper's factory/product distinction). No stage ever receives another stage's contract. Each stage runs on a **fresh** `AppLanguageModel.sessionWithoutTools(instructions:)` — no transcript carryover, so per-stage context stays small by construction.

### Pipeline state

`Models/Reflection/ReflectionPipelineViewModel.swift` — `@MainActor @Observable`:

- State: `entry: String`, `stageIndex: Int`, `artifacts: [String: String]` (stage id → accepted text), `draft: String` (current stage output being reviewed), `phase` (`.generating`, `.reviewing`, `.failed(message:)`, `.finished`).
- Actions: `start(entry:config:)`, `acceptAndContinue()` (commits the possibly-edited `draft` as the artifact, persists it, runs the next stage), `regenerate()` (re-runs current stage only), `retry()` (after failure).
- Model calls go through an injectable `StageGenerating` protocol (default implementation wraps `LanguageModelSession`), the same seam pattern the tool-routing spec uses.
- Reuses the `generation` guard pattern from `ConversationViewModel` so an abandoned run can't mutate a superseded one.

## Section B — Persistence and handoff

No new SwiftData models. On `start`, the entry is appended as a user `ChatMessage` to a new `ChatThread` (existing `ConversationViewModel.append`/`persistCurrentTurn` machinery). Each **accepted** stage artifact is appended as an assistant message prefixed with its stage name (e.g. `**Themes**\n…`). Consequences, all free:

- History shows guided runs like any thread; resuming works.
- Abandoning mid-run keeps the accepted stages.
- "Continue in chat" after Takeaways is just the normal chatting mode — `buildSession(from:)` already reconstructs the transcript from those messages.
- Title generation runs as today from the entry.

## Section C — Entry point and UI

- `ModelResponseType` gains a fourth case: `case guided = "Guided"`. The existing response-type picker surfaces it with zero new UI; `ConversationViewModel.send` routes `.guided` on a **first** message to the pipeline. Follow-up messages in an existing chat always use standard behavior (a pipeline only makes sense for a fresh entry) — `.guided` on a follow-up falls back to `.streaming`.
- `Views/Reflection/GuidedReflectionView.swift` (+ small subviews per project conventions: `StageProgressHeader`, `AcceptedStageCard`, `StageReviewCard`): progress indicator across the three stages; accepted stages as collapsed cards; the current draft in a `TextEditor` with **Regenerate** and **Continue** buttons; failure state with **Retry**; after Takeaways, **Continue in chat** switches to the normal `MessageListView` surface.
- `ChatConversationView` hosts either the pipeline view or the message list based on the view model's mode.

## Section D — Error handling

| Failure | Behavior |
|---|---|
| Stage generation throws / guardrail | `phase = .failed`; Retry re-runs current stage; accepted artifacts untouched |
| Refusal-phrased output | Treated as failure (reuse `isRefusalMessage`) |
| Empty output | Treated as failure |
| User abandons run (reset/back) | Accepted stages remain persisted in the thread |
| Context overflow | Not expected (scoped contexts are small); if thrown, treated as stage failure |

## Section E — Testing (Swift Testing)

- `ReflectionContextBuilder`: layer composition per stage — themes stage excludes tone config, reflection includes it; accepted artifacts appear under Layer 4 and edited artifacts propagate verbatim; no stage contract leaks into another stage's prompt.
- `ReflectionPipelineViewModel` with a stubbed `StageGenerating`: happy path through three gates; edit-then-continue commits the edited text; regenerate replaces only the draft; failure → retry; generation-guard on reset; persistence calls append the right messages in the right order.
- `ModelResponseType.guided` routing: first message → pipeline, follow-up → fallback.
- Existing tests unaffected.

## Files touched

- **New:** `Models/Reflection/ReflectionStage.swift`, `ReflectionContextBuilder.swift`, `ReflectionPipelineViewModel.swift`, `ThemeExtraction.swift`, `StageGenerating.swift`; `Views/Reflection/GuidedReflectionView.swift` + subview files.
- **Modified:** `Models/Helpers/ModelResponseType.swift`, `Models/ConversationViewModel.swift` (routing + append reuse), `Views/Chat/ChatConversationView.swift` (host pipeline view).
- **Tests:** new `itsWrittenTests/ReflectionContextBuilderTests.swift`, `ReflectionPipelineViewModelTests.swift`.

## Out of scope

- Medical tools inside the pipeline (tool-routing spec is separate and unaffected).
- Configurable or user-authored stages; weekly/multi-entry reviews.
- The paper's Section 6 future work (provenance markers, cross-stage Verify audits) — a natural follow-up once the pipeline exists.
