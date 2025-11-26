/*╔══════════════════════════════════════════════════════════╗
  ║  ░  LMWORKER  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
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
  • WHAT ▸ JSONL LM stream protocol (context → tone)
  • WHY  ▸ CONTRACT-LM-STREAM
  • HOW  ▸ See linked contracts and guides in docs
*/
/// <reference lib="webworker" />

import { createQwenTokenStreamer } from '../../../core/lm/transformersRunner';

interface GenerateParams {
  text: string;
  band: { start: number; end: number };
  settings?: {
    prompt?: string;
    maxNewTokens?: number;
  };
}

type Msg =
  | { type: 'generate'; requestId: string; params: GenerateParams }
  | { type: 'abort' };

let streamerPromise: Promise<ReturnType<typeof createQwenTokenStreamer>> | null = null;
async function getStreamer() {
  if (streamerPromise) return streamerPromise;
  streamerPromise = (async () => {
    try {
      // Use only local assets as requested by user
      const localOnly = true;
      const wasmPaths = '/wasm/';
      const localModelPath = '/models/onnx-community/Qwen2.5-0.5B-Instruct';

      console.log('[LMWorker] 🚀 Initializing with local-only assets:', {
        localModelPath,
        wasmPaths,
      });

      console.log('[LMWorker] 📦 Calling createQwenTokenStreamer...');
      const streamer = createQwenTokenStreamer({
        localOnly,
        wasmPaths,
        localModelPath,
      });

      console.log('[LMWorker] ✅ Streamer created successfully');
      return streamer;
    } catch (error: unknown) {
      console.error('[LMWorker] ❌ Failed to create streamer:', error);
      console.error('[LMWorker] Error details:', {
        message: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
        name: error instanceof Error ? error.name : undefined,
      });
      throw error;
    }
  })();
  return streamerPromise;
}
let controller: AbortController | null = null;

self.addEventListener('message', async (e: MessageEvent<Msg>) => {
  try {
    const msg = e.data;
    console.log('[LMWorker] Received message:', { type: msg?.type, hasData: !!msg });

    if (!msg) {
      console.warn('[LMWorker] Received empty message');
      return;
    }

    if (msg.type === 'abort') {
      console.log('[LMWorker] Abort request received');
      try {
        controller?.abort();
      } catch {}
      return;
    }

    if (msg.type === 'generate') {
      const { requestId, params } = msg;
      console.log('[LMWorker] Generate request received:', {
        requestId,
        hasParams: !!params,
        hasBand: !!params?.band,
        bandDetails: params?.band ? `${params.band.start}-${params.band.end}` : 'none',
        prompt: params?.settings?.prompt?.slice(0, 50),
      });

      controller = new AbortController();

      try {
        // Validate input parameters with detailed logging
        if (!params) {
          throw new Error('Missing params object');
        }
        if (!params.band) {
          throw new Error('Missing band parameter in params');
        }
        if (
          typeof params.band.start !== 'number' ||
          typeof params.band.end !== 'number'
        ) {
          throw new Error(
            `Invalid band types: start=${typeof params.band.start}, end=${typeof params.band.end}`,
          );
        }
        if (params.band.start === params.band.end) {
          throw new Error(
            `Empty band: start=${params.band.start}, end=${params.band.end}`,
          );
        }

        console.log('[LMWorker] Parameters validated successfully');
        console.log('[LMWorker] Attempting to get streamer...');
        const streamer = await getStreamer();
        console.log('[LMWorker] Streamer ready, starting generation');

        const prompt =
          params.settings?.prompt ??
          params.text.slice(params.band.start, params.band.end);
        const maxNewTokens = params.settings?.maxNewTokens ?? 16;

        console.log('[LMWorker] Generation params:', {
          prompt: prompt.slice(0, 50),
          maxNewTokens,
          bandSize: params.band.end - params.band.start,
        });

        let chunkCount = 0;
        for await (const chunk of streamer.generateStream({ prompt, maxNewTokens })) {
          chunkCount++;
          console.log('[LMWorker] Chunk', chunkCount, ':', chunk.slice(0, 20));
          (self as unknown as Worker).postMessage({
            type: 'chunk',
            requestId,
            text: chunk,
          });
        }
        console.log('[LMWorker] Generation complete, total chunks:', chunkCount);
        (self as unknown as Worker).postMessage({ type: 'done', requestId });
      } catch (err: unknown) {
        console.error('[LMWorker] Generation failed:', err);
        const errorMessage = err instanceof Error ? err.message : String(err);
        console.error('[LMWorker] Error details:', {
          errorMessage,
          stack: err instanceof Error ? err.stack : undefined,
          name: err instanceof Error ? err.name : undefined,
          cause: err instanceof Error ? err.cause : undefined,
        });
        (self as unknown as Worker).postMessage({
          type: 'error',
          requestId,
          message: errorMessage,
        });
      }
    } else {
      console.warn('[LMWorker] Unknown message type:', msg.type);
    }
  } catch (parseError: unknown) {
    console.error('[LMWorker] Failed to parse message:', parseError);
    console.error('[LMWorker] Raw message data:', e.data);
    console.error('[LMWorker] Message type:', typeof e.data);
    // Try to send error response if we can extract requestId
    try {
      const requestId =
        e.data && typeof e.data === 'object' && 'requestId' in e.data
          ? String(e.data.requestId)
          : 'unknown';
      const errorMsg =
        parseError instanceof Error ? parseError.message : String(parseError);
      (self as unknown as Worker).postMessage({
        type: 'error',
        requestId,
        message: `Message parsing failed: ${errorMsg}`,
      });
    } catch {
      console.error('[LMWorker] Could not send error response');
    }
  }
});

// Add error handler for worker
self.addEventListener('error', (e) => {
  console.error('[LMWorker] Worker error:', e);
});

self.addEventListener('unhandledrejection', (e) => {
  console.error('[LMWorker] Unhandled rejection:', e.reason);
});
