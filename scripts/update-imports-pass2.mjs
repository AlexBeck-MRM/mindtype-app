#!/usr/bin/env node

/**
 * Import Path Updater - Pass 2
 * Fixes remaining relative path issues within src/
 */

import { readFileSync, writeFileSync } from 'fs';
import { glob } from 'glob';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const root = join(__dirname, '..');

// Within src/, fix relative imports
const srcMappings = [
  // From src/lm/ files
  { from: /from ['"]\.\.\/logger['"]/g, to: "from '../pipeline/logger'" },
  { from: /from ['"]\.\.\/diagnosticsBus['"]/g, to: "from '../pipeline/diagnosticsBus'" },
  { from: /from ['"]\.\.\/stagingBuffer['"]/g, to: "from '../pipeline/stagingBuffer'" },
  {
    from: /from ['"]\.\.\/\.\.\/config\/defaultThresholds['"]/g,
    to: "from '../config/thresholds'",
  },
  { from: /from ['"]\.\.\/\.\.\/utils\/diff['"]/g, to: "from '../safety/diff'" },

  // From src/pipeline/ files
  { from: /from ['"]\.\/typingMonitor['"]/g, to: "from './monitor'" },
  { from: /from ['"]\.\/diffusionController['"]/g, to: "from '../region/diffusion'" },
  { from: /from ['"]\.\/security['"]/g, to: "from '../safety/security'" },
  { from: /from ['"]\.\/activeRegionPolicy['"]/g, to: "from '../region/policy'" },
  { from: /from ['"]\.\/lm\/types['"]/g, to: "from '../lm/types'" },

  // From src/region/ files
  { from: /from ['"]\.\/lm\/policy['"]/g, to: "from '../lm/policy'" },
  { from: /from ['"]\.\/lm\/mergePolicy['"]/g, to: "from '../lm/mergePolicy'" },
  { from: /from ['"]\.\/logger['"]/g, to: "from '../pipeline/logger'" },

  // Double ../src/ paths (wrong)
  { from: /from ['"]\.\.\/src\//g, to: "from '../" },
  { from: /from ['"]\.\.\/\.\.\/src\//g, to: "from '../../" },

  // Tests to src/
  { from: /from ['"]\.\.\/index['"]/g, to: "from '../src/pipeline/index'" },
  {
    from: /from ['"]\.\.\/\.\.\/core\/caretMonitor['"]/g,
    to: "from '../../src/safety/caretMonitor'",
  },
  {
    from: /from ['"]\.\.\/\.\.\/core\/confidenceGate['"]/g,
    to: "from '../../src/pipeline/confidenceGate'",
  },
  { from: /from ['"]\.\.\/\.\.\/core\/lm\//g, to: "from '../../src/lm/" },
  {
    from: /from ['"]\.\.\/\.\.\/core\/sweepScheduler['"]/g,
    to: "from '../../src/pipeline/scheduler'",
  },
  {
    from: /from ['"]\.\.\/\.\.\/core\/typingMonitor['"]/g,
    to: "from '../../src/pipeline/monitor'",
  },
  {
    from: /from ['"]\.\.\/\.\.\/config\/defaultThresholds['"]/g,
    to: "from '../../src/config/thresholds'",
  },
];

async function updateFile(filePath) {
  try {
    let content = readFileSync(filePath, 'utf8');
    let modified = false;

    for (const { from, to } of srcMappings) {
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
  console.log('🔗 Updating import paths (pass 2)...\n');

  const patterns = ['src/**/*.ts', 'src/**/*.tsx', 'tests/**/*.ts'];

  const files = [];
  for (const pattern of patterns) {
    const matches = await glob(pattern, {
      cwd: root,
      ignore: ['**/node_modules/**', '**/dist/**'],
      absolute: true,
    });
    files.push(...matches);
  }

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



