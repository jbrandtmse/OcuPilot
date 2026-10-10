/**
 * The handlers that run a screen's declared actions (AD-5, AD-19).
 *
 * A descriptor declares its actions; the screen that can carry one out registers a handler for
 * it here, keyed by the descriptor's class name and the action's declared id. The command bar
 * and the command box offer a primary action only while `has` answers `true`, and both surfaces
 * run it through `run`, so neither draws a control nothing can act on.
 *
 * Framework-free, like the rest of `core/`: a plain subscribable that components mirror into a
 * signal.
 */

import type { ScreenDeclaration } from './screens.generated';
import { STRINGS } from './strings.ts';

/** What runs one declared action. */
export type ScreenActionRun = () => void;

/**
 * The well-known id of the Refresh action a screen with a read registers (DW-260).
 *
 * **It is not a descriptor `primaryAction` or `rowAction`.** Refresh re-reads whatever the screen
 * already reads; it is shell behaviour over a declared read, not one of the screen's own declared
 * actions, and adding it to a descriptor would have made every Epic 2 screen action-bearing --
 * which is what the empty state's agent invitation and `AdminPort.TYPESUFFIXES` both key off.
 * Registering it here instead is what lets both surfaces offer it on exactly the screens that can
 * carry it out: a screen with nothing to re-read registers none, and the audit viewer registers
 * only once it has a search to re-run.
 */
export const REFRESH_ACTION_ID = 'refresh';

/** Download CSV (Story 16.23): a view control the data table registers, which the command box does not list. */
export const DOWNLOAD_CSV_ACTION_ID = 'download-csv';

/**
 * Check permission (Story 16.3): like Refresh, a screen-level action rather than a declared one. It
 * needs no row -- a selected row or the open user or role only prefills its dialog -- so it is never
 * held back for want of a selection, and a descriptor declaring it would make the Users and Roles
 * lists write-capable (`Registry.IsWriteCapable`).
 */
export const PERMISSION_CHECK_ACTION_ID = 'permission-check';

/**
 * Import on Task schedule (Story 16.4), and on System Explorer's Classes and Routines lists (Story
 * 19.13): screen-level like Check permission. It names a file, not a row, so it is never held back
 * for want of a selection. Each descriptor declares `import` so the action route admits it; this id
 * is what those pages register and the two surfaces draw.
 */
export const TASK_IMPORT_ACTION_ID = 'task-import';

/**
 * Suspend Task Manager on Task schedule (Story 16.11): screen-level like Import. It names the Task
 * Manager, not a row, so it is never held back for want of a selection. The descriptor declares
 * `suspendmanager` so the action route admits it; this id is what the Task schedule's page registers
 * and the two surfaces draw.
 */
export const TASK_MANAGER_SUSPEND_ACTION_ID = 'task-manager-suspend';

/**
 * Switch file and Switch directory on Journals (Story 18.5): screen-level like Suspend Task Manager.
 * Each names the journal the instance writes now, not a row, so neither is held back for want of a
 * selection. The descriptor declares `switchfile` and `switchdirectory` so the action route admits
 * them; these ids are what the Journals page registers and the two surfaces draw.
 */
export const JOURNAL_SWITCH_FILE_ACTION_ID = 'journal-switch-file';
export const JOURNAL_SWITCH_DIRECTORY_ACTION_ID = 'journal-switch-directory';

/**
 * The declared actions `screen`'s banner cases offer (Story 16.11, AD-5), in case order. Each is
 * screen-level: it names no row, so the command bar draws none of them as a row action -- the strip
 * does -- and the command box lists them beside the screen's other screen-level actions.
 */
export function bannerActionIds(screen: Pick<ScreenDeclaration, 'banner'>): readonly string[] {
  const ids: string[] = [];
  for (const entry of screen.banner?.cases ?? []) {
    const id = entry.action ?? '';
    if (id !== '' && !ids.includes(id)) ids.push(id);
  }
  return ids;
}

/**
 * The label a surface draws for `actionId` on `descriptor`.
 *
 * A declared action's label is its own identifier until a screen carries published copy for it.
 * Both the command bar and the command box resolve through here, so the two surfaces cannot name
 * the same action two ways -- which is exactly what `command-bar.spec.ts`'s reachability assertion
 * compares.
 *
 * **The descriptor is not decoration** (DW-370). One action id means different things on different
 * screens: `create` is "Create" on the Definitions list and "Switch off a user" on Switches, and a
 * map keyed by the bare id can only ever draw one of them. A screen's own entry wins; an id the
 * screen publishes nothing for falls back to the shared map, which is where an action that means
 * the same thing everywhere lives.
 */
