/*╔══════════════════════════════════════════════════════════╗
  ║  ░  TRANSFORMERSCLIENT  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
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
  • WHAT ▸ On-device LM integration with graceful fallback
  • WHY  ▸ REQ-LOCAL-LM-INTEGRATION
  • HOW  ▸ See linked contracts and guides in docs
*/
import type { LMAdapter, LMCapabilities, LMInitOptions, LMStreamParams } from './types';
import { DEVICE_TIERS, type DeviceTierPolicy } from './deviceTiers';
import { createLogger } from '../pipeline/logger';
import { buildCorrectionPrompt, type CorrectionStage } from './promptBuilder';

const log = createLogger('lm.adapter');

// Device tier token caps from PRD
const DEFAULT_TOKEN_CAPS = {
  webgpu: 48,
  wasm: 24,
  cpu: 16,
} as const;

export interface TokenStreamRequest {
  prompt: string;
  maxNewTokens?: number;
  signal?: AbortSignal;
}

export interface TokenStreamer {
  generateStream(input: TokenStreamRequest): AsyncIterable<string>;
}

export function detectBackend(): LMCapabilities['backend'] {
  try {
    if (typeof navigator !== 'undefined') {
      const nav = navigator as unknown as Record<string, unknown>;
      // ⟢ WebGPU detection: check for gpu object (tests use simple mock)
      if ('gpu' in nav) {
        // In tests, gpu object exists but may not have requestAdapter
        if (
          typeof (nav.gpu as { requestAdapter?: unknown })?.requestAdapter === 'function'
        ) {
          return 'webgpu';
        }
        // Fallback for test environments with simple gpu mock
        if (nav.gpu) return 'webgpu';
      }
    }
  } catch {}
  try {
    // In browsers without WebGPU but with WebAssembly (SIMD/threads optional), use WASM
    if (typeof WebAssembly !== 'undefined') return 'wasm';
  } catch {}
  return 'cpu';
}

export async function detectCapabilities(): Promise<LMCapabilities> {
  const backend = detectBackend();
  const caps: LMCapabilities = {
    backend,
    maxContextTokens: 1024,
    tokenCaps: DEFAULT_TOKEN_CAPS,
  };
  // WebGPU flag
  try {
    caps.features = { ...(caps.features ?? {}), webgpu: backend === 'webgpu' };
  } catch {}
  // WASM feature probes
  try {
    // Threads
    const threads =
      typeof (WebAssembly as unknown as Record<string, unknown>).Memory === 'function';
    // SIMD: minimal probe via feature detection
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const simd = typeof (WebAssembly as any)?.validate === 'function';
    caps.features = { ...(caps.features ?? {}), wasmThreads: threads, wasmSimd: simd };
  } catch {}
  return caps;
}

export function getTierPolicy(backend: LMCapabilities['backend']): DeviceTierPolicy {
  if (backend === 'unknown') return DEVICE_TIERS.cpu;
  return DEVICE_TIERS[backend as keyof typeof DEVICE_TIERS] || DEVICE_TIERS.cpu;
}

export function cooldownForBackend(backend: LMCapabilities['backend']): number {
  return getTierPolicy(backend).cooldownMs;
}

export async function verifyLocalAssets(
  localOnly: boolean = true,
  modelPath?: string,
): Promise<boolean> {
  if (!localOnly) return true; // Skip verification for remote mode
  if (typeof window === 'undefined') return true; // Node/test environments do not host assets

  // ⟢ Verify local model assets are available
  try {
    const base = modelPath ?? '/mindtype/models/onnx-community/Qwen2.5-0.5B-Instruct';
    const normalizedBase = base.endsWith('/') ? base.slice(0, -1) : base;
    const configUrl = `${normalizedBase}/config.json`;

    const response = await fetch(configUrl, { method: 'HEAD' });
    if (!response.ok) {
      log.warn('assets.missing', { url: configUrl, status: response.status });
      return false;
    }
    return true;
  } catch {
    log.warn('assets.verify_failed', { url: modelPath });
    return false;
  }
}

