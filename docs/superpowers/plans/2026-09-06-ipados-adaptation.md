# iPadOS Adaptation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make itsWritten feel native on iPad: readable content widths, a chat-history sidebar in regular width, all four orientations, and hardware keyboard shortcuts.

**Architecture:** The app is SwiftUI-only (`@Observable` view models, SwiftData persistence, on-device FoundationModels). `HomeView` owns all conversation state and currently wraps everything in a single `NavigationStack`. This plan splits that into two layout roots chosen by `horizontalSizeClass` — the existing stack for compact, a `NavigationSplitView` (history sidebar + conversation detail) for regular — and introduces one shared `.readableContentWidth()` modifier for width capping.

**Tech Stack:** Swift 6, SwiftUI, iOS 26 deployment target, Xcode file-system-synchronized project (new files on disk are picked up automatically; no pbxproj edits needed except Task 1's build settings).

**Spec:** `docs/superpowers/specs/2026-09-06-ipados-adaptation.md`

## Global Constraints

- Target iOS 26.0+; Swift 6 strict concurrency; SwiftUI only (no UIKit unless already present).
- `@Observable` classes are `@MainActor`. Never `ObservableObject`.
- `.foregroundStyle()` not `.foregroundColor()`; `.clipShape(.rect(cornerRadius:))` not `.cornerRadius()`; `Button("Title", systemImage:)` for icon buttons; no `GeometryReader` where `.containerRelativeFrame()`/`.visualEffect()` works; no `UIScreen.main.bounds`.
- New view pieces go in new `View` structs and separate files, not computed properties.
- No third-party frameworks.
- SwiftLint must report no errors before every commit. Run it as `swiftlint lint --quiet` from the repo root.
- Build/test commands (script sandboxing blocks the SwiftLint build phase in CLI builds; `ENABLE_USER_SCRIPT_SANDBOXING=NO` is a required workaround, not optional):
  - Build (iPad): `xcodebuild build -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet`
  - Tests (run on iPhone, they are UI-independent): `xcodebuild test -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ENABLE_USER_SCRIPT_SANDBOXING=NO -quiet`
- **Context note:** the medical-tools/PubMed layer was removed on 2026-09-06 (no `PubMedToolStore`, no `MedicalPromptAnalyzer`, no `ToolsView`). If you see references to those in older docs, ignore them; the code in this plan reflects the post-removal tree.

---

### Task 1: Declare all four iPad orientations

The app supports iPad multitasking (no `UIRequiresFullScreen`), which requires all four orientations on iPad. The shared `INFOPLIST_KEY_UISupportedInterfaceOrientations` lacks upside-down portrait.

**Files:**
- Modify: `itsWritten.xcodeproj/project.pbxproj` (both `itsWritten` app-target build configurations — the two blocks containing `INFOPLIST_KEY_UISupportedInterfaceOrientations`, near lines 400 and 449)

**Interfaces:**
- Consumes: nothing
- Produces: nothing code-visible; later verification (Task 6) relies on rotation working in all orientations on iPad

- [ ] **Step 1: Add the iPad orientation key to both build configurations**

In each of the two build-configuration blocks that contain the line

```
INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortrait";
```

add this line directly below it (keep the surrounding alphabetical-ish ordering; exact position isn't functionally significant):

```
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown";
```

There must be exactly 2 insertions (Debug and Release of the app target; do NOT touch the two test-target blocks, which have no `INFOPLIST_KEY_` lines).

- [ ] **Step 2: Verify the project still parses and builds**

Run the iPad build command from Global Constraints.
Expected: `BUILD SUCCEEDED` (no output with `-quiet` also means success; check exit code 0).

- [ ] **Step 3: Commit**

```bash
git add itsWritten.xcodeproj/project.pbxproj
git commit -m "Support all four orientations on iPad"
```

---

### Task 2: Shared readable-content-width modifier, applied to composer/chat/onboarding

**Files:**
- Create: `itsWritten/Helpers/ReadableContentWidth.swift`
- Modify: `itsWritten/Views/Home/ComposingView.swift`
- Modify: `itsWritten/Views/Chat/MessageListView.swift`
- Modify: `itsWritten/Views/Chat/PromptInputView.swift`
- Modify: `itsWritten/Views/Onboarding/OnboardingView.swift`
- Modify: `itsWritten/Views/Home/WhyAIView.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `extension View { func readableContentWidth() -> some View }` — used again in later tasks; the exact name matters.

- [ ] **Step 1: Create the modifier**

```swift
//
//  ReadableContentWidth.swift
//  itsWritten
//

import SwiftUI

/// Caps content to a comfortable reading width on wide layouts (iPad, landscape)
/// while remaining full-width on compact screens, where the 700pt cap never binds.
struct ReadableContentWidthModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func readableContentWidth() -> some View {
        modifier(ReadableContentWidthModifier())
    }
}
```

- [ ] **Step 2: Apply to the composer**

In `ComposingView.swift`, wrap both the main content and the bottom inset. The outer `VStack` gets the modifier after its closing brace (before `.safeAreaInset`), and the inset's `VStack(spacing: 0)` gets it too:

```swift
        VStack {
            HomeTextEditor(
                text: $text,
                isFocused: $isFocused,
                placeholderText: homeViewModel.placeholderText,
                isResponding: viewModel.session.isResponding
            )
            #if !DEBUG
            .hideSensitiveData()
            #endif
            if countDownViewModel.timerActive || countDownViewModel.timerPaused {
                CountdownView()
            }
        }
        .readableContentWidth()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if isFocused == false {
                    CrossPromoBannerView()
                }

                HomeFooterView(
                    text: text,
                    isResponding: viewModel.session.isResponding,
                    sendAction: sendAction
                )
            }
            .readableContentWidth()
        }
