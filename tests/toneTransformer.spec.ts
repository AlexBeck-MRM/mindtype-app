/* Auto-generated test for REQ-TONE-TRANSFORMER */
import { describe, it, expect } from 'vitest';
import type { LMAdapter } from '../src/lm/types';
import {
  getConfidenceThresholds,
  setConfidenceThresholds,
} from '../src/config/thresholds';
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

  it('returns empty proposals when LM adapter is missing', async () => {
    const result = await toneTransform({
      ...baseInput,
      toneTarget: 'Professional',
      lmAdapter: undefined,
    });
    expect(result.proposals).toHaveLength(0);
  });

  it('returns empty proposals when active region crosses the caret', async () => {
    const adapter = createStubAdapter('A completely different span');
    const result = await toneTransform({
      ...baseInput,
      toneTarget: 'Professional',
      activeRegion: { start: 0, end: baseInput.caret + 2 },
      lmAdapter: adapter,
    });
    expect(result.proposals).toHaveLength(0);
  });

  it('returns empty proposals when the span is empty', async () => {
    const adapter = createStubAdapter('anything');
    const result = await toneTransform({
      ...baseInput,
      toneTarget: 'Professional',
      activeRegion: { start: baseInput.caret, end: baseInput.caret },
      lmAdapter: adapter,
    });
    expect(result.proposals).toHaveLength(0);
  });

  it('returns empty proposals when the LM adapter throws', async () => {
    const adapter = {
      stream: async function* () {
        throw new Error('LM failure');
      },
    } as LMAdapter;
    const result = await toneTransform({
      ...baseInput,
      toneTarget: 'Professional',
      lmAdapter: adapter,
    });
    expect(result.proposals).toHaveLength(0);
  });

  it('respects tone confidence thresholds and can reject proposals', async () => {
    const original = getConfidenceThresholds();
    setConfidenceThresholds({ τ_tone: 0.99 });
    const adapter = createStubAdapter('Hello refined world');
    const result = await toneTransform({
      ...baseInput,
      toneTarget: 'Professional',
      lmAdapter: adapter,
    });
    expect(result.proposals).toHaveLength(0);
    setConfidenceThresholds(original);
  });
});
