/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  M I N D T Y P E   P I P E L I N E   H O O K  ░░░░░░░░░░  ║
  ║                                                              ║
  ║   Centralized hook for bootstrapping pipeline, LM adapter,  ║
  ║   diagnostics subscriptions, and DOM event bridging.        ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ React hook managing pipeline lifecycle + diagnostics
  • WHY  ▸ Single source of truth for demo state
  • HOW  ▸ Boots pipeline, subscribes diagBus, bridges DOM events
*/

import { useCallback, useEffect, useRef, useState } from 'react';
import { boot, createDefaultLMAdapter } from '../../../../src/pipeline/index';
import type { LMAdapter } from '../../../../src/lm/types';
import { diagBus, type DiagEvent } from '../../../../src/pipeline/diagnosticsBus';
import { setLoggerConfig, type LogRecord } from '../../../../src/pipeline/logger';
import { createLiveRegion } from '../../../../src/ui/liveRegion';
import { verifyLocalAssets } from '../../../../src/lm/transformersClient';
import {
  buildTestPrompt,
  extractReplacementText,
} from '../../../../src/lm/promptBuilder';

const MODEL_PATH = '/mindtype/models/onnx-community/Qwen2.5-0.5B-Instruct';
const WASM_PATH = '/mindtype/wasm/';

export interface PipelineState {
  lmStatus: 'loading' | 'ready' | 'error';
  assetStatus: 'checking' | 'ready' | 'missing';
  errorMessage: string | null;
  canUseRemote: boolean;
}

export interface ActiveRegionState {
  start: number;
  end: number;
  lastUpdated: number;
}

export interface SwapEvent {
  start: number;
  end: number;
  text: string;
  originalText?: string;
  timestamp: number;
}

export interface DiagnosticsState {
  logs: Array<{ ts: number; level: string; message: string; data?: unknown }>;
  noiseEvents: Array<DiagEvent & { channel: 'noise' }>;
  lmWireEvents: Array<DiagEvent & { channel: 'lm-wire' }>;
  contextWindowEvents: Array<DiagEvent & { channel: 'context-window' }>;
  lmJsonlEvents: Array<DiagEvent & { channel: 'lm-jsonl' }>;
}

export type LmTestStatus = 'idle' | 'running' | 'success' | 'error';

export interface LmTestState {
  status: LmTestStatus;
  lastRun?: number;
  durationMs?: number;
  chunkCount?: number;
  prompt: string;
  response: string;
  trigger: 'warmup' | 'manual';
  errorMessage?: string;
}

export interface UseMindtypePipelineReturn {
  state: PipelineState;
  activeRegion: ActiveRegionState | null;
  swaps: SwapEvent[];
  diagnostics: DiagnosticsState;
  lmTest: LmTestState;
  ingest: (text: string, caret: number) => void;
  initWithRemote: () => Promise<void>;
  retryAssets: () => void;
  runLMTest: (trigger?: 'warmup' | 'manual') => Promise<void>;
}

// Improved test prompt with clear instructions
const LM_TEST_INPUT =
  'heya ha ve you hgeard there was a n icre cream trk outside that s kinda cool right';
const LM_TEST_PROMPT = buildTestPrompt(LM_TEST_INPUT);