export function actionLabel(descriptor: string, actionId: string): string {
  const own = Object.hasOwn(DESCRIPTOR_ACTION_LABELS, descriptor)
    ? DESCRIPTOR_ACTION_LABELS[descriptor]
    : undefined;
  if (own !== undefined && Object.hasOwn(own, actionId)) return own[actionId];
  return Object.hasOwn(ACTION_LABELS, actionId) ? ACTION_LABELS[actionId] : actionId;
}

/**
 * The actions that carry published copy wherever they appear, keyed by the id a descriptor
 * declares (or, for Refresh, by the well-known id above).
 *
 * An id with no entry here and none on its screen renders as itself, which is the state every
 * action was in until a screen published words for one: `ActionDeclaration` carries no label key,
 * so these maps are where a declared action's name lives until it does.
 */
const ACTION_LABELS: Readonly<Record<string, string>> = {
  [REFRESH_ACTION_ID]: STRINGS.actionRefresh,
  [PERMISSION_CHECK_ACTION_ID]: STRINGS.permissionCheckAction,
  [TASK_IMPORT_ACTION_ID]: STRINGS.actionImport,
  [TASK_MANAGER_SUSPEND_ACTION_ID]: STRINGS.taskManagerSuspendAction,
  [JOURNAL_SWITCH_FILE_ACTION_ID]: STRINGS.journalSwitchFileAction,
  [JOURNAL_SWITCH_DIRECTORY_ACTION_ID]: STRINGS.journalSwitchDirectoryAction,
  create: STRINGS.actionCreate,
  enable: STRINGS.agentDefinitionEnable,
  disable: STRINGS.agentDefinitionDisable,
  // The published verb a delete carries wherever one is offered -- the row menu, the command bar,
  // the command box and the typed-name dialog's own title and button. A screen whose delete means
  // something narrower publishes its own words below (Switches' removes a hold, not an entity).
  delete: STRINGS.actionDelete,
  'set-default': STRINGS.agentDefinitionSetDefault,
  // Story 7.5: a task's Run, on On-demand tasks and the Task schedule.
  run: STRINGS.actionRun,
  // Story 7.6: a task's Suspend and Resume, on the Task schedule.
  suspend: STRINGS.actionSuspend,
  resume: STRINGS.actionResume,
  // Story 7.8: a process's Terminate, on Processes and Process details.
  terminate: STRINGS.actionTerminate,
  // Story 7.11: an audit event's Reset counters, on System events and User events.
  reset: STRINGS.actionResetCounters,
  // Story 16.5: a background task's Pause, on Background tasks.
  pause: STRINGS.actionPause,
  // Story 16.10: an external language server's Start and Stop, on External language servers.
  start: STRINGS.actionStart,
  stop: STRINGS.actionStop,
  // Story 20.2: a production's Restart, Update and Recover, on Productions.
  restart: STRINGS.actionRestart,
  update: STRINGS.actionUpdate,
  recover: STRINGS.actionRecover,
};

/**
 * The actions one screen publishes its own words for, keyed by the descriptor class name the
 * mirror carries and then by the action id (DW-370).
 *
 * Switches is the first screen here: its `create` adds a per-user hold and its `delete` removes
 * one, and EXPERIENCE.md publishes a sentence for each. Both ids also mean something else
 * elsewhere, which is the whole reason this map is keyed by descriptor.
 */
