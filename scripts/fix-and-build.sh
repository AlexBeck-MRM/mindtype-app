#!/usr/bin/env bash
# Fix PATH to use rustup's rustc and run build commands
set -euo pipefail

# Ensure rustup's cargo/bin is first in PATH
export PATH="$HOME/.cargo/bin:$PATH"

echo "🔍 Checking Rust toolchain..."
which rustc
rustc --version

echo ""
echo "🔨 Building WASM package..."
wasm-pack build core-rs --target web --out-dir bindings/wasm/pkg

echo ""
echo "📦 Installing dependencies..."
pnpm install
pnpm --prefix hosts/web install
pnpm --prefix monitor install

echo ""
echo "✅ Build complete!"

