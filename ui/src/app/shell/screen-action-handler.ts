import { Injectable, Injector, inject, signal } from '@angular/core';

import { AGENT_WRITE_EVENT } from '../core/agent-status';
import { ApiService } from '../core/api';
import { ChangeBus, type ChangeAction } from '../core/change-bus';
import { splitCompositeId } from '../core/entity-id';
import { ScreenActions, actionLabel } from '../core/screen-actions';
import { SCREEN_READ_PATH_PREFIX } from '../core/screen-read';
import { ScreenStores } from '../core/screen-store';
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
 * configuration form (Story 7.4), whose page selects the singleton itself, and the On-demand tasks
 * list (Story 7.5), whose Run is sent at once with no dialog, and the Task schedule (Story 7.6),
 * whose Run, Suspend and Resume are sent at once and whose Delete types the task's name, and
 * Processes and Process details (Story 7.8), whose Suspend and Resume are sent at once and whose
 * Terminate types the pid, and the application error log (Story 7.10), whose one Delete names the
 * scope its target's composite id selects, and the System events and User events lists (Story 7.11),
 * whose Enable and Reset counters are sent at once, whose marker-event Disable warns first, and
 * whose user-event Delete types the event's name.
 */
export const SCREEN_ACTION_DESCRIPTORS: readonly string[] = [
  'OcuPilot.Screen.Descriptor.WebAppList',
  'OcuPilot.Screen.Descriptor.OAuthClientTab',
  'OcuPilot.Screen.Descriptor.OAuthServerClientTab',
  'OcuPilot.Screen.Descriptor.UserList',
  'OcuPilot.Screen.Descriptor.AuditingConfig',
  'OcuPilot.Screen.Descriptor.TaskOnDemandList',
  'OcuPilot.Screen.Descriptor.TaskScheduleList',
  'OcuPilot.Screen.Descriptor.ProcessList',
  'OcuPilot.Screen.Descriptor.ProcessDetails',
  'OcuPilot.Screen.Descriptor.LogErrorList',
  'OcuPilot.Screen.Descriptor.AuditSystemEventList',
  'OcuPilot.Screen.Descriptor.AuditUserEventList',
];

/** The Users list's descriptor, whose row actions carry values (AD-56). */
const USER_LIST = 'OcuPilot.Screen.Descriptor.UserList';

/** The Web applications list's descriptor, whose four role actions the web application editor sends (Story 9.2). */
const WEB_APP_LIST = 'OcuPilot.Screen.Descriptor.WebAppList';

/** The web application role actions, and the values each sends (AD-56 (ii)). */
export const ADD_APPLICATION_ROLE = 'add-application-role';
export const REMOVE_APPLICATION_ROLE = 'remove-application-role';
export const ADD_MATCHING_ROLE = 'add-matching-role';
export const REMOVE_MATCHING_ROLE = 'remove-matching-role';

/** The Task schedule's descriptor, whose delete types a name that is not its row key. */
const TASK_SCHEDULE = 'OcuPilot.Screen.Descriptor.TaskScheduleList';

/** The processes list and Process details, whose Terminate carries the error-to-job flag. */
const PROCESS_LIST = 'OcuPilot.Screen.Descriptor.ProcessList';
const PROCESS_DETAILS = 'OcuPilot.Screen.Descriptor.ProcessDetails';

/** The application error log, whose delete's scope is its target's composite id (Story 7.10). */
const LOG_ERROR_LIST = 'OcuPilot.Screen.Descriptor.LogErrorList';

/** The User events list, whose delete and marker-event disable state a consequence (Story 7.11). */
const AUDIT_USER_EVENT_LIST = 'OcuPilot.Screen.Descriptor.AuditUserEventList';

/** The Terminate dialog's flagged action: declared, undrawn, sent only by the checked flag. */
export const TERMINATE_WITH_ERROR = 'terminate-with-error';

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

/**
 * The form read whose `roles` an add offers, each marked `privileged` by the server's own
 * classifier (AD-10): the Add role dialog states the grant's consequence from it (DW-1523).
 */
