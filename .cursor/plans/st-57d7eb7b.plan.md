<!-- 57d7eb7b-ec1c-4a98-93dd-361a242dd93f 5f3c941a-8cab-4301-9b0e-5325d4453f61 -->

# Live Telemetry Plan

1. **Instrument diagBus publisher**

- Extend `hosts/web/src/App.tsx` (or a tiny sibling module) so, after boot, we subscribe to `diagBus` channels (`noise`, `lm-wire`, `context-window`).
- Serialize each event (add waveId when available) and push it into a lightweight bridge (e.g., `window.postMessage` or new `diagRelay.ts`).
- Guard behind `if (import.meta.env.DEV)` so production builds stay clean.

2. **Add Vite dev relay (SSE)**

- Create `hosts/web/vite.diagRelay.ts` (SSR middleware) that opens an EventSource endpoint `/diag-stream`.
- Use a shared in-memory queue so the client-side publisher can `fetch('/diag-stream/push', {body:event})` or use WebSocket; simplest: `BroadcastChannel` → middleware.
- Ensure disconnect handling and small ring buffer (≤200 events) to avoid memory churn.

3. **Monitor client hookup**

- In `monitor/src/App.tsx`, open the SSE/WebSocket endpoint when running locally; keep fallback to static map when stream unavailable.
- Update `SystemMap` to highlight nodes and append log rows when events arrive (e.g., glow `stage-noise` on noise events, show requestId tail for LM wire).

4. **Docs + validation**

- Document the new telemetry bridge in `READY-TO-DEMO.md` (mention Monitor streaming) and `monitor/README.md`.
- Add a quick `pnpm diag:smoke` script (dev-only) that starts both apps and confirms SSE endpoint responds.

### To-dos

- [ ] Subscribe to diagBus & forward events in hosts/web
- [ ] Expose dev-only SSE/WebSocket relay via Vite middleware
- [ ] Monitor app listens to stream & updates UI
- [ ] Update docs + add smoke validation instructions
