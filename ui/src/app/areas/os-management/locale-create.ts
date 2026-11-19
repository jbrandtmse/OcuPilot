import type { ApiService } from '../../core/api';
import type { ChangeBus } from '../../core/change-bus';
import { INSTANCE_SCOPE } from '../../core/entity-ref';
import { readBackOf } from '../../core/read-back';
import { violationsOf } from '../../core/violations';

/** The route Locale definitions' Copy posts to (AD-55): the same tool the agent's copy resolves. */
export const LOCALE_COPY_PATH = '/api/ocupilot/locales';

/** The route Locale properties' Add table posts to (AD-55): the same tool the agent's add resolves. */
export const LOCALE_TABLE_PATH = '/api/ocupilot/locale-properties';

/** The entity types and tools the two creates' change events carry (AD-13, AD-14). */
export const LOCALE_ENTITY = 'locale';
export const LOCALE_COPY_TOOL = 'osmgmt.locales.copy';
export const LOCALE_PROPERTY_ENTITY = 'locale-property';
export const LOCALE_TABLE_TOOL = 'osmgmt.localeproperties.add';

/** One person's create over a locale Save route. */
export interface LocaleCreate {
  readonly api: ApiService;
  readonly bus: ChangeBus;
  /** The Save route. */
  readonly path: string;
  /** The JSON body, members named as the server names them. */
  readonly body: Readonly<Record<string, string>>;
  /** The entity type and tool the `created` change event carries. */
  readonly type: string;
  readonly tool: string;
  /** The id the event names when the answer carries none. */
  readonly fallbackId: string;
}

/** What the server answered: an accepted create, or the sentence of the refusal. */
export type LocaleCreateOutcome = { readonly accepted: true } | { readonly accepted: false; readonly reason: string };

/**
 * Post one create to its Save route and, when the server accepts it, publish one `created` change event for the member the answer names, so the lists showing the
 * type re-read (AD-14). **It composes no rule of its own**: a refusal's reason is the server's sentence, the first violation's else the envelope's.
 */
export async function postLocaleCreate(create: LocaleCreate): Promise<LocaleCreateOutcome> {
  const result = await create.api.requestJson<unknown>(create.path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(create.body),
  });
  if (result.kind !== 'ok') {
    const named = violationsOf(result).find((entry) => entry.reason !== '')?.reason ?? '';
    return { accepted: false, reason: named !== '' ? named : result.kind === 'error' ? (result.reason ?? '') : '' };
  }
  const answer = result.body !== null && typeof result.body === 'object' ? (result.body as Record<string, unknown>) : {};
  const target = answer['target'] !== null && typeof answer['target'] === 'object' ? (answer['target'] as Record<string, unknown>) : {};
  const id =
    typeof target['id'] === 'string' && target['id'] !== '' ? target['id'] : typeof answer['id'] === 'string' && answer['id'] !== '' ? answer['id'] : create.fallbackId;
  create.bus.publish({
    kind: 'changed',
    type: create.type,
    scope: INSTANCE_SCOPE,
    id,
    action: 'created',
    readBack: readBackOf(answer['readBack']),
    tool: create.tool,
  });
  return { accepted: true };
}
