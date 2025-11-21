/* LM-only pipeline coverage: SweepScheduler ↔ CorrectionWave integration */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

vi.mock('../src/config/thresholds', () => ({
  SHORT_PAUSE_MS: 5,
  LONG_PAUSE_MS: 2000,
  MAX_SWEEP_WINDOW: 80,
  getTypingTickMs: () => 1_000_000,
  getMinValidationWords: () => 3,
  getMaxValidationWords: () => 8,
}));

import { createTypingMonitor } from '../src/pipeline/monitor';

import type { CorrectionWaveResult } from '../src/pipeline/correctionWave';

const runCorrectionWave = vi.hoisted(() =>
  vi.fn<[], Promise<CorrectionWaveResult>>(async () => ({
    diffs: [],
    activeRegion: { start: 0, end: 0 },
  })),
);

vi.mock('../src/pipeline/correctionWave', () => ({
  runCorrectionWave,
}));

let state = { text: '', caret: 0, frontier: 0 };
const tickOnce = vi.fn();
const catchUp = vi.fn(async () => {
  state.frontier = state.caret;
});
const update = (text: string, caret: number) => {
  state.text = text;
  state.caret = caret;
};
const getState = () => state;
const applyExternal = vi.fn((diff: { start: number; end: number; text: string }) => {
  if (diff.end > state.caret) return false;
  state.text = state.text.slice(0, diff.start) + diff.text + state.text.slice(diff.end);
  state.frontier = Math.max(state.frontier, diff.start + diff.text.length);
  return true;
});

vi.mock('../src/region/diffusion', () => ({
  createDiffusionController: () => ({
    update,
    tickOnce,
    catchUp,
    getState,
    applyExternal,
  }),
}));

import { createSweepScheduler } from '../src/pipeline/scheduler';
import { SHORT_PAUSE_MS } from '../src/config/thresholds';

describe('SweepScheduler LM pipeline', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    state = { text: '', caret: 0, frontier: 0 };
    applyExternal.mockClear();
    runCorrectionWave.mockReset();
    runCorrectionWave.mockResolvedValue({
      diffs: [],
      activeRegion: { start: 0, end: 0 },
    });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('applies diffs returned by runCorrectionWave', async () => {
    runCorrectionWave.mockResolvedValueOnce({
      diffs: [{ start: 0, end: 4, text: 'That', stage: 'noise' }],
      activeRegion: { start: 0, end: 4 },
    });
    const monitor = createTypingMonitor();
    const mockLM = { stream: async function* () {} } as any;
    const scheduler = createSweepScheduler(monitor, undefined, () => mockLM);
    scheduler.start();
    const text = 'this is a test';
    monitor.emit({ text, caret: text.length, atMs: Date.now() });
    vi.advanceTimersByTime(SHORT_PAUSE_MS + 1);
    await vi.runOnlyPendingTimersAsync();
    await Promise.resolve();
    expect(runCorrectionWave).toHaveBeenCalled();
    expect(applyExternal).toHaveBeenCalledWith({ start: 0, end: 4, text: 'That' });
    scheduler.stop();
  });

  it('passes tone target when tone is enabled', async () => {
    const monitor = createTypingMonitor();
    const mockLM = { stream: async function* () {} } as any;
    const scheduler = createSweepScheduler(monitor, undefined, () => mockLM, {
      toneEnabled: true,
      toneTarget: 'Professional',
    });
    scheduler.start();
    const text = 'polish this';
    monitor.emit({ text, caret: text.length, atMs: Date.now() });
    vi.advanceTimersByTime(SHORT_PAUSE_MS + 1);
    await vi.runOnlyPendingTimersAsync();
    await Promise.resolve();
    expect(runCorrectionWave).toHaveBeenCalledWith(
      expect.objectContaining({ toneTarget: 'Professional' }),
    );
    scheduler.stop();
  });

  it('swallows runCorrectionWave errors and skips applyExternal', async () => {
    runCorrectionWave.mockRejectedValueOnce(new Error('wave failed'));
    const monitor = createTypingMonitor();
    const mockLM = { stream: async function* () {} } as any;
    const scheduler = createSweepScheduler(monitor, undefined, () => mockLM);
    scheduler.start();
    const text = 'error path';
    monitor.emit({ text, caret: text.length, atMs: Date.now() });
    vi.advanceTimersByTime(SHORT_PAUSE_MS + 1);
    await vi.runOnlyPendingTimersAsync();
    await Promise.resolve();
    expect(applyExternal).not.toHaveBeenCalled();
    scheduler.stop();
  });
});
