<!--══════════════════════════════════════════════════════════════════════════
  ╔═══════════════════════════════════════════════════════════════════════════╗
  ║  ADR-0002: CARET-SAFE DIFF                                                ║
  ╚═══════════════════════════════════════════════════════════════════════════╝
    • WHAT  ▸  Never apply edits at or after the cursor
    • WHY   ▸  User trust, accessibility, flow state
-->

# ADR-0002: Caret-Safe Diff

**Status:** Active (Core Invariant)  
**Date:** 2025-08-09  
**Updated:** 2025-11-26

---

## Context

Users must never see unexpected forward edits. Screen reader users depend on stable cursor position. IME composition requires strict boundaries.

## Decision

**All diffs MUST satisfy `end <= caret`.**

```swift
/// Validates that a region is safe to modify
public func isCaretSafe(region: TextRegion, caret: Int) -> Bool {
    region.end <= caret && region.start < region.end
}
```

### Rules

1. **Boundary:** No correction may modify text at or after the cursor position
2. **Rejection:** Pipeline MUST reject proposals that cross the caret
3. **Cancellation:** If cursor moves into active correction zone, correction cancels immediately

## Consequences

### Positive
- Simple mental model for users: "text behind me gets better"
- Robust accessibility: screen reader position never disrupted
- Clean undo integration

### Negative
- Cannot fix errors user is currently typing (acceptable for trust)
- Limits some ahead-of-caret suggestions (rejected per design)

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|-----------------|
| Allow ahead edits with preview/confirm | Breaks flow, adds latency |
| Highlight-only suggestions | Still disrupts visual flow |

## Implementation

**Swift (v0.9):**
```swift
// CaretSafety.swift
public func isCaretSafe(region: TextRegion, caret: Int) -> Bool {
    region.end <= caret && region.start < region.end
}
```

**Test coverage:**
- `Tests/MindTypeCoreTests/CaretSafetyTests.swift`

---

*This ADR is a core invariant. Violating it is a critical bug.*

<!-- DOC META: VERSION=2.0 | UPDATED=2025-11-26 -->