const DESCRIPTOR_ACTION_LABELS: Readonly<Record<string, Readonly<Record<string, string>>>> = {
  // Story 20.3: Production items' Add opens the dialog that adds one item, and its Remove deletes one.
  'OcuPilot.Screen.Descriptor.InteropItemList': { add: STRINGS.interopItemAddTitle, remove: STRINGS.actionRemove },
  // Story 8.5: the X.509 list's Create imports a credential rather than typing one in.
  'OcuPilot.Screen.Descriptor.X509CredentialList': { create: STRINGS.actionImport },
  'OcuPilot.Screen.Descriptor.AgentSwitches': {
    create: STRINGS.agentSwitchesHoldAdd,
    delete: STRINGS.agentSwitchesHoldRemove,
  },
  // Story 7.2: the Users list's three value-carrying row actions; Story 12.2: its token revoke.
  'OcuPilot.Screen.Descriptor.UserList': {
    'set-password': STRINGS.userActionSetPassword,
    'add-role': STRINGS.userActionAddRole,
    'remove-role': STRINGS.userActionRemoveRole,
    'revoke-tokens': STRINGS.userActionRevokeTokens,
    // Story 18.9: the SQL privileges tab's two actions.
    'grant-sql': STRINGS.sqlPrivilegeGrantAction,
    'revoke-sql': STRINGS.sqlPrivilegeRevokeAction,
  },
  // Story 18.9: the Roles list's two SQL privilege actions.
  'OcuPilot.Screen.Descriptor.RoleList': { 'grant-sql': STRINGS.sqlPrivilegeGrantAction, 'revoke-sql': STRINGS.sqlPrivilegeRevokeAction },
  // Story 7.4: the Auditing configuration form's two actions, and the warning dialog's title;
  // Story 12.3: its audit database copy and purge.
  'OcuPilot.Screen.Descriptor.AuditingConfig': {
    enable: STRINGS.auditingTurnOnAction,
    disable: STRINGS.auditingTurnOffAction,
    copy: STRINGS.auditDatabaseCopyAction,
    purge: STRINGS.auditDatabasePurgeAction,
  },
  // Story 12.4: the OAuth 2.0 Server descriptions tab's key-set refresh.
  'OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab': { updatejwks: STRINGS.oauthServerUpdateJwks },
  // Story 12.5: the OAuth 2.0 Client configurations tab's key rotation and dynamic registration.
  'OcuPilot.Screen.Descriptor.OAuthClientTab': { rotatekeys: STRINGS.oauthClientRotateKeys, register: STRINGS.oauthClientRegister },
  // Story 12.7: the OAuth 2.0 Authorization server tab's key rotation.
  'OcuPilot.Screen.Descriptor.OAuthServerTab': { rotatekeys: STRINGS.oauthClientRotateKeys },
  // Story 12.8: the OAuth 2.0 Server client descriptions tab's key-set refresh.
  'OcuPilot.Screen.Descriptor.OAuthServerClientTab': { updatejwks: STRINGS.oauthServerUpdateJwks },
  // Story 16.2: the Web sessions list's End session.
  'OcuPilot.Screen.Descriptor.WebSessionList': { end: STRINGS.webSessionEndAction },
  // Story 16.5: the Background tasks list's Cancel task, which also titles its warning dialog.
  'OcuPilot.Screen.Descriptor.BackgroundTaskList': { cancel: STRINGS.backgroundTaskCancelAction },
  // Story 18.14: the Namespaces list's Copy mappings, which also titles its dialog; Story 18.15: its
  // Enable interoperability.
  'OcuPilot.Screen.Descriptor.NamespaceList': { 'copy-mappings': STRINGS.namespaceCopyMappingsAction, 'enable-interop': STRINGS.namespaceEnableInteropAction },
  // Story 16.6: the Processes list's Broadcast, over its checked rows.
  'OcuPilot.Screen.Descriptor.ProcessList': { broadcast: STRINGS.processBroadcastAction },
  // Story 16.4: the Task schedule's Export, on the selected task; Story 16.11: the Task Manager's
  // three actions, the suspend's also titling its warning dialog.
  'OcuPilot.Screen.Descriptor.TaskScheduleList': {
    export: STRINGS.taskExportAction,
    suspendmanager: STRINGS.taskManagerSuspendAction,
    resumemanager: STRINGS.taskManagerResumeAction,
    startmanager: STRINGS.taskManagerStartAction,
  },
  // Story 18.4: Database details' five disk operations, each also titling its warning dialog.
  'OcuPilot.Screen.Descriptor.DatabaseDetails': {
    mount: STRINGS.databaseActionMount,
    dismount: STRINGS.databaseActionDismount,
    truncate: STRINGS.databaseActionTruncate,
    compact: STRINGS.databaseActionCompact,
    defragment: STRINGS.databaseActionDefragment,
  },
  // Story 18.4: the Databases list's Check integrity, which opens its flow.
  'OcuPilot.Screen.Descriptor.DatabaseList': { integrity: STRINGS.databaseIntegrityLabel },
  // Story 18.4: the editor's Add a volume, which also titles its warning dialog.
  'OcuPilot.Screen.Descriptor.LocalDatabaseList': { expand: STRINGS.databaseExpandAction },
  // Story 16.12: the Locks list's one row entry, Remove locks, which opens its dialog.
  'OcuPilot.Screen.Descriptor.LockList': { remove: STRINGS.lockRemoveAction },
  // Story 19.2: the Classes and Routines lists' Compile, over the checked rows; Story 19.13 their
  // Export, which opens the export dialog over them.
  'OcuPilot.Screen.Descriptor.ExplorerClassList': { compile: STRINGS.explorerCompileAction, export: STRINGS.taskExportAction },
  'OcuPilot.Screen.Descriptor.ExplorerRoutineList': { compile: STRINGS.explorerCompileAction, export: STRINGS.taskExportAction },
  // Story 18.5: Journals' two switches, each also titling its warning dialog, and its Check integrity.
  'OcuPilot.Screen.Descriptor.JournalList': {
    switchfile: STRINGS.journalSwitchFileAction,
    switchdirectory: STRINGS.journalSwitchDirectoryAction,
    integrity: STRINGS.databaseIntegrityLabel,
  },
  // Story 18.6: License key's Activate new key, which opens the activate dialog.
  'OcuPilot.Screen.Descriptor.LicenseKey': { activate: STRINGS.licenseKeyActivateAction },
  // Story 18.20: ECP data servers' Change status, which opens its dialog.
  'OcuPilot.Screen.Descriptor.EcpDataServerList': { changestatus: STRINGS.ecpDataServerChangeStatus },
  // Story 20.15: Screen permissions' Change permissions, which opens its dialog, and its Reset. The
  // declared Remove is sent by that dialog and drawn nowhere.
  'OcuPilot.Screen.Descriptor.AgentScreenPermissions': {
    'add-pair': STRINGS.screenPermissionsChangeAction,
    'remove-pair': STRINGS.actionRemove,
    reset: STRINGS.screenPermissionsResetAction,
  },
  // Story 18.21: the SSL/TLS authorizations tab's Authorize and Reject, each titling its warning dialog.
  'OcuPilot.Screen.Descriptor.EcpSslConnectionTab': { authorize: STRINGS.ecpSslAuthorize, reject: STRINGS.ecpSslReject },
  // Story 18.7: Encryption key files' Create key file, Add key and Remove, and its administrators'
  // Add administrator and Remove, which the key file page draws beside its two tables.
  'OcuPilot.Screen.Descriptor.EncryptionKeyFile': {
    create: STRINGS.encryptionKeyFileCreateAction,
    addkey: STRINGS.encryptionKeyFileAddKeyAction,
    removekey: STRINGS.actionRemove,
  },
  'OcuPilot.Screen.Descriptor.EncryptionKeyFileAdminList': {
    addadministrator: STRINGS.encryptionKeyFileAddAdminAction,
    removeadministrator: STRINGS.actionRemove,
  },
  // Story 18.22: Database encryption's and Data element encryption's Activate key, which opens the
  // page's dialog, and each row's Deactivate.
  'OcuPilot.Screen.Descriptor.DatabaseEncryption': { activate: STRINGS.encryptionKeyActivateAction, deactivate: STRINGS.encryptionKeyDeactivateAction },
  'OcuPilot.Screen.Descriptor.DataElementEncryption': { activate: STRINGS.encryptionKeyActivateAction, deactivate: STRINGS.encryptionKeyDeactivateAction },
  // Story 19.17: Document databases' delete, which drops the database and titles its typed-name dialog.
  'OcuPilot.Screen.Descriptor.ExplorerDocDbList': { delete: STRINGS.explorerDocDbDropLabel },
  // Story 18.26: managed file transfer connections' token revoke.
  'OcuPilot.Screen.Descriptor.MftConnectionList': { 'revoke-token': STRINGS.mftConnectionRevokeAction },
};

