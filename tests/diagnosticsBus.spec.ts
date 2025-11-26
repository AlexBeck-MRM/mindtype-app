import { describe, it, expect, vi } from 'vitest';
import { diagBus, type DiagEvent } from '../src/pipeline/diagnosticsBus';

describe('diagnosticsBus', () => {
  it('publishes events to subscribers and retains them in the ring buffer', () => {
    const received: DiagEvent[] = [];
    const unsubscribe = diagBus.subscribe('noise', (event) => received.push(event));
    const marker = Date.now();
    diagBus.publish({
      channel: 'noise',
      time: marker,
      rule: 'test-case',
      start: null,
      end: null,
      text: 'payload',
      window: { start: 0, end: 0 },
      decision: 'applied',
    });
    unsubscribe();

    expect(received).toHaveLength(1);
    const fromRing = diagBus.getValues('noise');
    expect(
      fromRing.some((event) => event.time === marker && event.rule === 'test-case'),
    ).toBe(true);
  });

  it('stops notifying unsubscribed listeners', () => {
    const callback = vi.fn();
    const unsubscribe = diagBus.subscribe('lm-wire', callback);
    unsubscribe();
    diagBus.publish({
      channel: 'lm-wire',
      time: Date.now(),
      phase: 'stream_init',
      requestId: 'case-123',
      detail: {},
    });
    expect(callback).not.toHaveBeenCalled();
  });
});
