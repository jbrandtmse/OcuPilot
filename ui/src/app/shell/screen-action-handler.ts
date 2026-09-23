import { Injectable, Injector, inject, signal } from '@angular/core';

import { ApiService } from '../core/api';
import { ChangeBus, type ChangeAction } from '../core/change-bus';
import { ScreenActions, actionLabel } from '../core/screen-actions';
import { SCREEN_READ_PATH_PREFIX, screenReadPath } from '../core/screen-read';
import { DEFAULT_MAX_ROWS, ScreenStores } from '../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../core/screens.generated';
import { selfProtectionReason } from '../core/self-protection';
import { Session } from '../core/session';
import { STRINGS } from '../core/strings';
import { rowKey } from '../core/table-model';

/** The absolute path a screen's own row action is issued under (AD-20, AD-53). */
export const SCREEN_ACTION_PATH_SUFFIX = '/action';

/**
 * The descriptors whose declared row actions this handler carries out.
 *
 * **A roster rather than "every write-capable screen"**, because two screens register their own:
 * the Definitions list (`areas/agent/definition-actions.ts`) writes OcuPilot's own state through
 * its own routes, and the Switches screen's `create`/`delete` add and remove a per-user hold.
 * Neither is an instance write and neither goes through `POST /screens/:screen/action`, so
 * registering generically for them would replace a handler that does something else. It grows one
 * entry per story, beside the consequence copy below: the Web applications list (Story 7.1), and
 * the OAuth 2.0 screen's Client configurations and Server client descriptions tabs (Story 7.3),
 * whose detail pages render the same `ListPage`, and the Users list (Story 7.2), and the Auditing
 * configuration form (Story 7.4), whose page selects the singleton itself.
 */
export const SCREEN_ACTION_DESCRIPTORS: readonly string[] = [
  'OcuPilot.Screen.Descriptor.WebAppList',
  'OcuPilot.Screen.Descriptor.OAuthClientTab',
  'OcuPilot.Screen.Descriptor.OAuthServerClientTab',
  'OcuPilot.Screen.Descriptor.UserList',
  'OcuPilot.Screen.Descriptor.AuditingConfig',
];

/** The Users list's descriptor, whose row actions carry values (AD-56). */
const USER_LIST = 'OcuPilot.Screen.Descriptor.UserList';

/**
 * The change-on-login flag's action (AD-56): a declared, undrawn action. It is declared so the
 * route admits it, and it registers no handler, so no surface draws it (DW-389) -- the set-password
 * dialog alone sends it, first, when its checkbox is checked.
 */
export const REQUIRE_PASSWORD_CHANGE = 'require-password-change';

/** The set-password action, and the one value it sends: the declared secret (AD-56 (i)). */
export const SET_PASSWORD = 'set-password';
const PASSWORD_VALUE = 'Password';

/** The two role actions, and the one value each sends (AD-56 (ii)). */
export const ADD_ROLE = 'add-role';
export const REMOVE_ROLE = 'remove-role';
const ROLE_VALUE = 'Role';

/** The screen whose declared read lists the roles an add may offer (AD-5). */
const ROLES_TOOL_IDENTIFIER = 'permissions.roles';

/**
 * The row actions that open a dialog asking for a value, keyed by descriptor and then by action id.
 * An action here is never sent straight from a menu: the dialog is what supplies its value.
 */
const VALUE_ACTIONS: Readonly<Record<string, Readonly<Record<string, 'set-password' | 'role'>>>> = {
  [USER_LIST]: { [SET_PASSWORD]: 'set-password', [ADD_ROLE]: 'role', [REMOVE_ROLE]: 'role' },
};

/** The declared actions no surface draws, keyed by descriptor (DW-389). */
const UNDRAWN_ACTIONS: Readonly<Record<string, readonly string[]>> = {
  [USER_LIST]: [REQUIRE_PASSWORD_CHANGE],
};

/**
 * The row actions this handler confirms with the typed-name dialog before it sends anything.
 *
 * **It decides which dialog a person sees, never what may happen.** Whether a write is refused is
 * the instance's (AD-10); whether a card draws the destructive treatment is the tool's own
 * `DESTRUCTIVE` declaration. This is EXPERIENCE.md's `confirm-dialog` rule -- a delete carries the
 * typed-name field and a `button-destructive` -- applied to the verb that deletes.
 */
const DESTRUCTIVE_ACTIONS: readonly string[] = ['delete'];

