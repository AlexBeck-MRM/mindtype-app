#!/usr/bin/env node

/**
 * Import Path Updater - Pass 3
 * Fixes test file imports to use src/ prefix
 */

import { readFileSync, writeFileSync } from 'fs';
import { glob } from 'glob';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const root = join(__dirname, '..');

// Test files need src/ prefix
const testMappings = [
  {
    from: /from ['"]\.\.\/core\/activeRegion['"]/g,
    to: "from '../src/region/activeRegion'",
  },
  { from: /from ['"]\.\.\/region\/policy['"]/g, to: "from '../src/region/policy'" },
  {
    from: /from ['"]\.\.\/config\/thresholds['"]/g,
    to: "from '../src/config/thresholds'",
  },
  { from: /from ['"]\.\.\/safety\/grapheme['"]/g, to: "from '../src/safety/grapheme'" },
  {
    from: /from ['"]\.\.\/pipeline\/confidenceGate['"]/g,
    to: "from '../src/pipeline/confidenceGate'",
  },
  {
    from: /from ['"]\.\.\/pipeline\/conflictResolver['"]/g,
    to: "from '../src/pipeline/conflictResolver'",
  },
  {
    from: /from ['"]\.\.\/pipeline\/correctionWave['"]/g,
    to: "from '../src/pipeline/correctionWave'",
  },
  { from: /from ['"]\.\.\/lm\/types['"]/g, to: "from '../src/lm/types'" },
  { from: /from ['"]\.\.\/stages\/context['"]/g, to: "from '../src/stages/context'" },
  { from: /from ['"]\.\.\/stages\/noise['"]/g, to: "from '../src/stages/noise'" },
  { from: /from ['"]\.\.\/pipeline\/monitor['"]/g, to: "from '../src/pipeline/monitor'" },
  {
    from: /from ['"]\.\.\/pipeline\/scheduler['"]/g,
    to: "from '../src/pipeline/scheduler'",
  },
  { from: /from ['"]\.\.\/region\/diffusion['"]/g, to: "from '../src/region/diffusion'" },
  { from: /from ['"]\.\.\/safety\/diff['"]/g, to: "from '../src/safety/diff'" },
  {
    from: /from ['"]\.\.\/lm\/transformersClient['"]/g,
    to: "from '../src/lm/transformersClient'",
  },
  {
    from: /from ['"]\.\.\/core\/confidenceGate['"]/g,
    to: "from '../src/pipeline/confidenceGate'",
  },
  {
    from: /from ['"]\.\.\/config\/defaultThresholds['"]/g,
    to: "from '../src/config/thresholds'",
  },
];

async function updateFile(filePath) {
  try {
    let content = readFileSync(filePath, 'utf8');
    let modified = false;

    for (const { from, to } of testMappings) {
      if (from.test(content)) {
        content = content.replace(from, to);
        modified = true;
      }
    }

    if (modified) {
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
  console.log('🔗 Updating test imports (pass 3)...\n');

  const files = await glob('tests/**/*.ts', {
    cwd: root,
    ignore: ['**/node_modules/**'],
    absolute: true,
  });

  console.log(`Processing ${files.length} test files...\n`);

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



