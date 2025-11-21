/**
 * Test helpers for LM parameter normalization
 */

import type { LMStreamParams } from '../../src/lm/types';
import { normalizeLMStreamParams } from '../../src/lm/types';

/**
 * Helper to normalize and stream with activeRegion/band compatibility
 */
export async function* streamWithNormalizedRegion(
  adapter: { stream: (params: LMStreamParams) => AsyncIterable<string> },
  params: {
    text: string;
    caret: number;
    band?: { start: number; end: number };
    activeRegion?: { start: number; end: number };
    settings?: Record<string, unknown> & {
      maxNewTokens?: number;
      deviceTier?: 'webgpu' | 'wasm' | 'cpu';
      localOnly?: boolean;
    };
  },
): AsyncIterable<string> {
  const normalized = normalizeLMStreamParams(params as LMStreamParams);
  // Preserve settings
  const fullParams: LMStreamParams = params.settings
    ? { ...normalized, settings: params.settings as any }
    : normalized;
  yield* adapter.stream(fullParams);
}

/**
 * Normalize LM params (band→activeRegion) - returns normalized params object
 */
export function withNormalizedRegion(params: {
  text: string;
  caret: number;
  band?: { start: number; end: number };
  activeRegion?: { start: number; end: number };
  settings?: Record<string, unknown> & {
    maxNewTokens?: number;
    deviceTier?: 'webgpu' | 'wasm' | 'cpu';
    localOnly?: boolean;
  };
}): LMStreamParams {
  const normalized = normalizeLMStreamParams(params as LMStreamParams);
  // Preserve settings if provided
  if (params.settings) {
    return { ...normalized, settings: params.settings as any };
  }
  return normalized;
}

/**
 * Mock LM params for testing
 */
export const mockLMParams = {
  text: 'Test text',
  caret: 9,
  activeRegion: { start: 0, end: 9 },
};
