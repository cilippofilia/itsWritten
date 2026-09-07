# Guided Reflection (ICM) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional "Guided" reflection mode: a three-stage on-device pipeline (Themes → Reflection → Takeaways) with an editable human review gate between stages, per the ICM paper's staged/scoped-context architecture.

**Architecture:** A pure `ReflectionContextBuilder` assembles a small layered prompt per stage; a `ReflectionPipelineViewModel` state machine runs one fresh tool-free `LanguageModelSession` per stage behind a `StageGenerating` protocol seam; accepted artifacts are appended to the existing `ChatThread` as assistant messages, so persistence, history, titles, and post-pipeline chat need no new code.

**Tech Stack:** SwiftUI, SwiftData, FoundationModels (`@Generable` guided generation), `@Observable` view models, XCTest (existing test style — do NOT introduce Swift Testing).

**Spec:** `docs/superpowers/specs/2026-09-07-guided-reflection-icm-design.md`

## Global Constraints

- iOS 26.0+, Swift 6 strict concurrency; `@Observable` classes are `@MainActor`.
- Follow `~/.claude/CLAUDE.md` Swift/SwiftUI rules (`.foregroundStyle`, no `.onTapGesture` for buttons, `Button("Text", systemImage:)`, no computed-property view splitting — new `View` structs instead, one type per file where practical).
- New source files are picked up automatically (project uses file-system-synchronized groups) — **no pbxproj edits**.
- Build: `xcodebuild build -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet`
- Tests: `xcodebuild test -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet` (append `-only-testing:itsWrittenTests/<ClassName>` to scope).
- Foundation Models calls fail in this simulator setup (runtime/macOS version mismatch — known issue); all unit tests therefore go through the `StageGenerating` stub seam and never require a live model.
- Commit after every task. If SwiftLint is installed (`which swiftlint`), it must pass before each commit.

---

### Task 1: Stage definitions and theme extraction types

**Files:**
- Create: `itsWritten/Models/Reflection/ReflectionStage.swift`
- Create: `itsWritten/Models/Reflection/ThemeExtraction.swift`
- Test: `itsWrittenTests/ReflectionStageTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `ReflectionStage` (`id: String`, `name: String`, `systemImage: String`, `contract: String`, `includesToneConfig: Bool`, `static let pipeline: [ReflectionStage]`, `static let themesID/reflectionID/takeawaysID: String`); `ThemeExtraction` (`themes: [Theme]`, `var formattedList: String`), `Theme` (`name: String`, `note: String`).

- [ ] **Step 1: Write the failing test**

`itsWrittenTests/ReflectionStageTests.swift`:

```swift
//
//  ReflectionStageTests.swift
//  itsWrittenTests
//

import XCTest
@testable import itsWritten

final class ReflectionStageTests: XCTestCase {
    func testPipelineHasThreeStagesInOrder() {
        XCTAssertEqual(
            ReflectionStage.pipeline.map(\.id),
            [ReflectionStage.themesID, ReflectionStage.reflectionID, ReflectionStage.takeawaysID]
        )
    }

    func testOnlyThemesStageExcludesToneConfig() {
        let toneFlags = ReflectionStage.pipeline.map(\.includesToneConfig)
        XCTAssertEqual(toneFlags, [false, true, true])
    }

    func testEveryStageHasANonEmptyContract() {
        for stage in ReflectionStage.pipeline {
            XCTAssertFalse(stage.contract.isReallyEmpty, "Stage \(stage.id) has an empty contract")
        }
    }

