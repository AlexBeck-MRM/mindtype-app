/*╔══════════════════════════════════════════════════════════╗
  ║  ░  SCHEDULER  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                            ║
  ║                                                            ║
  ║                                                            ║
  ║                                                            ║
  ║           ╌╌  P L A C E H O L D E R  ╌╌              ║
  ║                                                            ║
  ║                                                            ║
  ║                                                            ║
  ║                                                            ║
  ╚══════════════════════════════════════════════════════════╝
  • WHAT ▸ On-device by default; secure/IME exclusion; Pause-triggered sweep; stops at caret; Deterministic noise stage continues under load; graceful degradation; Correction Marker visual system with two-mode operation; Muscle memory training through burst-pause-correct cycles; Support for all seven revolutionary usage scenarios
  • WHY  ▸ REQ-PRIVACY-LOCAL, REQ-PAUSE-SWEEP, REQ-DETERMINISTIC-FIRST, REQ-CORRECTION-MARKER, REQ-BURST-PAUSE-CORRECT, REQ-SEVEN-SCENARIOS
  • HOW  ▸ See linked contracts and guides in docs
*/

import { SHORT_PAUSE_MS, getTypingTickMs } from '../config/thresholds';
import type { TypingMonitor, TypingEvent } from './monitor';
import { createDiffusionController } from '../region/diffusion';
import type { LMAdapter } from '../lm/types';
import { createLogger } from '../pipeline/logger';
import type { SecurityContext } from '../safety/security';
import { runCorrectionWave, type ToneTarget } from './correctionWave';
import { defaultActiveRegionPolicy } from '../region/policy';
import { computePauseDelay } from './pausePolicy';

export interface SweepScheduler {
  start(): void;
  stop(): void;
  setOptions(opts: Partial<PipelineOptions>): void;
  onEvent(ev: TypingEvent): void; // exposed for tests and hosts
}

export interface PipelineOptions {
  toneEnabled?: boolean;
  toneTarget?: ToneTarget; // 'None' | 'Casual' | 'Professional'
}

