/* Covers sweep scheduler runSweeps try/catch branch when diffusion.catchUp throws */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

vi.mock('../src/config/thresholds', () => ({
  SHORT_PAUSE_MS: 5,
  LONG_PAUSE_MS: 2000,
  MAX_SWEEP_WINDOW: 80,
  getTypingTickMs: () => 1_000_000,
  getMinValidationWords: () => 3,
  getMaxValidationWords: () => 8,
}));

// Mock correction wave to assert LM path runs after catchUp throws
const runCorrectionWave = vi.hoisted(() =>
  vi.fn<[], Promise<CorrectionWaveResult>>(async () => ({
    diffs: [],
    activeRegion: { start: 0, end: 0 },
  })),
);

vi.mock('../src/pipeline/correctionWave', () => ({
  runCorrectionWave,
}));

const tickOnce = vi.fn();
const catchUp = vi.fn(async () => {
  throw new Error('catchUp failed');
});
let state = { text: '', caret: 5, frontier: 0 };
const update = (text: string, caret: number) => {
  state.text = text;
  state.caret = caret;
};
const getState = () => state;
vi.mock('../src/region/diffusion', () => ({
  createDiffusionController: () => ({ update, tickOnce, catchUp, getState }),
}));

import { createTypingMonitor } from '../src/pipeline/monitor';
import { createSweepScheduler } from '../src/pipeline/scheduler';
import { SHORT_PAUSE_MS } from '../src/config/thresholds';
import type { CorrectionWaveResult } from '../src/pipeline/correctionWave';

describe('SweepScheduler catchUp error branch', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    runCorrectionWave.mockClear();
  });
  afterEach(() => {
    vi.useRealTimers();
  });

  it('swallows catchUp error and continues with engines', async () => {
    const monitor = createTypingMonitor();
    const mockLM = { stream: async function* () {} } as any;
    const scheduler = createSweepScheduler(monitor, undefined, () => mockLM);
    scheduler.start();
    monitor.emit({ text: 'abc def', caret: 7, atMs: Date.now() });

    vi.advanceTimersByTime(SHORT_PAUSE_MS + 1);
    await vi.runOnlyPendingTimersAsync();
    await Promise.resolve();

    expect(runCorrectionWave).toHaveBeenCalled();
  });
});