/**
 * The consequence sentence a destructive action states above its typed-name field, keyed by
 * descriptor and then by action id -- the shape `DESCRIPTOR_ACTION_LABELS` already uses, and for
 * the same reason: one verb means a different consequence on each screen, and the sentence is
 * published per screen in EXPERIENCE.md's Fixed strings table.
 *
 * **A destructive action whose screen publishes no consequence is not registered at all**, so no
 * surface draws it (DW-389) and nothing here invents copy.
 */
const DESTRUCTIVE_CONSEQUENCES: Readonly<Record<string, Readonly<Record<string, string>>>> = {
  'OcuPilot.Screen.Descriptor.WebAppList': { delete: STRINGS.webAppDeleteConsequence },
  'OcuPilot.Screen.Descriptor.OAuthClientTab': { delete: STRINGS.oauthClientDeleteConsequence },
  'OcuPilot.Screen.Descriptor.OAuthServerClientTab': { delete: STRINGS.oauthServerClientDeleteConsequence },
  [USER_LIST]: { delete: STRINGS.userDeleteConsequence },
};

/**
 * The warning a non-delete write states before it is sent, keyed by descriptor and then by action
 * id (EXPERIENCE.md `confirm-dialog`: a warning's confirming action is `button-primary`, never
 * destructive). An action with a warning here opens the warning dialog; nothing is sent until its
 * Proceed.
 */
const WARNING_CONSEQUENCES: Readonly<Record<string, Readonly<Record<string, string>>>> = {
  'OcuPilot.Screen.Descriptor.AuditingConfig': { disable: STRINGS.proposalAuditWarning },
};

/** What the screen-action route answers (AD-14): the verb, and the triple the write was made against. */
interface ScreenActionAnswer {
  readonly action?: string;
  readonly target?: { readonly type?: string; readonly scope?: string; readonly id?: string };
}

/** Which dialog a pending row action is waiting on. */
export type PendingKind = 'typed-name' | 'warning' | 'set-password' | 'role';

/**
 * The dialog a row action is waiting on, or `null`: the typed-name confirm of a destructive action,
 * the warning before a non-delete write, the set-password dialog, or the role dialog. `kind` says
 * which; `consequence` is the typed-name or warning dialog's own sentence and `options` the role
 * dialog's choices, each empty for the other kinds.
 */
export interface PendingConfirm {
  readonly kind: PendingKind;
  readonly descriptor: string;
  readonly actionId: string;
  readonly verb: string;
  readonly target: string;
  readonly consequence: string;
  readonly options: readonly string[];
}

/** The values a row action sends beside its id, keyed by the names its tool declares (AD-56). */
export type ActionValues = Readonly<Record<string, string>>;

/**
 * The handler behind every declared row action this client runs through
 * `POST /api/ocupilot/screens/:screen/action` (AD-5, AD-53).
 *
 * **It is generic and it lives in the shell, not in an area.** A list archetype is served entirely
 * by `ListPage` over its descriptor, so a row action has no area page to be registered from; and
 * AD-5 makes a row action a declaration, so the thing that runs it is declaration-driven too. One
 * registration loop serves every screen on the roster above, and every later story in this epic
 * adds a descriptor rather than a service.
 *
 * **The target is the selected row's key**, which is what the row menu selects on open and what
 * the command bar acts on. A run with no selection does nothing: both surfaces already draw the
 * action `aria-disabled` with "Select a row first" in that state.
 *
 * **A destructive action opens the typed-name dialog first** and sends nothing until it is
 * confirmed. `ListPage` renders the dialog from `pending()`, because the list is the surface the
 * action belongs to and the shell has one modal surface (`dialog.ts`).
 *
 * **Nothing is patched from the write's own answer** (AD-14). A confirmed write publishes the
 * triple and verb the instance answered on the change bus; the refresh framework re-fetches the
 * screen in place and marks the row. A refusal publishes nothing and puts the envelope's own
 * sentence on the screen's store, which `ListPage` renders (AD-39).
 */
@Injectable({ providedIn: 'root' })
export class ScreenActionHandler {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  private readonly stores = inject(ScreenStores);

  private readonly session = inject(Session, { optional: true });

  private readonly waiting = signal<PendingConfirm | null>(null);

  constructor() {
    for (const screen of SCREENS) {
      if (!SCREEN_ACTION_DESCRIPTORS.includes(screen.descriptor)) continue;
      for (const action of screen.rowActions) {
        if (action.id === '') continue;
        // A declared action only a dialog sends has no menu entry of its own (DW-389).
        if ((UNDRAWN_ACTIONS[screen.descriptor] ?? []).includes(action.id)) continue;
        // No inert control: a destructive action with no published consequence has no dialog to
        // open, so it registers no handler and no surface draws it (DW-389).
        if (this.isDestructive(action.id) && this.consequence(screen.descriptor, action.id) === '') {
          continue;
        }
        this.actions.register(screen.descriptor, action.id, () => this.start(screen, action.id));
      }
    }
  }

