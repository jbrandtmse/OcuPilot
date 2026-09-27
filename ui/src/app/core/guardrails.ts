/**
 * The Guardrails page over `/api/ocupilot/ui/guardrails` (Story 16.22): the store, the narrowing of
 * its answer, and the pure helpers that turn the answer into the page's lines.
 *
 * **Every rule is the instance's.** The refused list and its sentences, the tools that need a
 * Confirm, their secret arguments, the switches and the limits all arrive in the answer; this
 * client holds no copy of any refusal sentence and decides nothing (AD-10, AD-30). A malformed
 * answer counts as a failed read.
 *
 * **Its own caller-own chrome read.** The page loads it when it opens. It fails closed: a read that
 * does not answer drops any earlier answer and raises `failed()`, so the page shows no section
 * rather than a stale one. Only the newest read settles, and `reset()` drops a departed
 * principal's answer.
 *
 * Framework-free, like the rest of `core/` (AD-19).
 */

import type { ApiService, JsonResult } from './api';
import { STRINGS } from './strings.ts';

/** Absolute from the origin root, through the one API service (AD-20). */
export const GUARDRAILS_PATH = '/api/ocupilot/ui/guardrails';

/** Between a tool's name and its secret fields on the secret list, and between the fields. */
export const TOOL_FIELDS_SEPARATOR = ': ';

export const FIELDS_SEPARATOR = ', ';

export interface ProhibitedRow {
  readonly code: string;
  readonly reason: string;
}

export interface GuardrailsSwitches {
  readonly killSwitch: boolean;
  /** `everyone`, `you` or `''`. */
  readonly killSwitchAudience: string;
  readonly enforcedReadOnly: boolean;
}

export interface ConfirmTool {
  readonly name: string;
  /** The descriptor class the tool writes for, or `''`. */
  readonly descriptor: string;
}

export interface SecretTool {
  readonly tool: string;
  readonly fields: readonly string[];
}

export interface GuardrailsLimits {
  readonly contextRowCap: number;
  readonly totalMaxLength: number;
  readonly fieldMaxLength: number;
}

export interface GuardrailsAnswer {
  readonly prohibited: readonly ProhibitedRow[];
  readonly switches: GuardrailsSwitches;
  readonly confirmTools: readonly ConfirmTool[];
  readonly secrets: readonly SecretTool[];
  readonly limits: GuardrailsLimits;
}

/** One group of the Confirm section: a screen's label, or `null` for the tools with no screen. */
export interface ConfirmGroup {
  readonly key: string;
  readonly label: string | null;
  readonly tools: readonly string[];
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

function strings(value: unknown): string[] | null {
  if (!Array.isArray(value)) return null;
  const out: string[] = [];
  for (const entry of value) {
    if (typeof entry !== 'string') return null;
    out.push(entry);
  }
  return out;
}

function wholeNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0 ? value : null;
}

/** The answer, or `null` for anything that is not one. */
export function narrowGuardrails(body: unknown): GuardrailsAnswer | null {
  const root = record(body);
  if (root === null) return null;

  if (!Array.isArray(root['prohibited'])) return null;
  const prohibited: ProhibitedRow[] = [];
  for (const entry of root['prohibited']) {
    const row = record(entry);
    if (row === null || typeof row['code'] !== 'string' || typeof row['reason'] !== 'string') return null;
    prohibited.push({ code: row['code'], reason: row['reason'] });
  }

  const switchesRow = record(root['switches']);
  if (
    switchesRow === null ||
    typeof switchesRow['killSwitch'] !== 'boolean' ||
    typeof switchesRow['killSwitchAudience'] !== 'string' ||
    typeof switchesRow['enforcedReadOnly'] !== 'boolean'
  ) {
    return null;
  }
  const switches: GuardrailsSwitches = {
    killSwitch: switchesRow['killSwitch'],
    killSwitchAudience: switchesRow['killSwitchAudience'],
    enforcedReadOnly: switchesRow['enforcedReadOnly'],
  };

  if (!Array.isArray(root['confirmTools'])) return null;
  const confirmTools: ConfirmTool[] = [];
  for (const entry of root['confirmTools']) {
    const row = record(entry);
    if (row === null || typeof row['name'] !== 'string' || typeof row['descriptor'] !== 'string') return null;
    confirmTools.push({ name: row['name'], descriptor: row['descriptor'] });
  }

  if (!Array.isArray(root['secrets'])) return null;
  const secrets: SecretTool[] = [];
  for (const entry of root['secrets']) {
    const row = record(entry);
    const fields = row === null ? null : strings(row['fields']);
    if (row === null || typeof row['tool'] !== 'string' || fields === null) return null;
    secrets.push({ tool: row['tool'], fields });
  }

  const limitsRow = record(root['limits']);
  if (limitsRow === null) return null;
  const contextRowCap = wholeNumber(limitsRow['contextRowCap']);
  const totalMaxLength = wholeNumber(limitsRow['totalMaxLength']);
  const fieldMaxLength = wholeNumber(limitsRow['fieldMaxLength']);
  if (contextRowCap === null || totalMaxLength === null || fieldMaxLength === null) return null;

  return { prohibited, switches, confirmTools, secrets, limits: { contextRowCap, totalMaxLength, fieldMaxLength } };
}

