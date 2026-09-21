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

import {
  ENTITY_ID_RULES,
  ENTITY_REF_SEPARATOR_CODE,
  ENTITY_TYPES,
  type EntityTypeKey,
} from './screens.generated.ts';

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
 * The character joining the three parts of a reference key.
 *
 * **Built from the mirrored code point, not from a literal of its own** (AD-5, DW-1403). It was
 * a hand-copied escape beside `OcuPilot.Kernel.EntityRef`'s `Parameter REFSEPARATOR = 2`, with
 * nothing comparing the two, so moving either would have shipped two key builders that agree on
 * every part of a key except the joins. `ui/tools/screen-mirror.mjs` reads the kernel's parameter
 * and emits it, the way it emits the entity-type enum and the id-rule table, so there is one
 * source and no literal byte in a source file either (Rule 14).
 */
export const REF_SEPARATOR = String.fromCharCode(ENTITY_REF_SEPARATOR_CODE);

/**
 * One rule name to the spelling it canonicalizes an id to.
 *
 * **This is a mirror, not a second source** (AD-5, AD-13 as amended by DW-1359). Which entity
 * types have a rule is declared once, in `OcuPilot.Kernel.EntityRef.IDRULES`, and reaches this
 * module as `ENTITY_ID_RULES` in the generated mirror; what a named rule does is implemented
 * here because it has to run in this language. `ui/tools/screen-mirror.mjs` fails
 * `npm run build` on a declared rule this table does not hold, so a kernel rule cannot reach the
 * client as a silent identity function -- which is what DW-1364 was: the server folded a
 * web-application id per entity type while this builder joined the parts verbatim, so a
 * server-built key and a client-built key for one entity were two strings.
 */
const ID_RULES: Readonly<Record<string, (id: string) => string>> = {
  'foldcase-striptrailingslash': (id) => {
    let value = id.toLowerCase();
    while (value !== '' && value.endsWith('/')) value = value.slice(0, -1);
    return value;
  },
  foldcase: (id) => id.toLowerCase(),
};

/**
 * The rule names this module implements, for the roster pin in `ui/tools/entity-ref.test.mjs`:
 * equal to `screen-mirror.mjs`'s `IMPLEMENTED_ID_RULES`, in both directions.
 */
export const IMPLEMENTED_ID_RULE_NAMES: readonly string[] = Object.keys(ID_RULES);

/**
 * `id` in the one spelling a reference to an entity of type `type` carries -- the client half of
 * `OcuPilot.Kernel.EntityRef.NormalizedId`. A type the mirrored table holds no rule for is
 * answered verbatim.
 *
 * An unimplemented rule name cannot reach here (the generator refuses it), and answering
 * verbatim is what this would do anyway, so there is no throw: a key that cannot be formed is
 * `null` from `entityRefKey`, never an exception in a subscriber.
 */
export function normalizeEntityId(type: string, id: string): string {
  const rule = ENTITY_ID_RULES[type as EntityTypeKey];
  if (rule === undefined) return id;
  const apply = ID_RULES[rule];
  return apply === undefined ? id : apply(id);
}

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
 *
 * The id reaches the key in the spelling `normalizeEntityId` answers for that type, which is the
 * spelling `OcuPilot.Kernel.EntityRef.Key` builds too, so a key built here and a key built on
 * the instance for one entity are one string (DW-1364). Normalization runs **before** the
 * emptiness gate, so a web-application id of `/`, which normalizes to nothing, is refused rather
 * than keyed.
 */
export function entityRefKey(type: string, scope: string, id: string): string | null {
  if (!isKnownEntityType(type)) return null;
  const canonical = normalizeEntityId(type, id);
  if (scope === '' || canonical === '') return null;
  return type + REF_SEPARATOR + scope + REF_SEPARATOR + canonical;
}

/**
 * The triple a key carries, or `null` when the key is not one. The id is everything after the
 * second separator, so a composite id carrying `COMPOSITE_SEPARATOR` comes back whole.
 *
 * **It does not normalize, and that mirrors the server**: `OcuPilot.Kernel.EntityRef.Parse` reads
 * a key as it was written so a stored reference comes back as the thing that was stored, and
 * `Canonical` is the separate answer for a caller that wants the spelling `Key` would have built.
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
