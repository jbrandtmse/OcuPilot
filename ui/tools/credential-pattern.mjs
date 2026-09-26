/**
 * The credential pattern (Consistency Conventions, Secrets), in one place on this side.
 *
 * Two build-time gates read it and neither may carry its own copy: `field-lists.mjs`, which
 * refuses a derived string field whose name matches and is classified anything but `secret`
 * (AD-3), and `screen-mirror.mjs`, which refuses a descriptor whose declared criteria or settable
 * fields name one that `secretArguments` does not declare (AD-6). `field-lists.mjs` re-exports
 * the two arrays, so `credential-lists.test.mjs` keeps holding them equal to
 * `OcuPilot.Kernel.Audit.Log`'s own parameters (DW-399).
 *
 * It is a module of its own rather than a third export of either gate because `field-lists.mjs`
 * already imports from `screen-mirror.mjs`: putting the pattern in one of them would make the
 * other import back.
 */

/**
 * The suffix half, held equal by `credential-lists.test.mjs` to
 * `OcuPilot.Kernel.Audit.Log.CREDENTIALSUFFIXES` (DW-399).
 */
export const CREDENTIAL_SUFFIXES = [
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

/**
 * The exact-name half, held equal by `credential-lists.test.mjs` to
 * `OcuPilot.Kernel.Audit.Log.CREDENTIALEXACTNAMES` (DW-399).
 */
export const CREDENTIAL_EXACT_NAMES = ['key', 'credentialname'];

/**
 * The names the pattern matches that are not credentials, lower-cased, held equal by
 * `credential-lists.test.mjs` to `OcuPilot.Kernel.Audit.Log.CREDENTIALEXCEPTIONS` and to the spine's
 * Conventions › Secrets row: `ReturnRefreshToken`, the authorization server's refresh-token policy
 * (one of `""`, `a`, `c`, `f`), which Story 12.7's tools show and set.
 */
export const CREDENTIAL_EXCEPTIONS = ['returnrefreshtoken'];

/** The credential pattern, matched against a path's last segment. */
export const CREDENTIAL_RE = new RegExp(
  `(${CREDENTIAL_SUFFIXES.join('|')})$|^(${CREDENTIAL_EXACT_NAMES.join('|')})$`,
  'i'
);

/** A path's last segment with any `[]` removed: `Resources[].Name` -> `Name`, `CipherList[]` -> `CipherList`. */
export function lastSegment(path) {
  return path.split('.').pop().replace(/(\[\])+$/, '');
}

/** Whether `name`'s last segment matches the pattern and is not one of `CREDENTIAL_EXCEPTIONS`. */
export function isCredentialName(name) {
  const segment = lastSegment(name);
  return CREDENTIAL_RE.test(segment) && !CREDENTIAL_EXCEPTIONS.includes(segment.toLowerCase());
}
