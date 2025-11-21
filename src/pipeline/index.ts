/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  M I N D T Y P E R   E N T R Y  ░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Wires TypingMonitor → SweepScheduler → Engines.            ║
  ║   Single entrypoint for bootstrapping the system.            ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Bootstraps monitoring and scheduling pipelines
  • WHY  ▸ Provides a stable API for host apps/tests
  • HOW  ▸ Imports core modules; returns handles for control
*/

import { createTypingMonitor, type TypingEvent } from '../pipeline/monitor';
import { createSweepScheduler } from '../pipeline/scheduler';
import { createDefaultSecurityContext, type SecurityContext } from '../safety/security';
import type { LMAdapter } from '../lm/types';
import { createLogger } from './logger';
export { createDefaultLMAdapter } from '../lm/factory';

export type BootOptions = {
  security?: SecurityContext;
  toneEnabled?: boolean;
  toneTarget?: 'None' | 'Casual' | 'Professional';
  lmAdapter?: LMAdapter;
};

export function boot(options?: BootOptions) {
  const monitor = createTypingMonitor();
  const security = options?.security ?? createDefaultSecurityContext();
  // LM adapter must be injected by the host; start as null and require setLMAdapter()
  let lmAdapter: LMAdapter | null =
    (options as { lmAdapter?: LMAdapter } | undefined)?.lmAdapter ?? null;
  const scheduler = createSweepScheduler(monitor, security, () => lmAdapter, {
    toneEnabled: options?.toneEnabled,
    toneTarget: options?.toneTarget,
  });
  const log = createLogger('pipeline');

  let started = false;

  function start() {
    if (!started) {
      log.info('start');
      scheduler.start();
      started = true;
    } else {
      log.debug('start_skipped');
    }
  }

  function stop() {
    if (started) {
      log.info('stop');
      scheduler.stop();
      started = false;
    } else {
      log.debug('stop_skipped');
    }
  }

  function ingest(text: string, caret: number, atMs: number = Date.now()) {
    const ev: TypingEvent = { text, caret, atMs };
    log.debug('ingest', { caret, textLen: text.length });
    monitor.emit(ev);
  }

  function setLMAdapter(adapter: LMAdapter) {
    lmAdapter = adapter;
    log.info('lmAdapter.set', {
      hasAdapter: Boolean(adapter),
      stats: adapter.getStats?.(),
    });
  }

  function isRunning() {
    return started;
  }

  return {
    // controls
    start,
    stop,
    ingest,
    setLMAdapter,
    getLMAdapter: () => lmAdapter,
    isRunning,
    // exposed handles for advanced hosts/tests
    monitor,
    scheduler,
    security,
    setToneEnabled(v: boolean) {
      scheduler.setOptions({ toneEnabled: v });
    },
    setToneTarget(v: 'None' | 'Casual' | 'Professional') {
      scheduler.setOptions({ toneTarget: v });
    },
  };
}