```

(The `// Hidden while composing:` comment above `if isFocused == false` stays; it is elided here for brevity only.)

- [ ] **Step 3: Apply to the message list**

In `MessageListView.swift`, add the modifier to the `LazyVStack` inside the `ScrollView`, after `.padding()`:

```swift
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                        .id(message.id)
                }
                if showsTypingIndicator {
                    TypingIndicatorView()
                        .id(typingIndicatorID)
                }
            }
            .padding()
            .readableContentWidth()
        }
```

- [ ] **Step 4: Apply to the prompt input**

In `PromptInputView.swift`, add `.readableContentWidth()` as the last modifier on the outer `HStack` (after `.padding(.bottom, 8)`).

- [ ] **Step 5: Apply to onboarding and WhyAI**

In `OnboardingView.swift`, on the `LazyVStack`, after `.frame(maxWidth: .infinity, alignment: .topLeading)`, add `.readableContentWidth()`.
In `WhyAIView.swift`, on the outer `VStack(spacing: 0)`, after `.padding()`, add `.readableContentWidth()`.

- [ ] **Step 6: Build for iPad and verify visually**

Run the iPad build command. Then boot the iPad simulator, install and launch, and screenshot:

```bash
xcrun simctl boot "iPad Pro 13-inch (M5)" || true
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/itsWritten-*/Build/Products/Debug-iphonesimulator/itsWritten.app
xcrun simctl launch booted "$(defaults read ~/Library/Developer/Xcode/DerivedData/itsWritten-*/Build/Products/Debug-iphonesimulator/itsWritten.app/Info CFBundleIdentifier)"
sleep 5 && xcrun simctl io booted screenshot /tmp/ipad-composer.png
```

Read the screenshot. Expected: the composer text area and footer buttons are centered in a ~700pt column, not edge-to-edge.

- [ ] **Step 7: Run unit tests, then commit**

Run the test command (expect `** TEST SUCCEEDED **`), then:

```bash
git add itsWritten/Helpers/ReadableContentWidth.swift itsWritten/Views
git commit -m "Cap content to a readable width on wide layouts"
```

---

### Task 3: Cap chat bubble width

**Files:**
- Modify: `itsWritten/Views/Chat/MessageBubble.swift:70-72`

**Interfaces:**
- Consumes: nothing new
- Produces: nothing new

- [ ] **Step 1: Cap the container-relative width**

Replace:

```swift
        .containerRelativeFrame(.horizontal, alignment: frameAlignment) { size, _ in
            size * 0.75
        }
```

with:

```swift
        .containerRelativeFrame(.horizontal, alignment: frameAlignment) { size, _ in
            min(size * 0.75, 560)
        }
```

- [ ] **Step 2: Build for iPad, screenshot a conversation, verify**

Rebuild and reinstall (commands as in Task 2 Step 6), start a chat in the simulator (type any prompt via `xcrun simctl io` is unreliable — use `xcrun simctl launch` then AXe if available, otherwise verify via Xcode Previews: the "AI response - Dark" preview in `MessageBubble.swift` renders with a long message). Expected: bubbles never exceed 560pt even on the 13" iPad.

- [ ] **Step 3: Commit**

