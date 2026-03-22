# itsWritten: Private journaling with on-device AI reflection

## About

itsWritten is a SwiftUI journaling app built around a simple idea: write first, reflect second, and keep that experience on device whenever possible.

The app combines a focused writing surface, configurable Apple Intelligence responses, saved chat threads, onboarding, and privacy protections for sensitive content. It also includes an optional PubMed-backed research tool for biomedical questions inside the AI flow.

## Features

### Writing Flow

- Minimal journal-first home screen designed for quick capture.
- Optional writing timer with start, pause, resume, and expiry handling.
- Typewriter-style launch and onboarding experience.
- Restorable onboarding from the main menu.

### AI Reflection

- On-device response generation through Apple’s `FoundationModels` APIs.
- Multiple response styles, including standard and streaming.
- Configurable instructions, temperature, and sampling strategy.
- Dedicated chat view for continuing a reflection after the first response.
- Chat history screen for reopening previous threads.

### Persistence And Tools

- SwiftData-backed storage for chat threads and messages.
- Shared PubMed tool integration for biomedical lookups.
- Source recording for tool-backed responses.

### Privacy

- Privacy-sensitive rendering on the main interface.
- Privacy shield when the app moves inactive outside debug builds.
- Sensitive-data helper views for protected UI presentation.

## Tech Stack

- SwiftUI
- SwiftData
- Foundation Models
- `@Observable` state models
- Swift concurrency
- `URLSession` for PubMed requests

## Project Structure

```text
itsWritten/
├── itsWritten/
│   ├── Assets/
│   ├── Helpers/
│   │   └── SensitiveData/
│   ├── Models/
│   │   └── Helpers/
│   ├── Tools/
│   └── Views/
│       ├── Chat/
│       ├── Helpers/
│       ├── Home/
│       ├── Onboarding/
│       ├── Privacy/
│       ├── Settings/
│       ├── Splash/
│       └── Unavailable Views/
├── itsWrittenTests/
└── itsWritten.xcodeproj
```

The app entry point is [`itsWritten/itsWrittenApp.swift`](itsWritten/itsWrittenApp.swift), which sets up the SwiftData container for `ChatThread` and `ChatMessage`, injects the shared PubMed tool store, and overlays the privacy shield when the scene becomes inactive.

## Requirements

- Xcode 26 or later
- iOS 26.0+
- Swift 6.2+
- A device configuration that supports Apple Intelligence for AI-powered features

The checked-in project currently uses iOS 26.0 deployment settings. AI availability depends on Apple Intelligence support, device eligibility, and system configuration.

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

3. Select the `itsWritten` scheme and an iPhone device or simulator.

4. Build and run the app.

For the full AI experience, run on a device or environment where Apple Intelligence is available and enabled.

## Development Notes

- The main journaling flow lives under `itsWritten/Views/Home`.
- Chat screens and history management live under `itsWritten/Views/Chat`.
- Model configuration and response behavior helpers live under `itsWritten/Models/Helpers`.
- The PubMed tool implementation lives in `itsWritten/Tools/PubMedSearchTool.swift`.
- Availability fallback screens live under `itsWritten/Views/Unavailable Views`.

## Tests

Unit tests live in `itsWrittenTests` and currently cover:

- `ChatModel` codable and equality behavior
- `ChatThread` persistence with SwiftData
- `CountdownViewModel` timer lifecycle and formatting

Run tests from Xcode’s test action for the `itsWritten` scheme.

## Author

Filippo Cilia

## License

This project is proprietary software. All rights reserved.
