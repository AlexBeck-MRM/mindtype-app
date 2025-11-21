import { useState } from 'react';
import './SystemMap.css';

interface Node {
  id: string;
  type: string;
  label: string;
  description: string;
  module?: string;
  connections?: string[];
  config?: Record<string, unknown>;
}

interface SystemMapProps {
  data: {
    nodes: Node[];
    hosts: Array<{
      id: string;
      label: string;
      path: string;
      description: string;
    }>;
  };
  liveActivity?: Record<string, number>;
}

const NODE_COLORS: Record<string, string> = {
  source: '#3b82f6', // Blue
  orchestrator: '#8b5cf6', // Purple
  compute: '#06b6d4', // Cyan
  control: '#10b981', // Green
  transformer: '#f59e0b', // Amber
  service: '#ec4899', // Pink
  validator: '#14b8a6', // Teal
  sink: '#6366f1', // Indigo
  visual: '#a855f7', // Purple-light
};

export default function SystemMap({ data, liveActivity }: SystemMapProps) {
  const [selectedNode, setSelectedNode] = useState<Node | null>(null);
  const [hoveredNode, setHoveredNode] = useState<string | null>(null);
  const now = Date.now();

  // Left-to-right flow ordering based on pipeline sequence
  // Each array represents a column, nodes in same array are vertically stacked
  const FLOW_ORDER: string[][] = [
    ['input'], // Column 0: Input
    ['scheduler'], // Column 1: Scheduler
    ['region-policy', 'correction-wave'], // Column 2: Policy & Wave orchestrator
    ['diffusion'], // Column 3: Diffusion controller
    ['stage-noise', 'stage-context', 'stage-tone'], // Column 4: Three stages (stacked)
    ['lm-adapter'], // Column 5: LM service (can be positioned vertically)
    ['confidence-gate'], // Column 6: Confidence gate
    ['ui-render'], // Column 7: UI rendering
    ['correction-marker', 'highlighter', 'rollback'], // Column 8: Visual components
  ];

  // Build a map of node ID to position
  const nodePositions = new Map<string, { x: number; y: number }>();
  const COLUMN_SPACING = 280;
  const ROW_SPACING = 100;
  const START_X = 100;
  const START_Y = 80;

  FLOW_ORDER.forEach((columnNodes, colIndex) => {
    columnNodes.forEach((nodeId, rowIndex) => {
      const node = data.nodes.find((n) => n.id === nodeId);
      if (node) {
        nodePositions.set(nodeId, {
          x: START_X + colIndex * COLUMN_SPACING,
          y: START_Y + rowIndex * ROW_SPACING,
        });
      }
    });
  });

  // Handle any nodes not in FLOW_ORDER (fallback to right side)
  let fallbackCol = FLOW_ORDER.length;
  data.nodes.forEach((node) => {
    if (!nodePositions.has(node.id)) {
      nodePositions.set(node.id, {
        x: START_X + fallbackCol * COLUMN_SPACING,
        y: START_Y,
      });
      fallbackCol++;
    }
  });

  const getNodePosition = (node: Node) => {
    return nodePositions.get(node.id) || { x: START_X, y: START_Y };
  };

  const getConnectionPath = (from: Node, to: Node) => {
    const fromPos = getNodePosition(from);
    const toPos = getNodePosition(to);

    const startX = fromPos.x + 160; // Right edge of source node
    const startY = fromPos.y + 30; // Middle of source node
    const endX = toPos.x; // Left edge of target node
    const endY = toPos.y + 30; // Middle of target node

    const midX = (startX + endX) / 2;

    return `M ${startX} ${startY} C ${midX} ${startY}, ${midX} ${endY}, ${endX} ${endY}`;
  };

  return (
    <div className="system-map">
      <svg className="connections-layer" width="100%" height="100%">
        {data.nodes.map((node) =>
          node.connections?.map((connId) => {
            const toNode = data.nodes.find((n) => n.id === connId);
            if (!toNode) return null;

            const isHighlighted = hoveredNode === node.id || hoveredNode === toNode.id;

            return (
              <path
                key={`${node.id}-${connId}`}
                d={getConnectionPath(node, toNode)}
                stroke={isHighlighted ? '#3b82f6' : '#374151'}
                strokeWidth={isHighlighted ? 2 : 1}
                fill="none"
                opacity={isHighlighted ? 1 : 0.4}
              />
            );
          }),
        )}
      </svg>

      <div className="nodes-layer">
        {data.nodes.map((node) => {
          const pos = getNodePosition(node);
          const color = NODE_COLORS[node.type] || '#6b7280';
          const isSelected = selectedNode?.id === node.id;
          const isHovered = hoveredNode === node.id;
          const liveTs = liveActivity?.[node.id];
          const isLive = typeof liveTs === 'number' && now - liveTs < 2500;

          return (
            <div
              key={node.id}
              className={`node ${isSelected ? 'selected' : ''} ${isHovered ? 'hovered' : ''} ${
                isLive ? 'live' : ''
              }`}
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
          );
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
                  {selectedNode.connections.map((connId) => (
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
  );
}