```bash
git add itsWritten/Views/Chat/MessageBubble.swift
git commit -m "Cap chat bubble width for wide layouts"
```

---

### Task 4: Split-view layout with history sidebar in regular width

`HomeView` currently returns one `NavigationStack` with an inline `toolbarMenu` computed property and a pushed `ChatHistoryView`. Split it into two layout structs plus a shared toolbar menu struct; `HomeView` keeps all state and the cross-cutting ad/lifecycle modifiers.

**Files:**
- Create: `itsWritten/Views/Home/HomeStackLayout.swift`
- Create: `itsWritten/Views/Home/HomeSplitLayout.swift`
- Create: `itsWritten/Views/Home/HomeToolbarMenu.swift`
- Modify: `itsWritten/Views/Home/HomeView.swift` (full body rewrite shown below)

**Interfaces:**
- Consumes: `HomeContentView(config:responseType:)`, `ChatHistoryView(config:responseType:)`, `MenuButtonView`, `SheetType`, `ConversationViewModel` (environment).
- Produces: `HomeStackLayout(config:responseType:presentedSheet:showChatHistoryView:showOnboarding:)`, `HomeSplitLayout(config:responseType:presentedSheet:showOnboarding:)`, `HomeToolbarMenu(presentedSheet:showChatHistory:config:responseType:showOnboarding:)` — exact signatures below.

- [ ] **Step 1: Create `HomeToolbarMenu.swift`**

```swift
//
//  HomeToolbarMenu.swift
//  itsWritten
//

import SwiftUI

/// Wraps `MenuButtonView` with the binding plumbing shared by both layout roots.
/// `showChatHistory` means "push the history screen" in compact width and
/// "reveal the sidebar" in regular width — each layout supplies its own binding.
struct HomeToolbarMenu: View {
    @Binding var presentedSheet: SheetType?
    @Binding var showChatHistory: Bool
    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType
    let showOnboarding: () -> Void

    var body: some View {
        GlassEffectContainer {
            MenuButtonView(
                showWhyAISheet: .init(
                    get: { presentedSheet == .whyAI },
                    set: { presentedSheet = $0 ? .whyAI : nil }
                ),
                showChatHistoryView: $showChatHistory,
                showSettings: .init(
                    get: { presentedSheet == .settings($config, $responseType) },
                    set: { presentedSheet = $0 ? .settings($config, $responseType) : nil }
                ),
                showOnboarding: showOnboarding
            )
        }
    }
}
```

- [ ] **Step 2: Create `HomeStackLayout.swift`** (the current compact/iPhone experience, extracted verbatim)

```swift
//
//  HomeStackLayout.swift
//  itsWritten
//

import SwiftUI

/// Compact-width root: the existing iPhone experience with history pushed
/// onto the navigation stack.
struct HomeStackLayout: View {
    @Environment(ConversationViewModel.self) private var conversationViewModel

    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType
    @Binding var presentedSheet: SheetType?
    @Binding var showChatHistoryView: Bool
    let showOnboarding: () -> Void

    var body: some View {
        NavigationStack {
            HomeContentView(
                config: $config,
                responseType: $responseType
            )
            .toolbar {
                if conversationViewModel.mode == .chatting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("New Chat", systemImage: "plus", action: { conversationViewModel.reset(config: config) })
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HomeToolbarMenu(
                        presentedSheet: $presentedSheet,
                        showChatHistory: $showChatHistoryView,
                        config: $config,
                        responseType: $responseType,
                        showOnboarding: showOnboarding
                    )
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                sheet.view
            }
            .navigationDestination(isPresented: $showChatHistoryView) {
                ChatHistoryView(
                    config: $config,
                    responseType: $responseType
                )
            }
        }
    }
}
```

- [ ] **Step 3: Create `HomeSplitLayout.swift`**

```swift
//
//  HomeSplitLayout.swift
//  itsWritten
//

import SwiftUI

/// Regular-width (iPad) root: chat history lives in a sidebar. The sidebar
/// starts hidden so launch matches the iPhone's composer-first experience.
struct HomeSplitLayout: View {
    @Environment(ConversationViewModel.self) private var conversationViewModel

    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType
    @Binding var presentedSheet: SheetType?
    let showOnboarding: () -> Void

    @State private var columnVisibility = NavigationSplitViewVisibility.detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ChatHistoryView(
                config: $config,
                responseType: $responseType
            )
        } detail: {
            HomeContentView(
                config: $config,
                responseType: $responseType
            )
            .toolbar {
                if conversationViewModel.mode == .chatting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("New Chat", systemImage: "plus", action: { conversationViewModel.reset(config: config) })
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HomeToolbarMenu(
                        presentedSheet: $presentedSheet,
                        showChatHistory: .init(
                            get: { columnVisibility != .detailOnly },
                            set: { columnVisibility = $0 ? .all : .detailOnly }
                        ),
                        config: $config,
                        responseType: $responseType,
                        showOnboarding: showOnboarding
                    )
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                sheet.view
            }
        }
    }
}
```