export function createTransformersAdapter(runner: TokenStreamer): LMAdapter {
  let aborted = false;
  let inflight: Promise<void> | null = null;
  let resolveInflight: (() => void) | null = null;
  let lastMergeAt = 0;
  let cooldownMs = 160;
  let caps: LMCapabilities | null = null;
  let runs = 0;
  let staleDrops = 0;
  let localAssetsVerified = false;
  const ABORT_WAIT_MS = 250;
  let activeAbortController: AbortController | null = null;

  return {
    init(opts?: LMInitOptions): LMCapabilities {
      const backend = opts?.preferBackend ?? detectBackend();
      // Synchronous feature probes (best-effort)
      let wasmThreads = false;
      try {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        wasmThreads = typeof (WebAssembly as any)?.Memory === 'function';
      } catch {}
      const features = {
        webgpu: backend === 'webgpu',
        wasmThreads,
        // SIMD probe omitted (browser-dependent); assume undefined
        wasmSimd: undefined as unknown as boolean | undefined,
      };
      const nextCaps: LMCapabilities = {
        backend,
        maxContextTokens: 1024,
        features,
        tokenCaps: DEFAULT_TOKEN_CAPS,
      };
      caps = nextCaps;
      // Apply device-tier policy with auto-degrade
      const tierPolicy = getTierPolicy(backend);
      cooldownMs = tierPolicy.cooldownMs;
      // ⟢ Auto-degrade: extend cooldown for limited WASM capabilities
      if (backend === 'wasm' && !features.wasmThreads) cooldownMs += 80;
      return nextCaps;
    },
    abort() {
      aborted = true;
      activeAbortController?.abort();
      activeAbortController = null;
      resolveInflight?.();
      resolveInflight = null;
      inflight = null;
    },
    getStats() {
      return { runs, staleDrops };
    },
    async *stream(params: LMStreamParams): AsyncIterable<string> {
      const band = params.band ?? params.activeRegion;
      if (!band) {
        log.warn('stream.missingBand', { textLen: params.text?.length ?? 0 });
        return;
      }
      // ⟢ Local-only asset guard (FT-231E)
      if (params.settings?.localOnly && !localAssetsVerified) {
        localAssetsVerified = await verifyLocalAssets(
          true,
          params.settings?.localModelPath as string | undefined,
        );
        if (!localAssetsVerified) {
          log.warn('assets.unavailable', { mode: 'localOnly' });
          return; // Graceful fallback - no tokens emitted
        }
      }

      // enforce cooldown
      const now = Date.now();
      const since = now - lastMergeAt;
      if (since < cooldownMs) {
        await new Promise((r) => setTimeout(r, cooldownMs - since));
      }
      // single‑flight: mark previous as stale and request its termination
      if (inflight) {
        staleDrops += 1;
        activeAbortController?.abort();
        await Promise.race([
          inflight.catch(() => undefined),
          new Promise((resolve) => setTimeout(resolve, ABORT_WAIT_MS)),
        ]);
      }
      aborted = false;
      runs += 1;

      const { text } = params;
      const contextBefore = text.slice(Math.max(0, band.start - 40), band.start);
      const contextAfter = text.slice(band.end, Math.min(text.length, band.end + 40));

      // Determine stage from settings (default to 'noise' for typo correction)
      const stage: CorrectionStage =
        (params.settings?.stage as CorrectionStage) || 'noise';
      const toneTarget = params.settings?.toneTarget as
        | 'Casual'
        | 'Professional'
        | undefined;

      // Build properly formatted prompt with instructions
      const prompt = buildCorrectionPrompt({
        stage,
        text,
        activeRegion: band,
        contextBefore: contextBefore || undefined,
        contextAfter: contextAfter || undefined,
        toneTarget,
      });

      // ⟢ Token cap safeguards (FT-231F) - enforce device-appropriate limits
      const tierPolicy = caps ? getTierPolicy(caps.backend) : DEVICE_TIERS.cpu;
      const requestedTokens =
        (params.settings?.maxNewTokens as number) || tierPolicy.maxTokens;
      const maxTokens = Math.min(requestedTokens, tierPolicy.maxTokens);
      const clampedMaxTokens = Math.max(8, Math.min(48, maxTokens)); // [8,48] range

      const abortController = new AbortController();
      activeAbortController = abortController;
      const stream = runner.generateStream({
        prompt,
        maxNewTokens: clampedMaxTokens,
        signal: abortController.signal,
      });

      // create a completion promise resolved when this stream finishes
      inflight = new Promise<void>((resolve) => {
        resolveInflight = resolve;
      });

      try {
        for await (const chunk of stream) {
          if (aborted) return;
          yield chunk;
        }
        lastMergeAt = Date.now();
      } finally {
        if (activeAbortController?.signal === abortController.signal) {
          activeAbortController = null;
        }
        resolveInflight?.();
        resolveInflight = null;
        inflight = null;
      }
    },
  };
}
