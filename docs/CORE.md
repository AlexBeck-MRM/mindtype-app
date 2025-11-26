<!--══════════════════════════════════════════════════════════════════════════
  ╔═══════════════════════════════════════════════════════════════════════════╗
  ║  M I N D ⠶ T Y P E   C O R E   D O C U M E N T A T I O N                   ║
  ║                                                                           ║
  ║  Vision · Scenarios · Principles · Constraints                            ║
  ╚═══════════════════════════════════════════════════════════════════════════╝
    • WHAT  ▸  Product definition and design philosophy
    • WHO   ▸  AI agents and human developers
    • WHY   ▸  Single source of truth for behavior and intent
-->

# Mind⠶Type Core

> Transform typing from mechanical skill into **fluid expression of thought**.

## Mission

Mind⠶Type amplifies human capability by removing the cognitive overhead of mechanical accuracy. Users operate at the speed of thought, trusting the system to handle translation between rapid intent and polished communication.

---

## The Seven Scenarios

These scenarios define **who** Mind⠶Type serves and **what** success looks like. All features trace back to at least one scenario.

### Scenario 1: Academic Excellence — Maya

| Attribute | Value |
|-----------|-------|
| **Profile** | PhD student, dyslexic, writes scientific papers |
| **Challenge** | Letter transpositions break complex terminology |
| **Solution** | Three-stage pipeline with academic vocabulary |
| **Success** | "resarch" → "research" instantly, without breaking flow |

**Key requirements:** Scientific terminology, privacy for unpublished work, accessibility.

### Scenario 2: Multilingual Professional — Carlos

| Attribute | Value |
|-----------|-------|
| **Profile** | Business analyst, switches English/Spanish/Portuguese |
| **Challenge** | Mixed-language errors, keyboard mapping confusion |
| **Solution** | Context-aware language detection |
| **Success** | "finacial analisys shows que" corrected contextually |

**Key requirements:** 15ms latency at 85 WPM, professional tone preservation.

### Scenario 3: Accessibility Champion — Dr. Sarah Chen

| Attribute | Value |
|-----------|-------|
| **Profile** | Legally blind researcher, relies on screen readers |
| **Challenge** | Audio correction feedback disrupts concentration |
| **Solution** | Silent corrections with single batch announcement |
| **Success** | "Text updated behind cursor" — one announcement per wave |

**Key requirements:** Caret-safe guarantee, high-contrast marker, VoiceOver compatible.

### Scenario 4: Creative Flow — James

| Attribute | Value |
|-----------|-------|
| **Profile** | Novelist, seeks uninterrupted creative momentum |
| **Challenge** | Stopping for typos breaks creative state |
| **Solution** | Stream-of-consciousness with background refinement |
| **Success** | 35% more daily words with maintained quality |

**Key requirements:** Voice preservation, narrative coherence, minimal tone interference.

### Scenario 5: Everyday Efficiency — Emma

| Attribute | Value |
|-----------|-------|
| **Profile** | Working parent, types during stolen moments |
| **Challenge** | Fatigue-induced errors in professional emails |
| **Solution** | Invisible enhancement |
| **Success** | "campain" → "campaign" without conscious awareness |

**Key requirements:** Battery-efficient, professional tone, burst typing support.

### Scenario 6: Speed Demon — Marcus

| Attribute | Value |
|-----------|-------|
| **Profile** | Former stenographer, 225 WPM on stenotype |
| **Challenge** | Standard keyboard limits speed to ~100 WPM |
| **Solution** | **Velocity Mode** — phonetic shorthand understanding |
| **Success** | "Th defdnt clamd" → "The defendant claimed" at 180+ WPM |

**Key requirements:** Sub-15ms latency, complete trust interface.

### Scenario 7: Data Whisperer — Priya

| Attribute | Value |
|-----------|-------|
| **Profile** | Quantitative analyst, rapid data annotation |
| **Challenge** | Traditional UI too slow for analytical flow |
| **Solution** | Custom "data dialect" with intelligent formatting |
| **Success** | "hgh rvn grwth tch stk +sent" expands correctly |

