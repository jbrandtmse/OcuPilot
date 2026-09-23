/**
 * The Auditing configuration form's own view rules (Story 7.4): the one row the screen's declared
 * read answers, the status line it states and the one action it offers.
 *
 * Framework-free, like `database-details.store.ts`, so the rules are plain functions the page and
 * its spec both call.
 */

import { STRINGS } from '../../core/strings.ts';

/** The descriptor this screen is declared by. */
export const AUDITING_CONFIG_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.AuditingConfig';

/** The row action that turns auditing on, as the descriptor declares it. */
export const AUDITING_ENABLE_ACTION = 'enable';

/** The row action that turns auditing off, as the descriptor declares it. */
export const AUDITING_DISABLE_ACTION = 'disable';

/** The two event lists embedded beneath the form, by their declared routes. */
export const AUDITING_EVENT_LIST_ROUTES: readonly string[] = [
  'security/auditing/system-events',
  'security/auditing/user-events',
];

/** The Audit database viewer this screen cross-links to. */
export const AUDIT_DATABASE_ROUTE = 'logs/audit';

/** The one action the form offers: its declared id, its published label, and whether it is the primary button. */
export interface AuditingControl {
  readonly actionId: string;
  readonly label: string;
  readonly primary: boolean;
}

/**
 * Whether the read's one row says auditing is on: `true` or `false` from its `Enabled` boolean, or
 * `null` when no row has been read or the row carries no boolean -- never a guess.
 */
export function auditingEnabled(row: unknown): boolean | null {
  if (row === null || typeof row !== 'object' || Array.isArray(row)) return null;
  const value = (row as Record<string, unknown>)['Enabled'];
  return typeof value === 'boolean' ? value : null;
}

/** The status line for `enabled`. */
export function auditingStatus(enabled: boolean): string {
  return enabled ? STRINGS.auditingStatusOn : STRINGS.auditingStatusOff;
}

/**
 * The one action for `enabled`: turning auditing off is secondary while it is on, and turning it
 * on is the primary button while it is off.
 */
export function auditingControl(enabled: boolean): AuditingControl {
  return enabled
    ? { actionId: AUDITING_DISABLE_ACTION, label: STRINGS.auditingTurnOffAction, primary: false }
    : { actionId: AUDITING_ENABLE_ACTION, label: STRINGS.auditingTurnOnAction, primary: true };
}