/**
 * The Confirm section's groups: the tools grouped by descriptor in first-appearance order, each
 * headed by `lookup(descriptor)`, the screen's label. The tools whose descriptor `lookup` cannot
 * name go last, in one group with no heading.
 */
export function confirmGroups(
  tools: readonly ConfirmTool[],
  lookup: (descriptor: string) => string | null
): ConfirmGroup[] {
  const groups = new Map<string, { label: string; tools: string[] }>();
  const unnamed: string[] = [];
  for (const tool of tools) {
    const label = tool.descriptor === '' ? null : lookup(tool.descriptor);
    if (label === null || label === '') {
      unnamed.push(tool.name);
      continue;
    }
    const group = groups.get(tool.descriptor);
    if (group === undefined) groups.set(tool.descriptor, { label, tools: [tool.name] });
    else group.tools.push(tool.name);
  }
  const out: ConfirmGroup[] = [...groups.entries()].map(([descriptor, group]) => ({
    key: descriptor,
    label: group.label,
    tools: group.tools,
  }));
  if (unnamed.length > 0) out.push({ key: '', label: null, tools: unnamed });
  return out;
}

/** The kill-switch line for the caller's verdict. */
export function killSwitchLine(switches: GuardrailsSwitches): string {
  if (!switches.killSwitch) return STRINGS.agentGuardrailsKillSwitchOff;
  return switches.killSwitchAudience === 'you'
    ? STRINGS.agentGuardrailsKillSwitchYou
    : STRINGS.agentGuardrailsKillSwitchEveryone;
}

/** The enforced read-only line. */
export function readOnlyLine(switches: GuardrailsSwitches): string {
  return switches.enforcedReadOnly ? STRINGS.agentGuardrailsReadOnlyOn : STRINGS.agentGuardrailsReadOnlyOff;
}

const GROUPED = new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 });

/** The limits line, each number grouped en-US. */
export function limitsLine(limits: GuardrailsLimits): string {
  return STRINGS.agentGuardrailsContextLimits.split('<rows>')
    .join(GROUPED.format(limits.contextRowCap))
    .split('<total>')
    .join(GROUPED.format(limits.totalMaxLength))
    .split('<field>')
    .join(GROUPED.format(limits.fieldMaxLength));
}

export interface GuardrailsOptions {
  readonly api: ApiService;
}

export class Guardrails {
  private readonly api: ApiService;

  private dataValue: GuardrailsAnswer | null = null;

  private failedValue = false;

  private loadingValue = false;

  /** Bumped by `reset()`, so an answer for a departed principal never lands (AD-8). */
  private generation = 0;

  /** Bumped by every `load()`, so only the newest settles. */
  private request = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: GuardrailsOptions) {
    this.api = options.api;
  }

  /** The last answer, or `null` before the first. */
  data(): GuardrailsAnswer | null {
    return this.dataValue;
  }

  /** Whether the most recent read did not answer. Cleared by the next one that does. */
  failed(): boolean {
    return this.failedValue;
  }

  /** Whether a read is in flight. */
  loading(): boolean {
    return this.loadingValue;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Read the guardrails. A read that does not answer leaves no answer. */
  async load(): Promise<void> {
    const generation = this.generation;
    const request = (this.request += 1);
    this.loadingValue = true;
    this.notify();
    const result: JsonResult<unknown> = await this.api.requestJson<unknown>(GUARDRAILS_PATH);
    if (generation !== this.generation || request !== this.request) return;
    this.loadingValue = false;
    const answer = result.kind === 'ok' ? narrowGuardrails(result.body) : null;
    if (answer === null) {
      this.dataValue = null;
      this.failedValue = true;
    } else {
      this.dataValue = answer;
      this.failedValue = false;
    }
    this.notify();
  }

  /** Forget the answer, so a sign-out leaves nothing of the departed principal's. */
  reset(): void {
    this.generation += 1;
    this.request += 1;
    this.dataValue = null;
    this.failedValue = false;
    this.loadingValue = false;
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