export function useMindtypePipeline(): UseMindtypePipelineReturn {
  const pipelineRef = useRef<ReturnType<typeof boot> | null>(null);
  const lmAdapterRef = useRef<LMAdapter | null>(null);
  const liveRegionRef = useRef<ReturnType<typeof createLiveRegion> | null>(null);
  const [assetProbe, setAssetProbe] = useState(0);
  const warmupTriggeredRef = useRef(false);
  const adapterInitRef = useRef(false);

  const [state, setState] = useState<PipelineState>({
    lmStatus: 'loading',
    assetStatus: 'checking',
    errorMessage: null,
    canUseRemote: false,
  });

  const [activeRegion, setActiveRegion] = useState<ActiveRegionState | null>(null);
  const [swaps, setSwaps] = useState<SwapEvent[]>([]);
  const [diagnostics, setDiagnostics] = useState<DiagnosticsState>({
    logs: [],
    noiseEvents: [],
    lmWireEvents: [],
    contextWindowEvents: [],
    lmJsonlEvents: [],
  });
  const [lmTest, setLmTest] = useState<LmTestState>({
    status: 'idle',
    prompt: LM_TEST_PROMPT,
    response: '',
    trigger: 'manual',
  });

  const loggerSink = useCallback((record: LogRecord) => {
    setDiagnostics((prev) => ({
      ...prev,
      logs: [
        ...prev.logs.slice(-199),
        {
          ts: record.timeMs,
          level: record.level,
          message: record.message,
          data: record.data,
        },
      ],
    }));
  }, []);

  // Bootstrap pipeline
  useEffect(() => {
    const lr = createLiveRegion();
    liveRegionRef.current = lr;
    const pipeline = boot();
    pipelineRef.current = pipeline;

    setLoggerConfig({ enabled: true, level: 'debug', sink: loggerSink });

    const unsubscribeNoise = diagBus.subscribe('noise', (event) => {
      setDiagnostics((prev) => ({
        ...prev,
        noiseEvents: [...prev.noiseEvents.slice(-49), event],
      }));
    });

    const unsubscribeLM = diagBus.subscribe('lm-wire', (event) => {
      setDiagnostics((prev) => ({
        ...prev,
        lmWireEvents: [...prev.lmWireEvents.slice(-99), event],
      }));
    });

    const unsubscribeContext = diagBus.subscribe('context-window', (event) => {
      setDiagnostics((prev) => ({
        ...prev,
        contextWindowEvents: [...prev.contextWindowEvents.slice(-49), event],
      }));
    });

    const unsubscribeJsonl = diagBus.subscribe('lm-jsonl', (event) => {
      setDiagnostics((prev) => ({
        ...prev,
        lmJsonlEvents: [...prev.lmJsonlEvents.slice(-49), event],
      }));
    });

    // Listen for active region updates
    const onActiveRegion = (event: Event) => {
      const detail = (event as CustomEvent<{ start: number; end: number }>).detail;
      if (detail) {
        setActiveRegion({
          start: detail.start,
          end: detail.end,
          lastUpdated: Date.now(),
        });
      }
    };

    // Listen for mechanical swap events (corrections applied)
    const onMechanicalSwap = (event: Event) => {
      const detail = (
        event as CustomEvent<{
          start: number;
          end: number;
          text: string;
          originalText?: string;
        }>
      ).detail;
      if (detail) {
        setSwaps((prev) => [
          ...prev.slice(-99),
          {
            start: detail.start,
            end: detail.end,
            text: detail.text,
            originalText: detail.originalText,
            timestamp: Date.now(),
          },
        ]);
      }
    };

    // Listen for swap announcements (screen reader)
    const onSwapAnnouncement = (event: Event) => {
      const detail = (event as CustomEvent<{ message: string; count: number }>).detail;
      if (detail && liveRegionRef.current) {
        liveRegionRef.current.announce(detail.message);
      }
    };

    window.addEventListener('mindtype:activeRegion', onActiveRegion);
    window.addEventListener('mindtype:mechanicalSwap', onMechanicalSwap);
    window.addEventListener('mindtype:swapAnnouncement', onSwapAnnouncement);

    return () => {
      try {
        pipeline.stop();
      } catch {}
      unsubscribeNoise();
      unsubscribeLM();
      unsubscribeContext();
      unsubscribeJsonl();
      lr.destroy();
      window.removeEventListener('mindtype:activeRegion', onActiveRegion);
      window.removeEventListener('mindtype:mechanicalSwap', onMechanicalSwap);
      window.removeEventListener('mindtype:swapAnnouncement', onSwapAnnouncement);
    };
  }, [loggerSink]);

  // Initialize LM adapter
  const initAdapter = useCallback(async (useLocal: boolean) => {
    const pipeline = pipelineRef.current;
    if (!pipeline || adapterInitRef.current) return;
    adapterInitRef.current = true;

    setState((prev) => ({
      ...prev,
      lmStatus: 'loading',
      assetStatus: 'checking',
      errorMessage: null,
    }));

    let assetsVerified = false;

    try {
      if (useLocal) {
        const assetsAvailable = await verifyLocalAssets(true, MODEL_PATH);
        if (!assetsAvailable) {
          setState((prev) => ({
            ...prev,
            assetStatus: 'missing',
            lmStatus: 'error',
            errorMessage:
              'Local LM assets missing. Use remote tier or run `pnpm setup:local`.',
            canUseRemote: true,
          }));
          pipeline.stop();
          return;
        }
        assetsVerified = true;
        setState((prev) => ({ ...prev, assetStatus: 'ready' }));
      } else {
        assetsVerified = true;
        setState((prev) => ({ ...prev, assetStatus: 'ready', canUseRemote: true }));
      }

      const adapter = createDefaultLMAdapter({
        localOnly: useLocal,
        localModelPath: useLocal ? MODEL_PATH : undefined,
        wasmPaths: WASM_PATH,
      });

      lmAdapterRef.current = adapter;
      await adapter.init?.();
      pipeline.setLMAdapter(adapter);

      if (!pipeline.isRunning()) {
        pipeline.start();
      }

      setState((prev) => ({ ...prev, lmStatus: 'ready', errorMessage: null }));
    } catch (error) {
      // Preserve assetStatus as 'ready' if assets were verified; only set to 'missing'
      // if error occurred during asset verification (before assetsVerified was set to true)
      setState((prev) => ({
        ...prev,
        lmStatus: 'error',
        assetStatus: assetsVerified ? 'ready' : 'missing',
        errorMessage: error instanceof Error ? error.message : 'LM initialization failed',
        canUseRemote: !useLocal,
      }));
      console.error('[useMindtypePipeline] LM init failed', error);
    }
  }, []);

  useEffect(() => {
    initAdapter(true);
  }, [assetProbe, initAdapter]);

  const ingest = useCallback((text: string, caret: number) => {
    pipelineRef.current?.ingest(text, caret);
  }, []);

  const initWithRemote = useCallback(async () => {
    adapterInitRef.current = false;
    await initAdapter(false);
  }, [initAdapter]);

  const retryAssets = useCallback(() => {
    setAssetProbe((n) => n + 1);
  }, []);

  const runLMTest = useCallback(async (trigger: 'warmup' | 'manual' = 'manual') => {
    const adapter = lmAdapterRef.current;
    if (!adapter) {
      setLmTest((prev) => ({
        ...prev,
        status: 'error',
        errorMessage: 'LM adapter not ready',
        trigger,
        lastRun: Date.now(),
      }));
      return;
    }
    // Use the test input text directly (prompt builder will format it)
    const testInput = LM_TEST_INPUT;
    const prompt = LM_TEST_PROMPT;
    setLmTest({
      status: 'running',
      prompt,
      response: '',
      trigger,
    });
    const start = performance.now();
    try {
      const chunks: string[] = [];
      // Stream with proper prompt formatting
      for await (const chunk of adapter.stream({
        text: testInput,
        caret: testInput.length,
        activeRegion: { start: 0, end: testInput.length },
        settings: {
          maxNewTokens: 64,
          deviceTier: 'wasm',
          stage: 'noise', // Use noise stage for test
        },
      })) {
        if (chunk) chunks.push(chunk);
      }
      const rawResponse = chunks.join('').trim();
      const parsed = extractReplacementText(rawResponse);
      const response = (parsed ?? rawResponse).trim();
      setLmTest({
        status: 'success',
        prompt,
        response,
        trigger,
        durationMs: performance.now() - start,
        chunkCount: chunks.length,
        lastRun: Date.now(),
      });
    } catch (err) {
      setLmTest({
        status: 'error',
        prompt,
        response: '',
        trigger,
        errorMessage: err instanceof Error ? err.message : 'LM test failed',
        lastRun: Date.now(),
        durationMs: 0,
        chunkCount: 0,
      });
    }
  }, []);

  useEffect(() => {
    if (state.lmStatus === 'ready' && !warmupTriggeredRef.current) {
      warmupTriggeredRef.current = true;
      runLMTest('warmup').catch(() => {});
    }
  }, [state.lmStatus, runLMTest]);

  return {
    state,
    activeRegion,
    swaps,
    diagnostics,
    lmTest,
    ingest,
    initWithRemote,
    retryAssets,
    runLMTest,
  };
}
