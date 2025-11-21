/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  P R O M P T   B U I L D E R  ░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Constructs disciplined prompts so the LM returns           ║
  ║   deterministic JSON with the corrected text.                ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Build system/user instructions + response format
  • WHY  ▸ Keep corrections scoped + machine-parsable
  • HOW  ▸ JSON contract {"replacement":"..."}
*/

export type CorrectionStage = 'noise' | 'context' | 'tone';

export interface PromptOptions {
  stage: CorrectionStage;
  text: string;
  activeRegion: { start: number; end: number };
  contextBefore?: string;
  contextAfter?: string;
  toneTarget?: 'Casual' | 'Professional';
}

interface StageConfig {
  title: string;
  scope: string;
  rules: string[];
}

const STAGE_CONFIG: Record<CorrectionStage, StageConfig> = {
  noise: {
    title: 'typo + spelling correction assistant',
    scope:
      'Fix only misspellings, repeated letters, stray punctuation, or accidental spacing within the highlighted fragment.',
    rules: [
      'Never change grammar, sentence order, or meaning.',
      'Preserve capitalization unless it is clearly incorrect.',
      'Keep whitespace identical unless it is a typo (double space, missing space, etc.).',
    ],
  },
  context: {
    title: 'grammar + clarity assistant',
    scope:
      'Improve grammar, agreement, and readability while preserving the author’s intent and tone.',
    rules: [
      'Do not introduce new facts or ideas.',
      'Keep idioms and stylistic choices unless they are clearly wrong.',
      'Prefer minimal edits over rewrites.',
    ],
  },
  tone: {
    title: 'tone adjustment assistant',
    scope: 'Rephrase to match the requested tone while keeping the meaning identical.',
    rules: [
      'Do not simplify technical terms unless required for tone.',
      'Never add hedging or commentary unless tone explicitly demands it.',
      'Maintain sentence boundaries unless restructuring is essential.',
    ],
  },
};

const JSON_CONTRACT =
  'Respond with valid JSON ONLY: {"replacement":"<corrected text>"} (double quotes, UTF-8).';

const EXAMPLE_JSON = '{"replacement":"the corrected sentence"}';

export function buildCorrectionPrompt(options: PromptOptions): string {
  const { stage, text, activeRegion, contextBefore, contextAfter, toneTarget } = options;
  const config = STAGE_CONFIG[stage];
  const snippet = text.slice(activeRegion.start, activeRegion.end);

  const before = contextBefore ? truncateContext(contextBefore, 'before') : '';
  const after = contextAfter ? truncateContext(contextAfter, 'after') : '';

  const toneLine =
    stage === 'tone'
      ? `Target tone: ${toneTarget ?? 'Professional'}.`
      : 'Target tone: preserve original.';

  function bulletList(items: string[]): string {
    return items.map((rule) => `- ${rule}`).join('\n');
  }

  return [
    `You are a ${config.title}.`,
    config.scope,
    toneLine,
    '',
    'Rules:',
    bulletList(config.rules),
    '- If no corrections are necessary, return the original fragment exactly.',
    '',
    'Response format:',
    `- ${JSON_CONTRACT}`,
    `- Example: ${EXAMPLE_JSON}`,
    '',
    'Fragment to correct (between <text> tags):',
    `<text>${escapeForPrompt(snippet)}</text>`,
    before ? `Context before: ${before}` : 'Context before: ""',
    after ? `Context after: ${after}` : 'Context after: ""',
    '',
    'Return ONLY the JSON object. Do not wrap it in code fences or commentary.',
  ].join('\n');
}

export function buildTestPrompt(inputText: string): string {
  return [
    'Fix the following fragment as the noise stage would.',
    JSON_CONTRACT,
    'Fragment:',
    `"${escapeForPrompt(inputText)}"`,
  ].join('\n');
}

export function extractReplacementText(raw: string): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  const firstBrace = trimmed.indexOf('{');
  const lastBrace = trimmed.lastIndexOf('}');
  if (firstBrace === -1 || lastBrace === -1 || lastBrace <= firstBrace) return null;
  const candidate = trimmed.slice(firstBrace, lastBrace + 1);
  try {
    const parsed = JSON.parse(candidate);
    if (parsed && typeof parsed.replacement === 'string') {
      return parsed.replacement;
    }
  } catch {
    return null;
  }
  return null;
}

function truncateContext(ctx: string, position: 'before' | 'after'): string {
  const slice = position === 'before' ? ctx.slice(-80) : ctx.slice(0, 80);
  return `"${escapeForPrompt(slice)}"`;
}

function escapeForPrompt(value: string): string {
  return value.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}