    func testThemeExtractionFormatsAsDashList() {
        let extraction = ThemeExtraction(themes: [
            Theme(name: "Calm", note: "A quiet morning walk."),
            Theme(name: "Worry", note: "Uncertainty about the week ahead.")
        ])

        XCTAssertEqual(
            extraction.formattedList,
            "- Calm: A quiet morning walk.\n- Worry: Uncertainty about the week ahead."
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet -only-testing:itsWrittenTests/ReflectionStageTests`
Expected: BUILD FAILURE — `ReflectionStage` / `ThemeExtraction` not found.

- [ ] **Step 3: Write the implementation**

`itsWritten/Models/Reflection/ReflectionStage.swift`:

```swift
//
//  ReflectionStage.swift
//  itsWritten
//

import Foundation

/// One step of the guided reflection pipeline. The `contract` is the stage's
/// Layer 2 instructions (ICM): it defines only this stage's job, so no stage
/// ever sees another stage's instructions.
struct ReflectionStage: Identifiable, Equatable {
    let id: String
    let name: String
    let systemImage: String
    let contract: String
    /// Whether the user's configured tone instructions (Layer 3) are loaded
    /// for this stage. Extraction stages run without them.
    let includesToneConfig: Bool

    static let themesID = "themes"
    static let reflectionID = "reflection"
    static let takeawaysID = "takeaways"

    /// The fixed pipeline, in execution order.
    static let pipeline: [ReflectionStage] = [
        ReflectionStage(
            id: themesID,
            name: "Themes",
            systemImage: "tag",
            contract: """
            Read the journal entry and identify 2 to 4 dominant themes or emotions.
            For each, give a short name and a one-sentence note on how it shows up in the entry.
            Do not reflect, advise, or ask questions - extraction only.
            """,
            includesToneConfig: false
        ),
        ReflectionStage(
            id: reflectionID,
            name: "Reflection",
            systemImage: "bubble.left.and.text.bubble.right",
            contract: """
            Write a warm, reflective response to the journal entry, guided by the accepted themes in the input.
            Weave the themes in naturally; do not repeat them as a list.
            """,
            includesToneConfig: true
        ),
        ReflectionStage(
            id: takeawaysID,
            name: "Takeaways",
            systemImage: "lightbulb",
            contract: """
            Distill 2 or 3 gentle takeaways from the journal entry and the reflection: insights to sit with or questions to carry forward.
            Keep each takeaway to one or two sentences.
            """,
            includesToneConfig: true
        )
    ]
}
```

`itsWritten/Models/Reflection/ThemeExtraction.swift`:

```swift
//
//  ThemeExtraction.swift
//  itsWritten
//

import FoundationModels

/// Guided-generation schema for the Themes stage, so the small model cannot
/// reply conversationally where structure is required.
@Generable
struct ThemeExtraction {
    @Guide(description: "2 to 4 dominant themes or emotions found in the journal entry")
    var themes: [Theme]
}

@Generable
struct Theme {
    @Guide(description: "Short theme or emotion name, 1 to 3 words")
    var name: String

    @Guide(description: "One sentence explaining how this theme appears in the entry")
    var note: String
}

extension ThemeExtraction {
    /// Plain-text rendering shown at the review gate, editable like any other artifact.
    var formattedList: String {
        themes.map { "- \($0.name): \($0.note)" }.joined(separator: "\n")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Same command as Step 2. Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add itsWritten/Models/Reflection itsWrittenTests/ReflectionStageTests.swift
git commit -m "feat: add reflection stage definitions and theme extraction schema"
```

---

### Task 2: ReflectionContextBuilder (layered prompt assembly)

**Files:**
- Create: `itsWritten/Models/Reflection/ReflectionContextBuilder.swift`
- Test: `itsWrittenTests/ReflectionContextBuilderTests.swift`

**Interfaces:**
- Consumes: `ReflectionStage` (Task 1), `ModelConfiguration` (existing; `config.instructions: String`, `String.isReallyEmpty` helper).
- Produces: `ReflectionContextBuilder.instructions(for stage: ReflectionStage, config: ModelConfiguration) -> String` and `ReflectionContextBuilder.prompt(for stage: ReflectionStage, entry: String, artifacts: [String: String], stages: [ReflectionStage]) -> String`.

- [ ] **Step 1: Write the failing tests**

`itsWrittenTests/ReflectionContextBuilderTests.swift`:

```swift
//
//  ReflectionContextBuilderTests.swift
//  itsWrittenTests
//

import XCTest
@testable import itsWritten

final class ReflectionContextBuilderTests: XCTestCase {
    private let stages = ReflectionStage.pipeline
    private var themes: ReflectionStage { stages[0] }
    private var reflection: ReflectionStage { stages[1] }
    private var takeaways: ReflectionStage { stages[2] }

    func testInstructionsContainIdentityLineAndContract() {
        let instructions = ReflectionContextBuilder.instructions(for: themes, config: ModelConfiguration())

        XCTAssertTrue(instructions.contains("Themes step"))
        XCTAssertTrue(instructions.contains(themes.contract))
    }

    func testThemesInstructionsExcludeToneConfig() {
        var config = ModelConfiguration()
        config.instructions = "Speak like a pirate."

        let instructions = ReflectionContextBuilder.instructions(for: themes, config: config)

        XCTAssertFalse(instructions.contains("Speak like a pirate."))
        XCTAssertFalse(instructions.contains("Rules to follow:"))
    }

    func testReflectionInstructionsIncludeToneConfigAsRules() {
        var config = ModelConfiguration()
        config.instructions = "Speak like a pirate."

        let instructions = ReflectionContextBuilder.instructions(for: reflection, config: config)

        XCTAssertTrue(instructions.contains("Rules to follow:\nSpeak like a pirate."))
    }

    func testEmptyToneConfigAddsNoRulesSection() {
        var config = ModelConfiguration()
        config.instructions = "   "

        let instructions = ReflectionContextBuilder.instructions(for: reflection, config: config)

        XCTAssertFalse(instructions.contains("Rules to follow:"))
    }

    func testThemesPromptContainsEntryAndNoArtifacts() {
        let prompt = ReflectionContextBuilder.prompt(
            for: themes,
            entry: "Today I walked by the sea.",
            artifacts: [:],
            stages: stages
        )

        XCTAssertTrue(prompt.contains("Journal entry:\nToday I walked by the sea."))
        XCTAssertFalse(prompt.contains("Themes:"))
    }

    func testLaterPromptsIncludeEditedArtifactsVerbatimInStageOrder() {
        let prompt = ReflectionContextBuilder.prompt(
            for: takeaways,
            entry: "Entry text.",
            artifacts: [
                ReflectionStage.themesID: "- Calm: EDITED BY USER",
                ReflectionStage.reflectionID: "An edited reflection."
            ],
            stages: stages
        )

        XCTAssertTrue(prompt.contains("Themes:\n- Calm: EDITED BY USER"))
        XCTAssertTrue(prompt.contains("Reflection:\nAn edited reflection."))
        let themesRange = try? XCTUnwrap(prompt.range(of: "Themes:"))
        let reflectionRange = try? XCTUnwrap(prompt.range(of: "Reflection:"))
        if let themesRange, let reflectionRange {
            XCTAssertTrue(themesRange.lowerBound < reflectionRange.lowerBound)
        }
    }

    func testNoStageContractLeaksIntoAnotherStagesContext() {
        let instructions = ReflectionContextBuilder.instructions(for: reflection, config: ModelConfiguration())
        let prompt = ReflectionContextBuilder.prompt(
            for: reflection,
            entry: "Entry.",
            artifacts: [ReflectionStage.themesID: "- Calm: note"],
            stages: stages
        )

        for other in [themes, takeaways] {
            XCTAssertFalse(instructions.contains(other.contract))
            XCTAssertFalse(prompt.contains(other.contract))
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet -only-testing:itsWrittenTests/ReflectionContextBuilderTests`
Expected: BUILD FAILURE — `ReflectionContextBuilder` not found.

- [ ] **Step 3: Write the implementation**

`itsWritten/Models/Reflection/ReflectionContextBuilder.swift`:

```swift
//
//  ReflectionContextBuilder.swift
//  itsWritten
//

import Foundation

/// Assembles the layered per-stage context (ICM): a fixed identity line and the
/// stage contract (Layers 0-2), the user's tone configuration as rules to
/// internalize (Layer 3), and the entry plus accepted prior artifacts as input
/// to transform (Layer 4). Pure and stateless so layer composition is testable.
enum ReflectionContextBuilder {
    /// Session instructions for a stage: identity + contract, plus tone rules
    /// when the stage opts in.
    static func instructions(for stage: ReflectionStage, config: ModelConfiguration) -> String {
        var parts = [
            "You are the \(stage.name) step of a private, multi-step journaling reflection. Handle only this step.",
            stage.contract
        ]

        if stage.includesToneConfig, config.instructions.isReallyEmpty == false {
            parts.append("Rules to follow:\n\(config.instructions)")
        }

        return parts.joined(separator: "\n\n")
    }

    /// The stage prompt: the journal entry followed by accepted artifacts from
    /// earlier stages, in pipeline order. Edited artifacts pass through verbatim.
    static func prompt(
        for stage: ReflectionStage,
        entry: String,
        artifacts: [String: String],
        stages: [ReflectionStage]
    ) -> String {
        var sections = ["Input:", "Journal entry:\n\(entry)"]

        for prior in stages {
            if prior.id == stage.id { break }
            if let artifact = artifacts[prior.id] {
                sections.append("\(prior.name):\n\(artifact)")
            }
        }

        return sections.joined(separator: "\n\n")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Same command as Step 2. Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add itsWritten/Models/Reflection/ReflectionContextBuilder.swift itsWrittenTests/ReflectionContextBuilderTests.swift
git commit -m "feat: add layered per-stage context builder for guided reflection"
```

---

### Task 3: Extract RefusalDetector

**Files:**
- Create: `itsWritten/Models/Helpers/RefusalDetector.swift`
- Modify: `itsWritten/Models/ConversationViewModel.swift` (replace `isRefusalMessage` body at ~line 471 and delete the `refusalPhrases` static at ~line 631)
- Test: existing `itsWrittenTests/ConversationViewModelTests.swift` (`testIsRefusalMessageDetectsKnownRefusalPhrases`) must keep passing — no new tests.

**Interfaces:**
- Consumes: nothing new.
- Produces: `RefusalDetector.isRefusal(_ content: String) -> Bool` (used by Task 4's pipeline view model). `ConversationViewModel.isRefusalMessage(_:)` keeps its exact signature.

- [ ] **Step 1: Create the detector**

`itsWritten/Models/Helpers/RefusalDetector.swift`:

```swift
//
//  RefusalDetector.swift
//  itsWritten
//

import Foundation

/// Pure string matching against known on-device model refusal phrasing.
/// Shared by the chat flow and the guided reflection pipeline.
enum RefusalDetector {
    static func isRefusal(_ content: String) -> Bool {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return refusalPhrases.contains { normalized.localizedStandardContains($0) }
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
```

- [ ] **Step 2: Delegate from ConversationViewModel**

In `itsWritten/Models/ConversationViewModel.swift`, replace the existing method:

```swift
    /// Pure string matching against known refusal phrasing — no FoundationModels call
    /// involved, kept `internal` (not `private`) so it's directly unit-testable.
    func isRefusalMessage(_ content: String) -> Bool {
        RefusalDetector.isRefusal(content)
    }
```

and **delete** the entire `private static let refusalPhrases = [...]` declaration at the bottom of the class.

- [ ] **Step 3: Run existing tests to verify no regression**

Run: `xcodebuild test -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet -only-testing:itsWrittenTests/ConversationViewModelTests`
Expected: PASS (all existing tests, including the refusal-phrase test).

- [ ] **Step 4: Commit**

```bash
git add itsWritten/Models/Helpers/RefusalDetector.swift itsWritten/Models/ConversationViewModel.swift
git commit -m "refactor: extract RefusalDetector for reuse by the reflection pipeline"
```

---

### Task 4: StageGenerating seam and live generator

**Files:**
- Create: `itsWritten/Models/Reflection/StageGenerating.swift`
- Create: `itsWritten/Models/Reflection/LiveStageGenerator.swift`
- Test: none (this is the FoundationModels boundary — verified by build; behavior around it is tested via stubs in Task 5).

**Interfaces:**
- Consumes: `ReflectionStage`, `ThemeExtraction` (Task 1), `AppLanguageModel.sessionWithoutTools(instructions:)` (existing).
- Produces: `@MainActor protocol StageGenerating { func generate(stage: ReflectionStage, instructions: String, prompt: String) async throws -> String }` and `LiveStageGenerator` conforming to it.

- [ ] **Step 1: Write the protocol**

`itsWritten/Models/Reflection/StageGenerating.swift`:

```swift
//
//  StageGenerating.swift
//  itsWritten
//

import Foundation

/// Seam over the per-stage model call so pipeline behavior is unit-testable
/// without FoundationModels availability.
@MainActor
protocol StageGenerating {
    /// Runs one stage's generation and returns the plain-text artifact.
    func generate(stage: ReflectionStage, instructions: String, prompt: String) async throws -> String
}
```

- [ ] **Step 2: Write the live implementation**

`itsWritten/Models/Reflection/LiveStageGenerator.swift`:

```swift
//
//  LiveStageGenerator.swift
//  itsWritten
//

import FoundationModels

/// Production `StageGenerating`: one fresh tool-free session per stage, so
/// each stage's context contains only what its contract declares. The Themes
/// stage uses guided generation so structure is guaranteed.
struct LiveStageGenerator: StageGenerating {
    func generate(stage: ReflectionStage, instructions: String, prompt: String) async throws -> String {
        let session = AppLanguageModel.sessionWithoutTools(instructions: instructions)

        if stage.id == ReflectionStage.themesID {
            let response = try await session.respond(to: prompt, generating: ThemeExtraction.self)
            return response.content.formattedList
        }

        let response = try await session.respond(to: prompt)
        return response.content
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild build -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add itsWritten/Models/Reflection/StageGenerating.swift itsWritten/Models/Reflection/LiveStageGenerator.swift
git commit -m "feat: add stage generation seam and live FoundationModels generator"
```

---

### Task 5: ReflectionPipelineViewModel (state machine)

**Files:**
- Create: `itsWritten/Models/Reflection/ReflectionPipelineViewModel.swift`
- Test: `itsWrittenTests/ReflectionPipelineViewModelTests.swift`

**Interfaces:**
- Consumes: `ReflectionStage.pipeline`, `ReflectionContextBuilder.instructions(for:config:)` / `.prompt(for:entry:artifacts:stages:)`, `StageGenerating`, `RefusalDetector.isRefusal(_:)`.
- Produces (used by Tasks 6 and 7): `ReflectionPipelineViewModel` — `init(generator: any StageGenerating)`; `Phase` enum (`.idle`, `.generating`, `.reviewing`, `.failed(String)`, `.finished`); properties `stages: [ReflectionStage]`, `stageIndex: Int`, `phase: Phase`, `artifacts: [String: String]`, `draft: String` (settable, bindable), `currentStage: ReflectionStage?`, `acceptedStages: [ReflectionStage]`, `isLastStage: Bool`, callbacks `onArtifactAccepted: ((ReflectionStage, String) -> Void)?`, `onFinished: (() -> Void)?`; methods `start(entry:config:)`, `acceptAndContinue()`, `regenerate()`, `retry()`, `cancel()`; `static let failureMessage: String`.

- [ ] **Step 1: Write the failing tests**

`itsWrittenTests/ReflectionPipelineViewModelTests.swift`:

```swift
//
//  ReflectionPipelineViewModelTests.swift
//  itsWrittenTests
//

import XCTest
@testable import itsWritten

@MainActor
final class ReflectionPipelineViewModelTests: XCTestCase {
    enum StubError: Error { case boom }

    final class StubStageGenerator: StageGenerating {
        var results: [Result<String, Error>]
        private(set) var receivedPrompts: [String] = []
        private(set) var receivedInstructions: [String] = []

        init(results: [Result<String, Error>]) {
            self.results = results
        }

        func generate(stage: ReflectionStage, instructions: String, prompt: String) async throws -> String {
            receivedInstructions.append(instructions)
            receivedPrompts.append(prompt)
            guard results.isEmpty == false else { return "stub output" }
            return try results.removeFirst().get()
        }
    }

    /// Holds generation open until `finish` is called, for stale-result tests.
    final class GatedStageGenerator: StageGenerating {
        private var continuation: CheckedContinuation<String, Error>?

        func generate(stage: ReflectionStage, instructions: String, prompt: String) async throws -> String {
            try await withCheckedThrowingContinuation { self.continuation = $0 }
        }

        func finish(_ value: String) {
            continuation?.resume(returning: value)
            continuation = nil
        }
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while condition() == false {
            if Date() > deadline {
                XCTFail("Timed out waiting for condition")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func testStartGeneratesAndPresentsDraftForReview() async throws {
        let generator = StubStageGenerator(results: [.success("- Calm: a quiet walk")])
        let pipeline = ReflectionPipelineViewModel(generator: generator)

        pipeline.start(entry: "Entry.", config: ModelConfiguration())

        try await waitUntil { pipeline.phase == .reviewing }
        XCTAssertEqual(pipeline.draft, "- Calm: a quiet walk")
        XCTAssertEqual(pipeline.stageIndex, 0)
        XCTAssertTrue(pipeline.acceptedStages.isEmpty)
    }

    func testAcceptCommitsEditedDraftAndAdvances() async throws {
        let generator = StubStageGenerator(results: [
            .success("- Calm: original"),
            .success("A reflection.")
        ])
        let pipeline = ReflectionPipelineViewModel(generator: generator)
        var accepted: [(String, String)] = []
        pipeline.onArtifactAccepted = { stage, text in accepted.append((stage.id, text)) }

        pipeline.start(entry: "Entry.", config: ModelConfiguration())
        try await waitUntil { pipeline.phase == .reviewing }

        pipeline.draft = "- Calm: EDITED"
        pipeline.acceptAndContinue()

        XCTAssertEqual(pipeline.artifacts[ReflectionStage.themesID], "- Calm: EDITED")
        XCTAssertEqual(accepted.first?.0, ReflectionStage.themesID)
        XCTAssertEqual(accepted.first?.1, "- Calm: EDITED")

        try await waitUntil { pipeline.phase == .reviewing && pipeline.stageIndex == 1 }
        XCTAssertTrue(generator.receivedPrompts[1].contains("Themes:\n- Calm: EDITED"))
    }

    func testFullRunFinishesAndFiresCallback() async throws {
        let generator = StubStageGenerator(results: [
            .success("- Calm: note"),
            .success("A reflection."),
            .success("A takeaway.")
        ])
        let pipeline = ReflectionPipelineViewModel(generator: generator)
        var finished = false
        pipeline.onFinished = { finished = true }

        pipeline.start(entry: "Entry.", config: ModelConfiguration())
        for expectedIndex in 0..<3 {
            try await waitUntil { pipeline.phase == .reviewing && pipeline.stageIndex == expectedIndex }
            pipeline.acceptAndContinue()
        }

        XCTAssertEqual(pipeline.phase, .finished)
        XCTAssertTrue(finished)
        XCTAssertEqual(pipeline.artifacts.count, 3)
    }

    func testRegenerateReplacesDraftOnly() async throws {
        let generator = StubStageGenerator(results: [
            .success("First draft"),
            .success("Second draft")
        ])
        let pipeline = ReflectionPipelineViewModel(generator: generator)

        pipeline.start(entry: "Entry.", config: ModelConfiguration())
        try await waitUntil { pipeline.phase == .reviewing }
        pipeline.regenerate()
        try await waitUntil { pipeline.phase == .reviewing && pipeline.draft == "Second draft" }

        XCTAssertEqual(pipeline.stageIndex, 0)
        XCTAssertTrue(pipeline.artifacts.isEmpty)
    }

    func testFailureThenRetryRecovers() async throws {
        let generator = StubStageGenerator(results: [
            .failure(StubError.boom),
            .success("Recovered draft")
        ])
        let pipeline = ReflectionPipelineViewModel(generator: generator)

        pipeline.start(entry: "Entry.", config: ModelConfiguration())
        try await waitUntil { pipeline.phase == .failed(ReflectionPipelineViewModel.failureMessage) }

        pipeline.retry()
        try await waitUntil { pipeline.phase == .reviewing }
        XCTAssertEqual(pipeline.draft, "Recovered draft")
    }

    func testEmptyAndRefusalOutputsFail() async throws {
        let generator = StubStageGenerator(results: [.success("   ")])
        let pipeline = ReflectionPipelineViewModel(generator: generator)
        pipeline.start(entry: "Entry.", config: ModelConfiguration())
        try await waitUntil { pipeline.phase == .failed(ReflectionPipelineViewModel.failureMessage) }

        let refusalGenerator = StubStageGenerator(results: [.success("I'm sorry, but I can't help with that.")])
        let refusalPipeline = ReflectionPipelineViewModel(generator: refusalGenerator)
        refusalPipeline.start(entry: "Entry.", config: ModelConfiguration())
        try await waitUntil { refusalPipeline.phase == .failed(ReflectionPipelineViewModel.failureMessage) }
    }

    func testCancelDiscardsInFlightResult() async throws {
        let generator = GatedStageGenerator()
        let pipeline = ReflectionPipelineViewModel(generator: generator)

        pipeline.start(entry: "Entry.", config: ModelConfiguration())
        XCTAssertEqual(pipeline.phase, .generating)

        pipeline.cancel()
        generator.finish("Stale result")
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(pipeline.phase, .idle)
        XCTAssertEqual(pipeline.draft, "")
    }

    func testAcceptRejectsEmptyDraft() async throws {
        let generator = StubStageGenerator(results: [.success("Draft")])
        let pipeline = ReflectionPipelineViewModel(generator: generator)

        pipeline.start(entry: "Entry.", config: ModelConfiguration())
        try await waitUntil { pipeline.phase == .reviewing }

        pipeline.draft = "   "
        pipeline.acceptAndContinue()

        XCTAssertEqual(pipeline.phase, .reviewing)
        XCTAssertEqual(pipeline.stageIndex, 0)
        XCTAssertTrue(pipeline.artifacts.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet -only-testing:itsWrittenTests/ReflectionPipelineViewModelTests`
Expected: BUILD FAILURE — `ReflectionPipelineViewModel` not found.

- [ ] **Step 3: Write the implementation**

`itsWritten/Models/Reflection/ReflectionPipelineViewModel.swift`:

```swift
//
//  ReflectionPipelineViewModel.swift
//  itsWritten
//

import SwiftUI

/// State machine for one guided reflection run: generates a stage draft, holds
/// it at a review gate where the user can edit it, then commits and advances.
/// Regeneration and retry re-run only the current stage; accepted artifacts
/// are never touched.
@MainActor
@Observable
final class ReflectionPipelineViewModel {
    enum Phase: Equatable {
        case idle
        case generating
        case reviewing
        case failed(String)
        case finished
    }

    let stages = ReflectionStage.pipeline
    private(set) var stageIndex = 0
    private(set) var phase: Phase = .idle
    private(set) var artifacts: [String: String] = [:]
    /// The current stage's output under review. Bindable so the review gate's
    /// text editor writes edits straight back; whatever is here when the user
    /// continues becomes the accepted artifact.
    var draft = ""

    var onArtifactAccepted: ((ReflectionStage, String) -> Void)?
    var onFinished: (() -> Void)?

    private let generator: any StageGenerating
    private var entry = ""
    private var config = ModelConfiguration()
    /// Bumped by every (re)generation and by `cancel()`, so a stale in-flight
    /// result can detect it no longer owns the state. Same pattern as
    /// `ConversationViewModel.generation`.
    private var generation = 0

    init(generator: any StageGenerating = LiveStageGenerator()) {
        self.generator = generator
    }

    var currentStage: ReflectionStage? {
        stages.indices.contains(stageIndex) ? stages[stageIndex] : nil
    }

    var acceptedStages: [ReflectionStage] {
        Array(stages.prefix(stageIndex))
    }

    var isLastStage: Bool {
        stageIndex == stages.count - 1
    }

    func start(entry: String, config: ModelConfiguration) {
        guard phase == .idle else { return }
        self.entry = entry
        self.config = config
        runCurrentStage()
    }

    func acceptAndContinue() {
        guard phase == .reviewing, let stage = currentStage else { return }
        let text = draft.trimmed
        guard text.isEmpty == false else { return }

        artifacts[stage.id] = text
        onArtifactAccepted?(stage, text)
        stageIndex += 1

        if stageIndex >= stages.count {
            phase = .finished
            onFinished?()
        } else {
            runCurrentStage()
        }
    }

    func regenerate() {
        guard phase == .reviewing else { return }
        runCurrentStage()
    }

    func retry() {
        guard case .failed = phase else { return }
        runCurrentStage()
    }

    /// Abandons the run; any in-flight generation result is discarded.
    func cancel() {
        generation += 1
        phase = .idle
        draft = ""
    }

    private func runCurrentStage() {
        guard let stage = currentStage else { return }
        phase = .generating
        draft = ""
        generation += 1
        let myGeneration = generation
        let instructions = ReflectionContextBuilder.instructions(for: stage, config: config)
        let prompt = ReflectionContextBuilder.prompt(for: stage, entry: entry, artifacts: artifacts, stages: stages)

        Task {
            do {
                let output = try await generator.generate(stage: stage, instructions: instructions, prompt: prompt)
                guard myGeneration == generation else { return }
                let cleaned = output.trimmed
                if cleaned.isEmpty || RefusalDetector.isRefusal(cleaned) {
                    phase = .failed(Self.failureMessage)
                } else {
                    draft = cleaned
                    phase = .reviewing
                }
            } catch {
                guard myGeneration == generation else { return }
                phase = .failed(Self.failureMessage)
            }
        }
    }

    static let failureMessage = "Couldn't generate this step. Try again."
}
```

- [ ] **Step 4: Run tests to verify they pass**

Same command as Step 2. Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add itsWritten/Models/Reflection/ReflectionPipelineViewModel.swift itsWrittenTests/ReflectionPipelineViewModelTests.swift
git commit -m "feat: add guided reflection pipeline state machine"
```

---

### Task 6: `.guided` response type and ConversationViewModel routing

**Files:**
- Modify: `itsWritten/Models/Helpers/ModelResponseType.swift` (add case)
- Modify: `itsWritten/Models/ConversationViewModel.swift` (pipeline property, routing in `send`, clearing in `reset`/`resume`)
- Test: `itsWrittenTests/ConversationViewModelGuidedTests.swift` (new file — keeps the existing test class untouched)

**Interfaces:**
- Consumes: `ReflectionPipelineViewModel` (Task 5), `StageGenerating` (Task 4).
- Produces: `ModelResponseType.guided` (rawValue `"Guided"`); `ConversationViewModel.reflectionPipeline: ReflectionPipelineViewModel?` (read by Task 7's views); `ConversationViewModel.stageGenerator: any StageGenerating` (test seam, defaults to `LiveStageGenerator()`).

- [ ] **Step 1: Write the failing tests**

`itsWrittenTests/ConversationViewModelGuidedTests.swift`:

```swift
//
//  ConversationViewModelGuidedTests.swift
//  itsWrittenTests
//

import XCTest
@testable import itsWritten

@MainActor
final class ConversationViewModelGuidedTests: XCTestCase {
    final class StubStageGenerator: StageGenerating {
        var results: [String]

        init(results: [String]) {
            self.results = results
        }

        func generate(stage: ReflectionStage, instructions: String, prompt: String) async throws -> String {
            guard results.isEmpty == false else { return "stub output" }
            return results.removeFirst()
        }
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while condition() == false {
            if Date() > deadline {
                XCTFail("Timed out waiting for condition")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func testGuidedFirstMessageStartsPipelineAndAppendsEntry() async throws {
        let viewModel = ConversationViewModel()
        viewModel.stageGenerator = StubStageGenerator(results: ["- Calm: note"])

        viewModel.startConversation(with: "Today I felt calm.", config: ModelConfiguration(), responseType: .guided)

        XCTAssertEqual(viewModel.mode, .chatting)
        XCTAssertEqual(viewModel.messages.map(\.content), ["Today I felt calm."])
        let pipeline = try XCTUnwrap(viewModel.reflectionPipeline)
        try await waitUntil { pipeline.phase == .reviewing }
    }

    func testGuidedFollowUpDoesNotStartPipeline() {
        let viewModel = ConversationViewModel()
        viewModel.stageGenerator = StubStageGenerator(results: [])
        viewModel.append(ChatMessage(content: "Earlier message", isUser: true))

        viewModel.sendMessage("A follow up", config: ModelConfiguration(), responseType: .guided)

        XCTAssertNil(viewModel.reflectionPipeline)
        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages.last?.content, "A follow up")
    }

    func testAcceptedArtifactsAppendAsStageMessagesAndFinishClearsPipeline() async throws {
        let viewModel = ConversationViewModel()
        viewModel.stageGenerator = StubStageGenerator(results: [
            "- Calm: morning walk",
            "A reflection.",
            "A takeaway."
        ])

        viewModel.startConversation(with: "Entry.", config: ModelConfiguration(), responseType: .guided)
        let pipeline = try XCTUnwrap(viewModel.reflectionPipeline)

        try await waitUntil { pipeline.phase == .reviewing && pipeline.stageIndex == 0 }
        pipeline.acceptAndContinue()
        try await waitUntil { pipeline.phase == .reviewing && pipeline.stageIndex == 1 }
        pipeline.draft = "An edited reflection."
        pipeline.acceptAndContinue()
        try await waitUntil { pipeline.phase == .reviewing && pipeline.stageIndex == 2 }
        pipeline.acceptAndContinue()

        XCTAssertEqual(viewModel.messages.map(\.content), [
            "Entry.",
            "**Themes**\n- Calm: morning walk",
            "**Reflection**\nAn edited reflection.",
            "**Takeaways**\nA takeaway."
        ])
        XCTAssertNil(viewModel.reflectionPipeline)
        XCTAssertEqual(viewModel.mode, .chatting)
    }

    func testResetClearsPipeline() async throws {
        let viewModel = ConversationViewModel()
        viewModel.stageGenerator = StubStageGenerator(results: ["- Calm: note"])
        viewModel.startConversation(with: "Entry.", config: ModelConfiguration(), responseType: .guided)
        XCTAssertNotNil(viewModel.reflectionPipeline)

        viewModel.reset(config: ModelConfiguration())

        XCTAssertNil(viewModel.reflectionPipeline)
        XCTAssertEqual(viewModel.mode, .composing)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet -only-testing:itsWrittenTests/ConversationViewModelGuidedTests`
Expected: BUILD FAILURE — `.guided` / `reflectionPipeline` / `stageGenerator` not found.

- [ ] **Step 3: Add the response type case**

In `itsWritten/Models/Helpers/ModelResponseType.swift`, add the case:

```swift
enum ModelResponseType: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case streaming = "Streaming"
    case human = "Human"
    case guided = "Guided"

    var id: Self { self }
}
```

- [ ] **Step 4: Add routing to ConversationViewModel**

In `itsWritten/Models/ConversationViewModel.swift`:

4a. Add two properties after `private(set) var isResponding = false`:

```swift
    /// Non-nil while a guided reflection run is in progress; the chat surface
    /// hosts the pipeline UI instead of the message list while set.
    private(set) var reflectionPipeline: ReflectionPipelineViewModel?

    /// Model-call seam for the guided pipeline, injectable from tests.
    var stageGenerator: any StageGenerating = LiveStageGenerator()
```

4b. In `reset(config:)`, after `generation += 1` add:

```swift
        reflectionPipeline?.cancel()
        reflectionPipeline = nil
```

4c. In `resume(thread:config:)`, after `generation += 1` add:

```swift
        reflectionPipeline?.cancel()
        reflectionPipeline = nil
```

4d. In `private func send(_:config:responseType:)`, insert the guided route immediately after the `guard prompt.isReallyEmpty == false else { return }` line (before `pubMedStore?.reset()`):

```swift
        if responseType == .guided {
            routeGuidedReflection(for: prompt.trimmed, config: config)
            return
        }
```

4e. Add the routing method in the `// MARK: - Sending Messages` extension, after `send`:

```swift
    /// Starts the staged pipeline for a fresh entry. Guided mode only makes
    /// sense for a first message; follow-ups in an existing chat stream normally.
    private func routeGuidedReflection(for prompt: String, config: ModelConfiguration) {
        guard messages.isEmpty else {
            send(prompt, config: config, responseType: .streaming)
            return
        }

        append(ChatMessage(content: prompt, isUser: true))

        let pipeline = ReflectionPipelineViewModel(generator: stageGenerator)
        pipeline.onArtifactAccepted = { [weak self] stage, text in
            self?.append(ChatMessage(content: "**\(stage.name)**\n\(text)", isUser: false))
        }
        pipeline.onFinished = { [weak self] in
            self?.reflectionPipeline = nil
        }
        reflectionPipeline = pipeline
        pipeline.start(entry: prompt, config: config)
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Same command as Step 2. Expected: PASS (4 tests). Then run the full suite to catch regressions:
`xcodebuild test -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add itsWritten/Models/Helpers/ModelResponseType.swift itsWritten/Models/ConversationViewModel.swift itsWrittenTests/ConversationViewModelGuidedTests.swift
git commit -m "feat: add guided response type and pipeline routing"
```

---

### Task 7: Pipeline UI

**Files:**
- Create: `itsWritten/Views/Reflection/GuidedReflectionView.swift`
- Create: `itsWritten/Views/Reflection/StageProgressHeader.swift`
- Create: `itsWritten/Views/Reflection/AcceptedStageCard.swift`
- Create: `itsWritten/Views/Reflection/StageReviewCard.swift`
- Modify: `itsWritten/Views/Chat/ChatConversationView.swift` (host pipeline view)
- Modify: `itsWritten/Views/Settings/Sections/ResponseSection.swift` (footer copy)
- Test: none (no UI-test infrastructure in this project; logic is covered by Tasks 5–6). Verified by build + manual check.

**Interfaces:**
- Consumes: `ReflectionPipelineViewModel` (Task 5: `stages`, `stageIndex`, `phase`, `draft`, `artifacts`, `currentStage`, `acceptedStages`, `isLastStage`, `acceptAndContinue()`, `regenerate()`, `retry()`), `ConversationViewModel.reflectionPipeline` (Task 6), existing `TypingIndicatorView()`.
- Produces: `GuidedReflectionView(pipeline:)`.

- [ ] **Step 1: Create the subviews**

`itsWritten/Views/Reflection/StageProgressHeader.swift`:

```swift
//
//  StageProgressHeader.swift
//  itsWritten
//

import SwiftUI

struct StageProgressHeader: View {
    let stages: [ReflectionStage]
    let currentIndex: Int

    var body: some View {
        HStack {
            ForEach(stages.enumerated(), id: \.element.id) { index, stage in
                Label(stage.name, systemImage: stage.systemImage)
                    .font(.caption)
                    .foregroundStyle(index == currentIndex ? .primary : .secondary)

                if index < stages.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    StageProgressHeader(stages: ReflectionStage.pipeline, currentIndex: 1)
        .padding()
}
```

`itsWritten/Views/Reflection/AcceptedStageCard.swift`:

```swift
//
//  AcceptedStageCard.swift
//  itsWritten
//

import SwiftUI

struct AcceptedStageCard: View {
    let stage: ReflectionStage
    let text: String

    var body: some View {
        DisclosureGroup {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(stage.name, systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AcceptedStageCard(stage: ReflectionStage.pipeline[0], text: "- Calm: a quiet walk by the sea")
        .padding()
}
```

`itsWritten/Views/Reflection/StageReviewCard.swift`:

```swift
//
//  StageReviewCard.swift
//  itsWritten
//

import SwiftUI

struct StageReviewCard: View {
    let stage: ReflectionStage
    let isLastStage: Bool
    @Binding var draft: String
    let onRegenerate: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Label(stage.name, systemImage: stage.systemImage)
                .font(.headline)

            TextEditor(text: $draft)
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
                .background(.fill.tertiary, in: .rect(cornerRadius: 12))

            HStack {
                Button("Regenerate", systemImage: "arrow.clockwise", action: onRegenerate)
                    .buttonStyle(.bordered)

                Spacer()

                Button(isLastStage ? "Finish" : "Continue", systemImage: "checkmark", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.isReallyEmpty)
            }
        }
    }
}

#Preview {
    StageReviewCard(
        stage: ReflectionStage.pipeline[0],
        isLastStage: false,
        draft: .constant("- Calm: a quiet walk"),
        onRegenerate: {},
        onContinue: {}
    )
    .padding()
}
```

- [ ] **Step 2: Create the container view**

`itsWritten/Views/Reflection/GuidedReflectionView.swift`:

```swift
//
//  GuidedReflectionView.swift
//  itsWritten
//

import SwiftUI

/// Hosts one guided reflection run: progress across the stages, collapsed
/// cards for accepted artifacts, and the current stage at its review gate.
struct GuidedReflectionView: View {
    @Bindable var pipeline: ReflectionPipelineViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                StageProgressHeader(stages: pipeline.stages, currentIndex: pipeline.stageIndex)

                ForEach(pipeline.acceptedStages) { stage in
                    AcceptedStageCard(stage: stage, text: pipeline.artifacts[stage.id] ?? "")
                }

                switch pipeline.phase {
                case .idle, .generating:
                    TypingIndicatorView()
                case .reviewing:
                    if let stage = pipeline.currentStage {
                        StageReviewCard(
                            stage: stage,
                            isLastStage: pipeline.isLastStage,
                            draft: $pipeline.draft,
                            onRegenerate: pipeline.regenerate,
                            onContinue: pipeline.acceptAndContinue
                        )
                    }
                case .failed(let message):
                    VStack(alignment: .leading) {
                        Text(message)
                            .foregroundStyle(.secondary)
                        Button("Retry", systemImage: "arrow.clockwise", action: pipeline.retry)
                            .buttonStyle(.borderedProminent)
                    }
                case .finished:
                    EmptyView()
                }
            }
            .padding()
        }
    }
}

#Preview {
    GuidedReflectionView(pipeline: ReflectionPipelineViewModel())
}
```

- [ ] **Step 3: Host the pipeline in ChatConversationView**

Replace the `body` of `itsWritten/Views/Chat/ChatConversationView.swift` with:

```swift
    var body: some View {
        Group {
            if let pipeline = viewModel.reflectionPipeline {
                GuidedReflectionView(pipeline: pipeline)
            } else {
                MessageListView(
                    messages: viewModel.messages,
                    isResponding: viewModel.isResponding
                )
                .safeAreaInset(edge: .bottom) {
                    PromptInputView(
                        text: $input,
                        placeholder: homeViewModel.placeholderText,
                        isDisabled: viewModel.isResponding,
                        onSubmit: sendMessage
                    )
                }
            }
        }
        #if !DEBUG
        .hideSensitiveData()
        #endif
        .navigationTitle(viewModel.title)
        .onChange(of: config.instructions) {
            viewModel.rebuildSession(config: config)
        }
    }
```

(Everything else in the file — properties, `sendMessage()`, `#Preview` — stays unchanged.)

- [ ] **Step 4: Update the settings footer copy**

In `itsWritten/Views/Settings/Sections/ResponseSection.swift`, replace the footer `Text` content with:

```swift
            Text("""
            Temperature: Controls response randomness where 0 is random, 1 is deterministic.
            Standard: Generates the full response before displaying it.
            Streaming: Displays the response word by word as it is generated.
            Human: Displays the response character by character, mimicking natural typing.
            Guided: Steps through Themes, Reflection, and Takeaways, pausing for your review between steps.
            """)
```

- [ ] **Step 5: Build and run the full test suite**

Run: `xcodebuild build -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet`
Expected: BUILD SUCCEEDED.

Run: `xcodebuild test -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet`
Expected: PASS (all tests).

- [ ] **Step 6: Manual smoke check**

Foundation Models requests currently fail in this simulator setup (runtime/macOS mismatch), so the full happy path needs a physical device. In the simulator, verify the wiring instead: launch the app (use the `run` skill or `xcrun simctl`), set Speed to "Guided" in settings, submit an entry, and confirm the pipeline surface appears with the Themes stage and then shows the failure state with a working Retry button (expected, since FM calls fail in the sim). On a device, the full three-gate flow with editing should work.

- [ ] **Step 7: Commit**

```bash
git add itsWritten/Views/Reflection itsWritten/Views/Chat/ChatConversationView.swift "itsWritten/Views/Settings/Sections/ResponseSection.swift"
git commit -m "feat: add guided reflection pipeline UI"
```

---

## Self-review notes

- **Spec coverage:** stages/contracts (Task 1), layered context + factory/product separation (Task 2), refusal reuse (Task 3), fresh tool-free session per stage + `@Generable` themes (Task 4), state machine with gates/regenerate/retry/cancel (Task 5), `.guided` case + first-message routing + follow-up fallback + reset/resume clearing + artifact persistence via existing `append` (Task 6), UI + settings copy (Task 7). Persistence, history, titles, and post-pipeline chat need no tasks — they ride on existing `append`/`persistCurrentTurn`/`compactedSessionFromMessages`, as the spec argues.
- **Spec deviation (intentional, small):** the spec names an error message "Couldn't generate this step. Try again." — implemented as `ReflectionPipelineViewModel.failureMessage`. Context-overflow gets no special case: any thrown error lands in `.failed`, matching the spec's table.
- **Type consistency check:** `StageGenerating.generate(stage:instructions:prompt:)` is identical in Tasks 4, 5 (both stubs) and 6 (stub); `Phase` cases match between Tasks 5 and 7; `reflectionPipeline`/`stageGenerator` names match between Tasks 6 and 7.
