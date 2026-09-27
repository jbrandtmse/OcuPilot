/**
 * The credential pattern (the spine's Conventions, Secrets) at runtime, for the one client surface
 * that masks by name: the try-it console's record of a request it sent (AD-57 (4)).
 *
 * `ui/tools/credential-pattern.mjs` holds the same three lists for the build-time gates, and is not
 * importable by the bundle; `ui/tools/credential-lists.test.mjs` holds these equal to it, member for
 * member, so the two copies cannot drift.
 *
 * Framework-free, like the rest of `core/` (AD-19).
 */

/** The suffix half, lower-cased. */
export const CREDENTIAL_SUFFIXES: readonly string[] = [
  'password',
  'passwd',
  'pwd',
  'secret',
  'secret64',
  'apikey',
  'privatekey',
  'token',
  'credential',
];

/** The exact-name half, lower-cased. */
export const CREDENTIAL_EXACT_NAMES: readonly string[] = ['key', 'credentialname'];

/** The names the pattern matches that are not credentials, lower-cased. */
export const CREDENTIAL_EXCEPTIONS: readonly string[] = ['returnrefreshtoken'];

/**
 * Whether `name` matches the credential pattern, case-insensitively: it ends in one of the
 * suffixes or is exactly one of the exact names, and is not one of the exceptions.
 */
export function isSecretName(name: string): boolean {
  const lower = name.toLowerCase();
  if (CREDENTIAL_EXCEPTIONS.includes(lower)) return false;
  return CREDENTIAL_EXACT_NAMES.includes(lower) || CREDENTIAL_SUFFIXES.some((suffix) => lower.endsWith(suffix));
}
