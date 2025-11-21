#!/usr/bin/env node

import { readFileSync, writeFileSync } from 'fs';
import { glob } from 'glob';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const root = join(__dirname, '..');

const fixes = [
  // Remove .ts extensions from imports
  { from: /from ['"]\.\/helpers\/lmParams\.ts['"]/g, to: "from './helpers/lmParams'" },

  // Fix scheduler tone import
  { from: /from ['"]\.\.\/src\/stages\/tone['"]/g, to: "from '../stages/tone'" },

  // Fix tests in subdirectories (tests/core/, tests/integration/, tests/performance/)
  {
    from: /from ['"]\.\.\/src\/config\/thresholds['"]/g,
    to: "from '../../src/config/thresholds'",
  },

  // Add missing import for streamWithNormalizedRegion
  { from: /from ['"]\.\.\/lm\/types['"]/g, to: "from '../src/lm/types'" },
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

    // Add streamWithNormalizedRegion import if it's used but not imported
    if (
      content.includes('streamWithNormalizedRegion') &&
      !content.includes('import') &&
      !content.includes('streamWithNormalizedRegion') &&
      filePath.includes('transformersClient')
    ) {
      const importLine =
        "import { streamWithNormalizedRegion } from './helpers/lmParams';\n";
      content = content.replace(/^(import.*\n)+/, (match) => match + importLine);
      modified = true;
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
  console.log('🔧 Fixing .ts extensions and paths...\n');

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



