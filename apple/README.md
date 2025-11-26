# Mind⠶Type for Apple Platforms

**v1.0** — Apple-native typing intelligence with on-device language model

---

## Overview

Mind⠶Type is a caret-safe typing correction system that runs entirely on-device. It monitors your typing and applies intelligent corrections through a three-stage pipeline:

1. **Noise** — Fixes typos, transpositions, keyboard slip errors
2. **Context** — Improves grammar, punctuation, sentence flow
3. **Tone** — Adjusts writing style (optional: casual/professional)

### Key Features

- 🔒 **Private by default** — All processing happens on-device
- ⚡ **Fast** — Metal-accelerated inference on Apple Silicon
- 🎯 **Caret-safe** — Never modifies text at or after your cursor
- 👁 **Transparent** — Visual feedback via the Correction Marker (⠶)

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     MindType App                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │ Menu Bar UI │  │ Testing     │  │ Settings        │ │
│  │             │  │ Ground      │  │                 │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│                   MindTypeCore                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │ Correction  │  │ Active      │  │ Caret           │ │
│  │ Pipeline    │──│ Region      │──│ Safety          │ │
│  └──────┬──────┘  └─────────────┘  └─────────────────┘ │
│         │                                               │
│  ┌──────▼──────┐                                       │
│  │ LM Adapter  │ ← llama.cpp / Mock                    │
│  └─────────────┘                                       │
└─────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
apple/
├── MindType/                 # Swift Package (core library)
│   ├── Package.swift
│   ├── Sources/
│   │   ├── MindTypeCore/     # Pipeline, types, LM adapter
│   │   └── MindTypeUI/       # SwiftUI components
│   └── Tests/
│
├── MindTypeApp/              # macOS application
│   └── MindTypeApp/
│       ├── MindTypeApp.swift
│       ├── AppState.swift
│       └── Views/
│           ├── MenuBarView.swift
│           ├── TestingGroundView.swift
│           └── SettingsView.swift
│
└── Models/                   # GGUF model files (download separately)
```

---

## Quick Start

### 1. Build the Swift Package

```bash
cd apple/MindType
swift build
```

### 2. Run Tests

```bash
swift test
```

### 3. Open in Xcode

```bash
open MindTypeApp/MindTypeApp.xcodeproj
```

Or create a new Xcode project:
1. File → New → Project
2. Choose "App" under macOS
3. Add local package dependency: `../MindType`

---

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `activeRegionWords` | 20 | Words before caret to consider |
| `pauseDelayMs` | 600 | Milliseconds to wait before correcting |
| `confidenceThreshold` | 0.80 | Minimum confidence to apply correction |
| `toneTarget` | None | Tone adjustment: None, Casual, Professional |

---

## Three-Stage Pipeline

### Stage 1: Noise

Fixes mechanical typing errors:
- Single-character typos (teh → the)
- Transpositions (hte → the)
- Missing/extra characters
- Keyboard adjacency errors

### Stage 2: Context

Improves linguistic quality:
- Subject-verb agreement
- Article usage (a/an/the)
- Punctuation corrections
- Sentence structure

### Stage 3: Tone (Optional)

Adjusts writing style:
- **Casual**: Relaxed, conversational
- **Professional**: Formal, polished

---

## Caret Safety Guarantee

Mind⠶Type enforces a strict caret safety policy:

```swift
/// Region must be entirely before the caret
func isCaretSafe(start: Int, end: Int, caret: Int) -> Bool {
    end <= caret && start < end
}
```

This ensures:
- Your typing flow is never interrupted
- Corrections only apply to "settled" text
- No visual jumps or cursor displacement

---

## Language Model

The v1.0 demo uses a mock LM adapter with common typo corrections. For production:

### Option 1: llama.cpp (Recommended)

```swift
// Add to Package.swift dependencies
.package(url: "https://github.com/ggerganov/llama.cpp", branch: "master")

// Download GGUF model
curl -L -o Models/qwen2.5-0.5b-instruct-q4_k_m.gguf \
  https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf
```

### Option 2: Core ML

Convert the model to Core ML format using `coremltools`:

```python
import coremltools as ct
# See scripts/convert-to-coreml.py
```

---

## Privacy

Mind⠶Type is designed with privacy as a core principle:

- ✅ All processing happens on-device
- ✅ No text is sent to external servers
- ✅ No telemetry or analytics
- ✅ Secure fields are automatically skipped
- ✅ IME composition is respected

---

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3) recommended
- Xcode 15.0+
- Swift 5.9+

---

## License

MIT License — See LICENSE file for details.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v1.0.0 | 2025-11 | Apple-native rewrite, Swift/SwiftUI |
| v0.8.0 | 2025-11 | Final TypeScript/WASM version (archived) |

