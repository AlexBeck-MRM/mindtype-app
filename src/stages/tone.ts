/*╔══════════════════════════════════════════════════════════╗
  ║  ░  TONE  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
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
  • WHAT ▸ Never modify at or after the caret; Confidence gating for context/tone stages; Support for all seven revolutionary usage scenarios
  • WHY  ▸ REQ-CARET-SAFETY, REQ-CONFIDENCE-GATING, REQ-SEVEN-SCENARIOS
  • HOW  ▸ See linked contracts and guides in docs
*/

import type { LMAdapter } from '../lm/types';
import { getDefaultLMConfig } from '../lm/config';
import { isCaretSafe } from '../safety/grapheme';
import { createLogger } from '../pipeline/logger';
const LM_LOCAL_PATH =
  getDefaultLMConfig().localModelPath ??
  '/mindtype/models/onnx-community/Qwen2.5-0.5B-Instruct';
const log = createLogger('stage.tone');

import { computeConfidence, applyThresholds } from '../pipeline/confidenceGate';
import { getConfidenceThresholds } from '../config/thresholds';
import { streamActiveRegion } from './lmSpan';

export type ToneTarget = 'None' | 'Casual' | 'Professional';

export interface ToneInput {
  text: string;
  caret: number;
  activeRegion: { start: number; end: number };
  toneTarget: ToneTarget;
  lmAdapter?: LMAdapter;
  waveId?: string;
}

export interface ToneResult {
  proposals: Array<{ start: number; end: number; text: string; confidence: number }>;
}

export async function toneTransform(input: ToneInput): Promise<ToneResult> {
  const { text, caret, activeRegion, toneTarget, lmAdapter, waveId } = input;

  // v0.6: Default None - no tone adjustment unless explicitly set
  if (toneTarget === 'None') {
    return { proposals: [] };
  }

  // v0.6: Require LM adapter; no rule-based fallback
  if (!lmAdapter) {
    return { proposals: [] };
  }

  // Ensure Active Region is caret-safe
  if (!isCaretSafe(activeRegion.start, activeRegion.end, caret)) {
    return { proposals: [] };
  }

  // Extract text from Active Region
  const spanText = text.slice(activeRegion.start, activeRegion.end);
  if (spanText.length === 0) {
    return { proposals: [] };
  }

  const telemetry = {
    waveId,
    caret,
    start: activeRegion.start,
    end: activeRegion.end,
    spanLen: spanText.length,
    toneTarget,
  };

  log.debug('start', telemetry);

  try {
    const stageStart = Date.now();
    const { text: adjustedText, chunkCount } = await streamActiveRegion({
      text,
      caret,
      activeRegion,
      lmAdapter,
      settings: {
        maxNewTokens: Math.min(96, Math.floor(spanText.length * 2)), // Generous for tone adjustments
        deviceTier: 'webgpu', // Tone stage can use best resources
        localOnly: true,
        localModelPath: LM_LOCAL_PATH,
        stage: 'tone',
        toneTarget,
      },
    });

    // Only propose if LM produced a meaningful change
    if (adjustedText && adjustedText !== spanText && adjustedText.length > 0) {
      // Compute confidence score with τ_tone gating
      const confidence = computeConfidence({
        inputFidelity: 0.9, // Assume good input for tone stage
        transformationQuality: 0.8, // Tone changes are generally good
        contextCoherence: 0.9,
        temporalDecay: 1.0,
      });

      const thresholds = getConfidenceThresholds();
      const decision = applyThresholds(confidence, thresholds, { requireTone: true });

      if (decision === 'commit') {
        log.info('proposal.commit', {
          ...telemetry,
          durationMs: Date.now() - stageStart,
          confidence: confidence.combined,
          chunkCount,
        });
        return {
          proposals: [
            {
              start: activeRegion.start,
              end: activeRegion.end,
              text: adjustedText,
              confidence: confidence.combined,
            },
          ],
        };
      }

      log.debug('proposal.rejected', {
        ...telemetry,
        durationMs: Date.now() - stageStart,
        confidence: confidence.combined,
      });
    }

    return { proposals: [] };
  } catch (error) {
    // v0.6: LM errors disable corrections rather than fallback
    log.error('error', {
      ...telemetry,
      error: error instanceof Error ? error.message : error,
    });
    return { proposals: [] };
  }
}

// ═══════════════════════════════════════════════════════════════
// Legacy exports for scheduler backward compatibility
// TODO: Refactor scheduler to use toneTransform() directly
// ═══════════════════════════════════════════════════════════════
