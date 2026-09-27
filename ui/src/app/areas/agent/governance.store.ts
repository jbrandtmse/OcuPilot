import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { FormDirty } from '../../core/form-dirty';
import {
  STATE_CONFLICT_CODE,
  type Violation,
  reasonForField,
  violationsOf,
} from '../../core/violations';

/** The governance policy's route, absolute from the origin root (AD-20). */
export const GOVERNANCE_PATH = '/api/ocupilot/agent/governance';

/** The three presets, in the order the radio group lays them out; `''` is none. */
export const GOVERNANCE_PRESETS = ['', 'read-only', 'full'] as const;

/** The three settings a key takes, in the order the select lists them. */
export const GOVERNANCE_SETTINGS = ['inherit', 'enabled', 'disabled'] as const;

export type GovernancePreset = (typeof GOVERNANCE_PRESETS)[number];

export type GovernanceSetting = (typeof GOVERNANCE_SETTINGS)[number];

/** Where a key's value comes from, as the instance resolves it. */
export type GovernanceSource = 'setting' | 'preset' | 'baseline';

/** What the baseline lists for a key. */
export type GovernanceBaseline = 'enabled' | 'disabled' | 'absent';

/** One write key, as the read answers it. */
export interface GovernanceKeyRow {
  readonly key: string;
  readonly baseline: GovernanceBaseline;
  readonly setting: GovernanceSetting;
  readonly enabled: boolean;
  readonly source: GovernanceSource;
}

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : '';
}

function asPreset(value: string): GovernancePreset {
  return (GOVERNANCE_PRESETS as readonly string[]).includes(value) ? (value as GovernancePreset) : '';
}

function asSetting(value: string): GovernanceSetting {
  return (GOVERNANCE_SETTINGS as readonly string[]).includes(value)
    ? (value as GovernanceSetting)
    : 'inherit';
}

function asBaseline(value: string): GovernanceBaseline {
  return value === 'enabled' || value === 'disabled' ? value : 'absent';
}

function asSource(value: string): GovernanceSource {
  return value === 'setting' || value === 'preset' ? value : 'baseline';
}

/** The key rows a read carries, in the order the instance answers them. */
export function keysOf(body: unknown): readonly GovernanceKeyRow[] {
  if (body === null || typeof body !== 'object') return [];
  const rows = (body as Record<string, unknown>)['keys'];
  if (!Array.isArray(rows)) return [];
  return rows
    .filter((row): row is Record<string, unknown> => row !== null && typeof row === 'object')
    .map((row) => ({
      key: textAt(row, 'key'),
      baseline: asBaseline(textAt(row, 'baseline')),
      setting: asSetting(textAt(row, 'setting')),
      enabled: row['enabled'] === true,
      source: asSource(textAt(row, 'source')),
    }))
    .filter((row) => row.key !== '');
}

/**
 * The Governance policy screen's own state (AD-19): the preset and each key's setting as stored,
 * the edit buffer over them, the row version they were read at, and the one write, Save.
 *
 * **Everything on screen is rendered from a response body**, the rule `switches.store.ts` records:
 * what a key's setting does is the instance's answer after the save, never the buffer's guess.
 *
 * **It enforces nothing.** Whether a call is allowed is `OcuPilot.Kernel.Governance.Gate`'s alone
 * (AD-22); this screen changes what that gate reads.
 *
 * **Every refusal sentence is the server's** (AD-39), and a save carries the row version this
 * screen read (Consistency Conventions: concurrent writes), so a stale save is refused again until
 * a reload takes a version that matches.
 */
@Injectable({ providedIn: 'root' })
export class GovernanceStore {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private loadedValue = false;

  private savingValue = false;

  private savedValue = false;

  private presetValue: GovernancePreset = '';

  private rowsValue: readonly GovernanceKeyRow[] = [];

  /** The edit buffer: one setting per key, seeded from each read. */
  private settings: Readonly<Record<string, GovernanceSetting>> = {};

