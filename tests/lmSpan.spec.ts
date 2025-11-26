import { describe, it, expect } from 'vitest';
import { streamActiveRegion } from '../src/stages/lmSpan';
import type { LMAdapter } from '../src/lm/types';
import { diagBus, type LMJsonlEvent } from '../src/pipeline/diagnosticsBus';

function createStubAdapter(chunks: string[]): LMAdapter {
  return {
    async *stream() {
      for (const chunk of chunks) {
        await Promise.resolve();
        yield chunk;
      }
    },
  } as unknown as LMAdapter;
}

function captureJsonlEvents(run: () => Promise<unknown>): Promise<LMJsonlEvent[]> {
  const events: LMJsonlEvent[] = [];
  const unsubscribe = diagBus.subscribe('lm-jsonl', (ev) => events.push(ev));
  return run()
    .then(() => events)
    .finally(() => unsubscribe());
}

describe('streamActiveRegion diagnostics', () => {
  it('publishes lm-jsonl events with extracted replacements', async () => {
    const adapter = createStubAdapter(['{"replacement":"fixed span"}']);
    const events = await captureJsonlEvents(() =>
      streamActiveRegion({
        text: 'orig span',
        caret: 9,
        activeRegion: { start: 0, end: 9 },
        lmAdapter: adapter,
        settings: { stage: 'noise' },
      }),
    );
    expect(events).toHaveLength(1);
    const [event] = events;
    expect(event.stage).toBe('noise');
    expect(event.success).toBe(true);
    expect(event.extracted).toBe('fixed span');
    expect(event.raw).toContain('"replacement"');
  });

  it('publishes lm-jsonl events when no text is produced', async () => {
    const adapter = createStubAdapter(['']);
    const events = await captureJsonlEvents(() =>
      streamActiveRegion({
        text: 'abc',
        caret: 3,
        activeRegion: { start: 0, end: 3 },
        lmAdapter: adapter,
        settings: { stage: 'context' },
      }),
    );
    expect(events).toHaveLength(1);
    const [event] = events;
    expect(event.stage).toBe('context');
    expect(event.success).toBe(false);
    expect(event.extracted).toBeNull();
  });
});
