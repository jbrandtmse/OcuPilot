/**
 * The client mirror of `OcuPilot.Kernel.EntityRef` (AD-13, AD-14): the
 * `(entity type, scope, id)` triple every reference that crosses a boundary carries.
 *
 * A task named `Nightly purge` in `USER` and one in `HSCUSTOM` are different entities, so an id
 * alone is never an identity: without the scope a change event could re-fetch the wrong row and a
 * confirm could re-read the wrong object.
 *
 * **A reference key is not a URL segment.** `core/entity-id.ts` encodes twice and decodes once
 * because the web server consumes one decoding in transit, so its two functions are deliberately
 * not inverses and a key built from them would have none either. The key joins its parts with
 * `REF_SEPARATOR`, one code point above that codec's `COMPOSITE_SEPARATOR`, so a composite id
 * passes through a key whole and still splits on its own separator afterwards.
 *
 * The type is validated against `ENTITY_TYPES`, mirrored from the kernel's own closed enum, so
 * the client checks a type against one vocabulary rather than inventing a second.
 */

import { ENTITY_TYPES } from './screens.generated.ts';

/**
 * The literal scope of a configuration object that has no namespace, mirroring
 * `OcuPilot.Kernel.Scope.SCOPEINSTANCE`. A descriptor declares `instance` or `namespace`, and
 * nothing else reaches a reference: the server's registry refuses a third spelling.
 */
export const INSTANCE_SCOPE = 'instance';

/**
 * The declared scope of a namespace-scoped screen, mirroring
 * `OcuPilot.Kernel.Scope.SCOPENAMESPACE`. Spelled once here for the reason the server spells it
 * once there: a literal per reader is the divergence the two values exist to prevent.
 */
export const NAMESPACE_SCOPE = 'namespace';

/**
 * The character joining the three parts of a reference key. Authored as an escape, never a
 * literal byte (Rule 14).
 */
export const REF_SEPARATOR = '\u0002';

/** One reference, parsed. */
export interface EntityRef {
  readonly type: string;
  readonly scope: string;
  readonly id: string;
}

/** Whether `type` is one of the kernel's declared entity types. */
export function isKnownEntityType(type: string): boolean {
  return type !== '' && (ENTITY_TYPES as readonly string[]).includes(type);
}

/**
 * The key for one reference, or `null` when the triple is not one: an unknown entity type, or an
 * empty scope or id. `null` rather than a throw, for the reason `decodeEntityId` returns its
 * input on a malformed segment -- a screen renders nothing for a reference it cannot form, and
 * the build gates are what catch a type that does not exist.
 */
export function entityRefKey(type: string, scope: string, id: string): string | null {
  if (!isKnownEntityType(type)) return null;
  if (scope === '' || id === '') return null;
  return type + REF_SEPARATOR + scope + REF_SEPARATOR + id;
}

/**
 * The triple a key carries, or `null` when the key is not one. The id is everything after the
 * second separator, so a composite id carrying `COMPOSITE_SEPARATOR` comes back whole.
 */
export function parseEntityRefKey(key: string): EntityRef | null {
  const parts = key.split(REF_SEPARATOR);
  if (parts.length < 3) return null;
  const type = parts[0];
  const scope = parts[1];
  const id = parts.slice(2).join(REF_SEPARATOR);
  if (!isKnownEntityType(type)) return null;
  if (scope === '' || id === '') return null;
  return { type, scope, id };
}

/**
 * The scope half of a reference to an entity on a screen whose descriptor declares
 * `declaredScope`: the request's namespace for `namespace`, the literal for `instance`, and `''`
 * for anything else -- a value the server's registry refuses before a descriptor carrying it can
 * reach the mirror.
 *
 * `currentNamespace` is passed rather than read, because this module is framework-free and the
 * resolved scope lives in `ScopeService`.
 */
export function scopeFor(declaredScope: string, currentNamespace: string): string {
  if (declaredScope === NAMESPACE_SCOPE) return currentNamespace;
  if (declaredScope === INSTANCE_SCOPE) return INSTANCE_SCOPE;
  return '';
}
