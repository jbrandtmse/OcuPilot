/**
 * The self-protection rules a descriptor's declared action may name (AD-5, AD-53).
 *
 * **A rule explains a refusal; it never makes one.** The refusal itself is the instance's, in
 * `OcuPilot.Kernel.Proposal.Prohibited`, evaluated at the write whatever the caller (AD-10) -- so
 * a surface that draws an action refused sends nothing when it is pressed, and the route refuses
 * the same write with the same sentence if it is called anyway. What this file decides is what a
 * surface *draws* before a click, which is the half AD-53 calls "the row action drawn disabled
 * before a click".
 *
 * **The vocabulary is closed and both sides read it.** `OcuPilot.Screen.Registry`'s
 * `SELFPROTECTIONRULES` is the declaration; `ui/tools/screen-mirror.mjs` refuses a descriptor
 * naming a rule outside it, and refuses the build outright when that parameter and
 * `IMPLEMENTED_SELF_PROTECTION_RULES` there disagree with the rules this file can evaluate.
 *
 * Framework-free, like the rest of `core/`.
 */

import { normalizeEntityId } from './entity-ref.ts';
import { STRINGS } from './strings.ts';

/** The rule that protects the web applications OcuPilot is itself served through. */
export const SERVES_OCUPILOT_RULE = 'serves-ocupilot';

/** The entity type `SERVES_OCUPILOT_RULE` canonicalizes an id under (AD-13). */
const WEB_APPLICATION = 'web-application';

/**
 * The web applications OcuPilot is served through, as `src/OcuPilot/Install/Roster.cls`'s manifest
 * declares them.
 *
 * **Mirrored, and pinned equal to that manifest** by `ui/tools/self-protection.test.mjs`, which
 * reads the roster rather than trusting this list -- the discipline `ui/tools/ci.test.mjs` already
 * keeps for the throwaway's arming rosters. The instance's own predicate reads the roster *and*
 * install's record of what it created, so a probe profile's applications are protected there and
 * unknown here; that is the right way round, because this list only decides what a menu explains
 * and the instance decides what may happen.
 */
export const OCUPILOT_APPLICATION_PATHS: readonly string[] = [
  '/ocupilot',
  '/api/ocupilot',
  '/api/ocupilot/readiness',
];

/**
 * The published sentence explaining why `rowKey` refuses `rule`, or `''` where the rule does not
 * apply to that row -- which includes every action declaring no rule and every row a rule protects
 * nothing about.
 *
 * `rowKey` is the row's own key as the list reports it; the comparison is through
 * `normalizeEntityId`, so `/API/OcuPilot/` and `/api/ocupilot` earn one answer, exactly as the
 * instance's own predicate does (AD-13, DW-1352).
 */
export function selfProtectionReason(rule: string, rowKey: string): string {
  if (rule !== SERVES_OCUPILOT_RULE || rowKey === '') return '';
  const canonical = normalizeEntityId(WEB_APPLICATION, rowKey);
  const own = OCUPILOT_APPLICATION_PATHS.some(
    (path) => normalizeEntityId(WEB_APPLICATION, path) === canonical
  );
  return own ? STRINGS.webAppServesOcuPilotRefusal : '';
}
