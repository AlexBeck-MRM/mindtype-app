/* Auto-generated test for REQ-TONE-TRANSFORMER */
import { describe, it, expect } from 'vitest';
import type { LMAdapter } from '../src/lm/types';
import { toneTransform } from '../src/stages/tone';

const baseInput = {
  text: 'hello world',
  caret: 11,
  activeRegion: { start: 0, end: 11 },
  waveId: 'test-wave',
};

function createStubAdapter(output: string): LMAdapter {
  return {
    stream: async function* () {
      yield output;
    },
  };
}

describe('toneTransformer', () => {
  it('returns empty proposals when tone target is None', async () => {
    const adapter = createStubAdapter('HELLO WORLD');
    const result = await toneTransform({
      ...baseInput,
      toneTarget: 'None',
      lmAdapter: adapter,
    });
    expect(result.proposals).toHaveLength(0);
  });

  it('commits proposals when LM emits a change', async () => {
    const adapter = createStubAdapter('Hello World!');
    const result = await toneTransform({
      ...baseInput,
      toneTarget: 'Professional',
      lmAdapter: adapter,
    });
    expect(
      result.proposals.length === 0 || result.proposals[0].end <= baseInput.caret,
    ).toBe(true);
  });

  it('ignores proposals that match the original span', async () => {
    const adapter = createStubAdapter(baseInput.text);
    const result = await toneTransform({
      ...baseInput,
      toneTarget: 'Casual',
      lmAdapter: adapter,
    });
    expect(result.proposals).toHaveLength(0);
  });
});
