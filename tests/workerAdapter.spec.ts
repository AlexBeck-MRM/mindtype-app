/*╔══════════════════════════════════════════════════════╗
  ║  ░  W O R K E R   A D A P T E R   ( U N I T )  ░░░░  ║
  ║                                                      ║
  ║   Basic interface validation for browser worker.     ║
  ║                                                      ║
  ╚══════════════════════════════════════════════════════╝
  • WHAT ▸ Ensure worker adapter interface is correct
  • WHY  ▸ Coverage and basic validation
  • HOW  ▸ Mock worker and test message protocol
*/
import { describe, expect, it, vi } from 'vitest';
import { createWorkerLMAdapter } from '../src/lm/workerAdapter';

function createMockWorker() {
  const base = {
    postMessage: vi.fn(),
    terminate: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  };

  const worker = {
    ...base,
    onmessage: null,
    onerror: null,
    onmessageerror: null,
  };

  return worker as unknown as Worker;
}

describe('WorkerAdapter (interface)', () => {
  it('creates adapter interface without throwing', () => {
    const mockWorker = createMockWorker();
    const makeWorker = vi.fn(() => mockWorker);

    const adapter = createWorkerLMAdapter(makeWorker);
    expect(() => adapter.init?.()).not.toThrow();
    expect(adapter.getStats?.()).toEqual({ runs: 0, staleDrops: 0 });

    adapter.abort?.();
    expect(makeWorker).toHaveBeenCalledTimes(1);
    expect(mockWorker.postMessage).toHaveBeenCalledWith({ type: 'abort' });
  });
});
