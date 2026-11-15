import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { NAMESPACE_SCOPE, scopeFor } from '../../core/entity-ref';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { type Violation, violationsOf } from '../../core/violations';

/** The routes the New term list and Add entry dialogs post to (AD-55): the same tools the agent's adds resolve. */
export const TERM_LIST_PATH = '/api/ocupilot/analytics/term-lists';

export const TERM_LIST_ENTRY_PATH = '/api/ocupilot/analytics/term-list-entries';

/** The route that answers one term list's header, for the Edit term list and Add entry dialogs. */
export const TERM_LIST_FORM_PATH = '/api/ocupilot/analytics/term-lists/form';

/** The entity types and the tools a create's change event names (AD-13, AD-14). */
export const TERM_LIST_ENTITY = 'term-list';

export const TERM_LIST_ENTRY_ENTITY = 'term-list-entry';

export const TERM_LIST_ADD_TOOL = 'analytics.termlists.add';

export const TERM_LIST_ENTRY_ADD_TOOL = 'analytics.termlistentries.add';

/** One term list's header as the instance holds it. */
export interface TermListHeader {
  readonly name: string;
  readonly caption: string;
  readonly description: string;
  readonly pattern: string;
  readonly subjectArea: string;
  readonly fields: readonly string[];
  readonly hideValue: boolean;
}

/** What the instance answered a create: the read-back of an accepted one, or the refusal as it came. */
export type TermListOutcome =
  | { readonly accepted: true; readonly readBack: ReadBack | null }
  | { readonly accepted: false; readonly reason: string; readonly violations: readonly Violation[] };

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/**
 * The term list editor's own requests (Story 24.2, AD-19, AD-55): one term list's header, and the two creates.
 *
 * **It composes no rule of its own.** Each create posts to the route that resolves the tool the agent's add does, and every sentence a
 * dialog shows is the server's (AD-39). An accepted create publishes one `created` change event for the target the server names, which
 * re-reads the lists (AD-14), even when the dialog was dismissed while it was in flight. The Interoperability area's create helper is not
 * imported: a client area reaches no other area.
 */
@Injectable({ providedIn: 'root' })
export class TermListStore {
  private readonly injector = inject(Injector);

  /** The header of the term list `name` in `namespace`, or `null` when the instance does not answer one. */
  async header(namespace: string, name: string): Promise<TermListHeader | null> {
    const result = await this.injector.get(ApiService).requestJson<unknown>(`${TERM_LIST_FORM_PATH}?name=${encodeURIComponent(name)}`, {
      method: 'GET',
      scope: namespace,
    });
    if (result.kind !== 'ok' || result.body === null || typeof result.body !== 'object') return null;
    const body = result.body as Record<string, unknown>;
    const fields = Array.isArray(body['Fields']) ? body['Fields'].filter((entry): entry is string => typeof entry === 'string') : [];
    return {
      name: text(body['Name']),
      caption: text(body['Caption']),
      description: text(body['Description']),
      pattern: text(body['Pattern']),
      subjectArea: text(body['SubjectArea']),
      fields,
      hideValue: body['HideValue'] === true,
    };
  }

  /** Post a new term list, as typed, to `namespace`. */
  create(namespace: string, body: Readonly<Record<string, unknown>>): Promise<TermListOutcome> {
    return this.post(TERM_LIST_PATH, namespace, body, TERM_LIST_ENTITY, TERM_LIST_ADD_TOOL);
  }

  /** Post a new entry, as typed, to `namespace`. */
  addEntry(namespace: string, body: Readonly<Record<string, unknown>>): Promise<TermListOutcome> {
    return this.post(TERM_LIST_ENTRY_PATH, namespace, body, TERM_LIST_ENTRY_ENTITY, TERM_LIST_ENTRY_ADD_TOOL);
  }

  private async post(path: string, namespace: string, body: Readonly<Record<string, unknown>>, type: string, tool: string): Promise<TermListOutcome> {
    const result: JsonResult<unknown> = await this.injector.get(ApiService).requestJson<unknown>(path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      scope: namespace,
    });
    if (result.kind !== 'ok') {
      return { accepted: false, reason: result.kind === 'error' ? (result.reason ?? '') : '', violations: violationsOf(result) };
    }
    const answer = result.body !== null && typeof result.body === 'object' ? (result.body as Record<string, unknown>) : {};
    const readBack = readBackOf(answer['readBack']);
    const target = answer['target'] !== null && typeof answer['target'] === 'object' ? (answer['target'] as Record<string, unknown>) : {};
    const id = text(target['id']) !== '' ? text(target['id']) : text(answer['id']);
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type,
      scope: scopeFor(NAMESPACE_SCOPE, namespace),
      id,
      action: 'created',
      readBack,
      tool,
    });
    return { accepted: true, readBack };
  }
}
