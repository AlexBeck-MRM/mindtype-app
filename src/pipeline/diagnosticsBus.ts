/*╔══════════════════════════════════════════════════════╗
  ║  ░  D I A G N O S T I C S   B U S  ░░░░░░░░░░░░░░░░  ║
  ║                                                      ║
  ║   Typed, bounded in-memory bus for development      ║
  ║   diagnostics across engines (noise/context/LM).    ║
  ║                                                      ║
  ╚══════════════════════════════════════════════════════╝
  • WHAT ▸ Publish/subscribe diagnostics with ring buffers
  • WHY  ▸ Consistent, low-overhead debugging in dev builds
  • HOW  ▸ Channels with bounded arrays; no persistence
*/

export type NoiseDiagEvent = {
  channel: 'noise';
  time: number;
  rule: string;
  start: number | null;
  end: number | null;
  text: string | null;
  window: { start: number; end: number };
  decision: 'applied' | 'skipped' | 'none';
};

export type LMWireEvent = {
  channel: 'lm-wire';
  time: number;
  phase:
    | 'stream_init'
    | 'msg_send'
    | 'msg_recv'
    | 'chunk_recv'
    | 'chunk_yield'
    | 'stream_done'
    | 'stream_error';
  requestId: string;
  detail?: Record<string, unknown>;
};

export type LMJsonlEvent = {
  channel: 'lm-jsonl';
  time: number;
  raw: string;
};

export type ContextWindowEvent = {
  channel: 'context-window';
  time: number;
  bandStart: number;
  bandEnd: number;
  spanPreview: string;
};

export type DiagEvent = NoiseDiagEvent | LMWireEvent | LMJsonlEvent | ContextWindowEvent;

type Channel = DiagEvent['channel'];

const DEFAULT_BOUNDS: Record<Channel, number> = {
  noise: 50,
  'lm-wire': 100,
  'lm-jsonl': 50,
  'context-window': 50,
};

class Ring<T> {
  private buf: T[] = [];
  constructor(private cap: number) {}
  push(v: T) {
    this.buf.push(v);
    if (this.buf.length > this.cap) this.buf.splice(0, this.buf.length - this.cap);
  }
  values(): T[] {
    return this.buf.slice();
  }
}

type ChannelEvent<K extends Channel> = Extract<DiagEvent, { channel: K }>;

type ChannelRings = { [K in Channel]: Ring<ChannelEvent<K>> };
type ChannelSubs = { [K in Channel]: Set<(ev: ChannelEvent<K>) => void> };

class DiagnosticsBus {
  private rings: ChannelRings;
  private subs: ChannelSubs;

  constructor(bounds?: Partial<Record<Channel, number>>) {
    const createRing = <K extends Channel>(
      channel: K,
      override?: number,
    ): Ring<ChannelEvent<K>> => {
      return new Ring<ChannelEvent<K>>(override ?? DEFAULT_BOUNDS[channel]);
    };
    const createSub = <K extends Channel>(): Set<(ev: ChannelEvent<K>) => void> => {
      return new Set<(ev: ChannelEvent<K>) => void>();
    };

    this.rings = {
      noise: createRing('noise', bounds?.noise),
      'lm-wire': createRing('lm-wire', bounds?.['lm-wire']),
      'lm-jsonl': createRing('lm-jsonl', bounds?.['lm-jsonl']),
      'context-window': createRing('context-window', bounds?.['context-window']),
    };
    this.subs = {
      noise: createSub<'noise'>(),
      'lm-wire': createSub<'lm-wire'>(),
      'lm-jsonl': createSub<'lm-jsonl'>(),
      'context-window': createSub<'context-window'>(),
    };
  }

  publish<E extends DiagEvent>(event: E): void {
    const ring = this.rings[event.channel] as Ring<E>;
    ring.push(event);
    const subs = this.subs[event.channel] as Set<(ev: E) => void>;
    subs.forEach((fn) => {
      try {
        fn(event);
      } catch {}
    });
  }

  subscribe<K extends Channel>(
    channel: K,
    fn: (ev: ChannelEvent<K>) => void,
  ): () => void {
    const set = this.subs[channel] as Set<typeof fn>;
    set.add(fn);
    return () => set.delete(fn);
  }

  getValues<K extends Channel>(channel: K): Array<Extract<DiagEvent, { channel: K }>> {
    const ring = this.rings[channel] as Ring<Extract<DiagEvent, { channel: K }>>;
    return ring.values();
  }
}

// Singleton for demo/dev builds only
export const diagBus = new DiagnosticsBus();
