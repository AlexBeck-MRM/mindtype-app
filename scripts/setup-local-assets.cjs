/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  L O C A L   A S S E T S   S E T U P   S C R I P T  ░░░░░  ║
  ║                                                              ║
  ║   Copies ONNX WASM to /mindtype/wasm and downloads           ║
  ║   Qwen2.5-0.5B-Instruct model files to /mindtype/models      ║
  ║   for local-only serving (host-agnostic).                    ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Prepare static assets for offline/Local-Only mode
  • WHY  ▸ Avoid runtime network dependency while developing
  • HOW  ▸ Copy wasm; fetch model tree from HF and stream to disk
*/

const fs = require('node:fs');
const path = require('node:path');
const ROOT = path.resolve(__dirname, '..');
const MINDTYPE_ROOT = path.join(ROOT, 'mindtype');
const DEMO_PUBLIC = path.join(ROOT, 'web-demo', 'public');
const WASM_DST = path.join(MINDTYPE_ROOT, 'wasm');
const MODELS_DST = path.join(MINDTYPE_ROOT, 'models');
const REPO = 'onnx-community/Qwen2.5-0.5B-Instruct';
const REPO_DST = path.join(MODELS_DST, REPO);
const BRAND_BG_SRC = path.join(ROOT, 'docs', 'brand', 'assets', 'background-video.webm');
const BRAND_BG_DST = path.join(DEMO_PUBLIC, 'assets', 'background-video.webm');

async function ensureDir(p) {
  await fs.promises.mkdir(p, { recursive: true });
}

async function copyWasm() {
  // Locate wasm in onnxruntime-web (could be in pnpm or regular node_modules)
  let ortDist = path.join(ROOT, 'node_modules', 'onnxruntime-web', 'dist');
  if (!fs.existsSync(ortDist)) {
    // Try pnpm structure: find onnxruntime-web@* directory
    const pnpmDir = path.join(ROOT, 'node_modules', '.pnpm');
    if (fs.existsSync(pnpmDir)) {
      const entries = fs.readdirSync(pnpmDir);
      for (const entry of entries) {
        if (entry.startsWith('onnxruntime-web@')) {
          const candidate = path.join(pnpmDir, entry, 'node_modules', 'onnxruntime-web', 'dist');
          if (fs.existsSync(candidate)) {
            ortDist = candidate;
            break;
          }
        }
      }
    }
  }
  
  if (!fs.existsSync(ortDist)) {
    console.warn('⚠️  onnxruntime-web dist not found, skipping WASM copy');
    return;
  }

  // Copy both .wasm files AND .mjs loader files (including .jsep.mjs variants)
  const files = [
    'ort-wasm.wasm',
    'ort-wasm-threaded.wasm',
    'ort-wasm-simd.wasm',
    'ort-wasm-simd-threaded.wasm',
    'ort-wasm-simd-threaded.mjs',
    'ort-wasm-simd-threaded.jsep.mjs',
    'ort-wasm-simd-threaded.jsep.wasm',
  ];
  
  await ensureDir(WASM_DST);
  for (const f of files) {
    const src = path.join(ortDist, f);
    const dst = path.join(WASM_DST, f);
    try {
      if (fs.existsSync(src)) {
        await fs.promises.copyFile(src, dst);
        console.log(`✓ Copied ${f}`);
      } else {
        console.warn(`⚠️  Skip ${f}: not found in ${ortDist}`);
      }
    } catch (e) {
      console.warn(`⚠️  Skip copy ${f}: ${e.message}`);
    }
  }
}

async function copyBrandAssets() {
  try {
    await ensureDir(path.dirname(BRAND_BG_DST));
    await fs.promises.copyFile(BRAND_BG_SRC, BRAND_BG_DST);
    console.log(`Copied background video to ${path.relative(ROOT, BRAND_BG_DST)}`);
  } catch (e) {
    console.warn(`Skip background video: ${e.message}`);
  }
}

function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

async function downloadFile(url, outPath, fileName) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  
  const totalSize = parseInt(res.headers.get('content-length') || '0', 10);
  let downloadedSize = 0;
  let lastProgress = -1;
  
  await ensureDir(path.dirname(outPath));
  const fileStream = fs.createWriteStream(outPath);
  // @ts-ignore Node18 fetch body is a web stream; convert via reader
  const reader = res.body.getReader();
  
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    fileStream.write(Buffer.from(value));
    downloadedSize += value.length;
    
    // Show progress for large files (>1MB)
    if (totalSize > 1024 * 1024) {
      const progress = Math.floor((downloadedSize / totalSize) * 100);
      if (progress !== lastProgress && progress % 10 === 0) {
        process.stdout.write(`\r  ${fileName}: ${formatBytes(downloadedSize)} / ${formatBytes(totalSize)} (${progress}%)`);
        lastProgress = progress;
      }
    }
  }
  
  if (totalSize > 1024 * 1024) {
    process.stdout.write(`\r  ${fileName}: ${formatBytes(totalSize)} ✓\n`);
  }
  
  await new Promise((r) => fileStream.end(r));
}

async function downloadModelTree(repo) {
  // query the model tree and download files
  const api = `https://huggingface.co/api/models/${repo}/tree/main?recursive=1`;
  console.log(`Listing ${repo} ...`);
  const res = await fetch(api);
  if (!res.ok) throw new Error(`Failed to list ${repo}: ${res.status}`);
  const entries = await res.json();
  
  // Download ONLY essential files for q4f16 quantized model (smallest variant)
  const essentialFiles = new Set([
    'config.json',
    'tokenizer.json',
    'tokenizer_config.json',
    'generation_config.json',
    'special_tokens_map.json',
    'merges.txt',
    'vocab.json',
    'added_tokens.json',
    'onnx/model_q4f16.onnx',           // 4-bit quantized with fp16 embeddings (~460MB, smallest working variant)
  ]);
  
  const base = `https://huggingface.co/${repo}/resolve/main/`;

  // Helper to enqueue downloads - ONLY download essential files
  const queue = [];
  let totalSize = 0;
  for (const e of entries) {
    if (e.type !== 'file') continue;
    const rel = e.path;
    
    // Skip files not in essential set
    if (!essentialFiles.has(rel)) {
      console.log(`⊘ Skipping ${rel} (not essential for q4 inference)`);
      continue;
    }
    
    const url = base + rel;
    const out = path.join(REPO_DST, rel);
    const size = e.size || 0;
    totalSize += size;
    queue.push({ url, out, name: rel, size });
  }
  console.log(`\nDownloading ${queue.length} files (${formatBytes(totalSize)} total) to ${REPO_DST}...\n`);
  let ok = 0,
    fail = 0;
  for (const job of queue) {
    try {
      console.log(`[${ok + 1}/${queue.length}] ${job.name} (${formatBytes(job.size)})`);
      await downloadFile(job.url, job.out, job.name);
      ok++;
    } catch (e) {
      fail++;
      console.warn(`  ✗ Failed: ${e.message}`);
    }
  }
  console.log(`\n✓ Done. Success: ${ok}/${queue.length}, Failed: ${fail}`);
}

async function main() {
  console.log('Setting up Local-Only assets...');
  await ensureDir(DEMO_PUBLIC);
  await ensureDir(MINDTYPE_ROOT);
  await ensureDir(MODELS_DST);
  await copyWasm();
  await copyBrandAssets();
  await ensureDir(REPO_DST);
  await downloadModelTree(REPO);
  console.log(
    'Local-Only assets ready. In the demo, enable “Local models only” and click Load LM.',
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
