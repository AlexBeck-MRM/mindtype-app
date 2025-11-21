/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  S W E E P   S C H E D U L E R   T O N E   A P P L Y  ░░  ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Cover tone branch with commit decision and application
  • WHY  ▸ Increase branch coverage in scheduler tone path
*/
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { createSweepScheduler } from '../src/pipeline/scheduler';

vi.mock('../src/config/thresholds', () => ({
  SHORT_PAUSE_MS: 5,
  LONG_PAUSE_MS: 2000,
  MAX_SWEEP_WINDOW: 80,
  getTypingTickMs: () => 10,
  getMinValidationWords: () => 2,
  getMaxValidationWords: () => 3,
}));

const applyExternal = vi.fn();
vi.mock('../src/region/diffusion', () => ({
  createDiffusionController: () => ({
    update: vi.fn(),
    tickOnce: vi.fn(),
    catchUp: vi.fn(async () => {}),
    getState: () => ({ text: 'Hello world.', caret: 12, frontier: 6 }),
    applyExternal,
  }),
}));

import type { CorrectionWaveResult } from '../src/pipeline/correctionWave';

const runCorrectionWave = vi.hoisted(() =>
  vi.fn<[], Promise<CorrectionWaveResult>>(async () => ({
    diffs: [{ start: 0, end: 5, text: 'Howdy', stage: 'tone' }],
    activeRegion: { start: 0, end: 5 },
  })),
);

vi.mock('../src/pipeline/correctionWave', () => ({
  runCorrectionWave,
}));

describe('sweepScheduler tone apply path', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    applyExternal.mockClear();
  });
  afterEach(() => {
    vi.useRealTimers();
  });

  it('applies tone proposal when toneEnabled=true and decision=commit', async () => {
    const monitor = {
      on: (fn: (e: { text: string; caret: number; atMs: number }) => void) => {
        fn({ text: 'Hello world.', caret: 12, atMs: Date.now() });
        return () => {};
      },
    } as any;
    const mockLM = { stream: async function* () {} } as any;
    const sch = createSweepScheduler(monitor, undefined, () => mockLM, {
      toneEnabled: true,
      toneTarget: 'Professional',
    });
    sch.start();
    // allow pause to trigger runSweeps and flush async tasks
    vi.advanceTimersByTime(6);
    await vi.runOnlyPendingTimersAsync();
    await Promise.resolve();
    expect(applyExternal).toHaveBeenCalled();
  });
});
