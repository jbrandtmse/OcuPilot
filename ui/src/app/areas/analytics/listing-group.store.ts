import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { NAMESPACE_SCOPE, scopeFor } from '../../core/entity-ref';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { type Violation, violationsOf } from '../../core/violations';

/** The routes the New listing group and Add listing dialogs post to (AD-55): the same tools the agent's adds resolve. */
export const LISTING_GROUP_PATH = '/api/ocupilot/analytics/listing-groups';

export const LISTING_PATH = '/api/ocupilot/analytics/listing-group-listings';

/** The route that answers one listing group, for the Edit and Copy dialogs. */
export const LISTING_GROUP_FORM_PATH = '/api/ocupilot/analytics/listing-groups/form';

/** The entity types and the tools a create's change event names (AD-13, AD-14). */
export const LISTING_GROUP_ENTITY = 'listing-group';

export const LISTING_ENTITY = 'listing-group-listing';

export const LISTING_GROUP_ADD_TOOL = 'analytics.listinggroups.add';

export const LISTING_ADD_TOOL = 'analytics.listinggrouplistings.add';

/** One listing group as the instance holds it, each member as the form route answers it. */
export type ListingGroupForm = Readonly<Record<string, string | boolean>>;

/** What the instance answered a create: the read-back of an accepted one, or the refusal as it came. */
export type ListingGroupOutcome =
  | { readonly accepted: true; readonly readBack: ReadBack | null }
  | { readonly accepted: false; readonly reason: string; readonly violations: readonly Violation[] };

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/**
 * The listing group editor's own requests (Story 24.11, AD-19, AD-55): one group as the form shows it, and the two creates.
 *
 * **It composes no rule of its own.** Each create posts to the route that resolves the tool the agent's add does, and every sentence a
 * dialog shows is the server's (AD-39). An accepted create publishes one `created` change event for the target the server names, which
 * re-reads the lists (AD-14), even when the dialog was dismissed while it was in flight.
 */
@Injectable({ providedIn: 'root' })
export class ListingGroupStore {
  private readonly injector = inject(Injector);

  /** The group `name` in `namespace` as the form route answers it, or `null` when the instance does not answer one. */
  async form(namespace: string, name: string): Promise<ListingGroupForm | null> {
    const result = await this.injector.get(ApiService).requestJson<unknown>(`${LISTING_GROUP_FORM_PATH}?name=${encodeURIComponent(name)}`, {
      method: 'GET',
      scope: namespace,
    });
    if (result.kind !== 'ok' || result.body === null || typeof result.body !== 'object') return null;
    const body = result.body as Record<string, unknown>;
    const out: Record<string, string | boolean> = {};
    for (const [key, value] of Object.entries(body)) {
      if (typeof value === 'string' || typeof value === 'boolean') out[key] = value;
    }
    return out;
  }

  /** Post a new listing group, as typed, to `namespace`. */
  createGroup(namespace: string, body: Readonly<Record<string, unknown>>): Promise<ListingGroupOutcome> {
    return this.post(LISTING_GROUP_PATH, namespace, body, LISTING_GROUP_ENTITY, LISTING_GROUP_ADD_TOOL);
  }

  /** Post a new listing, as typed, to `namespace`. */
  createListing(namespace: string, body: Readonly<Record<string, unknown>>): Promise<ListingGroupOutcome> {
    return this.post(LISTING_PATH, namespace, body, LISTING_ENTITY, LISTING_ADD_TOOL);
  }

  private async post(path: string, namespace: string, body: Readonly<Record<string, unknown>>, type: string, tool: string): Promise<ListingGroupOutcome> {
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
