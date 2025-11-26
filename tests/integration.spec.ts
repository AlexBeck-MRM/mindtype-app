/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  I N T E G R A T I O N   T E S T S  ░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   End-to-end testing of the complete streaming pipeline      ║
  ║   from typing events to applied corrections.                ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Tests the full flow: Monitor → Scheduler → Diffusion → Engine
  • WHY  ▸ Verify components work together for magic typing behavior
  • HOW  ▸ Simulates typing events; checks corrections applied properly
*/
import { describe, it, expect, vi } from 'vitest';
import { createDiffusionController } from '../src/region/diffusion';
import type { LMAdapter } from '../src/lm/types';

// Mock the UI calls for clean testing
vi.mock('../src/ui/highlighter', () => ({
  emitActiveRegion: vi.fn(),
}));

vi.mock('../src/ui/swapRenderer', () => ({
  renderHighlight: vi.fn(),
}));

describe('Streaming Diffusion Integration', () => {
  it('handles streaming tick-by-tick progression', () => {
    const diffusion = createDiffusionController();

    // Simulate typing with multiple words
    diffusion.update('Fix teh adn hte issues', 23); // At end

    // First tick should advance frontier
    const initialState = diffusion.getState();
    expect(initialState.frontier).toBe(0);

    diffusion.tickOnce();
    const afterFirstTick = diffusion.getState();
    expect(afterFirstTick.frontier).toBeGreaterThan(0);

    // Multiple ticks should advance but never cross caret
    diffusion.tickOnce();
    diffusion.tickOnce();
    const finalState = diffusion.getState();
    expect(finalState.frontier).toBeLessThanOrEqual(finalState.caret);
  });

  it('emits highlight via LM merge when LMAdapter is provided', async () => {
    vi.useFakeTimers();
    // Use mocked highlighter to assert call instead of DOM events
    const swapRenderer = await import('../src/ui/swapRenderer');
    const renderHighlight = swapRenderer.renderHighlight as unknown as ReturnType<
      typeof vi.fn
    >;

    const adapter: LMAdapter = {
      async *stream() {
        yield 'the ';
      },
    } as unknown as LMAdapter;

    const diffusion = createDiffusionController(undefined, () => adapter);
    const text = 'Hello teh world';
    diffusion.update(text, text.length);
    await diffusion.catchUp();
    await vi.advanceTimersByTimeAsync(10);
    const mock = renderHighlight as unknown as { mock: { calls: unknown[] } };
    expect(mock.mock.calls.length).toBeGreaterThan(0);
  });

  // Rule-based correction tests removed in v0.8 – LM is mandatory now.
});
