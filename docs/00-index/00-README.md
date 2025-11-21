<!--══════════════════════════════════════════════════════════
  ╔══════════════════════════════════════════════════════════════╗
  ║  ░  M A S T E R   D O C U M E N T  ░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   The authoritative, newcomer‑friendly entry point.          ║
  ║   Dense in facts, gentle in tone, with links to go deeper.   ║
  ║                                                              ║
  ║           ╌╌  P L A C E H O L D E R  ╌╌                      ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
    • WHAT ▸ Master index + orientation for all documentation
    • WHY  ▸ One source of truth; everything links here and back
    • HOW  ▸ Short sections + cross‑links to deeper, canonical docs
-->

## Start here

- Master Plan & Tasks: [`docs/02-implementation/02-Implementation.md`](./02-implementation/02-Implementation.md)
- Product Requirements (PRD): [`docs/01-prd/01-PRD.md`](./01-prd/01-PRD.md)
- Architecture (diagram + ADRs): [`docs/04-architecture/`](./04-architecture/) and [`docs/05-adr/`](./05-adr/)
- Contracts: [`docs/contracts.md`](../contracts.md)
- Quality & QA: [`docs/quality.md`](../quality.md)
- Principles: [`docs/03-system-principles/03-System-Principles.md`](./03-system-principles/03-System-Principles.md)

Tip (for the parents): If you only read two docs to grasp the build, read this page and `implementation.md`. Everything else is linked from those two.

## Folder purposes

- Root (this folder)
  - Canonical top‑level docs: PRD, implementation, system principles, contracts, quality, PDF requirements.
  - Versioning policy now lives in `package.json` + `docs/quality.md` (quality gates control releases).

- `04-architecture/`
  - `README.md` walks the stack; `architecture.mmd` is the living diagram. ADRs live next door in `05-adr/`.

- `05-adr/`
  - Architectural Decision Records; permanent, numbered, and linked back to requirements + modules.

### Cross‑links (everything ↔ Master)

- Principles ↔ ADRs ↔ Architecture ↔ Guides ↔ QA form a closed loop:
  - Principles set behavior
  - ADRs lock consequential decisions
  - Architecture shows where behavior lives
  - Guides define exact contracts
  - QA verifies behavior continuously

Shortcuts:

- Back to Master (this page): `docs/00-index/00-README.md`
- Master Tasks: [`02-Implementation.md`](./02-implementation/02-Implementation.md)
- Revolutionary Roadmap: [`docs/02-implementation/02-Implementation.md#phase-5--macos-mvp`](./02-implementation/02-Implementation.md#phase-5--macos-mvp)

### Naming note

- Public‑facing name in messaging: “Mind⠶Flow”. Internal code and tests previously used “Mind⠶Flow”; docs now use Mind⠶Flow consistently.

## Glossary

- **Correction Marker**: Revolutionary visual system showing AI intelligence working alongside human creativity
- **Burst-Pause-Correct**: Natural typing rhythm where rapid bursts are followed by intelligent correction
- **Active Region**: Small neighborhood behind the caret (20 words) used for safe corrections
- **Listening Mode**: Correction Marker pulses with hypnotic braille animation while user types
- **Correction Mode**: Marker travels through text applying corrections with speed adaptation
- **Velocity Mode**: Revolutionary speed enhancement enabling 180+ WPM typing
- **Thought-Speed Typing**: Cognitive augmentation where users operate at the speed of neural firing
- **Seven Scenarios**: Revolutionary usage patterns from academic to speed typing to data analysis

## Conventions

- One canonical home per topic; avoid duplicates. If two docs drift or overlap, merge or link — don’t fork. If a mirror exists for export (e.g., NotebookLM), it must state clearly that it is non‑canonical and link back here.
- Cross‑link related content (PRD ↔ ADR ↔ architecture ↔ guides ↔ QA) for traceability.
- Keep Swiss‑grid headers; prefer concise files with hyperlinks over long monoliths.

## Where to edit what

- Explanatory specs (docs only): `docs/13-spec/spec/` (e.g., `docs/13-spec/spec/thresholds.yaml`).
- Live configuration (runtime): `config/defaultThresholds.ts`.
- Rule of thumb: docs/spec explains intent; config/ drives the running system.

---

## Orientation (plain language)

**Mind⠶Flow transforms typing from a mechanical skill into fluid expression of thought.** Through our revolutionary **Correction Marker** system, users achieve **thought-speed typing** with unprecedented accuracy and flow state preservation.

The **Correction Marker** acts as an intelligent visual worker that travels through your text, applying corrections behind your cursor while you maintain unbroken typing rhythm. Experience the **Burst-Pause-Correct** methodology that trains your muscle memory for optimal typing flow.

**Seven Revolutionary Scenarios** demonstrate Mind⠶Flow's transformative power:

- **Academic Excellence**: PhD students with dyslexia achieve 50% faster writing
- **Multilingual Mastery**: Business analysts create documents 40% faster across languages
- **Accessibility Champion**: Visually impaired researchers experience 60% fewer interruptions
- **Creative Flow**: Novelists increase daily word count by 35% with maintained quality
- **Professional Polish**: Working parents achieve 90% professional tone automatically
- **Speed Demon**: Former stenographers unlock 180+ WPM on standard keyboards
- **Data Whisperer**: Analysts process data 5× faster with intelligent formatting

- How it works: see Architecture overview → [`./04-architecture/README.md`](./04-architecture/README.md)
- Safety rules: see [`03-System-Principles.md`](./03-system-principles/03-System-Principles.md)
- Try it quickly: follow `README.md#web-demo-build-and-run` for the live demo

<!-- DOC META: VERSION=1.0 | UPDATED=2025-09-17T20:45:45Z -->
