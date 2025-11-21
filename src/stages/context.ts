/*╔══════════════════════════════════════════════════════════╗
  ║  ░  CONTEXT  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
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
  • WHAT ▸ Never modify at or after the caret; Confidence gating for context/tone stages; Active Area editable; Context Area read-only; Speed enhancement mode for 180+ WPM typing; Support for all seven revolutionary usage scenarios
  • WHY  ▸ REQ-CARET-SAFETY, REQ-CONFIDENCE-GATING, REQ-ZONES, REQ-VELOCITY-MODE, REQ-SEVEN-SCENARIOS
  • HOW  ▸ See linked contracts and guides in docs
*/

import type { LMAdapter } from '../lm/types';
import { getDefaultLMConfig } from '../lm/config';
import { isCaretSafe } from '../safety/grapheme';
import { createLogger } from '../pipeline/logger';
import { diagBus } from '../pipeline/diagnosticsBus';
import { streamActiveRegion } from './lmSpan';
import {
  computeConfidence,
  applyThresholds,
  computeInputFidelity,
  computeDynamicThresholds,
} from '../pipeline/confidenceGate';

const LM_LOCAL_PATH =
  getDefaultLMConfig().localModelPath ??
  '/mindtype/models/onnx-community/Qwen2.5-0.5B-Instruct';

const log = createLogger('stage.context');

export interface ContextInput {
  text: string;
  caret: number;
  activeRegion: { start: number; end: number };
  lmAdapter?: LMAdapter;
  waveId?: string;
}

export interface ContextResult {
  proposals: Array<{ start: number; end: number; text: string; confidence: number }>;
}

export async function contextTransform(input: ContextInput): Promise<ContextResult> {
  const { text, caret, activeRegion, lmAdapter, waveId } = input;

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
  };
  log.debug('start', telemetry);
  const stageStart = Date.now();

  diagBus.publish({
    channel: 'context-window',
    time: stageStart,
    bandStart: activeRegion.start,
    bandEnd: activeRegion.end,
    spanPreview: spanText.slice(0, 160),
  });

  try {
    // Compute input fidelity for confidence gating
    const inputFidelity = computeInputFidelity(spanText);
    const thresholds = computeDynamicThresholds({
      caret,
      start: activeRegion.start,
      end: activeRegion.end,
      editType: 'context',
    });

    if (inputFidelity < thresholds.τ_input) {
      log.debug('gate.input-fidelity', {
        ...telemetry,
        inputFidelity,
        threshold: thresholds.τ_input,
      });
      return { proposals: [] }; // Input quality too low
    }

    const { text: correctedText, chunkCount } = await streamActiveRegion({
      text,
      caret,
      activeRegion,
      lmAdapter,
      settings: {
        stage: 'context',
        maxNewTokens: Math.min(64, Math.floor(spanText.length * 1.5)), // More generous for context
        deviceTier: 'wasm', // Context stage can use more resources
        localOnly: true,
        localModelPath: LM_LOCAL_PATH,
      },
    });

    // Only propose if LM produced a meaningful change
    if (correctedText && correctedText !== spanText && correctedText.length > 0) {
      // Compute confidence score for the proposal
      const confidence = computeConfidence({
        inputFidelity,
        transformationQuality: correctedText.length > spanText.length * 2 ? 0.3 : 0.8,
        contextCoherence: 0.9, // Assume high coherence from context-aware LM
        temporalDecay: 1.0,
      });

      const decision = applyThresholds(confidence, thresholds);

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
              text: correctedText,
              confidence: confidence.combined,
            },
          ],
        };
      }

      log.debug('proposal.rejected', {
        ...telemetry,
        durationMs: Date.now() - stageStart,
        confidence: confidence.combined,
        thresholds,
      });
    }

    return { proposals: [] };
  } catch (error) {
    // v0.6: LM errors disable corrections rather than fallback
    log.error('error', {
      waveId,
      error: error instanceof Error ? error.message : error,
    });
    return { proposals: [] };
  }
}

// Legacy helper removed in v0.9 — buildContextWindow was rule-based and is now
// redundant with LM-only context. Tests import contextTransform directly.
