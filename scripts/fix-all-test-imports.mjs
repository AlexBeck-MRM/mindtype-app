#!/usr/bin/env node

import { readFileSync, writeFileSync } from 'fs';
import { glob } from 'glob';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const root = join(__dirname, '..');

const fixes = [
  // All test imports need src/ prefix
  { from: /from ['"]\.\.\/pipeline\//g, to: "from '../src/pipeline/" },
  { from: /from ['"]\.\.\/lm\//g, to: "from '../src/lm/" },
  { from: /from ['"]\.\.\/ui\//g, to: "from '../src/ui/" },
  { from: /from ['"]\.\.\/safety\//g, to: "from '../src/safety/" },
  { from: /from ['"]\.\.\/index['"]/g, to: "from '../src/pipeline/index'" },

  // Fix contextTransform calls with old 3-arg signature
  {
    from: /await contextTransform\(\s*\{\s*text,\s*caret\s*\},\s*lmAdapter,\s*\w+\s*\)/g,
    to: 'await contextTransform({ text, caret, activeRegion: { start: 0, end: caret }, lmAdapter })',
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
  console.log('🔧 Fixing all test imports...\n');

  const files = await glob('tests/**/*.spec.ts', {
    cwd: root,
    absolute: true,
  });

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



