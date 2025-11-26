/*╔══════════════════════════════════════════════════════════╗
  ║  ░  MONITOR  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
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
  • WHAT ▸ Pause-triggered sweep; stops at caret; Muscle memory training through burst-pause-correct cycles
  • WHY  ▸ REQ-PAUSE-SWEEP, REQ-BURST-PAUSE-CORRECT
  • HOW  ▸ See linked contracts and guides in docs
*/

export interface TypingEvent {
  text: string;
  caret: number;
  atMs: number;
}

export interface TypingMonitor {
  on(listener: (event: TypingEvent) => void): () => void;
  emit(event: TypingEvent): void;
}

import { createLogger, getLoggerConfig } from '../pipeline/logger';

export function createTypingMonitor(): TypingMonitor {
  // Optional debug logger
  let log: import('./logger').Logger | null = null;
  try {
    if (getLoggerConfig().enabled) log = createLogger('monitor');
  } catch {}
  const listeners = new Set<(event: TypingEvent) => void>();
  return {
    on(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    emit(event) {
      const payload = {
        caret: event.caret,
        textLen: event.text.length,
        atMs: event.atMs,
      };
      log?.debug('emit', payload);
      for (const listener of listeners) listener(event);
    },
  };
}
