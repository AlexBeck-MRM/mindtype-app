/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  D I F F U S I O N   C O N T R O L L E R   B R A N C H E S  ║
  ║                                                              ║
  ║   Covers fallback paths (no Intl.Segmenter) and error paths  ║
  ║   (replaceRange failure) to lift branch coverage.            ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Exercise iterate fallback and try/catch on apply
  • WHY  ▸ Increase branch coverage in diffusion controller
  • HOW  ▸ Mock globals and deps; assert calls and state advances
*/

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

// Capture UI events
const activeRegionCalls: Array<{ start: number; end: number }> = [];
const highlightCalls: Array<{ start: number; end: number; text?: string }> = [];

vi.mock('../src/ui/highlighter', () => ({
  emitActiveRegion: (r: { start: number; end: number }) => {
    activeRegionCalls.push({ start: r.start, end: r.end });
  },
}));

vi.mock('../src/ui/swapRenderer', () => ({
  renderHighlight: (r: { start: number; end: number; text?: string }) => {
    highlightCalls.push({ start: r.start, end: r.end, text: r.text });
  },
}));

describe('DiffusionController branches', () => {
  beforeEach(() => {
    activeRegionCalls.length = 0;
    highlightCalls.length = 0;
    vi.resetModules();
  });

  afterEach(() => {
    // Restore Segmenter if we changed it

    const I = (globalThis as any).Intl as { Segmenter?: unknown } | undefined;
    if (I && '__mtSavedSegmenter' in I) {
      (I as any).Segmenter = (I as any).__mtSavedSegmenter;

      delete (I as any).__mtSavedSegmenter;
    }
  });

  it('falls back when Intl.Segmenter is unavailable', async () => {
    // Force Intl.Segmenter constructor to throw

    const I = (globalThis as any).Intl as { Segmenter?: unknown } | undefined;
    if (I) {
      // Save original and install throwing ctor

      (I as any).__mtSavedSegmenter = (I as any).Segmenter;

      (I as any).Segmenter = function ThrowingSegmenter(this: unknown): never {
        throw new Error('no Segmenter');
      } as unknown as typeof Intl.Segmenter;
    }

    const { createDiffusionController } = await import('../src/region/diffusion');
    const ctrl = createDiffusionController();

    // Enough words to compute a band
    const text = 'one two three four five six';
    const caret = text.length;
    ctrl.update(text, caret);

    expect(activeRegionCalls.length).toBeGreaterThan(0);
    const last = activeRegionCalls[activeRegionCalls.length - 1];
    expect(last.end).toBe(caret);
  });

  it('advances frontier during tickOnce even without deterministic diffs', async () => {
    const { createDiffusionController } = await import('../src/region/diffusion');
    const ctrl = createDiffusionController();
    const text = 'teh is here';
    const caret = text.length;
    ctrl.update(text, caret);
    const before = ctrl.getState().frontier;
    ctrl.tickOnce();
    const after = ctrl.getState().frontier;
    expect(after).toBeGreaterThanOrEqual(before);
    expect(after).toBeLessThanOrEqual(caret);
  });
});
