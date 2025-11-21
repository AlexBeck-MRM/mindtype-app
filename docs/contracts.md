<!--══════════════════════════════════════════════════════════
  ╔══════════════════════════════════════════════════════════════╗
  ║  ░  S Y S T E M   C O N T R A C T S  ░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Canonical behavioral contracts that bridge product specs   ║
  ║   and implementation. Update these first, then ship code.    ║
  ║                                                              ║
  ║           ╌╌  P L A C E H O L D E R  ╌╌                      ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
    • WHAT ▸ Living source for policy/adapter/stream contracts
    • WHY  ▸ Keep TypeScript, Rust, and hosts aligned
    • HOW  ▸ SPEC blocks + plain-language notes per contract
-->

# Mind⠶Flow Contracts

Contracts describe the non-negotiable interfaces and invariants that glue the TypeScript core, Rust crate, and platform hosts together. Whenever a contract changes, update this document first, then regenerate traceability via `pnpm doc:sync`.

## Active Region Policy (render vs. context)

The active region is the only portion of text the engine is allowed to edit. We maintain two windows:

- **Render window** (~20 trailing words). Visual overlays and sweep effects must remain inside this window.
- **Context window** (extends past render). Used to build LM prompts but still stops before secure fields or the caret.

On macOS the overlay is drawn in the focused NSText input; on the web we render a shimmer/fade span behind the caret. Reduced-motion users get a static gradient with the same bounds.

<!-- SPEC:CONTRACT
id: CONTRACT-ACTIVE-REGION
title: Active region policy (render vs context ranges)
modules:
  - src/region/policy.ts
  - src/region/diffusion.ts
  - core-rs/src/active_region.rs
invariants:
  - Context can extend beyond the render window but never crosses secure fields or the caret
  - Render range must exclude the caret and shrink immediately when the user re-enters it
-->

## LMAdapter Streaming Contract

The LM adapter owns prompt construction, device-tier fallbacks, and span merges. Hosts supply `LMStreamParams` and receive an async generator that yields caret-safe diffs.

- Never emit a diff that modifies text at or after the caret.
- Abort in-flight runs if the user keeps typing (single-flight guarantee).
- Tone stage is optional; tone `None` short circuits after context.

```ts
export interface LMStreamParams {
  text: string;
  caret: number;
  active_region: { start: number; end: number };
  settings?: Record<string, unknown>;
}
```

<!-- SPEC:CONTRACT
id: CONTRACT-LM-ADAPTER
title: LMAdapter streaming contract
modules:
  - src/lm/types.ts
  - src/lm/factory.ts
  - src/lm/policy.ts
  - src/region/policy.ts
invariants:
  - Never emit a diff that modifies content at/after the caret (REQ-CARET-SAFE)
  - Abort or drop stale generations if the active region changes before commit
types:
  - name: LMStreamParams
    ts: |
      export interface LMStreamParams {
        text: string;
        caret: number;
        active_region: { start: number; end: number };
        settings?: Record<string, unknown>;
      }
-->

## JSONL LM Stream Protocol

Transformers run inside workers (Web or native) and speak a JSON Lines protocol so diagnostics and hosts can replay waves deterministically. Events are newline-delimited JSON objects with a required `type` field. Order is always:

1. `meta` → optional `rules`
2. `stage start` (context) → `diff`/`commit`
3. `stage start` (tone) → `diff`/`commit` (if tone enabled)
4. `done`

Hosts convert region-local span offsets into absolute document positions before applying diffs.

<!-- SPEC:CONTRACT
id: CONTRACT-LM-STREAM
title: JSONL LM stream protocol (context → tone)
status: active
modules:
  - src/lm/types.ts
  - src/lm/mockStreamAdapter.ts
  - hosts/web/src/worker/lmWorker.ts
acceptance:
  - tests/lm_stream.spec.ts#SCEN-LM-STREAM-001
  - e2e/tests/lm_lab.spec.ts#SCEN-LM-LAB-002
invariants:
  - Events are JSON objects per line with required type + stage metadata
  - Tone stage cannot start until the context stage commits successfully
-->

Keep this file concise, authoritative, and device-agnostic—the same contracts power the web demo, macOS host, and Rust FFI bindings.

<!-- DOC META: VERSION=1.0 | UPDATED=2025-11-20T00:00:00Z -->