Note: `ChatHistoryView` calls `dismiss()` after resuming a thread; in the sidebar that dismiss is a harmless no-op, and the resumed conversation appears in the detail column because both share `ConversationViewModel`. Do not "fix" that.

- [ ] **Step 4: Rewrite `HomeView.swift`**

Replace the whole struct body (keep the header comment, imports, and `#Preview` as-is; delete the `toolbarMenu` computed property entirely):

```swift
struct HomeView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Environment(HomeViewModel.self) private var viewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel
    @Environment(CrossPromoSignal.self) private var crossPromoSignal
    @Environment(RemoveAdsStore.self) private var removeAdsStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var config = ModelConfiguration()
    @State private var responseType = ModelResponseType.standard
    @State private var presentedSheet: SheetType?
    @State private var conversationViewModel = ConversationViewModel()
    @State private var showChatHistoryView = false
    @State private var interstitialAd: Ad?
    @State private var isInterstitialPending = false

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                HomeSplitLayout(
                    config: $config,
                    responseType: $responseType,
                    presentedSheet: $presentedSheet,
                    showOnboarding: showOnboarding
                )
            } else {
                HomeStackLayout(
                    config: $config,
                    responseType: $responseType,
                    presentedSheet: $presentedSheet,
                    showChatHistoryView: $showChatHistoryView,
                    showOnboarding: showOnboarding
                )
            }
        }
        .environment(conversationViewModel)
        .onAppear {
            conversationViewModel.configure(
                modelContext: modelContext,
                crossPromoSignal: crossPromoSignal
            )
            conversationViewModel.prewarmIdleSession(config: config)
        }
        // A PrivateAds cross-promo ad every 3rd new chat started (see `CrossPromoSignal`,
        // bumped from `ConversationViewModel.persistCurrentTurn` when a brand-new thread is
        // first saved). The interstitial waits for the user to return to the composer
        // (`mode == .composing`) before showing, so it never interrupts an in-progress
        // conversation.
        .fullScreenCover(item: $interstitialAd) { ad in
            AdView(advert: ad, config: .crossPromo) {
                CrossPromoRemoveAdsInfoView()
            }
        }
        .onChange(of: crossPromoSignal.count) { _, newValue in
            guard removeAdsStore.isAdsRemoved == false, newValue > 0, newValue.isMultiple(of: 3) else { return }
            isInterstitialPending = true
        }
        .onChange(of: conversationViewModel.mode) { _, newMode in
            guard newMode == .composing, isInterstitialPending else { return }
            isInterstitialPending = false
            Task { await refreshInterstitialAd() }
        }
        // Dismiss an ad the user is mid-way through if they buy "Remove Ads" from its own paywall.
        .onChange(of: removeAdsStore.isAdsRemoved) { _, isAdsRemoved in
            guard isAdsRemoved else { return }
            interstitialAd = nil
        }
    }

    private func showOnboarding() {
        presentedSheet = nil
        hasCompletedOnboarding = false
    }

    private func refreshInterstitialAd() async {
        guard removeAdsStore.isAdsRemoved == false else { return }
        guard let url = AdConfiguration.crossPromo.adsJSONURL else { return }
        interstitialAd = try? await AdStore.fetchRandomAd(
            from: url,
            excludedIDs: AdConfiguration.crossPromo.excludedIDs
        )
    }
}
```

- [ ] **Step 5: Build for both device families**

Run the iPad build command AND an iPhone build (`-destination 'platform=iOS Simulator,name=iPhone 17 Pro'`). Expected: both succeed.

- [ ] **Step 6: Verify on the iPad simulator**

Install/launch on the iPad simulator (commands from Task 2 Step 6). Verify with screenshots:
1. Launch shows the composer full-width (sidebar hidden).
2. The system sidebar-toggle button (top-leading) reveals "History".
3. Menu → History reveals the sidebar too.
4. Menu → Settings and Why AI? present as form sheets, not full screen.

- [ ] **Step 7: Verify on the iPhone simulator**

