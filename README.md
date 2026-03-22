# itsWritten: Privacy-first journaling on device

## About

**itsWritten** is a privacy-first journaling app for iPhone built with SwiftUI, SwiftData, and Apple's Foundation Models framework.

The app is designed to feel calm and minimal while still being useful: you write, reflect, and optionally get AI-generated responses without sending your journal to a third-party backend. The project combines a focused writing experience, persistent chat threads, configurable response behavior, onboarding, and privacy protections aimed at keeping sensitive writing on device whenever possible.

---

## Features

### Writing Experience
- Clean journaling interface with dynamic placeholder prompts
- Focused text-entry flow designed around fast capture
- Built-in writing timer with pause and resume support
- Typewriter-style launch experience and onboarding flow

### AI Reflection
- On-device AI responses using `FoundationModels`
- Multiple response modes:
  - `standard`
  - `streaming`
  - `human`
- Configurable model instructions and sampling behavior
- Session prewarming and recovery handling for failed or refused responses

### Chat and Persistence
- Dedicated chat view for AI-assisted reflection
- Conversation history saved with SwiftData
- Restorable chat threads for returning to previous sessions

### Research Support
- Built-in PubMed tool integration for biomedical lookups
- Source capture and source attribution appended to responses when the tool is used

### Privacy and Safety
- Privacy shield when the app becomes inactive in non-debug builds
- Privacy-sensitive content handling in the main interface
- On-device-first design with no custom backend in the repository

---

## Tech Stack

### Core
- Swift
- SwiftUI
- SwiftData
- FoundationModels

### Supporting APIs
- Observation via `@Observable`
- Modern Swift concurrency
- `AppStorage` for lightweight preferences
- `URLSession` for PubMed requests

---

## Architecture

The app follows a feature-oriented SwiftUI structure with state held in observable models and persistence handled through SwiftData.

```text
itsWritten/
├── itsWritten/
│   ├── Assets/                     # App assets and icons
│   ├── Helpers/                    # Shared helpers and privacy utilities
│   │   └── SensitiveData/          # Screenshot/privacy protection helpers
│   ├── Models/                     # App state and persisted models
│   │   └── Helpers/                # Model configuration and response helpers
│   ├── Tools/                      # External tool integrations
│   │   └── PubMedSearchTool.swift
│   ├── Views/
│   │   ├── Chat/                   # AI chat experience and history
│   │   ├── Helpers/                # Shared view components
│   │   ├── Home/                   # Main journaling flow
│   │   ├── Onboarding/             # First-run onboarding
│   │   ├── Privacy/                # Privacy shield UI
│   │   ├── Settings/               # Model and app settings
│   │   ├── Splash/                 # Launch and intro views
│   │   └── Unavailable Views/      # Apple Intelligence availability states
│   └── itsWrittenApp.swift         # App entry point
└── itsWrittenTests/                # Unit tests
```

### Patterns
- Feature-based SwiftUI composition
- `@Observable` models for shared state
- `NavigationStack` for navigation
- SwiftData for thread/message persistence
- Tool-backed language model sessions for richer responses

---

## Requirements

- Xcode 26 or later
- iOS 26.0 or later
- Swift 6.2 or later
- A device that supports Apple Intelligence for the AI features

Some functionality, especially model availability, depends on Apple Intelligence support and device configuration.

---

## Getting Started

1. Clone the repository:

   ```bash
   git clone https://github.com/cilippofilia/itsWritten.git
   cd itsWritten
   ```

2. Open the project in Xcode:

   ```bash
   open itsWritten.xcodeproj
   ```

3. Select an iPhone target or supported device.

4. Build and run.

If you want to test AI features, make sure Apple Intelligence is available and enabled on the device you use.

---

## Current Project Status

This project is actively in development.

Implemented today:
- Main journaling flow
- Timer support
- Onboarding
- AI chat flow
- Streaming and alternate response modes
- SwiftData-backed thread persistence
- Model settings UI
- PubMed search tool integration
- Privacy shield behavior

Still evolving:
- Product polish and copy refinement
- Additional testing coverage
- Broader settings and customization
- More robust handling around model availability and edge cases

---

## Testing

The repository includes unit tests in `itsWrittenTests`, including coverage for core chat and countdown logic.

Run tests from Xcode or with:

```bash
xcodebuild test -project itsWritten.xcodeproj -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 16'
```

You may need to adjust the simulator destination to match what is installed locally.

---

## License

This project is proprietary software. All rights reserved.

---

## Author

Filippo Cilia
