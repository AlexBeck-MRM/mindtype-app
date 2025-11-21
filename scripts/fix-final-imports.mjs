#!/usr/bin/env node

import { readFileSync, writeFileSync } from 'fs';
import { glob } from 'glob';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const root = join(__dirname, '..');

const fixes = [
  // tests/core/ imports
  {
    from: /from ['"]\.\.\/src\/config\/thresholds['"]/g,
    to: "from '../../src/config/thresholds'",
  },

  // tests/ root imports
  { from: /from ['"]\.\.\/\.\.\/index['"]/g, to: "from '../../src/pipeline/index'" },
  { from: /from ['"]\.\.\/core\/tapestry['"]/g, to: "from '../src/region/tapestry'" },
  { from: /from ['"]\.\.\/stages\/tone['"]/g, to: "from '../src/stages/tone'" },
  {
    from: /from ['"]\.\.\/engines\/toneTransformer['"]/g,
    to: "from '../src/stages/tone'",
  },

  // Fix mergePolicy band→activeRegion
  {
    from: /adapter\.stream\(normalizeLMStreamParams\(\{ text, caret, band \}\)\)/g,
    to: 'adapter.stream(normalizeLMStreamParams({ text, caret, activeRegion: band }))',
  },
];

async function updateFile(filePath) {
  try {
    let content = readFileSync(filePath, 'utf8');
    let modified = false;

    for (const { from, to } of fixes) {
      if (from.test(content)) {
        content = content.replace(from, to);
        modified = true;
      }
    }

    if (modified) {
      writeFileSync(filePath, content, 'utf8');
      return 1;
    }

    return 0;
  } catch (err) {
    console.error(`✗ ${filePath}: ${err.message}`);
    return 0;
  }
}

async function main() {
  console.log('🔧 Fixing final imports...\n');

  const patterns = ['tests/**/*.spec.ts', 'src/**/*.ts'];

  const files = [];
  for (const pattern of patterns) {
    const matches = await glob(pattern, { cwd: root, absolute: true });
    files.push(...matches);
  }

  let updatedCount = 0;
  for (const file of files) {
    const result = await updateFile(file);
    if (result) {
      console.log(`✓ ${file.replace(root + '/', '')}`);
      updatedCount++;
    }
  }

  console.log(`\n✅ Updated ${updatedCount} files`);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});



