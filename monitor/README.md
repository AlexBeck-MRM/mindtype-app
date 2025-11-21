# Mind⠶Flow Monitor 📊

**Interactive pipeline visualization** with retro 16-bit aesthetic.

![Version](https://img.shields.io/badge/version-0.8.0-purple)
![Status](https://img.shields.io/badge/status-live-green)
![Tech](https://img.shields.io/badge/tech-React%20%2B%20Vite-blue)

---

## What Is This?

The Monitor is a **live visual representation** of the Mind⠶Flow pipeline—think of it as looking inside the machine while it's running.

### Features

- **Interactive Node Graph**: See all 14 pipeline components with type-coded colors
- **Drill-Down Details**: Click any node to view module path, configuration, and connections
- **Live Data Flow**: Hover connections to highlight the data path
- **Real-Time Telemetry**: Dev-only SSE bridge pulses nodes as diagBus events stream from the web demo
- **Retro Aesthetic**: Dark terminal theme with grid background and 16-bit styling
- **Always Current**: Driven by `system-map.json` which stays in sync with code
- **Responsive Design**: Viewport-filling, works on any screen size

---

## Quick Start

```bash
# From repo root
pnpm monitor

# Or from monitor/ directory
cd monitor
pnpm install
pnpm dev
```

→ Open http://localhost:3001

---

## How It Works

### System Map (Source of Truth)

The Monitor reads from `public/system-map.json`, which defines:

- **Nodes**: All pipeline components (input, stages, LM, output)
- **Connections**: Data flow between components
- **Config**: Runtime parameters for each component
- **Metadata**: Version, architecture description, principles

### Node Types & Colors

| Type           | Color        | Purpose                              |
| -------------- | ------------ | ------------------------------------ |
| `source`       | Blue         | User input capture                   |
| `orchestrator` | Purple       | Timing/scheduling logic              |
| `compute`      | Cyan         | Calculation/policy                   |
| `control`      | Green        | State management                     |
| `transformer`  | Amber        | Pipeline stages (Noise/Context/Tone) |
| `service`      | Pink         | External services (LM)               |
| `validator`    | Teal         | Quality gates                        |
| `sink`         | Indigo       | Output rendering                     |
| `visual`       | Purple-light | UI components                        |

### Interaction

- **Click node**: Opens detail panel showing:
  - Module path (e.g., `src/stages/noise.ts`)
  - Configuration (e.g., token caps, thresholds)
  - Connections (which components it talks to)
- **Hover node**: Highlights all connected paths
- **Scroll/Pan**: Navigate the full graph

### Live Telemetry (Dev Mode)

1. Start the web demo: `pnpm demo:web`
2. (Optional) Verify the SSE relay with `pnpm diag:smoke`
3. Launch the Monitor (`pnpm monitor`) and watch Noise/Context/LM nodes glow as diagBus events arrive
4. Telemetry is dev-only; production builds fall back to the static system map

---

## Development

### Project Structure

```
monitor/
├── src/
│   ├── App.tsx           # Main app shell (header, footer, error handling)
│   ├── SystemMap.tsx     # Node graph visualization logic
│   ├── App.css           # App-level styling
│   ├── SystemMap.css     # Graph styling (nodes, connections, panels)
│   ├── index.css         # Global resets
│   └── main.tsx          # React entry point
├── public/
│   └── system-map.json   # Canonical pipeline definition
├── index.html
├── package.json
├── vite.config.ts
└── tsconfig.json
```

### Customizing the Visualization

#### Layout

Edit `SystemMap.tsx` → `getNodePosition()` to change node placement:

```typescript
const getNodePosition = (node: Node, index: number) => {
  const cols = 4; // Nodes per row
  const col = index % cols;
  const row = Math.floor(index / cols);
  return {
    x: 100 + col * 250, // Horizontal spacing
    y: 80 + row * 140, // Vertical spacing
  };
};
```

#### Styling

Edit `SystemMap.css` for colors, sizes, animations:

```css
.node {
  width: 160px;
  height: 60px;
  border-radius: 6px;
  /* Customize appearance */
}
```

#### Node Colors

Edit `NODE_COLORS` constant in `SystemMap.tsx`:

```typescript
const NODE_COLORS: Record<string, string> = {
  source: '#3b82f6', // Blue
  transformer: '#f59e0b', // Amber
  // ...add more types
};
```

---

## Updating the System Map

When you add/modify pipeline components:

### 1. Edit `public/system-map.json`

```json
{
  "nodes": [
    {
      "id": "my-component",
      "type": "transformer",
      "label": "My Component",
      "description": "What it does",
      "module": "src/stages/myComponent.ts",
      "connections": ["next-component"],
      "config": {
        "someParam": 42
      }
    }
  ]
}
```

### 2. Commit with Code Changes

```bash
git add monitor/public/system-map.json src/stages/myComponent.ts
git commit -m "Add MyComponent stage"
```

### 3. Refresh Monitor

The Monitor hot-reloads automatically—refresh browser to see updates.

---

## Deployment

### Production Build

```bash
cd monitor
pnpm build
```

Output goes to `dist/` — serve with any static host.

### Hosting Options

- **Local**: Run `pnpm preview` after build
- **Static host**: Deploy `dist/` to Netlify/Vercel/GitHub Pages
- **Docs site**: Embed as iframe in main documentation

---

## Troubleshooting

### Monitor Shows Blank Screen

**Cause**: `system-map.json` not found or invalid  
**Fix**: Check `monitor/public/system-map.json` exists and is valid JSON

### Nodes Overlap

**Cause**: Too many nodes for current layout  
**Fix**: Increase spacing in `getNodePosition()` or switch to force-directed layout

### Build Fails

**Cause**: Missing dependencies  
**Fix**: Run `pnpm install` in monitor/ directory

### Hot Reload Not Working

**Cause**: Vite dev server issue  
**Fix**: Stop (Ctrl+C) and restart `pnpm dev`

---

## Design Philosophy

The Monitor embodies Mind⠶Flow principles:

- **Minimalist**: Shows only essential information
- **Professional**: Retro aesthetic without gimmicks
- **Accessible**: High contrast, clear labels, keyboard navigable
- **Accurate**: Always synced with actual code via system-map.json
- **Explorable**: Drill down from overview to implementation details

It turns abstract architecture into something you can **see, click, and understand**.

---

## Future Enhancements

Potential additions (not in v0.8 scope):

- **Performance metrics**: Show latency, throughput per node
- **Time travel**: Replay past correction waves
- **Diff view**: Show before/after for each stage
- **Export**: Generate diagrams for docs/presentations

---

## Technical Details

- **Framework**: React 18 + TypeScript
- **Build**: Vite 5 (fast HMR, optimized production builds)
- **Styling**: Vanilla CSS (no framework overhead)
- **Data**: JSON-driven (easy to generate/update programmatically)
- **Size**: ~150KB gzipped (production build)
- **Performance**: 60 FPS rendering, <200ms initial load

---

## Contributing

When adding features to Mind⠶Flow:

1. Update the code
2. Update `monitor/public/system-map.json` with new nodes/connections
3. Commit both together
4. Monitor reflects changes immediately

This keeps architecture documentation **always current** without manual diagram updates.

---

**The Monitor is your window into Mind⠶Flow's cognitive engine.**

Use it to understand, debug, and demonstrate how thought flows through the pipeline.

<!-- DOC META: VERSION=1.1 | UPDATED=2025-11-20T19:05:00Z -->
