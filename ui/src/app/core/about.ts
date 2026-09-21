/**
 * The system overview the About dialog shows, over `/api/ocupilot/ui/about` (Story 15.3, FR-73).
 *
 * **Its own read, not a wider `/instance`.** The identity call is made at sign-in and on every
 * connectivity probe and its seven fields are pinned as a set; About is opened on demand and needs
 * twelve more reads. A second caller-own chrome store keeps the hot read lean, and follows the
 * `/instance`, `/navigation`, `/namespaces` precedent (AD-36's shell-chrome exception).
 *
 * **A transport failure never clears what was answered.** A read that does not answer leaves the
 * previous fields standing and raises `failed()`, so a dialog reopened while the instance is
 * unreachable shows what it last heard rather than emptying itself; a dialog that has never had an
 * answer shows its error state instead. A read a later one overtook settles nothing either --
 * `request` is what makes "only the newest answer wins" a property of this store rather than of
 * whichever response happened to arrive last, the shape `agent-status.ts` and
 * `account-preferences.ts` use for the same hazard.
 *
 * Framework-free, like the rest of `core/` (AD-19), so `ui/tools/about.test.mjs` executes it under
 * `node --test`.
 */

import type { ApiService, JsonResult } from './api';

/** Absolute from the origin root, through the one API service (AD-20). */
export const ABOUT_PATH = '/api/ocupilot/ui/about';

/**
 * The thirteen scalar members the read answers, in the order the dialog lists them. Held as a list
 * so the dialog renders what the wire carries rather than a second hand-kept order.
 */
export const ABOUT_FIELDS = [
  'version',
  'productComponents',
  'configuration',
  'databaseCacheMb',
  'routineCacheMb',
  'journalFile',
  'superServerPort',
  'webServerPort',
  'licenseServer',
  'licensedTo',
  'encryptionKeyId',
  'locale',
  'buildIdentity',
] as const;

export type AboutField = (typeof ABOUT_FIELDS)[number];

/** The three destinations the links panel names. */
export const ABOUT_LINKS = ['documentation', 'support', 'intersystems'] as const;

export type AboutLink = (typeof ABOUT_LINKS)[number];

export type AboutFields = Readonly<Record<AboutField, string>>;

export type AboutLinks = Readonly<Record<AboutLink, string>>;

export interface AboutOptions {
  readonly api: ApiService;
}

function emptyFields(): AboutFields {
  const out: Record<string, string> = {};
  for (const field of ABOUT_FIELDS) out[field] = '';
  return out as AboutFields;
}

function emptyLinks(): AboutLinks {
  const out: Record<string, string> = {};
  for (const link of ABOUT_LINKS) out[link] = '';
  return out as AboutLinks;
}

/**
 * One string off an answered body.
 *
 * Narrowed rather than cast, the way `account-preferences.ts` narrows a row: a member the answer
 * does not carry, or carries as something other than a string, reads `''` -- which is exactly what
 * the instance sends for a field it could not report, so the dialog has one case to render rather
 * than two.
 */
function stringOf(body: unknown, member: string): string {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) return '';
  const value = (body as Record<string, unknown>)[member];
  return typeof value === 'string' ? value : '';
}

export class About {
  private readonly api: ApiService;

  private fieldsValue: AboutFields = emptyFields();

  private linksValue: AboutLinks = emptyLinks();

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

  constructor(options: AboutOptions) {
    this.api = options.api;
  }

  /** Whether a read has ever settled, so the dialog can tell "not asked yet" from "empty". */
  answered(): boolean {
    return this.answeredValue;
  }

  /** Whether the most recent read did not answer. Cleared by the next one that does. */
  failed(): boolean {
    return this.failedValue;
  }

  fields(): AboutFields {
    return this.fieldsValue;
  }

  links(): AboutLinks {
    return this.linksValue;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Read the overview. A read that does not answer leaves the previous one standing. */
  async load(): Promise<void> {
    const generation = this.generation;
    const request = (this.request += 1);
    const result: JsonResult<unknown> = await this.api.requestJson<unknown>(ABOUT_PATH);
    if (generation !== this.generation) return;
    if (request !== this.request) return;
    if (result.kind !== 'ok') {
      // Parked. A refusal is not an answer about the instance, and neither is an instance that did
      // not reply: both leave the previous fields standing and say so.
      if (this.failedValue) return;
      this.failedValue = true;
      this.notify();
      return;
    }
    const fields: Record<string, string> = {};
    for (const field of ABOUT_FIELDS) fields[field] = stringOf(result.body, field);
    const rawLinks =
      typeof result.body === 'object' && result.body !== null
        ? (result.body as Record<string, unknown>)['links']
        : null;
    const links: Record<string, string> = {};
    for (const link of ABOUT_LINKS) links[link] = stringOf(rawLinks, link);
    this.fieldsValue = fields as AboutFields;
    this.linksValue = links as AboutLinks;
    this.answeredValue = true;
    this.failedValue = false;
    this.notify();
  }

  /**
   * Forget the overview, so the next `load()` asks again. Sign-out clears the tab in place, and
   * the licensee and the build stamp are the instance's answer to *this* caller (AD-8) -- the same
   * gesture that drops the navigation map and the remembered lists.
   */
  reset(): void {
    this.generation += 1;
    this.request += 1;
    this.fieldsValue = emptyFields();
    this.linksValue = emptyLinks();
    this.answeredValue = false;
    this.failedValue = false;
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