export class ScreenActions {
  private readonly handlers = new Map<string, Map<string, { readonly run: ScreenActionRun }>>();

  private readonly listeners = new Set<() => void>();

  /**
   * Register `run` for `actionId` on `descriptor`, replacing any handler already there, and
   * return the function that removes it. The remover removes only the registration it made, so
   * a stale remover called after a re-registration leaves the newer one in place, even when both
   * registered the same function.
   */
  register(descriptor: string, actionId: string, run: ScreenActionRun): () => void {
    let forDescriptor = this.handlers.get(descriptor);
    if (forDescriptor === undefined) {
      forDescriptor = new Map();
      this.handlers.set(descriptor, forDescriptor);
    }
    const registration = { run };
    forDescriptor.set(actionId, registration);
    this.notify();

    return () => {
      const current = this.handlers.get(descriptor);
      if (current?.get(actionId) !== registration) return;
      current.delete(actionId);
      if (current.size === 0) this.handlers.delete(descriptor);
      this.notify();
    };
  }

  /** Whether a handler is registered for `actionId` on `descriptor`. An empty id never has one. */
  has(descriptor: string, actionId: string): boolean {
    if (actionId === '') return false;
    return this.handlers.get(descriptor)?.has(actionId) ?? false;
  }

  /** Run the registered handler once, and report whether there was one. */
  run(descriptor: string, actionId: string): boolean {
    if (actionId === '') return false;
    const registration = this.handlers.get(descriptor)?.get(actionId);
    if (registration === undefined) return false;
    registration.run();
    return true;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}
