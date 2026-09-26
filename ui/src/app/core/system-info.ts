/**
 * The instance state Home's System Information panel reports, over
 * `/api/ocupilot/ui/system` (Story 15.4, FR-73).
 *
 * **Its own caller-own chrome read, and it carries the shell's namespace.** Production status is
 * per namespace, and the router resolves and validates `?ns=` and stashes it as the request's
 * scope for the handler to read (AD-44) -- so this call passes no scope override and lets
 * `ApiService` attach whatever the shell is scoped to. A `scope: null` here would ask the instance
 * about the install namespace whatever the user is looking at.
 *
 * **A transport failure never clears what was answered.** A read that does not answer leaves the
 * previous values standing and raises `failed()`, so the panel shows what it last heard rather
 * than emptying itself; a panel that has never had an answer shows its error state instead. A
 * read a later one overtook settles nothing either -- `request` is what makes "only the newest
 * answer wins" a property of this store rather than of whichever response happened to arrive
 * last, the shape `about.ts` and `agent-status.ts` use for the same hazard.
 *
 * **No timer.** The panel settles with this one read and Home is not on AD-43's auto-refresh
 * roster; nothing here schedules a second call.
 *
 * Framework-free, like the rest of `core/` (AD-19), so `ui/tools/system-info.test.mjs` executes
 * it under `node --test`.
 */

import type { ApiService, JsonResult } from './api';

/** Absolute from the origin root, through the one API service (AD-20). */
export const SYSTEM_INFO_PATH = '/api/ocupilot/ui/system';

/**
 * The seven scalar members the read answers, in the order the panel lists them. Held as a list so
 * the panel renders what the wire carries rather than a second hand-kept order.
 */
export const SYSTEM_INFO_FIELDS = [
  'uptime',
  'mirror',
  'databaseSpace',
  'journalSpace',
  'lockTable',
  'writeDaemon',
  'production',
] as const;

export type SystemInfoField = (typeof SYSTEM_INFO_FIELDS)[number];

export type SystemInfoFields = Readonly<Record<SystemInfoField, string>>;

export interface SystemInfoOptions {
  readonly api: ApiService;
}

function emptyFields(): SystemInfoFields {
  const out: Record<string, string> = {};
  for (const field of SYSTEM_INFO_FIELDS) out[field] = '';
  return out as SystemInfoFields;
}

/**
 * One string off an answered body.
 *
 * Narrowed rather than cast, the way `about.ts` narrows a member: a member the answer does not
 * carry, or carries as something other than a string, reads `''` -- which is exactly what the
 * instance sends for a value it could not report, so the panel has one case to render rather than
 * two.
 */
function stringOf(body: unknown, member: string): string {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) return '';
  const value = (body as Record<string, unknown>)[member];
  return typeof value === 'string' ? value : '';
}

export class SystemInfo {
  private readonly api: ApiService;

  private fieldsValue: SystemInfoFields = emptyFields();

  private answeredValue = false;

  private failedValue = false;

  /**
   * Bumped by `reset()`, read across the await: an answer about the instance a departed principal
   * was reading must not land on the one who replaced them (AD-8).
   */
  private generation = 0;

  /**
   * Bumped by every `load()`, read across the await, so only the newest one settles. `generation`
   * alone does not cover it: two loads without a `reset()` between them carry the same generation,
   * and the one that happened to return last would otherwise win.
   */
  private request = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: SystemInfoOptions) {
    this.api = options.api;
  }

  /** Whether a read has ever settled, so the panel can tell "not asked yet" from "empty". */
  answered(): boolean {
    return this.answeredValue;
  }

  /** Whether the most recent read did not answer. Cleared by the next one that does. */
  failed(): boolean {
    return this.failedValue;
  }

  fields(): SystemInfoFields {
    return this.fieldsValue;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Read the panel's state. A read that does not answer leaves the previous one standing. */
  async load(): Promise<void> {
    const generation = this.generation;
    const request = (this.request += 1);
    const result: JsonResult<unknown> = await this.api.requestJson<unknown>(SYSTEM_INFO_PATH);
    if (generation !== this.generation) return;
    if (request !== this.request) return;
    if (result.kind !== 'ok') {
      // Parked. A refusal is not an answer about the instance, and neither is an instance that did
      // not reply: both leave the previous values standing and say so.
      if (this.failedValue) return;
      this.failedValue = true;
      this.notify();
      return;
    }
    const fields: Record<string, string> = {};
    for (const field of SYSTEM_INFO_FIELDS) fields[field] = stringOf(result.body, field);
    this.fieldsValue = fields as SystemInfoFields;
    this.answeredValue = true;
    this.failedValue = false;
    this.notify();
  }

  /**
   * Forget the panel's state, so the next `load()` asks again. Sign-out clears the tab in place,
   * and every member here is the instance's answer to *this* caller (AD-8) -- a member the next
   * principal may not read must not still be on screen from the last one.
   */
  reset(): void {
    this.generation += 1;
    this.request += 1;
    this.fieldsValue = emptyFields();
    this.answeredValue = false;
    this.failedValue = false;
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
