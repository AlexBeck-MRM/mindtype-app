import { diagBus, type DiagEvent } from '../../../src/pipeline/diagnosticsBus';

type RelayEvent = {
  ts: number;
  event: DiagEvent;
};

const RELAY_ENDPOINT = '/diag-stream/push';
const FLUSH_INTERVAL_MS = 120;
const BATCH_SIZE = 10;
const MAX_BUFFER = 200;

const isBrowser = typeof window !== 'undefined';

function flushFactory() {
  const buffer: RelayEvent[] = [];
  let flushTimer: number | null = null;
  let inflight = false;

  const scheduleFlush = () => {
    if (flushTimer !== null) return;
    flushTimer = window.setTimeout(() => {
      flushTimer = null;
      void flush();
    }, FLUSH_INTERVAL_MS);
  };

  const flush = async () => {
    if (inflight || buffer.length === 0) return;
    inflight = true;
    const batch = buffer.splice(0, BATCH_SIZE);
    try {
      await fetch(RELAY_ENDPOINT, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(batch),
        keepalive: true,
      });
    } catch (error) {
      console.warn('[diagBridge] failed to push events', error);
      buffer.unshift(...batch);
      buffer.splice(MAX_BUFFER);
    } finally {
      inflight = false;
      if (buffer.length > 0) scheduleFlush();
    }
  };

  const enqueue = (event: RelayEvent) => {
    buffer.push(event);
    if (buffer.length >= BATCH_SIZE) {
      void flush();
    } else {
      scheduleFlush();
    }
  };

  return enqueue;
}

function startDiagBridge() {
  if (!isBrowser || !import.meta.env.DEV) return;

  const enqueue = flushFactory();

  const subscribe = <K extends DiagEvent['channel']>(channel: K) => {
    diagBus.subscribe(channel, (event) => {
      enqueue({ ts: Date.now(), event });
    });
  };

  subscribe('noise');
  subscribe('lm-wire');
  subscribe('context-window');
}

startDiagBridge();
