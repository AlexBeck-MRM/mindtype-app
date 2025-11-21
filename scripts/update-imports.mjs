#!/usr/bin/env node

/**
 * Automated Import Path Updater for v0.8 Restructure
 * Updates all import statements to match new src/ structure
 */

import { readFileSync, writeFileSync } from 'fs';
import { glob } from 'glob';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const root = join(__dirname, '..');

// Import path mappings (OLD → NEW)
const mappings = [
  // Core/Pipeline
  { from: /(['"])\.\.?\/core\/typingMonitor(['"])/g, to: '$1../src/pipeline/monitor$2' },
  {
    from: /(['"])\.\.?\/core\/sweepScheduler(['"])/g,
    to: '$1../src/pipeline/scheduler$2',
  },
  {
    from: /(['"])\.\.?\/core\/correctionWave_v06(['"])/g,
    to: '$1../src/pipeline/correctionWave$2',
  },
  { from: /(['"])\.\.?\/core\/logger(['"])/g, to: '$1../src/pipeline/logger$2' },
  {
    from: /(['"])\.\.?\/core\/diagnosticsBus(['"])/g,
    to: '$1../src/pipeline/diagnosticsBus$2',
  },
  {
    from: /(['"])\.\.?\/core\/confidenceGate(['"])/g,
    to: '$1../src/pipeline/confidenceGate$2',
  },
  {
    from: /(['"])\.\.?\/core\/stagingBuffer(['"])/g,
    to: '$1../src/pipeline/stagingBuffer$2',
  },
  {
    from: /(['"])\.\.?\/core\/waveHistory(['"])/g,
    to: '$1../src/pipeline/waveHistory$2',
  },
  {
    from: /(['"])\.\.?\/core\/languageDetection(['"])/g,
    to: '$1../src/pipeline/languageDetection$2',
  },

  // Stages
  {
    from: /(['"])\.\.?\/engines\/noiseTransformer(['"])/g,
    to: '$1../src/stages/noise$2',
  },
  {
    from: /(['"])\.\.?\/engines\/contextTransformer_v06(['"])/g,
    to: '$1../src/stages/context$2',
  },
  {
    from: /(['"])\.\.?\/engines\/toneTransformer_v06(['"])/g,
    to: '$1../src/stages/tone$2',
  },
  {
    from: /(['"])\.\.?\/engines\/conflictResolver(['"])/g,
    to: '$1../src/pipeline/conflictResolver$2',
  },

  // Legacy engines (remove v06 suffix in imports)
  {
    from: /from ['"]\.\.?\/engines\/toneTransformer['"]/g,
    to: "from '../src/stages/tone'",
  },
  {
    from: /from ['"]\.\.?\/engines\/contextTransformer['"]/g,
    to: "from '../src/stages/context'",
  },

  // Region
  {
    from: /(['"])\.\.?\/core\/activeRegionPolicy(['"])/g,
    to: '$1../src/region/policy$2',
  },
  {
    from: /(['"])\.\.?\/core\/diffusionController(['"])/g,
    to: '$1../src/region/diffusion$2',
  },

  // Safety
  { from: /(['"])\.\.?\/utils\/diff(['"])/g, to: '$1../src/safety/diff$2' },
  { from: /(['"])\.\.?\/utils\/grapheme(['"])/g, to: '$1../src/safety/grapheme$2' },
  { from: /(['"])\.\.?\/core\/security(['"])/g, to: '$1../src/safety/security$2' },
  {
    from: /(['"])\.\.?\/core\/caretMonitor(['"])/g,
    to: '$1../src/safety/caretMonitor$2',
  },

  // UI
  { from: /(['"])\.\.?\/ui\/correctionMarker_v06(['"])/g, to: '$1../src/ui/marker$2' },
  { from: /(['"])\.\.?\/ui\/highlighter(['"])/g, to: '$1../src/ui/highlighter$2' },
  { from: /(['"])\.\.?\/ui\/rollbackHandler(['"])/g, to: '$1../src/ui/rollback$2' },
  { from: /(['"])\.\.?\/ui\/swapRenderer(['"])/g, to: '$1../src/ui/swapRenderer$2' },
  { from: /(['"])\.\.?\/ui\/liveRegion(['"])/g, to: '$1../src/ui/liveRegion$2' },
  { from: /(['"])\.\.?\/ui\/motion(['"])/g, to: '$1../src/ui/motion$2' },
  {
    from: /(['"])\.\.?\/ui\/securityDetection(['"])/g,
    to: '$1../src/ui/securityDetection$2',
  },

  // Config
  {
    from: /(['"])\.\.?\/config\/defaultThresholds(['"])/g,
    to: '$1../src/config/thresholds$2',
  },

  // LM
  { from: /(['"])\.\.?\/core\/lm\/types(['"])/g, to: '$1../src/lm/types$2' },
  { from: /(['"])\.\.?\/core\/lm\/factory(['"])/g, to: '$1../src/lm/factory$2' },
  { from: /(['"])\.\.?\/core\/lm\/adapter_v06(['"])/g, to: '$1../src/lm/adapter_v06$2' },
  {
    from: /(['"])\.\.?\/core\/lm\/transformersClient(['"])/g,
    to: '$1../src/lm/transformersClient$2',
  },
  {
    from: /(['"])\.\.?\/core\/lm\/transformersRunner(['"])/g,
    to: '$1../src/lm/transformersRunner$2',
  },
  {
    from: /(['"])\.\.?\/core\/lm\/workerAdapter(['"])/g,
    to: '$1../src/lm/workerAdapter$2',
  },
  {
    from: /(['"])\.\.?\/core\/lm\/contextManager(['"])/g,
    to: '$1../src/lm/contextManager$2',
  },
  { from: /(['"])\.\.?\/core\/lm\/mockAdapter(['"])/g, to: '$1../src/lm/mockAdapter$2' },
  {
    from: /(['"])\.\.?\/core\/lm\/mockStreamAdapter(['"])/g,
    to: '$1../src/lm/mockStreamAdapter$2',
  },
  { from: /(['"])\.\.?\/core\/lm\/policy(['"])/g, to: '$1../src/lm/policy$2' },
  { from: /(['"])\.\.?\/core\/lm\/config(['"])/g, to: '$1../src/lm/config$2' },
  { from: /(['"])\.\.?\/core\/lm\/mergePolicy(['"])/g, to: '$1../src/lm/mergePolicy$2' },
  {
    from: /(['"])\.\.?\/core\/lm\/resilientAdapter(['"])/g,
    to: '$1../src/lm/resilientAdapter$2',
  },
  { from: /(['"])\.\.?\/core\/lm\/deviceTiers(['"])/g, to: '$1../src/lm/deviceTiers$2' },

  // Root index
  { from: /from ['"]\.\/index['"]/g, to: "from './src/pipeline/index'" },
];

async function updateFile(filePath) {
  try {
    let content = readFileSync(filePath, 'utf8');
    let modified = false;

    for (const { from, to } of mappings) {
      if (from.test(content)) {
        content = content.replace(from, to);
        modified = true;
      }
    }

    if (modified) {
      writeFileSync(filePath, content, 'utf8');
      console.log(`✓ Updated: ${filePath.replace(root + '/', '')}`);
      return 1;
    }

    return 0;
  } catch (err) {
    console.error(`✗ Error updating ${filePath}:`, err.message);
    return 0;
  }
}

async function main() {
  console.log('🔗 Updating import paths...\n');

  // Find all TypeScript files (excluding node_modules, dist, etc.)
  const patterns = [
    'src/**/*.ts',
    'src/**/*.tsx',
    'tests/**/*.ts',
    'hosts/web/src/**/*.ts',
    'hosts/web/src/**/*.tsx',
    'core-rs/**/*.rs',
  ];

  const files = [];
  for (const pattern of patterns) {
    const matches = await glob(pattern, {
      cwd: root,
      ignore: ['**/node_modules/**', '**/dist/**', '**/build/**', '**/coverage/**'],
      absolute: true,
    });
    files.push(...matches);
  }

  console.log(`Found ${files.length} files to process\n`);

  let updatedCount = 0;
  for (const file of files) {
    updatedCount += await updateFile(file);
  }

  console.log(`\n✅ Updated ${updatedCount} files`);
  console.log('\nNext: Run "pnpm typecheck" to verify imports');
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});