Install/launch on iPhone 17 Pro. Verify launch shows the composer and Menu → History still pushes the history screen (unchanged behavior).

- [ ] **Step 8: Run unit tests, then commit**

Run the test command (expect `** TEST SUCCEEDED **`), then:

```bash
git add itsWritten/Views/Home
git commit -m "Add split-view layout with history sidebar on iPad"
```

---

### Task 5: Hardware keyboard shortcuts

**Files:**
- Modify: `itsWritten/Views/Chat/PromptInputView.swift` (Send button)
- Modify: `itsWritten/Views/Home/HomeFooterView.swift` (composer send)
- Modify: `itsWritten/Views/Home/HomeStackLayout.swift` and `itsWritten/Views/Home/HomeSplitLayout.swift` (New Chat buttons)

**Interfaces:**
- Consumes: the Task 4 layout structs
- Produces: ⌘↩ sends, ⌘N starts a new chat

- [ ] **Step 1: Add ⌘↩ to the chat send button**

In `PromptInputView.swift`, on the `Button("Send", ...)`, after `.disabled(...)`, add:

```swift
                .keyboardShortcut(.return, modifiers: .command)
```

- [ ] **Step 2: Add ⌘↩ to the composer send button**

In `HomeFooterView.swift`, on `SendButtonView(...)` after `.disabled(isResponding || isInputEmpty)`, add:

```swift
            .keyboardShortcut(.return, modifiers: .command)
```

(`keyboardShortcut` applied to a container view targets the button it contains.)

- [ ] **Step 3: Add ⌘N to both New Chat buttons**

In `HomeStackLayout.swift` and `HomeSplitLayout.swift`, on the `Button("New Chat", ...)` line, add:

```swift
                        .keyboardShortcut("n", modifiers: .command)
```

- [ ] **Step 4: Build, verify, commit**

Build for iPad. In the simulator with hardware keyboard connected (I/O → Keyboard → Connect Hardware Keyboard), type a prompt, press ⌘↩ — the message sends; press ⌘N while chatting — returns to composer. Run the test command, then:

```bash
git add itsWritten/Views
git commit -m "Add hardware keyboard shortcuts for send and new chat"
```

---

### Task 6: Full iPad verification pass

No planned code changes — a verification gate with one defined contingency.

**Files:**
- Possibly modify: `itsWritten/itsWrittenApp.swift` (contingency only, below)

- [ ] **Step 1: Orientation sweep**

On the iPad simulator rotate through all four orientations (Hardware → Rotate). Expected: app rotates in all four; no layout breakage in composer or chat.

- [ ] **Step 2: Multitasking sweep**

Put the app in Split View (drag another app from the Dock) at 1/3, 1/2, and 2/3 widths, and in Slide Over. Expected:
- At narrow widths the app switches to the compact (stack) layout automatically; at wide widths the split layout returns. Transient navigation state (open sidebar / pushed history) resetting across the switch is accepted per the spec.
- The privacy shield must NOT be visible while the app sits unfocused-but-visible in Split View. If it is (i.e. `scenePhase` reports `.inactive` in that state), apply this contingency in `itsWrittenApp.swift`: replace `isPrivacyShieldVisible = newValue == .inactive` with `isPrivacyShieldVisible = newValue != .active`, which keeps the shield for backgrounding/app-switcher (where snapshots are taken) and tolerates brief flashes during focus changes. Note the shield is `#if !DEBUG` — verify with a Release-configuration build (`-configuration Release`).

- [ ] **Step 3: Screenshot-prevention check**

`ScreenshotPreventHelperView` (secure `UITextField` canvas trick) wraps chat content in Release builds. On the iPad simulator with a Release build, take a screenshot (Hardware → Screenshot inside the sim, or ⌘S) and open it: chat content should be blanked. If the secure-canvas subview lookup fails on iPadOS 26 (content invisible in-app, or not blanked in the screenshot), report it as a finding — do not improvise a fix in this plan.

- [ ] **Step 4: Interstitial + paywall check**

Trigger the cross-promo interstitial (start 3 new chats with ads not removed). Expected: `fullScreenCover` ad covers the full iPad screen and its Remove Ads flow works.

- [ ] **Step 5: Final gate**

Run: `swiftlint lint --quiet` (expect no output) and the unit-test command (expect `** TEST SUCCEEDED **`). Then commit any contingency change:

```bash
git add -A
git commit -m "iPad verification fixes"
```

(Skip the commit if nothing changed.)
