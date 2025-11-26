import { defineConfig, type PluginOption } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';
import pkg from '../../package.json';
import fs from 'fs';
import { join } from 'path';
import type { IncomingMessage, ServerResponse } from 'http';
import { diagRelayPlugin } from './vite.diagRelay';

// https://vitejs.dev/config/
export default defineConfig({
  clearScreen: false,
  assetsInclude: ['**/*.wasm'],
  plugins: [
    react(),
    diagRelayPlugin(),
    // Fix WASM MIME types - intercept responses to set correct Content-Type
    {
      name: 'wasm-mime-fix',
      configureServer(server) {
        server.middlewares.use((req, res, next) => {
          const url = req.url || '';
          if (url.includes('.wasm')) {
            // Override setHeader to always set correct WASM MIME type
            const originalSetHeader = res.setHeader.bind(res);
            res.setHeader = function (name: string, value: string | string[] | number) {
              if (name.toLowerCase() === 'content-type') {
                return originalSetHeader('Content-Type', 'application/wasm');
              }
              return originalSetHeader(name, value);
            };
            // Also set headers before next() to ensure they're applied
            res.setHeader('Content-Type', 'application/wasm');
            res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
          }
          next();
        });
      },
    } as PluginOption,
    // Inject dev-time middleware via plugin hook (Vite 5/7 compatible)
    {
      name: 'mt-assets-alias',
      configureServer(server: import('vite').ViteDevServer) {
        const MINDTYPE_ROOT = resolve(__dirname, '..', '..', 'mindtype');
        const MODELS = join(MINDTYPE_ROOT, 'models');
        const WASM = join(MINDTYPE_ROOT, 'wasm');
        const DEMO_DIR = resolve(__dirname, '..', 'demo');

        console.log('[mt-assets-alias] MODELS path:', MODELS);
        console.log('[mt-assets-alias] WASM path:', WASM);

        server.middlewares.use(
          (req: IncomingMessage, res: ServerResponse, next: () => void) => {
            // Strip query parameters from URL for file serving
            const rawUrl = req?.url || '';
            const url = rawUrl.split('?')[0]; // Remove query string (?import, etc.)

            // Add COOP header for WebGPU/WASM threading support
            // COEP removed - it blocks ES module imports (.mjs files)
            res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');

            // Serve all demo assets from project-root /demo directory (HTML, JS, CSS, etc.)
            if (typeof url === 'string' && url.startsWith('/demo/')) {
              const rel = url.slice('/demo/'.length);
              const filePath = join(DEMO_DIR, rel);
              // If the path points to a directory (or ends with '/'), serve index.html
              try {
                if (
                  url.endsWith('/') ||
                  (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory())
                ) {
                  const asIndex = join(DEMO_DIR, rel, 'index.html');
                  if (fs.existsSync(asIndex)) {
                    res.setHeader('Content-Type', 'text/html; charset=utf-8');
                    fs.createReadStream(asIndex).pipe(res);
                    return;
                  }
                }
              } catch {
                // Ignore directory check errors
              }

              if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
                const ext = filePath.split('.').pop() || '';
                const m: Record<string, string> = {
                  json: 'application/json',
                  wasm: 'application/wasm',
                  onnx: 'application/octet-stream',
                  txt: 'text/plain; charset=utf-8',
                  html: 'text/html; charset=utf-8',
                  css: 'text/css; charset=utf-8',
                  js: 'application/javascript; charset=utf-8',
                };
                res.setHeader('Content-Type', m[ext] || 'application/octet-stream');
                fs.createReadStream(filePath).pipe(res);
                return;
              }
            }

            const serve = (baseDir: string, prefix: string) => {
              const rel = url.slice(prefix.length);
              const filePath = join(baseDir, rel);

              if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
                const ext = filePath.split('.').pop() || '';
                const m: Record<string, string> = {
                  json: 'application/json',
                  wasm: 'application/wasm',
                  onnx: 'application/octet-stream',
                  txt: 'text/plain; charset=utf-8',
                  html: 'text/html; charset=utf-8',
                  css: 'text/css; charset=utf-8',
                  js: 'application/javascript; charset=utf-8',
                  mjs: 'application/javascript; charset=utf-8',
                  jsep: 'application/wasm', // .jsep.wasm files
                };
                const contentType = m[ext] || 'application/octet-stream';
                res.setHeader('Content-Type', contentType);
                // CORS headers for WASM - but NOT COEP which blocks ES module imports
                res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
                res.setHeader('Access-Control-Allow-Origin', '*');
                // For ES modules (.mjs), ensure proper MIME type
                if (ext === 'mjs') {
                  res.setHeader('Content-Type', 'application/javascript; charset=utf-8');
                }
                console.log(`[serve] ✓ ${filePath} → ${contentType}`);
                fs.createReadStream(filePath).pipe(res);
                return true;
              }
              return false;
            };
            if (
              typeof url === 'string' &&
              url.startsWith('/mindtype/models/') &&
              serve(MODELS, '/mindtype/models/')
            )
              return;
            if (
              typeof url === 'string' &&
              url.startsWith('/mindtype/wasm/') &&
              serve(WASM, '/mindtype/wasm/')
            )
              return;
            next();
          },
        );
      },
    } as PluginOption,
    // Public directory still serves SPA assets; /demo/* is mounted from project root demo/
  ],
  define: {
    __APP_VERSION__: JSON.stringify(pkg.version),
  },
  server: {
    fs: {
      allow: [
        // project root and bindings dir for WASM package
        resolve(__dirname),
        resolve(__dirname, '..'),
        resolve(__dirname, '..', '..'),
        '/Users/alexanderbeck/Coding Folder /MindType',
        '/Users/alexanderbeck/Coding Folder /MindType/bindings/wasm/pkg',
      ],
      strict: false,
    },
    // Note: COEP removed - it blocks ES module imports (.mjs files)
    // WebGPU/SharedArrayBuffer will work without COEP in most cases
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
    },
    // Dev server defaults; asset/demo aliasing handled in plugins above
    middlewareMode: false,
    proxy: {},
    open: '/',
  },
  // Configure SPA fallback to not interfere with static demo routes
  appType: 'spa',
  publicDir: 'public',
  resolve: {
    alias: {
      '/demo': resolve(__dirname, '..', 'demo'),
      // Allow workers to import from src/ directory
      '@src': resolve(__dirname, '..', '..', 'src'),
    },
  },
  worker: {
    format: 'es',
    plugins: () => [react()],
  },
  build: {
    rollupOptions: {
      input: resolve(__dirname, 'index.html'),
    },
  },
});
