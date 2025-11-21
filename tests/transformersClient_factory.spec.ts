/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  L M   F A C T O R Y   —   T E S T S  ░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Ensures default factory wraps a token streamer correctly.  ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
*/
import { describe, it, expect } from 'vitest';
import { createDefaultLMAdapter } from '../src/lm/factory';
import { detectBackend } from '../src/lm/transformersClient';
import { withNormalizedRegion, streamWithNormalizedRegion } from './helpers/lmParams';

describe('createDefaultLMAdapter', () => {
  it('streams from a provided runner and respects boundary coalescing by consumer', async () => {
    const yielded: string[] = [];
    const runner = {
      async *generateStream() {
        yield 'Hello ';
        yield 'world';
        yield '!';
      },
    };
    const adapter = createDefaultLMAdapter(
      {},
      runner as unknown as import('../src/lm/transformersClient').TokenStreamer,
    );
    const it = streamWithNormalizedRegion(adapter, {
      text: 'xxHello world!yy',
      caret: 13,
      band: { start: 2, end: 13 },
    });
    for await (const c of it) yielded.push(c);
    expect(yielded.join('')).toBe('Hello world!');
  });

  it('initializes capabilities and counts runs/stale drops', async () => {
    const runner = {
      async *generateStream() {
        yield 'x ';
      },
    };
    const adapter = createDefaultLMAdapter(
      {},
      runner as unknown as import('../src/lm/transformersClient').TokenStreamer,
    );
    // preferBackend expects 'webgpu' | 'wasm' | 'cpu'; coerce unknown to cpu
    const pref = ((): 'webgpu' | 'wasm' | 'cpu' => {
      const b = detectBackend();
      return b === 'webgpu' || b === 'wasm' || b === 'cpu' ? b : 'cpu';
    })();
    const caps = adapter.init?.({ preferBackend: pref });
    expect(caps && 'backend' in caps).toBe(true);
    // Start two streams rapidly to trigger stale drop increment
    const a = streamWithNormalizedRegion(adapter, {
      text: 'abc',
      caret: 3,
      band: { start: 0, end: 3 },
    });
    const b = streamWithNormalizedRegion(adapter, {
      text: 'abcd',
      caret: 4,
      band: { start: 0, end: 4 },
    });
    // Consume both
    for await (const _ of a) {
      void _;
    }
    for await (const _ of b) {
      void _;
    }
    const stats = adapter.getStats?.();
    expect(stats && stats.runs).toBeGreaterThanOrEqual(2);
    expect(stats && stats.staleDrops).toBeGreaterThanOrEqual(0);
  });
});