export const USER_FORM_READ_PATH = '/api/ocupilot/users/form';

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
  // The web application editor draws these beside each roles tab's pickers, which supply the values.
  [WEB_APP_LIST]: [ADD_APPLICATION_ROLE, REMOVE_APPLICATION_ROLE, ADD_MATCHING_ROLE, REMOVE_MATCHING_ROLE],
  [PROCESS_LIST]: [TERMINATE_WITH_ERROR],
  [PROCESS_DETAILS]: [TERMINATE_WITH_ERROR],
};

/**
 * The optional flag a typed-name dialog offers, keyed by descriptor and then by action id: the
 * checkbox's published label and the declared action a checked box sends in place of the one the
 * dialog was opened for. Each flagged action is its own write tool, because the flag cannot travel
 * as a value on a bodyless write (AD-51, AD-56).
 */
const FLAGGED_ACTIONS: Readonly<Record<string, Readonly<Record<string, { readonly label: string; readonly action: string }>>>> = {
  [PROCESS_LIST]: { terminate: { label: STRINGS.processTerminateErrorFlag, action: TERMINATE_WITH_ERROR } },
  [PROCESS_DETAILS]: { terminate: { label: STRINGS.processTerminateErrorFlag, action: TERMINATE_WITH_ERROR } },
};

/**
 * The screen whose action route a descriptor's row actions are sent to, where it is not the
 * descriptor's own: Process details acts on the pid it shows through the processes list's write
 * tools, which name that list (AD-53).
 */
const ACTION_ADDRESS: Readonly<Record<string, string>> = {
  [PROCESS_DETAILS]: PROCESS_LIST,
};

/**
 * The row actions this handler confirms with the typed-name dialog before it sends anything.
 *
 * **It decides which dialog a person sees, never what may happen.** Whether a write is refused is
 * the instance's (AD-10); whether a card draws the destructive treatment is the tool's own
 * `DESTRUCTIVE` declaration. This is EXPERIENCE.md's `confirm-dialog` rule -- a delete carries the
 * typed-name field and a `button-destructive` -- applied to the verb that deletes.
 */
const DESTRUCTIVE_ACTIONS: readonly string[] = ['delete', 'terminate'];

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
  [TASK_SCHEDULE]: { delete: STRINGS.taskDeleteConsequence },
  [PROCESS_LIST]: { terminate: STRINGS.processTerminateConsequence },
  [PROCESS_DETAILS]: { terminate: STRINGS.processTerminateConsequence },
  [LOG_ERROR_LIST]: { delete: STRINGS.errorDeleteEveryConsequence },
  [AUDIT_USER_EVENT_LIST]: { delete: STRINGS.auditUserEventDeleteConsequence },
};

/**
 * A destructive action whose target is a composite id naming a scope, keyed by descriptor and
 * then by action id: one `{verb, consequence}` per part count, the whole namespace first. The
 * typed-name dialog takes the entry for the target's own count, and asks for the target's last
 * part -- the namespace, the date or the error number -- rather than the joined id, which carries
 * a separator no one can type. A count with no entry falls back to the action's own label and
 * `DESTRUCTIVE_CONSEQUENCES`.
 */
const SCOPED_TARGETS: Readonly<
  Record<string, Readonly<Record<string, ReadonlyArray<{ readonly verb: string; readonly consequence: string }>>>>
> = {
  [LOG_ERROR_LIST]: {
    delete: [
      { verb: STRINGS.errorDeleteEveryVerb, consequence: STRINGS.errorDeleteEveryConsequence },
      { verb: STRINGS.errorDeleteDateVerb, consequence: STRINGS.errorDeleteDateConsequence },
      { verb: STRINGS.errorDeleteOneVerb, consequence: STRINGS.errorDeleteOneConsequence },
    ],
  },
};

