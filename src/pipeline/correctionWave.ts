/*╔══════════════════════════════════════════════════════════╗
  ║  ░  CORRECTIONWAVE  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
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
  • WHAT ▸ Pause-triggered sweep; stops at caret
  • WHY  ▸ REQ-PAUSE-SWEEP
  • HOW  ▸ See linked contracts and guides in docs
*/

import type { LMAdapter } from '../lm/types';
import { defaultActiveRegionPolicy } from '../region/policy';
import { noiseTransform } from '../stages/noise';
import { contextTransform } from '../stages/context';
import { toneTransform, type ToneTarget } from '../stages/tone';
import { createLogger } from './logger';
export type { ToneTarget } from '../stages/tone';
import { isCaretSafe } from '../safety/grapheme';

export interface CorrectionWaveInput {
  text: string;
  caret: number;
  lmAdapter?: LMAdapter;
  toneTarget?: ToneTarget;
  waveId?: string;
  burstState?: {
    lastTypingTime: number;
    burstStartTime: number;
    burstKeyCount: number;
  };
}

export interface CorrectionWaveResult {
  diffs: Array<{
    start: number;
    end: number;
    text: string;
    stage: 'noise' | 'context' | 'tone';
  }>;
  activeRegion: { start: number; end: number };
}

const log = createLogger('wave');

export async function runCorrectionWave(
  input: CorrectionWaveInput,
): Promise<CorrectionWaveResult> {
  const {
    text,
    caret,
    lmAdapter,
    toneTarget = 'None',
    burstState,
    waveId: providedWaveId,
  } = input;
  const waveId =
    providedWaveId ?? `wave-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;

  if (!lmAdapter) {
    throw new Error(
      '[CorrectionWave] LM adapter missing — waves cannot run without an LM.',
    );
  }

  // Compute Active Region with burst growth
  const state = {
    text,
    caret,
    frontier: Math.max(0, caret - 1000), // Search window
    ...burstState,
  };

  const startedAt = Date.now();
  const activeRegion = defaultActiveRegionPolicy.computeRenderRange(state);
  const startPayload = {
    waveId,
    caret,
    textLen: text.length,
    activeRegion,
  };
  log.info('start', startPayload);

  if (!isCaretSafe(activeRegion.start, activeRegion.end, caret)) {
    return { diffs: [], activeRegion: { start: caret, end: caret } };
  }

  const diffs: Array<{
    start: number;
    end: number;
    text: string;
    stage: 'noise' | 'context' | 'tone';
  }> = [];
  let currentText = text;

  try {
    // Stage 1: Noise Transformer (LM-only typo fixes)
    const noiseResult = await noiseTransform({
      text: currentText,
      caret,
      activeRegion,
      lmAdapter,
      waveId,
    });

    if (noiseResult.diff) {
      diffs.push({ ...noiseResult.diff, stage: 'noise' });
      // Apply diff to working text for next stage
      currentText =
        currentText.slice(0, noiseResult.diff.start) +
        noiseResult.diff.text +
        currentText.slice(noiseResult.diff.end);
    }

    // Stage 2: Context Transformer (LM-only grammar/coherence)
    const contextResult = await contextTransform({
      text: currentText,
      caret,
      activeRegion,
      lmAdapter,
      waveId,
    });

    for (const proposal of contextResult.proposals) {
      if (isCaretSafe(proposal.start, proposal.end, caret)) {
        const contextDiff = {
          start: proposal.start,
          end: proposal.end,
          text: proposal.text,
          stage: 'context' as const,
        };
        diffs.push({
          start: proposal.start,
          end: proposal.end,
          text: proposal.text,
          stage: 'context',
        });
        // Apply diff to working text for next stage
        currentText =
          currentText.slice(0, proposal.start) +
          proposal.text +
          currentText.slice(proposal.end);
      }
    }

    // Stage 3: Tone Transformer (LM-only style adjustment)
    if (toneTarget !== 'None') {
      const toneResult = await toneTransform({
        text: currentText,
        caret,
        activeRegion,
        toneTarget,
        lmAdapter,
        waveId,
      });

      for (const proposal of toneResult.proposals) {
        if (isCaretSafe(proposal.start, proposal.end, caret)) {
          const toneDiff = {
            start: proposal.start,
            end: proposal.end,
            text: proposal.text,
            stage: 'tone' as const,
          };
          diffs.push({
            start: proposal.start,
            end: proposal.end,
            text: proposal.text,
            stage: 'tone',
          });
        }
      }
    }

    const donePayload = {
      waveId,
      diffCount: diffs.length,
      durationMs: Date.now() - startedAt,
      activeRegion,
    };
    log.info('complete', donePayload);
    return { diffs, activeRegion };
  } catch (error) {
    log.error('error', {
      waveId,
      error: error instanceof Error ? error.message : error,
    });
    return { diffs: [], activeRegion };
  }
}
