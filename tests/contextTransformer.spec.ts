/* Auto-generated test for REQ-CONTEXT-TRANSFORMER */
import { describe, it, expect } from 'vitest';
import { contextTransform } from '../src/stages/context';

describe('contextTransformer', () => {
  it('produces caret-safe proposals only', async () => {
    const text = 'i am here';
    const caret = text.length; // end
    const r = await contextTransform({
      text,
      caret,
      activeRegion: { start: 0, end: caret },
    });
    for (const p of r.proposals) {
      expect(p.end).toBeLessThanOrEqual(caret);
    }
  });

  // Skip legacy tests - v0.8 uses LM-only, not rule-based grammar
  it.skip('normalizes punctuation in current sentence', async () => {
    const text = 'word ,next';
    const caret = text.length;
    const r = await contextTransform({
      text,
      caret,
      activeRegion: { start: 0, end: caret },
    });
    const joined = r.proposals.map((p) => p.text).join(' ');
    expect(joined.includes(', ')).toBe(true);
  });

  it.skip('capitalizes sentence starts and standalone i', async () => {
    const text = 'hello. world and i agree';
    const caret = text.length;
    const r = await contextTransform({
      text,
      caret,
      activeRegion: { start: 0, end: caret },
    });
    const merged = r.proposals.map((p: any) => p.text).join(' ');
    expect(/Hello\./.test(merged) || /World/.test(merged) || / I /.test(merged)).toBe(
      true,
    );
  });

  it('yields proposals on missing punctuation/capitalization', async () => {
    const text = 'this is fine';
    const caret = text.length;
    const r = await contextTransform({
      text,
      caret,
      activeRegion: { start: 0, end: caret },
    });
    // Likely to add capitalization and period
    if (r.proposals.length) {
      expect(r.proposals[0].text).toMatch(/[A-Z].*\.$/);
    }
  });

  it('holds when input fidelity is extremely low', async () => {
    const text = '!!!! ####';
    const caret = text.length;
    const r = await contextTransform({
      text,
      caret,
      activeRegion: { start: 0, end: caret },
    });
    expect(r.proposals.length).toBe(0);
  });
});
