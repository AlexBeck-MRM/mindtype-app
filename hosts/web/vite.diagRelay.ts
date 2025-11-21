import type { PluginOption } from 'vite';
import type { ServerResponse, IncomingMessage } from 'http';

type RelayEvent = {
  ts: number;
  event: unknown;
};

const SSE_PATH = '/diag-stream';
const PUSH_PATH = '/diag-stream/push';
const RING_SIZE = 200;

function createSSEPlugin(): PluginOption {
  const clients = new Set<ServerResponse>();
  const history: RelayEvent[] = [];

  const broadcast = (event: RelayEvent) => {
    history.push(event);
    if (history.length > RING_SIZE) {
      history.splice(0, history.length - RING_SIZE);
    }
    const payload = `data: ${JSON.stringify(event)}\n\n`;
    clients.forEach((res) => {
      res.write(payload);
    });
  };

  const handleSSE = (req: IncomingMessage, res: ServerResponse) => {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });
    res.write('\n');
    history.forEach((event) => {
      res.write(`data: ${JSON.stringify(event)}\n\n`);
    });
    clients.add(res);
    req.on('close', () => {
      clients.delete(res);
    });
  };

  const handlePush = (req: IncomingMessage, res: ServerResponse) => {
    const sendNoContent = () => {
      res.writeHead(204, {
        'Access-Control-Allow-Origin': '*',
      });
      res.end();
    };

    if (req.method === 'OPTIONS') {
      res.writeHead(204, {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'content-type',
      });
      res.end();
      return;
    }

    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const parsed = JSON.parse(body || '[]');
        const events: RelayEvent[] = Array.isArray(parsed) ? parsed : [parsed];
        events.forEach((event) => {
          if (event && typeof event === 'object' && 'event' in event) {
            broadcast(event as RelayEvent);
          }
        });
        sendNoContent();
      } catch (error) {
        res.writeHead(400, {
          'Access-Control-Allow-Origin': '*',
        });
        res.end('invalid payload');
      }
    });
  };

  return {
    name: 'mindtype-diag-relay',
    apply: 'serve',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        if (!req.url) return next();
        if (req.url.startsWith(SSE_PATH) && req.method === 'GET') {
          handleSSE(req, res);
          return;
        }
        if (
          req.url.startsWith(PUSH_PATH) &&
          (req.method === 'POST' || req.method === 'OPTIONS')
        ) {
          handlePush(req, res);
          return;
        }
        next();
      });
    },
  };
}

export const diagRelayPlugin = createSSEPlugin;
