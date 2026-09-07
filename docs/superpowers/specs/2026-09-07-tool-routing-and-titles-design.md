# Tool Routing & Chat Title Generation — Design

**Date:** 2026-09-07
**Status:** Approved in brainstorming; pending spec review

## Problem

Two user-facing quality issues in the chat pipeline:

1. **Tool suggestions are way off.** `MedicalPromptAnalyzer` gates and builds PubMed searches from hard-coded keyword lists (~44 medical keywords, ~11 intervention phrases, ~12 condition phrases). Prompts outside those lists produce wrong search topics (wrong papers cited) or trigger one of two canned clarifying questions far too often. The other three tools (ClinicalTrials, OpenFDA, MedicalCalculator) are always attached to every session alongside PubMed, and the small on-device model routes among all four unreliably.
2. **Chat titles are useless.** `generateAndSetTitle(from:)` runs once, at send time, from the first user prompt only (`HomeContentView.performSend`). For a prompt like "Hello", the freeform title session replies conversationally ("Hello there! How can I help you today?") and that reply is persisted as the permanent thread title. The title never reflects the conversation.

## Decisions made during brainstorming

- Replace keyword extraction with a **model-based structured extraction** (`@Generable` guided generation), accepting one extra short model call per message.
- The extraction step is a **full router**: it decides medical-or-not, best tool (or none), and query fields for all four tools — not just PubMed.
- Clarifying questions become **rare and model-phrased**: only when the router judges a search would be useless; never canned strings.
- Titles are generated **after the first assistant response** from the actual exchange, with a **refresh** as the conversation grows.

## Section A — RequestRouter (replaces MedicalPromptAnalyzer)

### RoutingDecision

New file `Models/Helpers/RequestRouter.swift` (with `RoutingDecision` in its own file per project conventions):

```swift
@Generable
struct RoutingDecision {
    var isMedicalQuestion: Bool
    var bestTool: RoutedTool            // .pubMed, .clinicalTrials, .openFDA, .calculator, .none
    var pubMedQuery: PubMedQueryFields? // topic, population, interventionOrExposure, outcome, studyPreference
    var clarifyingQuestion: String?     // set ONLY when a search would be useless without more info
}
```

`RoutedTool` is a `@Generable`-compatible enum. `PubMedQueryFields` mirrors `PubMedSearchTool.Arguments`' searchable fields (all optional except `topic`), including a `studyPreference` enum (`review`/`trial`/`observational`), defaulting to `review` when absent.

The router runs on a dedicated tool-free session (`AppLanguageModel.sessionWithoutTools`) with fixed instructions, prewarmed at app/session setup to hide latency. It uses `session.respond(to:generating: RoutingDecision.self)` so the schema is guaranteed by guided generation.

Router instructions (final wording during implementation) must state:

- Classify whether the message asks a medical/health question needing evidence.
- Pick at most one tool; pick `none` for greetings, chit-chat, writing tasks, and anything answerable without external data.
- Fill `pubMedQuery` only when `bestTool == .pubMed`.
- Set `clarifyingQuestion` only when the question is so vague that any search would be useless; phrase it naturally for the specific prompt.

### ConversationViewModel flow

`prepareModelRequest(for:)` is rewritten around the router:

- **Router says `.pubMed`** → keep the existing deterministic pipeline (direct `PubMedSearchTool.search` + `synthesisPrompt` + `pubMedStore` source recording), fed by `pubMedQuery` instead of phrase-list extraction. Existing error handling for `.noResults` / `.rateLimited` / other stays.
- **Router says `.clinicalTrials` / `.openFDA` / `.calculator`** → run the main session with **only that tool attached** (new `AppLanguageModel.session(tool:)` variants), so the small model isn't choosing among four tools.
- **Router says `.none` or not medical** → run a **tool-free** session. "Hello" can never trigger a lookup.
- **`clarifyingQuestion` present** → append it as the assistant message (as today), but it is model-phrased. `MedicalPromptAnalyzer.isClarifyingQuestion` string matching is removed; the follow-up merge logic (`resolvedMedicalPrompt`) is replaced by marking the pending-clarification state explicitly on the view model instead of sniffing message text.
- **Router call throws** → fall back to today's behavior: full session with all four tools, prompt passed through unchanged.

Session compaction (`compactedSessionFromMessages`, `buildSession`) must respect the per-request tool set — the compacted session is rebuilt with the same tool selection the router chose for the current turn.

### Deletions

- `Models/Helpers/MedicalPromptAnalyzer.swift` and all keyword/phrase lists.
- Canned clarifying-question strings and `isClarifyingQuestion` detection.
- Tests covering the keyword analyzer; replaced per Testing below.

## Section B — Chat titles

- **Trigger:** title generation moves out of `performSend` into the completion of the first assistant response (all three response paths: standard, streaming, human). Input is a digest: first user prompt + first assistant response, each clipped (~500 chars) to keep the call short.
- **Structured output:** the title session uses `@Generable`:

```swift
@Generable
struct TitleSuggestion {
    @Guide(description: "A 5-8 word noun-phrase title summarizing the conversation topic")
    var title: String
}
```

  This makes a conversational reply structurally impossible.
- **Refresh:** after the assistant response that follows the 5th user message, regenerate once from a clipped whole-conversation digest (most recent messages favored, same character budget as compaction style). One refresh only — titles should stabilize, not churn.
- **Normalization:** keep the existing cleanup (strip newlines/markdown, clip to 8 words).
- **Fallback:** if generation fails or returns empty, use the first user prompt clipped to 8 words. Never persist an assistant greeting as a title.
- **Generation guard:** keep the existing `generation` check so a reset conversation doesn't receive a stale title.

## Files touched

- New: `Models/Helpers/RequestRouter.swift`, `Models/Helpers/RoutingDecision.swift` (+ small types)
- Modified: `Models/ConversationViewModel.swift`, `Models/Helpers/AppLanguageModel.swift`, `Views/Home/HomeContentView.swift`
- Deleted: `Models/Helpers/MedicalPromptAnalyzer.swift`
- Tests: `itsWrittenTests/` — remove analyzer tests; add router-plumbing and title tests

## Testing

Model calls themselves can't run in unit tests (Foundation Models availability), so the seams are protocols:

- `RequestRouting` protocol over the router; `ConversationViewModel` takes an injectable router. Tests stub `RoutingDecision`s and assert: pubmed route hits the search pipeline, other-tool routes build single-tool sessions, `.none` builds tool-free sessions, thrown routing falls back to all-tools, clarifying question short-circuits generation.
- Title logic: injectable title generator; tests assert trigger timing (after first response, refresh after 5th user message), normalization, fallback on failure, and generation-guard behavior.
- Existing PubMed pipeline tests stay; keyword-analyzer tests deleted.

## Error handling summary

| Failure | Behavior |
|---|---|
| Router call throws | Full session, all tools, prompt unchanged (today's behavior) |
| PubMed no results / rate-limited / error | Existing canned responses (unchanged) |
| Title generation fails | First user prompt clipped to 8 words |

## Out of scope

- Changing the PubMed search implementation or synthesis prompt wording.
- Multi-tool turns (router picks at most one tool).
- Removing `ChatMessage.toolNames`/`toolSources` (legacy threads still render sources).
