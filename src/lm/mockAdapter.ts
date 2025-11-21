/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  M O C K   L M   A D A P T E R  ░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Deterministic stub for tests and demos.                    ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
*/
import type { LMAdapter, LMCapabilities, LMStreamParams } from './types';
import { normalizeLMStreamParams } from './types';

export function createMockLMAdapter(): LMAdapter {
  let aborted = false;
  return {
    init(): LMCapabilities {
      return {
        backend: 'cpu',
        maxContextTokens: 256,
        tokenCaps: { webgpu: 0, wasm: 0, cpu: 0 },
      };
    },
    abort() {
      aborted = true;
    },
    async *stream(params: LMStreamParams): AsyncIterable<string> {
      aborted = false;
      const normalized = normalizeLMStreamParams(params);
      const { activeRegion, text } = normalized;
      // naive correction: fix "teh"->"the" inside activeRegion only
      const bandText = text
        .slice(activeRegion.start, activeRegion.end)
        .replaceAll(' teh ', ' the ');
      const chunks = bandText.match(/.{1,8}/g) ?? [];
      for (const c of chunks) {
        if (aborted) return;
        // simulate async streaming
        await new Promise((r) => setTimeout(r, 0));
        yield c;
      }
    },
  };
}
