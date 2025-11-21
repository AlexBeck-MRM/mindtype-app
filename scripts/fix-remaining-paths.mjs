#!/usr/bin/env node

import { readFileSync, writeFileSync, readdirSync, statSync } from 'fs';
import { join, dirname, relative } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const root = join(__dirname, '..');

function fixFile(filePath) {
  let content = readFileSync(filePath, 'utf8');
  const original = content;

  // Within src/, remove ../src/ double prefix
  if (filePath.includes('/src/')) {
    content = content.replace(/from ['"]\.\.\/src\//g, "from '../");
  }

  // In tests/ root, use ../src/
  // In tests/subdir/, use ../../src/
  const relativePath = relative(root, filePath);

  if (relativePath.startsWith('tests/') && !relativePath.includes('/tests/')) {
    // tests/ root level
    content = content.replace(/from ['"]\.\.\/\.\.\/src\//g, "from '../src/");
  } else if (relativePath.match(/tests\/[^/]+\//)) {
    // tests/subdir/ level - already has correct ../../src/
  }

  // Fix specific broken imports
  content = content.replace(
    /from ['"]\.\.\/stages\/tone['"]/g,
    "from '../src/stages/tone'",
  );
  content = content.replace(
    /from ['"]\.\.\/engines\/toneTransformer['"]/g,
    "from '../src/stages/tone'",
  );

  if (content !== original) {
    writeFileSync(filePath, content, 'utf8');
    return true;
  }
  return false;
}

function walkDir(dir) {
  const files = [];
  for (const item of readdirSync(dir)) {
    if (item === 'node_modules' || item === 'dist' || item === '.git') continue;
    const fullPath = join(dir, item);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      files.push(...walkDir(fullPath));
    } else if (item.endsWith('.ts') && !item.endsWith('.d.ts')) {
      files.push(fullPath);
    }
  }
  return files;
}

console.log('🔧 Final path fixes...\n');

const srcFiles = walkDir(join(root, 'src'));
const testFiles = walkDir(join(root, 'tests'));

let count = 0;
for (const file of [...srcFiles, ...testFiles]) {
  if (fixFile(file)) {
    console.log(`✓ ${relative(root, file)}`);
    count++;
  }
}

console.log(`\n✅ Updated ${count} files`);



