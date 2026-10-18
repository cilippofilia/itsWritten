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
2. One `NavigationSplitView` root at every width, with chat history as the sidebar. In compact width the composer stays the main view and history is pushed from the menu, as before.
3. All four orientations declared for iPad.
4. Hardware keyboard shortcuts: ⌘N (new chat), ⌘↩ (send).
5. Verified behavior in Split View, Slide Over, and Stage Manager, including the privacy shield and screenshot-prevention wrappers.

## Non-goals

- No Mac Catalyst, no macOS target.
- No multi-window / multi-scene support. `UIApplicationSupportsMultipleScenes` is set to `false` in `Info.plist` (the generated scene manifest had silently turned it on); the `.shared` tool stores assume one window.
- No pointer-hover custom effects (system defaults are acceptable).
- No redesign of the ads/paywall flow; `fullScreenCover` interstitials remain full screen on iPad.

## Design decisions

- **Amended 2026-10-18 (iPhone Duo audit):** the original plan switched between a `NavigationStack` root and a `NavigationSplitView` root on size class, accepting that navigation state resets. On iPhone Duo, opening or closing the device changes size class routinely, so that reset would happen all the time. Instead `HomeView` uses one `NavigationSplitView(columnVisibility:preferredCompactColumn:)`. The composer stays the main view in compact width: the collapsed split view's back button to the sidebar is hidden (`navigationBarBackButtonHidden` while compact), and the menu's "History" entry pushes `ChatHistoryView` onto the detail column's `NavigationStack`, exactly as before. In regular width it reveals the sidebar instead. Widening the window while history is pushed pops it and shows the sidebar.
- **Sidebar starts hidden** (`columnVisibility = .detailOnly`) so iPad launch matches the iPhone experience: composer front and center. The system sidebar toggle and the existing menu's "History" entry (rewired to column visibility) reveal it.
- **Width capping** is one shared modifier (`.readableContentWidth()`, 700 pt max, centered) rather than per-view constants, applied to the composer, message list, prompt input, and onboarding content. Bubbles additionally cap at 560 pt.
- **Privacy shield** (`scenePhase == .inactive`) is expected to be correct on iPad because both Split View apps report `.active`; this is verified, with a defined contingency fix, rather than changed pre-emptively.
