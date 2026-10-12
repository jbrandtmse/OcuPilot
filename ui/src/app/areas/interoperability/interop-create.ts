import type { Injector } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { NAMESPACE_SCOPE, scopeFor } from '../../core/entity-ref';
import { readBackOf, type ReadBack } from '../../core/read-back';

/** One person's create over an Interoperability Save route: where it posts, what it posts, and what it announces. */
export interface InteropCreate {
  /** The Save route, e.g. `/api/ocupilot/interop/items`. */
  readonly path: string;
  /** The namespace the member is created in: the request's scope, and the scope of the change event. */
  readonly namespace: string;
  /** The JSON body, members named as the server names them. */
  readonly body: Readonly<Record<string, unknown>>;
  /** The entity type the `created` change event carries (AD-13, AD-14). */
  readonly type: string;
  /** The tool the change event names (AD-14), which keeps its toast on the screen that owns the type. */
  readonly tool: string;
}

/** What the server answered: the read-back of an accepted create, or the refusing result as it came. */
export type InteropCreateOutcome =
  | { readonly accepted: true; readonly readBack: ReadBack | null }
  | { readonly accepted: false; readonly result: JsonResult<unknown> };

/**
 * Post one create to its Save route and, when the server accepts it, publish one `created` change event for the
 * member the answer names, so the lists showing the type re-read (AD-14).
 *
 * `landed` runs once, as soon as the answer is in and before the event is published, so a caller can keep or drop
 * what it shows according to whether its form is still open; the event is published either way, because a member
 * the instance created is a change whether or not the form that asked for it is still on screen.
 */
export async function postInteropCreate(
  injector: Injector,
  create: InteropCreate,
  landed: (outcome: InteropCreateOutcome) => void
): Promise<InteropCreateOutcome> {
  const result = await injector.get(ApiService).requestJson<unknown>(create.path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(create.body),
    scope: create.namespace,
  });
  if (result.kind !== 'ok') {
    const refused: InteropCreateOutcome = { accepted: false, result };
    landed(refused);
    return refused;
  }
  const answer = result.body !== null && typeof result.body === 'object' ? (result.body as Record<string, unknown>) : {};
  const readBack = readBackOf(answer['readBack']);
  const target = answer['target'] !== null && typeof answer['target'] === 'object' ? (answer['target'] as Record<string, unknown>) : {};
  const id = typeof target['id'] === 'string' && target['id'] !== '' ? target['id'] : typeof answer['id'] === 'string' ? answer['id'] : '';
  const accepted: InteropCreateOutcome = { accepted: true, readBack };
  landed(accepted);
  injector.get(ChangeBus).publish({
    kind: 'changed',
    type: create.type,
    scope: scopeFor(NAMESPACE_SCOPE, create.namespace),
    id,
    action: 'created',
    readBack,
    tool: create.tool,
  });
  return accepted;
}