**Key requirements:** Domain-specific expansion, 5× speed over traditional entry.

---

## Core Principles

These principles are **invariants**. Violating them is a bug, not a tradeoff.

### 1. Caret-Safe Guarantee

```
❌ NEVER modify text at or after the cursor position
✓ All corrections apply to "settled" text behind caret
✓ If cursor moves into correction zone → cancel immediately
```

**Why:** Users must never experience text changing under their fingers. This breaks trust and disrupts screen readers.

### 2. Privacy-First Architecture

```
✓ DEFAULT: All processing happens on-device
✓ NO text sent to external servers
✓ NO persistent storage of user input
✓ Secure fields (passwords, IME) automatically skipped
```

**Why:** Maya's unpublished research, Carlos's business communications, and everyone's private thoughts deserve absolute protection.

### 3. Burst-Pause-Correct Rhythm

```
1. BURST  — User types rapidly, trusting the system
2. PAUSE  — Natural breathing moment (500ms+ trigger)
3. CORRECT — Marker travels through text, applying fixes
4. RESUME — Seamless continuation with enhanced confidence
```

**Why:** This rhythm becomes muscle memory. Users learn to trust rather than verify.

### 4. Fail-Safe Degradation

```
✓ LM fails to load → corrections disabled (not fallback guessing)
✓ Clear error indicator in UI
✓ Explicit restart control
✓ Never partial/hidden behavior
```

**Why:** Predictable failure is better than unpredictable incorrectness.

---

## The Three-Stage Pipeline

Each correction wave processes text through three sequential stages:

| Stage | Purpose | Speed | Examples |
|-------|---------|-------|----------|
| **Noise** | Mechanical typo fixes | Fast | teh→the, hte→the, writting→writing |
| **Context** | Grammar & coherence | Medium | Subject-verb agreement, articles |
| **Tone** | Style adjustment | Slow | Optional: Casual ↔ Professional |

### Processing Flow

```
Input: "I was writting a lettr to my freind becuase I beleive"
                                          ↑ caret here

┌─────────────────────────────────────────────────────────────────┐
│ Stage 1: NOISE                                                  │
│ ├─ "writting" → "writing"                                       │
│ ├─ "lettr" → "letter"                                           │
│ ├─ "freind" → "friend"                                          │
│ └─ "beleive" → "believe"                                        │
├─────────────────────────────────────────────────────────────────┤
│ Stage 2: CONTEXT                                                │
│ └─ Grammar intact, no changes                                   │
├─────────────────────────────────────────────────────────────────┤
│ Stage 3: TONE (if enabled)                                      │
│ └─ Style adjustment if toneTarget != none                       │
└─────────────────────────────────────────────────────────────────┘

Output: "I was writing a letter to my friend because I believe"
```

---

## Constraints (Won't Do)

| Constraint | Rationale |
|------------|-----------|
| No cloud text processing | Privacy guarantee |
| No suggestion popups | Flow state preservation |
| No ahead-of-caret edits | Trust guarantee |
| No blocking dialogs | Speed requirement |
| No rules-only fallback | Predictability requirement |

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Effective WPM increase | 3× |
| Semantic accuracy | ≥95% |
| "Thought-speed typing" reports | ≥80% of users |
| Week-1 activation | ≥70% |
| Audio interruptions (accessibility) | ≤1 per correction wave |

---

## Implementation Status

**v1.0 (Current):** Apple-native Swift implementation with llama.cpp LLM.

See [IMPLEMENTATION.md](IMPLEMENTATION.md) for technical details and [adr/0009-swift-rewrite.md](adr/0009-swift-rewrite.md) for architecture rationale.

---

*Mind⠶Type doesn't just correct typing—it unlocks human potential at the intersection of thought and text.*

<!-- DOC META: VERSION=2.0 | UPDATED=2025-11-26 -->

