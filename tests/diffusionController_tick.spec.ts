/* Covers tickOnce early-return branch when no next word range is available */
import { describe, it, expect, vi } from 'vitest';

vi.mock('../src/ui/highlighter', () => ({
  emitActiveRegion: vi.fn(),
  renderHighlight: vi.fn(),
}));

import { createDiffusionController } from '../src/region/diffusion';

describe('DiffusionController.tickOnce early return', () => {
  it('returns early when frontier >= caret (no next word)', () => {
    const c = createDiffusionController();
    c.update('abc', 0);
    const before = c.getState().frontier;
    expect(() => c.tickOnce()).not.toThrow();
    const after = c.getState().frontier;
    expect(after).toBe(before);
  });
});