  private rowVersionValue: number | null = null;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  /** Bumped per issued request, so a late answer to a screen the user has left is dropped. */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  saving(): boolean {
    return this.savingValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  preset(): GovernancePreset {
    return this.presetValue;
  }

  rows(): readonly GovernanceKeyRow[] {
    return this.rowsValue;
  }

  /** The buffered setting for `key`. */
  setting(key: string): GovernanceSetting {
    return this.settings[key] ?? 'inherit';
  }

  violations(): readonly Violation[] {
    return this.violationList;
  }

  /** The refusal sentence for one field, or `''`. */
  violationFor(field: string): string {
    return reasonForField(this.violationList, field);
  }

  /** The envelope's own `reason` for the last refusal that was not field-level, or `''`. */
  reason(): string {
    return this.envelopeReason;
  }

  refusalCode(): string {
    return this.refusalCodeValue;
  }

  refusalPair(): string {
    return this.refusalPairValue;
  }

  /** Whether the last refusal was a stale save. */
  conflicted(): boolean {
    return this.refusalCodeValue === STATE_CONFLICT_CODE;
  }

  /** Forget everything, from the sign-out teardown and when the screen is left. */
  reset(): void {
    this.generation += 1;
    this.loadedValue = false;
    this.savingValue = false;
    this.savedValue = false;
    this.presetValue = '';
    this.rowsValue = [];
    this.settings = {};
    this.rowVersionValue = null;
    this.violationList = [];
    this.clearRefusal();
    this.formDirty.reset();
    this.notify();
  }

  /** Read the policy. */
  async open(): Promise<void> {
    this.reset();
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(GOVERNANCE_PATH);
    if (generation !== this.generation) return;
    this.absorbAnswer(result);
    this.notify();
  }

  /** Choose a preset. */
  setPreset(value: GovernancePreset): void {
    if (this.presetValue === value) return;
    this.presetValue = value;
    this.clearFieldViolation('preset');
    this.edited();
  }

  /** Choose one key's setting. */
  setSetting(key: string, value: GovernanceSetting): void {
    if (this.setting(key) === value) return;
    this.settings = { ...this.settings, [key]: value };
    this.clearFieldViolation(`settings.${key}`);
    this.edited();
  }

  /** Save the preset and every key's setting, and render the answer in place of what was sent. */
  async save(): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    this.savingValue = true;
    this.savedValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.notify();

    const result = await this.api().requestJson<unknown>(GOVERNANCE_PATH, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(this.body()),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (!this.absorbAnswer(result)) {
      this.notify();
      return false;
    }
    this.savedValue = true;
    this.formDirty.setDirty(false);
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private edited(): void {
    this.savedValue = false;
    this.formDirty.setDirty(true);
    this.notify();
  }

  /** The whole body the route accepts: the preset, every key's setting, and the version read. */
  private body(): Record<string, unknown> {
    const settings: Record<string, GovernanceSetting> = {};
    for (const row of this.rowsValue) settings[row.key] = this.setting(row.key);
    return { preset: this.presetValue, settings, rowVersion: this.rowVersionValue ?? 0 };
  }

  private clearFieldViolation(field: string): void {
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
  }

  private absorbAnswer(result: JsonResult<unknown>): boolean {
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason =
        this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      if (result.kind === 'error') {
        this.refusalCodeValue = result.code ?? '';
        const pair = result.detail === null ? undefined : result.detail['failedPair'];
        this.refusalPairValue = typeof pair === 'string' ? pair : '';
      }
      return false;
    }
    const body = result.body;
    this.presetValue = asPreset(textAt(body, 'preset'));
    this.rowsValue = keysOf(body);
    const next: Record<string, GovernanceSetting> = {};
    for (const row of this.rowsValue) next[row.key] = row.setting;
    this.settings = next;
    const version =
      body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['rowVersion'] : null;
    this.rowVersionValue = typeof version === 'number' ? version : null;
    this.loadedValue = true;
    return true;
  }

  private clearRefusal(): void {
    this.envelopeReason = '';
    this.refusalCodeValue = '';
    this.refusalPairValue = '';
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