  /** The dialog a row action is waiting on (`PendingKind`), or `null`. The page that ran the action renders it. */
  pending(): PendingConfirm | null {
    return this.waiting();
  }

  /** The typed name matched, or the warning was proceeded past: send the write the dialog was standing in front of. */
  confirmPending(): void {
    const pending = this.waiting();
    this.waiting.set(null);
    if (pending === null || (pending.kind !== 'typed-name' && pending.kind !== 'warning')) return;
    void this.send(pending.descriptor, pending.actionId, pending.target);
  }

  /**
   * The set-password dialog was submitted (AD-56). With `changeOnLogin` the flag is its own write,
   * sent first, and a refusal of it stops here with nothing else sent; then the password is sent
   * once, exactly as given -- never trimmed -- and this frame is the only place it is held.
   *
   * **The flag is written again once the password has landed.** Measured on this build, the
   * vendor's password change clears `ChangePassword`, so the first write proves the flag can be
   * set -- and leaves it set if the password is refused -- while the second is what leaves the
   * account required to change it at its next sign-in.
   */
  async submitPassword(password: string, changeOnLogin: boolean): Promise<void> {
    const pending = this.waiting();
    this.waiting.set(null);
    if (pending === null || pending.kind !== 'set-password' || password === '') return;
    if (changeOnLogin) {
      const flagged = await this.send(pending.descriptor, REQUIRE_PASSWORD_CHANGE, pending.target);
      if (!flagged) return;
    }
    const set = await this.send(pending.descriptor, pending.actionId, pending.target, { [PASSWORD_VALUE]: password });
    if (set && changeOnLogin) await this.send(pending.descriptor, REQUIRE_PASSWORD_CHANGE, pending.target);
  }

  /** The role dialog was submitted: one role, applied on the instance as a delta (AD-56 (ii)). */
  submitRole(role: string): void {
    const pending = this.waiting();
    this.waiting.set(null);
    if (pending === null || pending.kind !== 'role' || role === '') return;
    void this.send(pending.descriptor, pending.actionId, pending.target, { [ROLE_VALUE]: role });
  }

  /** Escape, Cancel or the scrim: nothing was sent and nothing is. */
  cancelPending(): void {
    this.waiting.set(null);
  }

  /** Open the dialog, or send at once where the action is not destructive. */
  private start(screen: ScreenDeclaration, actionId: string): void {
    const target = this.selected(screen);
    if (target === '') return;
    // The surfaces already list a self-protected action as refused rather than selectable, so this
    // is the second half of the same explanation and not a second predicate: the instance refuses
    // it either way, with this same sentence (AD-10, AD-53).
    const rule = screen.rowActions.find((action) => action.id === actionId)?.selfProtection ?? '';
    const refusal = selfProtectionReason(rule, target, this.session?.userName() ?? '');
    if (refusal !== '') {
      this.store(screen.descriptor, screen.refreshRates).setRefusal(refusal);
      return;
    }
    const dialog = VALUE_ACTIONS[screen.descriptor]?.[actionId];
    if (dialog === 'set-password') {
      this.open('set-password', screen.descriptor, actionId, target, '', []);
      return;
    }
    if (dialog === 'role') {
      void this.openRole(screen, actionId, target);
      return;
    }
    const warning = this.warning(screen.descriptor, actionId);
    if (warning !== '') {
      this.open('warning', screen.descriptor, actionId, target, warning, []);
      return;
    }
    if (!this.isDestructive(actionId)) {
      void this.send(screen.descriptor, actionId, target);
      return;
    }
    this.open('typed-name', screen.descriptor, actionId, target, this.consequence(screen.descriptor, actionId), []);
  }

  private open(
    kind: PendingKind,
    descriptor: string,
    actionId: string,
    target: string,
    consequence: string,
    options: readonly string[]
  ): void {
    this.waiting.set({
      kind,
      descriptor,
      actionId,
      verb: actionLabel(descriptor, actionId),
      target,
      consequence,
      options,
    });
  }

