#!/usr/bin/env node

/**
 * Fix test signatures for v0.8 API changes
 */

import { readFileSync, writeFileSync } from 'fs';
import { glob } from 'glob';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const root = join(__dirname, '..');

function fixContextTransformCalls(content) {
  // Fix: contextTransform({ text, caret }, lmAdapter, mgr)
  // To: contextTransform({ text, caret, activeRegion: { start: 0, end: caret }, lmAdapter })

  // Pattern: contextTransform({ text, caret }, lmAdapter, mgr)
  return content
    .replace(
      /await contextTransform\(\s*\{\s*text,\s*caret\s*\},\s*lmAdapter,\s*mgr\s*\)/g,
      'await contextTransform({ text, caret, activeRegion: { start: 0, end: caret }, lmAdapter })',
    )
    .replace(
      /await contextTransform\(\s*\{\s*text,\s*caret\s*\}\s*,\s*lmAdapter\s*,\s*mgr\s*\)/g,
      'await contextTransform({ text, caret, activeRegion: { start: 0, end: caret }, lmAdapter })',
    );
}

async function updateFile(filePath) {
  try {
    let content = readFileSync(filePath, 'utf8');
    const original = content;

    content = fixContextTransformCalls(content);

    if (content !== original) {
      writeFileSync(filePath, content, 'utf8');
      console.log(`✓ ${filePath.replace(root + '/', '')}`);
      return 1;
    }

    return 0;
  } catch (err) {
    console.error(`✗ ${filePath}: ${err.message}`);
    return 0;
  }
}

async function main() {
  console.log('🔧 Fixing test signatures...\n');

  const files = await glob('tests/**/*gating*.spec.ts', {
    cwd: root,
    absolute: true,
  });

  console.log(`Processing ${files.length} files...\n`);

  let updatedCount = 0;
  for (const file of files) {
    updatedCount += await updateFile(file);
  }

  console.log(`\n✅ Updated ${updatedCount} files`);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});



