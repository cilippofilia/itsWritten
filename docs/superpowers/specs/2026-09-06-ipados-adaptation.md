# iPadOS Adaptation — Design Spec

**Date:** 2026-09-06
**Status:** Approved for planning

## Problem

itsWritten already ships with `TARGETED_DEVICE_FAMILY = "1,2"`, so it runs on iPad — but as a stretched iPhone layout. On an 11" or 13" iPad:

- The composer (`HomeTextEditor`) and chat (`MessageListView`) stretch edge-to-edge, producing unreadable ~1,300 pt line lengths.
- Chat bubbles use `containerRelativeFrame(.horizontal) { size, _ in size * 0.75 }`, so a bubble can be ~980 pt wide.
- Chat history is a pushed `navigationDestination`, wasting the iPad's space; the platform-idiomatic pattern is a sidebar.
- Upside-down portrait is not declared. The app supports iPad multitasking (no `UIRequiresFullScreen`), and multitasking-capable iPad apps must support all four orientations.
- No hardware-keyboard shortcuts, which iPad users expect.

## Goals

1. Readable content width everywhere on regular-width layouts (composer, chat, onboarding, sheets).
2. `NavigationSplitView` with chat history as a sidebar when `horizontalSizeClass == .regular`; the existing `NavigationStack` flow is unchanged in compact width (all iPhones, iPad Split View at narrow sizes).
3. All four orientations declared for iPad.
4. Hardware keyboard shortcuts: ⌘N (new chat), ⌘↩ (send).
5. Verified behavior in Split View, Slide Over, and Stage Manager, including the privacy shield and screenshot-prevention wrappers.

## Non-goals

- No Mac Catalyst, no macOS target.
- No multi-window / multi-scene support (`UIApplicationSupportsMultipleScenes` stays off).
- No pointer-hover custom effects (system defaults are acceptable).
- No redesign of the ads/paywall flow; `fullScreenCover` interstitials remain full screen on iPad.

## Design decisions

- **Layout switch lives in `HomeView`** on `@Environment(\.horizontalSizeClass)`. `NavigationSplitView` is not used as the single root because when collapsed on iPhone it would show the sidebar (history) first, changing the iPhone's composer-first UX.
- **Sidebar starts hidden** (`columnVisibility = .detailOnly`) so iPad launch matches the iPhone experience: composer front and center. The system sidebar toggle and the existing menu's "History" entry (rewired to column visibility) reveal it.
- **Width capping** is one shared modifier (`.readableContentWidth()`, 700 pt max, centered) rather than per-view constants, applied to the composer, message list, prompt input, and onboarding content. Bubbles additionally cap at 560 pt.
- **Switching size classes** (e.g. Stage Manager resize) swaps the layout root and resets transient navigation state (sidebar visibility, pushed history). Conversation state lives in `ConversationViewModel`/SwiftData, so no data is lost. Accepted trade-off.
- **Privacy shield** (`scenePhase == .inactive`) is expected to be correct on iPad because both Split View apps report `.active`; this is verified, with a defined contingency fix, rather than changed pre-emptively.
