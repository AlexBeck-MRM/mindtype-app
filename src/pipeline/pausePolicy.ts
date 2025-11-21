/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  P A U S E   P O L I C Y                                  ║
  ║                                                              ║
  ║   Centralized helpers for pause delay calculations based     ║
  ║   on device tier/backend capabilities.                       ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Compute adaptive pause delays for the scheduler
  • WHY  ▸ Keep tier detection in one place; avoid ad-hoc logic
  • HOW  ▸ Inspect backend via LM device detection helpers
*/

import { detectBackend } from '../lm/transformersClient';

/**
 * Returns a pause delay that adapts to the currently detected backend tier.
 * WebGPU keeps the base delay, WASM adds a small buffer, CPU adds more.
 */
export function computePauseDelay(baseMs: number): number {
  const backend = detectBackend();
  if (backend === 'webgpu') return baseMs;
  if (backend === 'wasm') return Math.round(baseMs * 1.1);
  return Math.round(baseMs * 1.3);
}
