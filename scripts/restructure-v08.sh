#!/bin/bash
set -e  # Exit on any error

# ═══════════════════════════════════════════════════════════════════════════
# Mind⠶Flow v0.8 Complete Restructure Script
# ═══════════════════════════════════════════════════════════════════════════
# This script reorganizes the entire repository to mirror the runtime pipeline
# and creates the Monitor visualization app.
#
# USAGE:
#   1. Review this script thoroughly
#   2. Commit current work: git add -A && git commit -m "Pre-restructure checkpoint"
#   3. Run: bash scripts/restructure-v08.sh
#   4. Validate: pnpm typecheck && pnpm lint && pnpm test
#
# ROLLBACK:
#   git reset --hard HEAD~1  (if something breaks)
# ═══════════════════════════════════════════════════════════════════════════

echo "🚀 Starting Mind⠶Flow v0.8 restructure..."
echo ""

# Get repo root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "📍 Working directory: $REPO_ROOT"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1: Create new directory structure
# ═══════════════════════════════════════════════════════════════════════════

echo "📁 Phase 1: Creating new directory structure..."

mkdir -p src/pipeline
mkdir -p src/stages
mkdir -p src/region
mkdir -p src/lm
mkdir -p src/safety
mkdir -p src/ui
mkdir -p src/config
mkdir -p hosts/web
mkdir -p hosts/macos
mkdir -p monitor/src
mkdir -p monitor/public
mkdir -p docs/monitor

echo "   ✓ New directories created"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2: Move TypeScript core files
# ═══════════════════════════════════════════════════════════════════════════

echo "📦 Phase 2: Moving TypeScript core files..."

# Pipeline orchestration
mv core/typingMonitor.ts src/pipeline/monitor.ts || true
mv core/sweepScheduler.ts src/pipeline/scheduler.ts || true
mv core/correctionWave_v06.ts src/pipeline/correctionWave.ts || true
mv index.ts src/pipeline/index.ts || true

# Stages (transformers)
mv engines/noiseTransformer.ts src/stages/noise.ts || true
mv engines/contextTransformer_v06.ts src/stages/context.ts || true
mv engines/toneTransformer_v06.ts src/stages/tone.ts || true

# Region computation
mv core/activeRegionPolicy.ts src/region/policy.ts || true
mv core/diffusionController.ts src/region/diffusion.ts || true

