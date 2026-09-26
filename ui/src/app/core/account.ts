/**
 * Changing your own password, over `POST /api/ocupilot/account/password` (Story 15.1, AD-49).
 *
 * **Three outcomes, because the dialog has three things to do about them**: close and announce,
 * stay open with the instance's refusal on the field it names, or report a fault. The rejected arm
 * carries `detail.violations[]` decoded by `violations.ts` unchanged, and the error arm carries the
 * envelope's own `reason` beside the classified fault -- the refusal copy is the server's (AD-39)
 * and this module publishes none of its own.
 *
 * **Neither password is retained.** Both are arguments, they reach one `fetch` body, and nothing
 * here stores, logs or returns either (NFR-5, AD-35, AD-47). The function is free rather than a
 * store for that reason: there is no per-user state to keep between calls.
 *
 * Framework-free, like the rest of `core/` (AD-19), so `ui/tools/account.test.mjs` executes it
 * under `node --test`.
 */

import type { ApiService } from './api';
import { classifyFault } from './fault.ts';
import type { Fault } from './fault';
import { violationsOf } from './violations.ts';
import type { Violation } from './violations';

/** Absolute from the origin root, through the one API service (AD-20). */
export const CHANGE_PASSWORD_PATH = '/api/ocupilot/account/password';

/** The body member carrying the password the caller is proving they know. */
export const CURRENT_PASSWORD_FIELD = 'currentPassword';

/** The body member carrying the replacement, and the field a policy refusal lands on. */
export const NEW_PASSWORD_FIELD = 'newPassword';

/** What one change attempt came back as. */
export type ChangePasswordOutcome =
  | { readonly kind: 'ok' }
  | { readonly kind: 'rejected'; readonly violations: readonly Violation[] }
  | { readonly kind: 'error'; readonly fault: Fault; readonly reason: string | null };

/**
 * Change the signed-in user's own password.
 *
 * The request carries no user name: the instance changes `$Username`, so there is nothing for a
 * caller to name and nothing for one to get wrong.
 *
 * A refusal that names at least one field is `rejected`; every other non-200 -- the body refusal,
 * a 403, a 5xx, an install in flight, an instance that did not answer -- is `error` with the one
 * client-side fault taxonomy's verdict on it. A 422 that carried no readable violation is an
 * `error` rather than a `rejected` with nothing in it, because a dialog that stayed open showing
 * no reason is the failure mode this split exists to avoid.
 */
export async function changePassword(
  api: ApiService,
  current: string,
  next: string
): Promise<ChangePasswordOutcome> {
  const result = await api.requestJson<unknown>(CHANGE_PASSWORD_PATH, {
    method: 'POST',
    body: JSON.stringify({ [CURRENT_PASSWORD_FIELD]: current, [NEW_PASSWORD_FIELD]: next }),
  });
  if (result.kind === 'ok') return { kind: 'ok' };
  const violations = violationsOf(result);
  if (violations.length > 0) return { kind: 'rejected', violations };
  // `classifyFault` is total over every non-`ok` arm, so this is never null; the fallback keeps
  // the return type honest without a non-null assertion.
  const fault = classifyFault(result, CHANGE_PASSWORD_PATH);
  return {
    kind: 'error',
    fault: fault ?? { kind: 'server-fault', status: result.status, code: null, path: CHANGE_PASSWORD_PATH },
    reason: 'reason' in result && result.reason !== '' ? result.reason : null,
  };
}