export function createSweepScheduler(
  monitor?: TypingMonitor,
  security?: SecurityContext,
  getLMAdapter?: () => LMAdapter | null,
  pipeline?: PipelineOptions,
): SweepScheduler {
  let lastEvent: TypingEvent | null = null;
  let timer: ReturnType<typeof setTimeout> | null = null;
  let typingInterval: ReturnType<typeof setInterval> | null = null;
  let isPauseRunning = false; // single-flight guard for pause sweeps
  // Provide default sentence/word-based policy for consistent context windows
  const diffusion = createDiffusionController(defaultActiveRegionPolicy, getLMAdapter);
  const log = createLogger('sweep');
  const opts: Required<PipelineOptions> = {
    toneEnabled: pipeline?.toneEnabled ?? false,
    toneTarget: pipeline?.toneTarget ?? 'None',
  };

  function clearIntervals() {
    if (timer) clearTimeout(timer);
    if (typingInterval) clearInterval(typingInterval);
    timer = null;
    typingInterval = null;
    isPauseRunning = false;
  }

  function onEvent(ev: TypingEvent) {
    if (security?.isSecure?.() || security?.isIMEComposing?.()) {
      // In secure contexts, stop timers and ignore events
      clearIntervals();
      log.debug('event dropped due to security/ime');
      return;
    }
    lastEvent = ev;
    log.debug('onEvent', { caret: ev.caret, textLen: ev.text.length });
    diffusion.update(ev.text, ev.caret);
    if (timer) clearTimeout(timer);
    // schedule pause catch-up with anti-thrash buffer per tier
    // Use device-tier aware debounce: WebGPU fastest, CPU slowest
    const tierDelay = computePauseDelay(SHORT_PAUSE_MS);
    timer = setTimeout(() => {
      if (isPauseRunning) return; // guard overlapping sweeps
      isPauseRunning = true;
      runSweeps()
        .catch((err) => {
          log.error('pause sweep failed', {
            err: err instanceof Error ? err.message : err,
          });
          try {
            (globalThis as unknown as Record<string, unknown>).__mtLastLMError = err;
          } catch {}
        })
        .finally(() => {
          isPauseRunning = false;
        });
    }, tierDelay);
    // ensure streaming tick during active typing
    if (!typingInterval) {
      typingInterval = setInterval(() => {
        try {
          diffusion.tickOnce();
          log.trace('tickOnce');
        } catch {
          // fail-safe: stop streaming to avoid runaway loops
          clearIntervals();
          log.warn('tickOnce threw; cleared intervals');
        }
      }, getTypingTickMs());
    }
  }

  async function runSweeps() {
    if (!lastEvent) return;
    // Final catch-up of streamed diffusion on pause with safety cap
    try {
      let steps = 0;
      const MAX_STEPS = 200; // cap to avoid infinite loops in edge cases
      while (
        diffusion.getState().frontier < diffusion.getState().caret &&
        steps < MAX_STEPS
      ) {
        await diffusion.catchUp();
        steps += 1;
        log.debug('catchUp step', { steps, frontier: diffusion.getState().frontier });
      }
      log.info('pause collected', { steps });
    } catch {
      // swallow to keep UI responsive
      log.warn('catchUp threw; continuing');
    }

    const toneTarget = opts.toneEnabled ? opts.toneTarget : 'None';
    const waveId = `wave-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    const lmAdapter = getLMAdapter?.();
    if (!lmAdapter) {
      const err = new Error(
        '[SweepScheduler] LM adapter missing — call setLMAdapter() before corrections run.',
      );
      log.error('wave.skip_no_lm', { waveId, caret: lastEvent?.caret, toneTarget });
      console.error('[SweepScheduler] LM adapter missing — corrections will not run');
      try {
        (globalThis as unknown as Record<string, unknown>).__mtLastLMError = err;
      } catch {}
      return;
    }
    console.log('[SweepScheduler] Running correction wave', {
      waveId,
      textLength: lastEvent.text.length,
      caret: lastEvent.caret,
      hasLMAdapter: !!lmAdapter,
    });
    log.info('wave.schedule', {
      waveId,
      caret: lastEvent.caret,
      textLen: lastEvent.text.length,
      toneTarget,
    });
    console.log('[SweepScheduler] Starting correction wave', {
      waveId,
      textPreview: lastEvent.text.slice(Math.max(0, lastEvent.caret - 50), lastEvent.caret),
      caret: lastEvent.caret,
    });
    const wave = await runCorrectionWave({
      text: lastEvent.text,
      caret: lastEvent.caret,
      lmAdapter,
      toneTarget,
      waveId,
    });
    // lastEvent is guaranteed non-null here (checked at start of function)
    const eventText = lastEvent.text;
    console.log('[SweepScheduler] Correction wave completed', {
      waveId,
      diffCount: wave.diffs.length,
      diffs: wave.diffs.map((d) => ({
        start: d.start,
        end: d.end,
        original: eventText.slice(d.start, d.end),
        corrected: d.text,
      })),
    });

    try {
      (
        globalThis as unknown as {
          __mtStagePreview?: { buffer?: string; context?: string };
        }
      ).__mtStagePreview = {
        buffer: lastEvent.text.slice(Math.max(0, lastEvent.caret - 48), lastEvent.caret),
        context: wave.diffs.length
          ? (wave.diffs[wave.diffs.length - 1]?.text ?? '')
          : undefined,
      };
    } catch {}

    if (wave.diffs.length === 0) {
      log.info('pause resolved with LM — no diffs', { waveId });
      console.log('[SweepScheduler] No corrections found', { waveId });
      return;
    }

    log.info('pause resolved with LM diffs', { waveId, count: wave.diffs.length });
    console.log('[SweepScheduler] Applying corrections', {
      waveId,
      count: wave.diffs.length,
    });
    for (const diff of wave.diffs) {
      const applied = diffusion.applyExternal({
        start: diff.start,
        end: diff.end,
        text: diff.text,
      });
      console.log('[SweepScheduler] Applied diff', {
        start: diff.start,
        end: diff.end,
        original: lastEvent?.text.slice(diff.start, diff.end) || '',
        corrected: diff.text,
        applied,
      });
    }
  }

  let unsubscribe: (() => void) | null = null;
  return {
    start() {
      if (!monitor) return;
      log.info('scheduler.start');
      unsubscribe = monitor.on(onEvent);
    },
    stop() {
      if (unsubscribe) unsubscribe();
      clearIntervals();
      log.info('scheduler.stop');
    },
    setOptions(next) {
      if (typeof next.toneEnabled === 'boolean') opts.toneEnabled = next.toneEnabled;
      if (next.toneTarget) opts.toneTarget = next.toneTarget;
    },
    onEvent,
  };
}
