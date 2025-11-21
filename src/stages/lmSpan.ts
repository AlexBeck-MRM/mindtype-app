/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  L M   S P A N   S T R E A M I N G  ░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Shared helpers for collecting LM output for an Active      ║
  ║   Region span without duplicating boilerplate across stages. ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Stream LM chunks for a caret-safe span and sanitize output
  • WHY  ▸ Reduce duplication across Noise/Context/Tone stages
  • HOW  ▸ Wrap LMAdapter.stream with consistent normalization
*/

import type { LMAdapter, LMStreamParams } from '../lm/types';
import { extractReplacementText } from '../lm/promptBuilder';

export interface StreamActiveRegionOptions {
  text: string;
  caret: number;
  activeRegion: { start: number; end: number };
  lmAdapter: LMAdapter;
  settings?: LMStreamParams['settings'];
}

export interface StreamActiveRegionResult {
  text: string | null;
  chunkCount: number;
}

/**
 * Streams LM output for the provided Active Region span.
 * Returns null when no meaningful change is produced.
 */
export async function streamActiveRegion(
  options: StreamActiveRegionOptions,
): Promise<StreamActiveRegionResult> {
  const { text, caret, activeRegion, lmAdapter, settings } = options;
  const originalSpan = text.slice(activeRegion.start, activeRegion.end);
  const chunks: string[] = [];
  for await (const chunk of lmAdapter.stream({ text, caret, activeRegion, settings })) {
    if (chunk) chunks.push(chunk);
  }
  const normalized = normalizeStreamedText(chunks.join(''));
  if (!normalized) return { text: null, chunkCount: chunks.length };

  const extracted = extractReplacementText(normalized);
  if (extracted) {
    if (extracted === originalSpan) return { text: null, chunkCount: chunks.length };
    return { text: extracted, chunkCount: chunks.length };
  }

  if (normalized === originalSpan) return { text: null, chunkCount: chunks.length };
  return { text: normalized, chunkCount: chunks.length };
}

export function normalizeStreamedText(raw: string): string {
  if (!raw) return '';
  // Drop carriage returns / nulls but preserve deliberate whitespace
  return raw.replace(/\r/g, '').replace(/\u0000/g, '');
}
