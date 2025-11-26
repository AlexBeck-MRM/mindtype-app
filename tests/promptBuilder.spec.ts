import { describe, it, expect } from 'vitest';
import {
  buildCorrectionPrompt,
  buildTestPrompt,
  extractReplacementText,
} from '../src/lm/promptBuilder';

describe('promptBuilder', () => {
  it('wraps stage instructions in the Qwen chat template', () => {
    const prompt = buildCorrectionPrompt({
      stage: 'noise',
      text: 'helo wrld',
      activeRegion: { start: 0, end: 9 },
      contextBefore: 'start',
      contextAfter: 'finish',
    });
    expect(prompt).toContain('<|im_start|>system');
    expect(prompt).toContain('<|im_start|>user');
    expect(prompt).toContain('<|im_start|>assistant');
    expect(prompt).toContain('<text>helo wrld</text>');
    expect(prompt).toMatch(/Respond with valid JSON ONLY/i);

    const testPrompt = buildTestPrompt('noize');
    expect(testPrompt).toContain('<|im_start|>system');
    expect(testPrompt).toContain('<|im_start|>assistant');
    expect(testPrompt).toContain('<text>noize</text>');
  });

  it('extracts replacement text from noisy JSON payloads', () => {
    const payload = 'preface {"replacement":"fixed text"} extra tokens';
    expect(extractReplacementText(payload)).toBe('fixed text');
  });
});
