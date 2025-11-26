# MindType Documentation

## Overview

This folder contains the documentation for MindType v1.0, an Apple-native typing intelligence system.

## Structure

```
docs/
├── 01-prd/                    # Product Requirements
│   └── 01-PRD.md             # Vision, scenarios, success metrics
│
├── 03-system-principles/      # Core Design Philosophy
│   └── 03-System-Principles.md  # Caret safety, privacy, flow
│
└── 05-adr/                    # Architecture Decisions
    ├── 0002-caret-safe-diff.md     # Core UX guarantee
    ├── 0003-architecture-constraints.md
    └── 0009-apple-native-rewrite.md  # v1.0 architecture decision
```

## Key Documents

| Document | Description |
|----------|-------------|
| [PRD](01-prd/01-PRD.md) | Product vision and the Seven Scenarios |
| [System Principles](03-system-principles/03-System-Principles.md) | Core design philosophy |
| [ADR-0009](05-adr/0009-apple-native-rewrite.md) | Why we moved to Swift |
| [ARCHITECTURE-MIGRATION.md](/ARCHITECTURE-MIGRATION.md) | Detailed migration analysis |

## Historical Documentation

Documentation for the previous Rust/TypeScript/WASM architecture (v0.5–v0.8) has been archived to `_archived/v0.8-web/docs/` for reference.

<!-- DOC META: VERSION=2.0 | UPDATED=2025-11-26T00:00:00Z -->

