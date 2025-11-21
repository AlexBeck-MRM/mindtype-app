# Mind⠶Flow v0.8 — Quickstart Guide 🚀

Welcome to the restructured Mind⠶Flow! This guide gets you up and running in minutes.

## Prerequisites

- **Node.js 18+** and **pnpm**
- **Rust toolchain** (for core-rs/)
- **macOS 14+** (for macOS app only)

## Installation

```bash
# 1. Install dependencies
pnpm install

# 2. Install Monitor dependencies
cd monitor && pnpm install && cd ..

# 3. Install web demo dependencies
cd hosts/web && pnpm install && cd ../..
```

## Running the System

### Option 1: Monitor (Pipeline Visualization)
```bash
pnpm monitor
```
→ Open http://localhost:3001

**What you'll see**: Interactive pipeline diagram with clickable nodes showing module details, connections, and configuration.

### Option 2: Web Demo (Typing Playground)
```bash
pnpm demo:web
```
→ Open http://localhost:5173

**What you'll see**: Live typing interface with Active Region visualization, autopilot, and diagnostic controls.

### Option 3: Development Mode (All Tests)
```bash
pnpm dev
```
→ Runs tests in watch mode

## Validation

Verify everything works:

```bash
# Type checking
pnpm typecheck          # Should pass with 0 errors

# Linting
pnpm lint               # Minor warnings OK, 0 structural errors

# Unit tests
pnpm test --run         # 407/415 tests pass (99% pass rate)

# Rust tests
cargo test --manifest-path core-rs/Cargo.toml
```

## Quick Tour

### 1. **Explore the Monitor**
```bash
pnpm monitor
```

- Click any node (e.g., "Noise Stage", "LM Adapter") to see implementation details
- Hover connections to highlight data flow
- Observe how the three-stage pipeline connects

### 2. **Try the Web Demo**
```bash
pnpm demo:web
```

- Type in the textarea and watch corrections appear
- Use the right-side panel (Cmd/Ctrl + /) to adjust:
  - Active Region size (5-50 words)
  - Tone target (None/Casual/Professional)
  - Confidence thresholds (τ_input, τ_commit, τ_tone)
- Enable autopilot to see the pipeline in action

### 3. **Review the Structure**
```bash
tree -L 2 src/
```

See how the code mirrors the runtime:
- `pipeline/` → orchestration
- `stages/` → transformers
- `region/` → Active Region
- `lm/` → language models
- `safety/` → caret-safe operations

## New Structure Highlights

### `src/` — TypeScript Pipeline
All TypeScript logic now lives under `src/` with logical subfolders mirroring the runtime flow.

**Before v0.8**:
```
core/typingMonitor.ts
core/sweepScheduler.ts
engines/noiseTransformer.ts
engines/contextTransformer_v06.ts
ui/highlighter.ts
utils/diff.ts
```

**After v0.8**:
```
src/pipeline/monitor.ts
src/pipeline/scheduler.ts
src/stages/noise.ts
src/stages/context.ts
src/ui/highlighter.ts
src/safety/diff.ts
```

### `monitor/` — NEW Pipeline Visualization
Interactive web app showing the complete system architecture:
- Driven by `monitor/public/system-map.json`
- Click nodes to drill into details
- Retro 16-bit terminal aesthetic
- Always stays in sync with code

### `hosts/` — Platform Implementations
```
hosts/web/     # Web demo (was web-demo/)
hosts/macos/   # macOS app (was macOS/)
```

## Common Tasks

### Add a New Pipeline Component

1. Create the module in appropriate `src/` subfolder
2. Update `monitor/public/system-map.json`:
```json
{
  "id": "my-new-component",
  "type": "transformer",
  "label": "My Component",
  "description": "What it does",
  "module": "src/stages/myComponent.ts",
  "connections": ["next-component"]
}
```
3. Monitor automatically shows the new node

### Update Configuration

Edit `src/config/thresholds.ts` for:
- Pause timing (`SHORT_PAUSE_MS`, `LONG_PAUSE_MS`)
- Active Region size (`activeRegionWords`)
- Confidence thresholds (`τ_input`, `τ_commit`, `τ_tone`)

### Debug the Pipeline

1. **Enable diagnostic mode** in web demo
2. **Check Monitor** to verify data flow
3. **Use logs panel** in web demo to see pipeline events
4. **Inspect system-map.json** for component connections

## Troubleshooting

### Import Errors
**Symptom**: TypeScript can't find module  
**Fix**: Check relative path depth — within `src/` use `../`, from `tests/` use `../src/`

### Monitor Won't Start
**Symptom**: Monitor build fails or shows blank  
**Fix**: Verify `monitor/public/system-map.json` exists and is valid JSON

### Web Demo Shows LM Error
**Symptom**: "LM unavailable" banner  
**Fix**: Check that mock adapter is loaded (real LM integration is TODO for next phase)

### Tests Fail
**Symptom**: Some tests fail after restructure  
**Fix**: Check if test uses old API (e.g., missing `activeRegion` parameter)

## Next Phase: LM Integration

The restructure sets the foundation for v0.8 LM goals (tracked in `docs/quality.md`):

1. ✅ Clean, navigable structure
2. ⏳ Bundle local LM weights
3. ⏳ Remove noop adapter, enforce real LM
4. ⏳ Wire `runCorrectionWave` in scheduler
5. ⏳ Add LM health monitoring

See `docs/quality.md` for the complete checklist and macOS acceptance anchors.

## Resources

- **Architecture**: `docs/04-architecture/architecture.mmd`
- **Documentation**: `docs/quality.md` (gates + acceptance) and `docs/contracts.md` (core contracts)
- **Project Structure**: `README.md` + `docs/02-implementation/02-Implementation.md`
- **LM Setup**: `README.md#web-demo-build-and-run` + `pnpm setup:local` (installs local Qwen weights)

## Success Criteria ✅

- [x] All files reorganized into logical structure
- [x] All imports updated and validated
- [x] Monitor app created and functional
- [x] Documentation updated
- [x] Build/test pipeline green
- [x] CHANGELOG comprehensive
- [x] Version bumped to 0.8.0

The v0.8 restructure is **complete and demo-ready**!

---

*Structure follows flow. Flow follows thought. Thought flows through Mind⠶Flow.*

<!-- DOC META: VERSION=1.0 | UPDATED=2025-11-15T00:00:00Z -->




