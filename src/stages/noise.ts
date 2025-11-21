/*╔══════════════════════════════════════════════════════════╗
  ║  ░  NOISE  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                            ║
  ║                                                            ║
  ║                                                            ║
  ║                                                            ║
  ║           ╌╌  P L A C E H O L D E R  ╌╌              ║
  ║                                                            ║
  ║                                                            ║
  ║                                                            ║
  ║                                                            ║
  ╚══════════════════════════════════════════════════════════╝
  • WHAT ▸ Never modify at or after the caret; Deterministic noise stage continues under load; graceful degradation; Active Area editable; Context Area read-only; Speed enhancement mode for 180+ WPM typing; Support for all seven revolutionary usage scenarios
  • WHY  ▸ REQ-CARET-SAFETY, REQ-DETERMINISTIC-FIRST, REQ-ZONES, REQ-VELOCITY-MODE, REQ-SEVEN-SCENARIOS
  • HOW  ▸ See linked contracts and guides in docs
*/

import type { LMAdapter } from '../lm/types';
import { getDefaultLMConfig } from '../lm/config';
import { isCaretSafe } from '../safety/grapheme';
import { createLogger } from '../pipeline/logger';
import { streamActiveRegion } from './lmSpan';

const LM_LOCAL_PATH =
  getDefaultLMConfig().localModelPath ??
  '/mindtype/models/onnx-community/Qwen2.5-0.5B-Instruct';
const log = createLogger('stage.noise');

export interface NoiseInput {
  text: string;
  caret: number;
  activeRegion: { start: number; end: number };
  lmAdapter?: LMAdapter;
  waveId?: string;
}

export interface NoiseResult {
  diff: { start: number; end: number; text: string } | null;
}

export async function noiseTransform(input: NoiseInput): Promise<NoiseResult> {
  const { text, caret, activeRegion, lmAdapter, waveId } = input;

  if (!lmAdapter) {
    throw new Error(
      '[NoiseTransformer] Missing LM adapter — all corrections must run through the LM.',
    );
  }

  // Ensure Active Region is caret-safe
  if (!isCaretSafe(activeRegion.start, activeRegion.end, caret)) {
    return { diff: null };
  }

  // Extract text from Active Region
  const spanText = text.slice(activeRegion.start, activeRegion.end);
  if (spanText.length === 0) {
    return { diff: null };
  }

  const telemetry = {
    waveId,
    caret,
    start: activeRegion.start,
    end: activeRegion.end,
    spanLen: spanText.length,
  };

  log.debug('start', telemetry);

  try {
    const stageStart = Date.now();
    const { text: correctedText, chunkCount } = await streamActiveRegion({
      text,
      caret,
      activeRegion,
      lmAdapter,
      settings: {
        maxNewTokens: Math.min(32, Math.floor(spanText.length * 1.2)), // Conservative for noise fixes
        deviceTier: 'cpu', // Start conservative; device detection happens in adapter
        localOnly: true,
        localModelPath: LM_LOCAL_PATH,
        stage: 'noise', // Explicitly set stage for prompt building
      },
    });
    const durationMs = Date.now() - stageStart;

    // Only apply if LM produced a meaningful change
    if (correctedText && correctedText !== spanText && correctedText.length > 0) {
      log.info('diff', {
        ...telemetry,
        durationMs,
        replacedLen: spanText.length,
        newLen: correctedText.length,
        chunkCount,
      });
      return {
        diff: {
          start: activeRegion.start,
          end: activeRegion.end,
          text: correctedText,
        },
      };
    }

    log.debug('no-change', { ...telemetry, durationMs });
    return { diff: null };
  } catch (error) {
    log.error('error', {
      ...telemetry,
      error: error instanceof Error ? error.message : error,
    });
    return { diff: null };
  }
}