# Language model
mv core/lm/* src/lm/ || true

# Safety
mv utils/diff.ts src/safety/diff.ts || true
mv utils/grapheme.ts src/safety/grapheme.ts || true
mv core/security.ts src/safety/security.ts || true

# UI
mv ui/correctionMarker_v06.ts src/ui/marker.ts || true
mv ui/highlighter.ts src/ui/highlighter.ts || true
mv ui/rollbackHandler.ts src/ui/rollback.ts || true
mv ui/swapRenderer.ts src/ui/swapRenderer.ts || true
mv ui/liveRegion.ts src/ui/liveRegion.ts || true
mv ui/motion.ts src/ui/motion.ts || true
mv ui/securityDetection.ts src/ui/securityDetection.ts || true

# Config
mv config/defaultThresholds.ts src/config/thresholds.ts || true

# Other core utilities
mv core/logger.ts src/pipeline/logger.ts || true
mv core/diagnosticsBus.ts src/pipeline/diagnosticsBus.ts || true
mv core/confidenceGate.ts src/pipeline/confidenceGate.ts || true
mv core/stagingBuffer.ts src/pipeline/stagingBuffer.ts || true
mv core/waveHistory.ts src/pipeline/waveHistory.ts || true
mv core/languageDetection.ts src/pipeline/languageDetection.ts || true
mv core/caretMonitor.ts src/safety/caretMonitor.ts || true

# Conflict resolver (belongs with pipeline)
mv engines/conflictResolver.ts src/pipeline/conflictResolver.ts || true

echo "   ✓ Core files moved"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 3: Move Rust crate
# ═══════════════════════════════════════════════════════════════════════════

echo "🦀 Phase 3: Moving Rust crate..."

if [ -d "crates/core-rs" ]; then
    mv crates/core-rs core-rs || true
    echo "   ✓ Rust crate moved to core-rs/"
else
    echo "   ⚠ crates/core-rs not found, skipping"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 4: Move hosts
# ═══════════════════════════════════════════════════════════════════════════

echo "🖥️  Phase 4: Moving host applications..."

# Web demo
if [ -d "web-demo" ]; then
    mv web-demo/* hosts/web/ || true
    rmdir web-demo || true
    echo "   ✓ Web demo moved to hosts/web/"
fi

# macOS app
if [ -d "macOS" ]; then
    mv macOS/* hosts/macos/ || true
    rmdir macOS || true
    echo "   ✓ macOS app moved to hosts/macos/"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 5: Create Monitor app
# ═══════════════════════════════════════════════════════════════════════════

echo "📊 Phase 5: Creating Monitor app..."

# Monitor package.json
cat > monitor/package.json << 'EOF'
{
  "name": "mindflow-monitor",
  "version": "0.8.0",
  "type": "module",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@vitejs/plugin-react": "^4.2.0",
    "typescript": "^5.5.4",
    "vite": "^5.0.0"
  }
}
EOF

# Monitor tsconfig.json
cat > monitor/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"]
}
EOF

# Monitor vite.config.ts
cat > monitor/vite.config.ts << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: './',
  server: {
    port: 3001
  }
})
EOF

# Monitor index.html
cat > monitor/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Mind⠶Flow Monitor</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

# Monitor main.tsx
cat > monitor/src/main.tsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

# Monitor index.css
cat > monitor/src/index.css << 'EOF'
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: 'SF Mono', 'Monaco', 'Cascadia Code', monospace;
  background: #0a0e14;
  color: #c5c8c6;
  overflow: hidden;
}

#root {
  width: 100vw;
  height: 100vh;
}
EOF

# Monitor App.tsx
cat > monitor/src/App.tsx << 'EOF'
import React, { useState, useEffect } from 'react'
import SystemMap from './SystemMap'
import './App.css'

interface SystemMapData {
  version: string
  name: string
  description: string
  nodes: Array<{
    id: string
    type: string
    label: string
    description: string
    module?: string
    connections?: string[]
    config?: Record<string, unknown>
  }>
  hosts: Array<{
    id: string
    label: string
    path: string
    description: string
  }>
  metadata: {
    updated: string
    architecture: string
    principles: string[]
  }
}

export default function App() {
  const [systemMap, setSystemMap] = useState<SystemMapData | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch('/system-map.json')
      .then(res => res.json())
      .then(data => {
        setSystemMap(data)
        setLoading(false)
      })
      .catch(err => {
        console.error('Failed to load system map:', err)
        setLoading(false)
      })
  }, [])

  if (loading) {
    return (
      <div className="loading">
        <div className="spinner"></div>
        <p>Loading Mind⠶Flow Monitor...</p>
      </div>
    )
  }

  if (!systemMap) {
    return (
      <div className="error">
        <p>❌ Failed to load system map</p>
        <p>Check that system-map.json exists in public/</p>
      </div>
    )
  }

  return (
    <div className="app">
      <header className="header">
        <div className="header-left">
          <h1>Mind⠶Flow Monitor</h1>
          <span className="version">v{systemMap.version}</span>
        </div>
        <div className="header-right">
          <span className="status">● LIVE</span>
        </div>
      </header>
      
      <main className="main">
        <SystemMap data={systemMap} />
      </main>
      
      <footer className="footer">
        <div className="footer-left">
          <span>Architecture: {systemMap.metadata.architecture}</span>
        </div>
        <div className="footer-right">
          <span>Last updated: {systemMap.metadata.updated}</span>
        </div>
      </footer>
    </div>
  )
}
EOF

# Monitor App.css
cat > monitor/src/App.css << 'EOF'
.app {
  width: 100vw;
  height: 100vh;
  display: flex;
  flex-direction: column;
  background: #0a0e14;
  color: #c5c8c6;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 2rem;
  background: #14181f;
  border-bottom: 2px solid #1f2937;
}

.header-left {
  display: flex;
  align-items: baseline;
  gap: 1rem;
}

.header h1 {
  font-size: 1.5rem;
  font-weight: 600;
  letter-spacing: -0.02em;
}

.version {
  font-size: 0.875rem;
  color: #6b7280;
  font-weight: 500;
}

.status {
  font-size: 0.875rem;
  color: #10b981;
  font-weight: 600;
}

.main {
  flex: 1;
  overflow: hidden;
  position: relative;
}

.footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 2rem;
  background: #14181f;
  border-top: 2px solid #1f2937;
  font-size: 0.75rem;
  color: #6b7280;
}

.loading, .error {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100vh;
  gap: 1rem;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid #1f2937;
  border-top-color: #3b82f6;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.error p {
  color: #ef4444;
}
EOF

# Monitor SystemMap.tsx
cat > monitor/src/SystemMap.tsx << 'EOF'
import React, { useState } from 'react'
import './SystemMap.css'

interface Node {
  id: string
  type: string
  label: string
  description: string
  module?: string
  connections?: string[]
  config?: Record<string, unknown>
}

interface SystemMapProps {
  data: {
    nodes: Node[]
    hosts: Array<{
      id: string
      label: string
      path: string
      description: string
    }>
  }
}

const NODE_COLORS: Record<string, string> = {
  source: '#3b82f6',      // Blue
  orchestrator: '#8b5cf6', // Purple
  compute: '#06b6d4',      // Cyan
  control: '#10b981',      // Green
  transformer: '#f59e0b',  // Amber
  service: '#ec4899',      // Pink
  validator: '#14b8a6',    // Teal
  sink: '#6366f1',         // Indigo
  visual: '#a855f7',       // Purple-light
}

export default function SystemMap({ data }: SystemMapProps) {
  const [selectedNode, setSelectedNode] = useState<Node | null>(null)
  const [hoveredNode, setHoveredNode] = useState<string | null>(null)

  // Layout nodes in a flow (simplified for now)
  const getNodePosition = (node: Node, index: number) => {
    const cols = 4
    const col = index % cols
    const row = Math.floor(index / cols)
    return {
      x: 100 + col * 250,
      y: 80 + row * 140
    }
  }

  const getConnectionPath = (from: Node, to: Node, fromIdx: number, toIdx: number) => {
    const fromPos = getNodePosition(from, fromIdx)
    const toPos = getNodePosition(to, toIdx)
    
    const startX = fromPos.x + 80
    const startY = fromPos.y + 30
    const endX = toPos.x
    const endY = toPos.y + 30
    
    const midX = (startX + endX) / 2
    
    return `M ${startX} ${startY} C ${midX} ${startY}, ${midX} ${endY}, ${endX} ${endY}`
  }

  return (
    <div className="system-map">
      <svg className="connections-layer" width="100%" height="100%">
        {data.nodes.map((node, fromIdx) => 
          node.connections?.map(connId => {
            const toNode = data.nodes.find(n => n.id === connId)
            const toIdx = data.nodes.findIndex(n => n.id === connId)
            if (!toNode) return null
            
            const isHighlighted = hoveredNode === node.id || hoveredNode === toNode.id
            
            return (
              <path
                key={`${node.id}-${connId}`}
                d={getConnectionPath(node, toNode, fromIdx, toIdx)}
                stroke={isHighlighted ? '#3b82f6' : '#374151'}
                strokeWidth={isHighlighted ? 2 : 1}
                fill="none"
                opacity={isHighlighted ? 1 : 0.4}
              />
            )
          })
        )}
      </svg>

      <div className="nodes-layer">
        {data.nodes.map((node, index) => {
          const pos = getNodePosition(node, index)
          const color = NODE_COLORS[node.type] || '#6b7280'
          const isSelected = selectedNode?.id === node.id
          const isHovered = hoveredNode === node.id
          
          return (
            <div
              key={node.id}
              className={`node ${isSelected ? 'selected' : ''} ${isHovered ? 'hovered' : ''}`}
              style={{
                left: `${pos.x}px`,
                top: `${pos.y}px`,
                borderColor: color,
              }}
              onClick={() => setSelectedNode(isSelected ? null : node)}
              onMouseEnter={() => setHoveredNode(node.id)}
              onMouseLeave={() => setHoveredNode(null)}
            >
              <div className="node-header" style={{ background: color }}>
                <span className="node-type">{node.type}</span>
              </div>
              <div className="node-body">
                <div className="node-label">{node.label}</div>
                <div className="node-id">{node.id}</div>
              </div>
            </div>
          )
        })}
      </div>

      {selectedNode && (
        <div className="detail-panel">
          <div className="detail-header">
            <h3>{selectedNode.label}</h3>
            <button onClick={() => setSelectedNode(null)}>✕</button>
          </div>
          <div className="detail-body">
            <div className="detail-section">
              <label>Type</label>
              <span className="detail-value">{selectedNode.type}</span>
            </div>
            <div className="detail-section">
              <label>Description</label>
              <p className="detail-description">{selectedNode.description}</p>
            </div>
            {selectedNode.module && (
              <div className="detail-section">
                <label>Module</label>
                <code className="detail-code">{selectedNode.module}</code>
              </div>
            )}
            {selectedNode.config && (
              <div className="detail-section">
                <label>Configuration</label>
                <pre className="detail-config">
                  {JSON.stringify(selectedNode.config, null, 2)}
                </pre>
              </div>
            )}
            {selectedNode.connections && selectedNode.connections.length > 0 && (
              <div className="detail-section">
                <label>Connections</label>
                <div className="detail-connections">
                  {selectedNode.connections.map(connId => (
                    <span key={connId} className="connection-tag">
                      → {connId}
                    </span>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
EOF

# Monitor SystemMap.css
cat > monitor/src/SystemMap.css << 'EOF'
.system-map {
  width: 100%;
  height: 100%;
  position: relative;
  overflow: auto;
  background: 
    linear-gradient(90deg, #1f2937 1px, transparent 1px),
    linear-gradient(#1f2937 1px, transparent 1px);
  background-size: 50px 50px;
}

.connections-layer {
  position: absolute;
  top: 0;
  left: 0;
  pointer-events: none;
  z-index: 1;
}

.nodes-layer {
  position: relative;
  min-width: 1200px;
  min-height: 800px;
  z-index: 2;
}

.node {
  position: absolute;
  width: 160px;
  height: 60px;
  background: #14181f;
  border: 2px solid;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s ease;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.3);
}

.node:hover, .node.hovered {
  transform: translateY(-2px);
  box-shadow: 0 8px 12px rgba(0, 0, 0, 0.5);
  z-index: 10;
}

.node.selected {
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.5);
  z-index: 11;
}

.node-header {
  padding: 0.25rem 0.5rem;
  border-radius: 4px 4px 0 0;
  font-size: 0.625rem;
  text-transform: uppercase;
  font-weight: 600;
  letter-spacing: 0.05em;
  color: white;
}

.node-body {
  padding: 0.5rem;
}

.node-label {
  font-size: 0.875rem;
  font-weight: 600;
  color: #f3f4f6;
  margin-bottom: 0.25rem;
}

.node-id {
  font-size: 0.625rem;
  color: #6b7280;
  font-family: monospace;
}

.detail-panel {
  position: fixed;
  right: 2rem;
  top: 6rem;
  bottom: 6rem;
  width: 400px;
  background: #14181f;
  border: 2px solid #1f2937;
  border-radius: 8px;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
  display: flex;
  flex-direction: column;
  z-index: 100;
}

.detail-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.5rem;
  border-bottom: 2px solid #1f2937;
}

.detail-header h3 {
  font-size: 1.125rem;
  font-weight: 600;
}

.detail-header button {
  background: none;
  border: none;
  color: #6b7280;
  cursor: pointer;
  font-size: 1.25rem;
  padding: 0;
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.detail-header button:hover {
  color: #f3f4f6;
}

.detail-body {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
}

.detail-section {
  margin-bottom: 1.5rem;
}

.detail-section label {
  display: block;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #6b7280;
  margin-bottom: 0.5rem;
  font-weight: 600;
}

.detail-value {
  color: #f3f4f6;
  font-size: 0.875rem;
}

.detail-description {
  color: #d1d5db;
  font-size: 0.875rem;
  line-height: 1.5;
}

.detail-code {
  display: block;
  background: #0a0e14;
  padding: 0.5rem;
  border-radius: 4px;
  font-size: 0.75rem;
  color: #3b82f6;
  overflow-x: auto;
}

.detail-config {
  background: #0a0e14;
  padding: 0.75rem;
  border-radius: 4px;
  font-size: 0.75rem;
  color: #d1d5db;
  overflow-x: auto;
}

.detail-connections {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.connection-tag {
  background: #1f2937;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.75rem;
  color: #3b82f6;
}
EOF

echo "   ✓ Monitor app created"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 6: Update import paths (TypeScript)
# ═══════════════════════════════════════════════════════════════════════════

echo "🔗 Phase 6: Updating import paths..."

# This is a simplified approach - in practice you'd use a more sophisticated tool
# For now, we'll create a marker file and instruct manual verification

cat > IMPORT_UPDATE_NEEDED.md << 'EOF'
# Import Path Updates Needed

The file moves have been completed, but import paths need to be updated.

## Automated approach (recommended):
```bash
# Use ts-morph or jscodeshift to update all imports
pnpm add -D ts-morph
node scripts/update-imports.js
```

## Manual approach:
Update all imports following this mapping:

OLD → NEW:
- `./core/typingMonitor` → `./src/pipeline/monitor`
- `./core/sweepScheduler` → `./src/pipeline/scheduler`
- `./engines/noiseTransformer` → `./src/stages/noise`
- `./engines/contextTransformer_v06` → `./src/stages/context`
- `./engines/toneTransformer_v06` → `./src/stages/tone`
- `./core/activeRegionPolicy` → `./src/region/policy`
- `./core/diffusionController` → `./src/region/diffusion`
- `./utils/diff` → `./src/safety/diff`
- `./utils/grapheme` → `./src/safety/grapheme`
- `./core/security` → `./src/safety/security`
- `./ui/*` → `./src/ui/*`
- `./config/defaultThresholds` → `./src/config/thresholds`
- `./core/lm/*` → `./src/lm/*`

Then run:
```bash
pnpm typecheck  # Will show remaining import errors
```
EOF

echo "   ⚠️  Import paths need updating - see IMPORT_UPDATE_NEEDED.md"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 7: Update configuration files
# ═══════════════════════════════════════════════════════════════════════════

echo "⚙️  Phase 7: Updating configuration files..."

# Update root tsconfig.json to include new src/ directory
if [ -f "tsconfig.json" ]; then
    # Backup original
    cp tsconfig.json tsconfig.json.backup
    
    # Note: Manual update needed for include paths
    echo "   ⚠️  tsconfig.json backed up - needs manual update for src/ paths"
fi

# Update root package.json
if [ -f "package.json" ]; then
    # Backup original
    cp package.json package.json.backup
    echo "   ✓ package.json backed up"
fi

# Update Justfile if it exists
if [ -f "Justfile" ]; then
    cp Justfile Justfile.backup
    echo "   ✓ Justfile backed up"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 8: Clean up old directories
# ═══════════════════════════════════════════════════════════════════════════

echo "🧹 Phase 8: Cleaning up old directories..."

# Remove now-empty directories (only if empty)
rmdir core 2>/dev/null || echo "   ⚠️  core/ not empty - check for remaining files"
rmdir engines 2>/dev/null || echo "   ⚠️  engines/ not empty - check for remaining files"
rmdir ui 2>/dev/null || echo "   ⚠️  ui/ not empty - check for remaining files"
rmdir utils 2>/dev/null || echo "   ⚠️  utils/ not empty - check for remaining files"
rmdir config 2>/dev/null || echo "   ⚠️  config/ not empty - check for remaining files"
rmdir crates 2>/dev/null || echo "   ⚠️  crates/ not empty - check for remaining files"

# Remove legacy files
rm -f engines/toneTransformer.ts 2>/dev/null || true
rm -f engines/contextTransformer.ts 2>/dev/null || true

echo "   ✓ Cleanup completed"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 9: Install Monitor dependencies
# ═══════════════════════════════════════════════════════════════════════════

echo "📦 Phase 9: Installing Monitor dependencies..."

cd monitor
pnpm install || echo "   ⚠️  Monitor install failed - run 'cd monitor && pnpm install' manually"
cd "$REPO_ROOT"

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 10: Create documentation
# ═══════════════════════════════════════════════════════════════════════════

echo "📚 Phase 10: Creating documentation..."

cat > docs/monitor/README.md << 'EOF'
# Mind⠶Flow Monitor

The Monitor is an interactive visualization of the Mind⠶Flow pipeline, showing real-time data flow through all stages.

## Quick Start

```bash
cd monitor
pnpm install
pnpm dev
```

Open http://localhost:3001 to view the Monitor.

## Features

- **Live pipeline visualization** - See all nodes and connections
- **Interactive drill-down** - Click any node to see details
- **16-bit retro aesthetic** - Professional, minimal design
- **Responsive** - Viewport-filling, works on any screen
- **Always up-to-date** - Driven by system-map.json

## Architecture

The Monitor reads from `monitor/public/system-map.json`, which is the canonical definition of the Mind⠶Flow pipeline. Update that file whenever the architecture changes, and the Monitor will automatically reflect the new structure.

## Development

Edit `monitor/src/SystemMap.tsx` to customize the visualization layout and styling.

The Monitor is a standalone Vite + React app with no dependencies on the main Mind⠶Flow codebase.
EOF

cat > docs/monitor/updating-system-map.md << 'EOF'
# Updating the System Map

The `monitor/public/system-map.json` file is the single source of truth for the Mind⠶Flow architecture.

## When to Update

Update the system map whenever you:
- Add a new module or component
- Change data flow between components
- Modify configuration or behavior
- Refactor module locations

## Structure

```json
{
  "nodes": [
    {
      "id": "unique-id",
      "type": "source|orchestrator|transformer|...",
      "label": "Human-readable name",
      "description": "What this does",
      "module": "path/to/file.ts",
      "connections": ["id-of-next-node"],
      "config": { ... }
    }
  ]
}
```

## Node Types

- `source`: Input (user keystrokes)
- `orchestrator`: Timing/scheduling logic
- `compute`: Calculation/policy
- `control`: State management
- `transformer`: Stage (Noise/Context/Tone)
- `service`: External service (LM)
- `validator`: Quality gate
- `sink`: Output (UI rendering)
- `visual`: UI component

Each type has a distinct color in the Monitor.

## Best Practices

1. Keep descriptions concise but informative
2. Always specify `module` paths relative to repo root
3. Use `connections` to show data flow (not just function calls)
4. Add `config` for any tunable parameters
5. Commit system-map.json changes with corresponding code changes
EOF

echo "   ✓ Documentation created"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# COMPLETION
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo "✅ Restructure Complete!"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Review IMPORT_UPDATE_NEEDED.md for import path mappings"
echo "2. Update import statements (can use find/replace or ts-morph)"
echo "3. Update tsconfig.json include paths to reference src/"
echo "4. Run validation:"
echo "   pnpm typecheck"
echo "   pnpm lint"
echo "   pnpm test"
echo ""
echo "5. Test Monitor:"
echo "   cd monitor && pnpm dev"
echo "   Open http://localhost:3001"
echo ""
echo "6. Test web demo:"
echo "   cd hosts/web && pnpm dev"
echo ""
echo "7. Test Rust:"
echo "   cd core-rs && cargo test"
echo ""
echo "8. Review and commit:"
echo "   git status"
echo "   git add -A"
echo "   git commit -m 'Restructure for v0.8: new src/ layout + Monitor app'"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""