/**
 * What a typed-name dialog reads off the selected row, keyed by descriptor, where it reads more
 * than the row key.
 *
 * `name` is the field the dialog titles and types. A task is keyed by its numeric `Id`, which the
 * write is sent with, while a person recognises it by its `Name`, so the dialog asks for the name
 * and the request still carries the id. A screen with no entry types its row key.
 *
 * `advisory` is a second sentence the dialog states when the row's `field` reads `equals` -- an
 * advisory, not a refusal: the delete is still offered, and whether it may happen is the
 * instance's answer (AD-10).
 */
const TYPED_NAME_ROWS: Readonly<
  Record<string, { readonly name: string; readonly field: string; readonly equals: string; readonly advisory: string }>
> = {
  [TASK_SCHEDULE]: { name: 'Name', field: 'Type', equals: 'System', advisory: STRINGS.taskSystemDeleteConsequence },
  // Deleting OcuPilot's own marker event stops agent writes being marked (AD-15).
  [AUDIT_USER_EVENT_LIST]: { name: 'EventName', field: 'EventName', equals: AGENT_WRITE_EVENT, advisory: STRINGS.proposalAuditWarning },
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

/**
 * The warning a non-delete write states for one row only, keyed by descriptor and then by action id:
 * the warning dialog opens when the selected row's `field` reads `equals`, and the action is sent at
 * once for every other row. Consulted after `WARNING_CONSEQUENCES`.
 */
const WARNING_ROWS: Readonly<
  Record<string, Readonly<Record<string, { readonly field: string; readonly equals: string; readonly consequence: string }>>>
> = {
  // Disabling OcuPilot's own marker event stops agent writes being marked (AD-15).
  [AUDIT_USER_EVENT_LIST]: { disable: { field: 'EventName', equals: AGENT_WRITE_EVENT, consequence: STRINGS.proposalAuditWarning } },
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
 *
 * `target` is the row key the write is sent with. `name` is what the typed-name dialog titles and
 * asks for -- the row key itself unless the screen names another field (`TYPED_NAME_ROWS`) --
 * `advisory` the dialog's second sentence, `''` when none applies, and `flagLabel` the label of
 * the dialog's optional checkbox (`FLAGGED_ACTIONS`), `''` when it offers none.
 */
export interface PendingConfirm {
  readonly kind: PendingKind;
  readonly descriptor: string;
  readonly actionId: string;
  readonly verb: string;
  readonly target: string;
  readonly name: string;
  readonly consequence: string;
  readonly advisory: string;
  readonly flagLabel: string;
  readonly options: readonly string[];
  /** The role dialog's choices that grant %All or an administrative privilege (AD-10, DW-1523). */
  readonly privileged: readonly string[];
}

/**
 * Where an action started with `startFor` reports back: the refusal sentence to show (AD-39), and,
 * optionally, that the instance applied the action. A list page's sink is its screen store; an
 * editor supplies its own.
 */
export interface ActionSink {
  setRefusal(reason: string): void;
  applied?(actionId: string): void;
}

/** The fields of the row an action is about, where the caller holds them. */
export type RowFields = Readonly<Record<string, unknown>> | null;

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
 * action `aria-disabled` with "Select a row first" in that state. An editor names its own entity
 * instead, through `startFor` (DW-1501).
 *
 * **A destructive action opens the typed-name dialog first** and sends nothing until it is
 * confirmed. `app-screen-action-dialogs` renders the dialog from `pending()` on the page the
 * action was started from -- the list, or the user editor -- over the shell's one modal surface
 * (`dialog.ts`).
 *
 * **Nothing is patched from the write's own answer** (AD-14). A confirmed write publishes the
 * triple and verb the instance answered on the change bus; the refresh framework re-fetches the
 * screen in place and marks the row. A refusal publishes nothing and puts the envelope's own
 * sentence on the caller's sink -- a list's store, which `ListPage` renders, or an editor's own
 * (AD-39).
 */
@Injectable({ providedIn: 'root' })
export class ScreenActionHandler {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  private readonly stores = inject(ScreenStores);

  private readonly session = inject(Session, { optional: true });

  private readonly waiting = signal<PendingConfirm | null>(null);

  /** The sink of the action `waiting` holds, which its dialog's answer reports to. */
  private waitingSink: ActionSink | null = null;

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

  /**
   * The typed name matched, or the warning was proceeded past: send the write the dialog was
   * standing in front of. `flag` is the dialog's checkbox; checked, the flagged action is sent in
   * place of the one the dialog was opened for, and nothing else about the request changes.
   */
  confirmPending(flag = false): void {
    const pending = this.waiting();
    const sink = this.takeSink();
    if (pending === null || (pending.kind !== 'typed-name' && pending.kind !== 'warning')) return;
    const flagged = flag ? this.flag(pending.descriptor, pending.actionId) : null;
    void this.send(pending.descriptor, flagged?.action ?? pending.actionId, pending.target, undefined, sink);
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
    const sink = this.takeSink();
    if (pending === null || pending.kind !== 'set-password' || password === '') return;
    if (changeOnLogin) {
      const flagged = await this.send(pending.descriptor, REQUIRE_PASSWORD_CHANGE, pending.target, undefined, sink);
      if (!flagged) return;
    }
    const set = await this.send(pending.descriptor, pending.actionId, pending.target, { [PASSWORD_VALUE]: password }, sink);
    if (set && changeOnLogin) await this.send(pending.descriptor, REQUIRE_PASSWORD_CHANGE, pending.target, undefined, sink);
  }

  /** The role dialog was submitted: one role, applied on the instance as a delta (AD-56 (ii)). */
  submitRole(role: string): void {
    const pending = this.waiting();
    const sink = this.takeSink();
    if (pending === null || pending.kind !== 'role' || role === '') return;
    void this.send(pending.descriptor, pending.actionId, pending.target, { [ROLE_VALUE]: role }, sink);
  }

  /** Escape, Cancel or the scrim: nothing was sent and nothing is. */
  cancelPending(): void {
    this.takeSink();
  }

  /**
   * Start declared action `actionId` of `descriptor` on the row keyed `target`, as a row menu does:
   * open its dialog, or send it at once where it has none (AD-53). `rowFields` is that row's own
   * fields where the caller holds them -- a Remove role reads its `Roles` -- and `sink` is where a
   * refusal, and optionally the applied write, is reported. A list page passes its selected row and
   * its store; an editor passes the entity it shows and its own sink (DW-1501).
   *
   * `role`, for a role action, is the one role the caller has already chosen, which is sent with no
   * dialog -- the Remove beside one role of an editor's list. `values`, where given, are the
   * action's declared values the caller has already chosen, sent at once with no dialog -- the web
   * application editor's role pickers (AD-56 (ii)).
   */
  startFor(
    descriptor: string,
    actionId: string,
    target: string,
    rowFields: RowFields,
    sink: ActionSink,
    role = '',
    values?: ActionValues
  ): void {
    const screen = SCREENS.find((entry) => entry.descriptor === descriptor);
    if (screen === undefined || target === '') return;
    // The surfaces already list a self-protected action as refused rather than selectable, so this
    // is the second half of the same explanation and not a second predicate: the instance refuses
    // it either way, with this same sentence (AD-10, AD-53).
    const rule = screen.rowActions.find((action) => action.id === actionId)?.selfProtection ?? '';
    const refusal = selfProtectionReason(rule, target, this.session?.userName() ?? '');
    if (refusal !== '') {
      sink.setRefusal(refusal);
      return;
    }
    if (values !== undefined) {
      void this.send(descriptor, actionId, target, values, sink);
      return;
    }
    const dialog = VALUE_ACTIONS[descriptor]?.[actionId];
    if (dialog === 'set-password') {
      this.open('set-password', descriptor, actionId, target, '', [], sink);
      return;
    }
    if (dialog === 'role') {
      if (role !== '') {
        void this.send(descriptor, actionId, target, { [ROLE_VALUE]: role }, sink);
        return;
      }
      void this.openRole(descriptor, actionId, target, rowFields, sink);
      return;
    }
    const warning = this.warning(descriptor, actionId) || this.rowWarning(descriptor, actionId, rowFields);
    if (warning !== '') {
      this.open('warning', descriptor, actionId, target, warning, [], sink);
      return;
    }
    if (!this.isDestructive(actionId)) {
      void this.send(descriptor, actionId, target, undefined, sink);
      return;
    }
    const scoped = this.scoped(descriptor, actionId, target);
    if (scoped !== null) {
      this.open('typed-name', descriptor, actionId, target, scoped.consequence, [], sink, scoped.name, '', scoped.verb);
      return;
    }
    // The row's own name and advisory, where the screen declares them; the row key otherwise.
    const read = TYPED_NAME_ROWS[descriptor];
    const row = read === undefined ? null : rowFields;
    const name = row?.[read?.name ?? ''];
    this.open(
      'typed-name',
      descriptor,
      actionId,
      target,
      this.consequence(descriptor, actionId),
      [],
      sink,
      typeof name === 'string' && name !== '' ? name : target,
      row !== null && row[read?.field ?? ''] === read?.equals ? (read?.advisory ?? '') : ''
    );
  }

  /** A row menu's action: `startFor` on the list's selected row, reporting to the list's store. */
  private start(screen: ScreenDeclaration, actionId: string): void {
    const target = this.selected(screen);
    if (target === '') return;
    this.startFor(screen.descriptor, actionId, target, this.row(screen, target), this.store(screen.descriptor, screen.refreshRates));
  }

  private open(
    kind: PendingKind,
    descriptor: string,
    actionId: string,
    target: string,
    consequence: string,
    options: readonly string[],
    sink: ActionSink,
    name: string = target,
    advisory = '',
    verb: string = actionLabel(descriptor, actionId),
    privileged: readonly string[] = []
  ): void {
    this.waitingSink = sink;
    this.waiting.set({
      kind,
      descriptor,
      actionId,
      verb,
      target,
      name,
      consequence,
      advisory,
      flagLabel: kind === 'typed-name' ? (this.flag(descriptor, actionId)?.label ?? '') : '',
      options,
      privileged,
    });
  }

  /** Clear the pending dialog and answer the sink it was opened with. */
  private takeSink(): ActionSink | null {
    const sink = this.waitingSink;
    this.waitingSink = null;
    this.waiting.set(null);
    return sink;
  }

  /**
   * Open the role dialog. A remove offers the row's own roles; an add offers the roles
   * `GET /users/form` lists -- the form read's own gate applies -- minus the roles the row holds,
   * with the server's `privileged` mark on each, so the dialog states the grant's consequence
   * (AD-10, DW-1523). Whether a role may be granted is the instance's answer at the write.
   */
  private async openRole(descriptor: string, actionId: string, target: string, rowFields: RowFields, sink: ActionSink): Promise<void> {
    const held = rowRoles(rowFields);
    if (actionId === REMOVE_ROLE) {
      this.open('role', descriptor, actionId, target, '', held, sink);
      return;
    }
    const result = await this.injector.get(ApiService).requestJson<{ readonly roles?: unknown }>(USER_FORM_READ_PATH);
    if (result.kind !== 'ok' || !Array.isArray(result.body?.roles)) {
      sink.setRefusal(result.kind === 'error' ? (result.reason ?? '') : '');
      return;
    }
    const heldKeys = new Set(held.map((name) => name.toLowerCase()));
    const offered: string[] = [];
    const privileged: string[] = [];
    for (const entry of result.body.roles as readonly unknown[]) {
      if (entry === null || typeof entry !== 'object') continue;
      const name = (entry as Record<string, unknown>)['name'];
      if (typeof name !== 'string' || name === '' || heldKeys.has(name.toLowerCase())) continue;
      offered.push(name);
      // A role whose flag the server did not send as false is marked, so the consequence is
      // stated rather than missed.
      const flag = (entry as Record<string, unknown>)['privileged'];
      if (!(flag === false || flag === 0)) privileged.push(name);
    }
    this.open('role', descriptor, actionId, target, '', offered, sink, target, '', actionLabel(descriptor, actionId), privileged);
  }

  /** The row keyed `target` on the screen's last read, or `null`. */
  private row(screen: ScreenDeclaration, target: string): Readonly<Record<string, unknown>> | null {
    const row = this.store(screen.descriptor, screen.refreshRates)
      .data()
      .find((entry) => rowKey(entry, screen) === target);
    if (row === undefined || row === null || typeof row !== 'object') return null;
    return row as Readonly<Record<string, unknown>>;
  }

  /**
   * The one request, and what its answer publishes; `true` when the instance applied it. `values`
   * travels only where the action's tool declares values, and is sent as given (AD-56). It is sent
   * to the action route of the screen `ACTION_ADDRESS` names, or the descriptor's own; a refusal is
   * put on the descriptor's own store, which is the page the person acted on.
   */
  private async send(
    descriptor: string,
    actionId: string,
    target: string,
    values?: ActionValues,
    sink: ActionSink | null = null
  ): Promise<boolean> {
    const screen = SCREENS.find((entry) => entry.descriptor === descriptor);
    if (screen === undefined) return false;
    const addressed = SCREENS.find((entry) => entry.descriptor === (ACTION_ADDRESS[descriptor] ?? descriptor));
    if (addressed === undefined) return false;
    const store = sink ?? this.store(descriptor, screen.refreshRates);
    store.setRefusal('');
    const request: { action: string; id: string; values?: ActionValues } = { action: actionId, id: target };
    if (values !== undefined) request.values = values;
    const result = await this.injector.get(ApiService).requestJson<ScreenActionAnswer>(
      `${SCREEN_READ_PATH_PREFIX}${encodeURIComponent(addressed.toolIdentifier)}${SCREEN_ACTION_PATH_SUFFIX}`,
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
    sink?.applied?.(actionId);
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

  /**
   * Send `actionId` for `target` on `descriptor` with no dialog, as a row action would, and answer
   * whether the instance applied it. For a page that composes several actions itself -- the
   * Selective SQL auditing dialog -- so each still takes the one request and change event `send`
   * makes.
   */
  sendFor(descriptor: string, actionId: string, target: string): Promise<boolean> {
    return this.send(descriptor, actionId, target);
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

  /** The `WARNING_ROWS` consequence for the row `rowFields`, or `''` where it does not match. */
  private rowWarning(descriptor: string, actionId: string, rowFields: RowFields): string {
    const own = WARNING_ROWS[descriptor];
    if (own === undefined || !Object.hasOwn(own, actionId)) return '';
    const entry = own[actionId];
    return rowFields?.[entry.field] === entry.equals ? entry.consequence : '';
  }

  private flag(descriptor: string, actionId: string): { readonly label: string; readonly action: string } | null {
    const own = FLAGGED_ACTIONS[descriptor];
    if (own === undefined) return null;
    return Object.hasOwn(own, actionId) ? own[actionId] : null;
  }

  /**
   * The verb, consequence and typed name `SCOPED_TARGETS` gives `target`'s part count, or `null`
   * where the action is not scoped or the count has no entry.
   */
  private scoped(
    descriptor: string,
    actionId: string,
    target: string
  ): { readonly verb: string; readonly consequence: string; readonly name: string } | null {
    const own = SCOPED_TARGETS[descriptor];
    if (own === undefined || !Object.hasOwn(own, actionId)) return null;
    const parts = splitCompositeId(target);
    const entry = own[actionId][parts.length - 1];
    if (entry === undefined) return null;
    return { verb: entry.verb, consequence: entry.consequence, name: parts[parts.length - 1] };
  }

  private consequence(descriptor: string, actionId: string): string {
    const own = DESTRUCTIVE_CONSEQUENCES[descriptor];
    if (own === undefined) return '';
    return Object.hasOwn(own, actionId) ? own[actionId] : '';
  }
}

/** The roles `rowFields` holds, as the instance spells them. */
function rowRoles(rowFields: RowFields): readonly string[] {
  const roles = rowFields?.['Roles'];
  return Array.isArray(roles) ? roles.filter((name): name is string => typeof name === 'string' && name !== '') : [];
}
