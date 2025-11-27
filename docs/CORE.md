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

Mind⠶Type amplifies human capability by removing the cognitive overhead of mechanical accuracy. Users operate at the speed of thought, trusting the system to **interpret their intent**—even when individual words are completely garbled.

## Philosophy: Interpretation, Not Correction

Mind⠶Type is **fundamentally different from autocorrect**:

| Autocorrect | Mind⠶Type |
|-------------|-----------|
| Dictionary lookup per word | LLM interprets full context |
| Fails on unknown patterns | Handles completely garbled text |
| "teh" → "the" | "iualpio" → "upon" |
| Rejects what it doesn't recognize | Reasons about what you meant |

**The key insight:** When typing at velocity, words become unrecognizable. `"msaasexd"` doesn't look like "masses"—but in context, that's clearly what was meant. Mind⠶Type uses the surrounding text to decode intent.

### Example

```
Input:  "the msaasexd has no idea who he wa showever he was a visionsary"
Output: "The masses had no idea who he was, however he was a visionary"
```

The model doesn't match `"msaasexd"` to a dictionary. It interprets: *"Given 'he was a visionary' and 'no idea who he was', what noun makes sense here?"*

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
| **Solution** | **Velocity Mode** — LLM interprets completely garbled input |
| **Success** | `"msaasexd"` → "masses", `"iualpio"` → "upon" at 180+ WPM |

**Key requirements:** Full fuzzy interpretation, context-aware decoding, complete trust interface.

**How it works:** At extreme typing speeds, words become unrecognizable. Mind⠶Type doesn't try to match them—it interprets what you meant from the surrounding context. `"ftookl"` becomes "tool" because you're writing about someone who "created a new [something]."

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

## The Interpretation Pipeline

Mind⠶Type interprets text in waves, each applying progressive refinement:

| Stage | Purpose | What it Does |
|-------|---------|--------------|
| **Interpret** | Decode garbled text | `"tbere weas"` → "there was" |
| **Structure** | Fix grammar & flow | Subject-verb agreement, articles |
| **Tone** | Adjust style (optional) | Casual ↔ Professional |

### How Interpretation Works

Unlike autocorrect, Mind⠶Type doesn't match individual words—it interprets the whole sentence:

```
Input: "once iualpio a time tbere weas a prince tgbhat wanted to crezt e"
                                                                    ↑ caret

┌─────────────────────────────────────────────────────────────────┐
│ 1. INTERPRET (whole-context LLM)                                │
│    The model reads the full text and asks:                      │
│    "What did this person intend to type?"                       │
│                                                                 │
│    Context clues: "a time", "prince", "wanted" → fairy tale     │
│    ├─ "iualpio" → "upon" (phonetic + context)                   │
│    ├─ "tbere weas" → "there was" (adjacent keys)                │
│    ├─ "tgbhat" → "who" (contextual guess)                       │
│    └─ "crezt e" → "create" (split word repair)                  │
├─────────────────────────────────────────────────────────────────┤
│ 2. VALIDATE (structural checks)                                 │
│    ├─ Same sentence count? ✓                                    │
│    ├─ Similar length (0.5x–1.8x)? ✓                             │
│    └─ Not conversational response? ✓                            │
├─────────────────────────────────────────────────────────────────┤
│ 3. SELF-REVIEW (optional)                                       │
│    LLM asks itself: "Is this interpretation reasonable?"        │
└─────────────────────────────────────────────────────────────────┘

Output: "Once upon a time there was a prince who wanted to create"
```

### Why This Works

1. **Context provides signal** — Even completely garbled words have semantic context
2. **LLMs reason, not match** — The model uses linguistic patterns, not dictionary lookup
3. **Structure is preserved** — Even with heavy interpretation, sentence count stays the same
4. **Trust, but verify** — Structural validation catches hallucinations

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

**v0.9.1 (Current):** Apple-native implementation with custom-trained MindFlow Qwen model.

### Model Architecture

| Component | Technology |
|-----------|------------|
| Base Model | Qwen 2.5 3B Instruct |
| Training | LoRA fine-tuning via MLX |
| Framework | MLX (Apple Silicon native) |
| Training Data | 4000 synthetic samples + 43 handcrafted context examples |

### Model Versions

| Version | Accuracy | Characteristics |
|---------|----------|-----------------|
| **v2** (default) | 100% | Literal interpretation, won't paraphrase |

### Demo Commands

```bash
# ENTER mode - type, press Enter, see interpretation
python3 tools/mindtype_mlx.py

# Real-time - corrections happen as you type
python3 tools/mindtype_realtime.py

# Evaluate model
python3 tools/evaluate_model.py
```

See [IMPLEMENTATION.md](IMPLEMENTATION.md) for technical details and [adr/0009-swift-rewrite.md](adr/0009-swift-rewrite.md) for architecture rationale.

---

*Mind⠶Type doesn't correct typing—it interprets intent. Context makes garbled text clear.*

<!-- DOC META: VERSION=2.2 | UPDATED=2025-11-27 -->