  /**
   * Open the role dialog. A remove offers the row's own roles; an add offers the Roles list's
   * declared read -- issued through the ordinary read route, so that screen's own gate and cap
   * apply (AD-5) -- minus the roles the row holds. No choice is pre-marked: whether a role may be
   * granted is the instance's answer at the write (AD-10).
   */
  private async openRole(screen: ScreenDeclaration, actionId: string, target: string): Promise<void> {
    const held = this.rowRoles(screen, target);
    if (actionId === REMOVE_ROLE) {
      this.open('role', screen.descriptor, actionId, target, '', held);
      return;
    }
    const roles = SCREENS.find((entry) => entry.toolIdentifier === ROLES_TOOL_IDENTIFIER);
    if (roles === undefined || roles.read === null) return;
    const result = await this.injector
      .get(ApiService)
      .requestJson<{ readonly rows?: unknown }>(screenReadPath(roles, DEFAULT_MAX_ROWS));
    if (result.kind !== 'ok' || !Array.isArray(result.body?.rows)) {
      this.store(screen.descriptor, screen.refreshRates).setRefusal(result.kind === 'error' ? (result.reason ?? '') : '');
      return;
    }
    const heldKeys = new Set(held.map((name) => name.toLowerCase()));
    const offered = (result.body.rows as readonly unknown[])
      .map((row) => rowKey(row, roles))
      .filter((name) => name !== '' && !heldKeys.has(name.toLowerCase()));
    this.open('role', screen.descriptor, actionId, target, '', offered);
  }

  /** The roles the row `target` holds on the screen's last read, as the instance spells them. */
  private rowRoles(screen: ScreenDeclaration, target: string): readonly string[] {
    const row = this.store(screen.descriptor, screen.refreshRates)
      .data()
      .find((entry) => rowKey(entry, screen) === target);
    if (row === undefined || row === null || typeof row !== 'object') return [];
    const roles = (row as Record<string, unknown>)['Roles'];
    return Array.isArray(roles) ? roles.filter((name): name is string => typeof name === 'string' && name !== '') : [];
  }

  /**
   * The one request, and what its answer publishes; `true` when the instance applied it. `values`
   * travels only where the action's tool declares values, and is sent as given (AD-56).
   */
  private async send(descriptor: string, actionId: string, target: string, values?: ActionValues): Promise<boolean> {
    const screen = SCREENS.find((entry) => entry.descriptor === descriptor);
    if (screen === undefined) return false;
    const store = this.store(descriptor, screen.refreshRates);
    store.setRefusal('');
    const request: { action: string; id: string; values?: ActionValues } = { action: actionId, id: target };
    if (values !== undefined) request.values = values;
    const result = await this.injector.get(ApiService).requestJson<ScreenActionAnswer>(
      `${SCREEN_READ_PATH_PREFIX}${encodeURIComponent(screen.toolIdentifier)}${SCREEN_ACTION_PATH_SUFFIX}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(request),
      }
    );
    if (result.kind !== 'ok') {
      // The envelope's own sentence (AD-39). A refused write changed nothing, so nothing is
      // published and no row is marked.
      store.setRefusal(result.kind === 'error' ? (result.reason ?? '') : '');
      return false;
    }
    const answer = result.body;
    const targetRef = answer?.target;
    if (targetRef === undefined) return true;
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: targetRef.type ?? '',
      scope: targetRef.scope ?? '',
      id: targetRef.id ?? '',
      // The verb is the instance's, never inferred here: the vocabulary is the kernel's closed set
      // and a screen routes on it (AD-14).
      action: (answer?.action ?? '') as ChangeAction,
    });
    return true;
  }

  /** The key of the row the screen has selected, or `''`. */
  private selected(screen: ScreenDeclaration): string {
    return this.store(screen.descriptor, screen.refreshRates).selection()[0] ?? '';
  }

  /**
   * The screen's own store. The rates are the declaration's, always: `ScreenStores.for` takes them
   * on the call that first creates the store, so a caller passing an empty list could be the one
   * that decides a refreshing screen has no rates.
   */
  private store(descriptor: string, rates: readonly number[]): ReturnType<ScreenStores['for']> {
    return this.stores.for(descriptor, rates);
  }

  private isDestructive(actionId: string): boolean {
    return DESTRUCTIVE_ACTIONS.includes(actionId);
  }

  private warning(descriptor: string, actionId: string): string {
    const own = WARNING_CONSEQUENCES[descriptor];
    if (own === undefined) return '';
    return Object.hasOwn(own, actionId) ? own[actionId] : '';
  }

  private consequence(descriptor: string, actionId: string): string {
    const own = DESTRUCTIVE_CONSEQUENCES[descriptor];
    if (own === undefined) return '';
    return Object.hasOwn(own, actionId) ? own[actionId] : '';
  }
}
