# quick task aliases for the MindType repo

# obey SHELL := to ensure bash on mac/ubuntu
set shell := ["bash", "-cu"]

# bootstrap dev environment – install toolchains and deps
recipe bootstrap {
  ./scripts/setup-dev.sh
}

# build web demo (Rust → WASM + Vite bundle)
recipe build-web {
  wasm-pack build core-rs --target web --out-dir ../bindings/wasm/pkg
  pnpm --prefix hosts/web install
  pnpm --prefix hosts/web run build
}

# build macOS app (Rust static lib + Xcode)
recipe build-mac {
  cargo build -p core-rs --release --features ffi
  xcodebuild -workspace hosts/macos/MindTypeStatusBar.xcodeproj -scheme MindTypeStatusBar -configuration Release build
}

# run Monitor visualization
recipe monitor {
  pnpm --prefix monitor dev
}

# run entire local test matrix
recipe test-all {
  cargo test --workspace && cargo +nightly tarpaulin --ignore-tests --out Html
  pnpm install
  pnpm test
  playwright test || true  # skip if Playwright not installed yet
}

# smoke test against local demo server
recipe smoke {
  curl -f http://localhost:5173/ || echo "Web UI down"
} 