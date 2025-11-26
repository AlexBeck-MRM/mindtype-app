import { describe, it, expect } from 'vitest';
import { noiseTransform } from '../src/stages/noise';
import type { LMAdapter } from '../src/lm/types';
function createAdapterMock(chunks: string[]): LMAdapter {
  return {
    async *stream() {
      for (const chunk of chunks) {
        yield chunk;
      }
    },
  } as unknown as LMAdapter;
}

describe('noiseTransform', () => {
  it('applies LM corrections when replacement differs', async () => {
    const adapter = createAdapterMock(['{"replacement":"hello world"}']);
    const result = await noiseTransform({
      text: 'helo world',
      caret: 10,
      activeRegion: { start: 0, end: 10 },
      lmAdapter: adapter,
    });
    expect(result.diff).not.toBeNull();
    expect(result.diff?.text).toBe('hello world');
  });

  it('returns null diff when LM emits no change', async () => {
    const adapter = createAdapterMock(['']);
    const result = await noiseTransform({
      text: 'hello',
      caret: 5,
      activeRegion: { start: 0, end: 5 },
      lmAdapter: adapter,
    });
    expect(result.diff).toBeNull();
  });

  it('skips processing when active region is not caret safe', async () => {
    const adapter = createAdapterMock(['{"replacement":"text"}']);
    const result = await noiseTransform({
      text: 'unsafe',
      caret: 3,
      activeRegion: { start: 0, end: 5 },
      lmAdapter: adapter,
    });
    expect(result.diff).toBeNull();
  });

  it('throws when LM adapter is missing', async () => {
    await expect(
      noiseTransform({
        text: 'hello',
        caret: 5,
        activeRegion: { start: 0, end: 5 },
      }),
    ).rejects.toThrow(/Missing LM adapter/);
  });
});
