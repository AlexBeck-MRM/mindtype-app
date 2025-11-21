#!/usr/bin/env node

const http = require('http');

const streamUrl = process.env.DIAG_STREAM_URL || 'http://localhost:5173/diag-stream';

console.log(`[diag:smoke] Probing SSE stream at ${streamUrl}`);
console.log('[diag:smoke] Ensure `pnpm demo:web` is running and diag events are being emitted.');

const req = http.get(
  streamUrl,
  {
    headers: {
      Accept: 'text/event-stream',
    },
  },
  (res) => {
    if (res.statusCode !== 200) {
      console.error(`[diag:smoke] Unexpected status code: ${res.statusCode}`);
      process.exit(1);
    }

    let buffer = '';
    const abortTimer = setTimeout(() => {
      console.error('[diag:smoke] No SSE payload within 5s — is the demo running?');
      res.destroy();
      process.exit(1);
    }, 5000);

    res.on('data', (chunk) => {
      buffer += chunk.toString();
      if (buffer.includes('data:')) {
        clearTimeout(abortTimer);
        console.log('[diag:smoke] ✅ Received SSE payload — telemetry relay is live.');
        res.destroy();
        process.exit(0);
      }
    });
  },
);

req.on('error', (err) => {
  console.error('[diag:smoke] Failed to connect to SSE stream:', err.message);
  process.exit(1);
});

