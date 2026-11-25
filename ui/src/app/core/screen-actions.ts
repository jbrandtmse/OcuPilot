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
 * Freeze writes and Thaw writes on Backup tasks (Story 21.2): screen-level like Switch file. Each acts on the instance's database writes,
 * not a row, so neither is held back for want of a selection. Freeze is the page's own id, since the declared `freeze` would be drawn as a
 * row action; Thaw is the declared id, which the frozen banner's own action runs too.
 */
export const BACKUP_FREEZE_ACTION_ID = 'backup-freeze';
export const BACKUP_THAW_ACTION_ID = 'thaw';

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
  [BACKUP_FREEZE_ACTION_ID]: STRINGS.backupFreezeAction,
  [BACKUP_THAW_ACTION_ID]: STRINGS.backupThawAction,
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
  // Story 20.23: an abort, on Queue messages and an item's Queue tab.
  abort: STRINGS.actionAbort,
  // Story 20.31: Resend, on Messages' checked rows and a message's Header tab, and Edit and resend, on the Header tab.
  resend: STRINGS.interopMessagesResendAction,
  editresend: STRINGS.interopMessagesEditResendAction,
  // Story 24.16: Suspended messages' Resubmit, Edit and resubmit and Discard; its Delete is every delete's word.
  resubmit: STRINGS.interopSuspendedResubmitAction,
  editresubmit: STRINGS.interopSuspendedEditResubmitAction,
  discard: STRINGS.interopSuspendedDiscardAction,
  // Story 21.19: a security recommendation's Ignore and Stop ignoring, on the Security advisor.
  ignore: STRINGS.securityAdvisorIgnoreAction,
  unignore: STRINGS.securityAdvisorUnignoreAction,
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
  // Story 21.37: Page resources' Assign resource, Change resource and Clear resource, each also the title of what it opens.
  'OcuPilot.Screen.Descriptor.PageResourceList': {
    assign: STRINGS.pageResourcesAssignAction,
    change: STRINGS.pageResourcesChangeAction,
    clear: STRINGS.pageResourcesClearAction,
  },
  // Story 24.3: Productions' Start with the instance and Shutdown group each open a dialog that sets one production's startup setting.
  'OcuPilot.Screen.Descriptor.InteropProductionList': { autostart: STRINGS.interopProductionAutoStartAction, shutdowngroup: STRINGS.interopProductionColumnShutdownGroup },
  // Story 20.3: Production items' Add opens the dialog that adds one item, and its Remove deletes one; Copy (Story 20.40) opens the dialog that copies the selected item; Change class (Story 20.41) opens the one that picks its new class.
  'OcuPilot.Screen.Descriptor.InteropItemList': { add: STRINGS.interopItemAddTitle, copy: STRINGS.auditDatabaseCopyConfirm, changeclass: STRINGS.interopItemChangeClassAction, remove: STRINGS.actionRemove },
  // Story 20.23: Queues' Abort all aborts every message the queue's read enumerated; Jobs' and an item's Jobs tab's three actions act
  // on the message a job keeps retrying and on the job itself.
  'OcuPilot.Screen.Descriptor.InteropQueueList': { abort: STRINGS.interopQueuesAbortAllAction },
  'OcuPilot.Screen.Descriptor.InteropJobList': { abort: STRINGS.interopJobsAbortAction, suspend: STRINGS.interopJobsSuspendAction, stop: STRINGS.interopJobsStopAction },
  'OcuPilot.Screen.Descriptor.InteropItemJobTab': { abort: STRINGS.interopJobsAbortAction, suspend: STRINGS.interopJobsSuspendAction, stop: STRINGS.interopJobsStopAction },
  // Story 21.2: Backup tasks' Run starts one backup, and Backup database list's Add database and Remove change the list the list backups use.
  'OcuPilot.Screen.Descriptor.BackupTaskList': { run: STRINGS.actionRun, freeze: STRINGS.backupFreezeAction, thaw: STRINGS.backupThawAction },
  'OcuPilot.Screen.Descriptor.BackupDatabaseList': { add: STRINGS.backupAddDatabaseAction, removedatabase: STRINGS.actionRemove },
  // Story 21.6: the SQL statements list's five plan and statistics actions, and the Cached queries tab's three purges.
  'OcuPilot.Screen.Descriptor.ExplorerSqlStatementList': {
    freeze: STRINGS.sqlStatementFreezeAction,
    unfreeze: STRINGS.sqlStatementUnfreezeAction,
    'clear-statistics': STRINGS.sqlStatementClearStatisticsAction,
    'clear-error': STRINGS.sqlStatementClearErrorAction,
    clean: STRINGS.sqlStatementCleanAction,
  },
  'OcuPilot.Screen.Descriptor.ExplorerSqlCachedQueries': {
    purge: STRINGS.auditDatabasePurgeConfirm,
    'purge-table': STRINGS.sqlCachedQueryPurgeTableAction,
    'purge-namespace': STRINGS.sqlCachedQueryPurgeAllAction,
  },
  // Story 21.25: a table's Rebuild all indices, and one index's Rebuild index.
  'OcuPilot.Screen.Descriptor.ExplorerSqlTable': {
    'rebuild-indices': STRINGS.sqlTableRebuildAllAction,
    tune: STRINGS.sqlTableTuneAction,
    'clear-statistics': STRINGS.sqlTableClearStatisticsAction,
    'set-extent-size': STRINGS.sqlTableSetExtentSizeAction,
  },
  // Story 21.25: a schema's Tune all tables.
  'OcuPilot.Screen.Descriptor.ExplorerSqlSchema': { tune: STRINGS.sqlSchemaTuneAction },
  'OcuPilot.Screen.Descriptor.ExplorerSqlIndices': { rebuild: STRINGS.sqlIndexRebuildAction, 'set-map-size': STRINGS.sqlIndexSetMapSizeAction },
  // Story 21.31: the Field statistics tab's Set selectivity.
  'OcuPilot.Screen.Descriptor.ExplorerSqlFieldStatistics': { 'set-selectivity': STRINGS.sqlFieldSetSelectivityAction },
  // Story 21.20: SQL activity's Cancel query and System alerts' Reset alerts.
  'OcuPilot.Screen.Descriptor.SqlActivityList': { cancel: STRINGS.sqlActivityCancelAction },
  'OcuPilot.Screen.Descriptor.SystemAlertsList': { reset: STRINGS.systemAlertsResetAction },
  // Story 24.13 Batch 2: Analytics' General settings' Set value, which opens the page's dialog (the key's own action is sent from it), and Worklists' Show and Hide.
  'OcuPilot.Screen.Descriptor.AnalyticsSettingList': { set: STRINGS.interopItemSettingSetAction, setkey: STRINGS.interopItemSettingSetAction },
  'OcuPilot.Screen.Descriptor.AnalyticsWorklistList': { show: STRINGS.oauthRegisteredClientShow, hide: STRINGS.oauthRegisteredClientHide },
  // Story 24.13 Batch 3: Run-time variables' Add, Change and Remove, and User-defined icons', each also the title of its dialog.
  'OcuPilot.Screen.Descriptor.AnalyticsRuntimeVariableList': {
    add: STRINGS.analyticsRuntimeVariableAddAction,
    set: STRINGS.analyticsRuntimeVariableChangeAction,
    remove: STRINGS.analyticsRuntimeVariableRemoveAction,
  },
  'OcuPilot.Screen.Descriptor.AnalyticsUserIconList': {
    add: STRINGS.analyticsUserIconAddAction,
    set: STRINGS.analyticsUserIconChangeAction,
    remove: STRINGS.analyticsUserIconRemoveAction,
  },
  // Story 21.3: the three settings screens' Set value, which opens the page's dialog.
  'OcuPilot.Screen.Descriptor.StartupSettingList': { set: STRINGS.interopItemSettingSetAction },
  'OcuPilot.Screen.Descriptor.MemorySettingList': { set: STRINGS.interopItemSettingSetAction },
  'OcuPilot.Screen.Descriptor.CompatibilitySettingList': { set: STRINGS.interopItemSettingSetAction },
  // Story 21.4: the four SQL settings screens' Set value, which opens the same page's dialog.
  'OcuPilot.Screen.Descriptor.SqlSettingList': { set: STRINGS.interopItemSettingSetAction },
  'OcuPilot.Screen.Descriptor.SqlShellSettingList': { set: STRINGS.interopItemSettingSetAction },
  'OcuPilot.Screen.Descriptor.TsqlSettingList': { set: STRINGS.interopItemSettingSetAction },
  'OcuPilot.Screen.Descriptor.IsqlSettingList': { set: STRINGS.interopItemSettingSetAction },
  // Story 21.10: System-wide security's Set value, which opens the same page's dialog.
  'OcuPilot.Screen.Descriptor.SystemSecuritySettingList': { set: STRINGS.interopItemSettingSetAction },
  // Story 21.19: Task Manager email's Set value, which opens the same page's dialog; Story 21.36: its Set mail password, also that dialog's title.
  'OcuPilot.Screen.Descriptor.TaskMailSettingList': { set: STRINGS.interopItemSettingSetAction, password: STRINGS.taskMailPasswordAction },
  // Story 21.13: the DDL mapping screens' Set value and Delete, and the user list's New mapping, which opens the page's dialog.
  'OcuPilot.Screen.Descriptor.DdlSystemMappingList': { set: STRINGS.interopItemSettingSetAction, delete: STRINGS.actionDelete },
  'OcuPilot.Screen.Descriptor.DdlUserMappingList': { add: STRINGS.ddlMappingNewAction, set: STRINGS.interopItemSettingSetAction, delete: STRINGS.actionDelete },
  // Story 21.14: the NLS defaults' Set value opens the settings page's dialog; the locales' Validate opens its own dialog, and Install and Delete type the name.
  'OcuPilot.Screen.Descriptor.NlsDefaultList': { set: STRINGS.interopItemSettingSetAction },
  'OcuPilot.Screen.Descriptor.LocaleList': { validate: STRINGS.licenseKeyValidate, install: STRINGS.localeInstallAction, delete: STRINGS.actionDelete, copy: STRINGS.auditDatabaseCopyConfirm, export: STRINGS.taskExportAction },
  // Story 21.19: the Resources list's Export acts on the selected resource and Export all on every one; its Import is the screen-level one.
  'OcuPilot.Screen.Descriptor.ResourceList': { export: STRINGS.taskExportAction, 'export-all': STRINGS.resourceExportAllAction },
  // Story 21.16: one locale's properties, whose Set value is the configuration settings page's own.
  'OcuPilot.Screen.Descriptor.LocalePropertyList': {
    set: STRINGS.interopItemSettingSetAction,
    'add-table': STRINGS.localeAddTableAction,
    'remove-table': STRINGS.localeRemoveTableAction,
    'load-table': STRINGS.localeLoadTableAction,
  },
  // Story 20.34: the Cube manager's Build rebuilds a cube and its dependents, and its Synchronize applies the source's recorded changes.
  'OcuPilot.Screen.Descriptor.AnalyticsCubeManager': { build: STRINGS.aboutBuild, synchronize: STRINGS.actionSynchronize },
  // Story 24.2: Term lists' New term list opens the dialog that creates a list, its Edit term list the dialog that changes one and its Delete removes one;
  // a term list's entries' Add entry opens the dialog that adds one, its Change entry the dialog that changes one and its Remove deletes one.
  'OcuPilot.Screen.Descriptor.AnalyticsTermListList': {
    add: STRINGS.analyticsTermListNewAction,
    update: STRINGS.analyticsTermListEditAction,
    delete: STRINGS.analyticsTermListDeleteAction,
    export: STRINGS.taskExportAction,
    copy: STRINGS.analyticsTermListCopyAction,
  },
  // Story 24.11: Listing groups' New listing group opens the dialog that creates a group, its Edit the dialog that changes one, its Copy the dialog that copies one and its Delete removes one;
  // a group's Listings' Add listing opens the dialog that adds one, its Change listing the dialog that changes one and its Remove listing deletes one.
  'OcuPilot.Screen.Descriptor.AnalyticsListingGroupList': {
    add: STRINGS.analyticsListingGroupNewAction,
    update: STRINGS.agentPanelSecretWarningEdit,
    copy: STRINGS.auditDatabaseCopyConfirm,
    delete: STRINGS.actionDelete,
  },
  'OcuPilot.Screen.Descriptor.AnalyticsListingGroupListingList': { add: STRINGS.analyticsListingAddAction, set: STRINGS.analyticsListingChangeAction, remove: STRINGS.analyticsListingRemoveAction },
  // Story 24.12 Batch 3: Groups and elements' Add element, Change element, Remove element and Remove group, and Documentation's Add, Change and Remove documentation item.
  'OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureElementList': {
    add: STRINGS.analyticsQualityMeasureElementAddAction,
    set: STRINGS.analyticsQualityMeasureElementChangeAction,
    remove: STRINGS.analyticsQualityMeasureElementRemoveAction,
    'remove-group': STRINGS.analyticsQualityMeasureGroupRemoveAction,
  },
  'OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureMetaList': {
    add: STRINGS.analyticsQualityMeasureMetaAddAction,
    set: STRINGS.analyticsQualityMeasureMetaChangeAction,
    remove: STRINGS.analyticsQualityMeasureMetaRemoveAction,
  },
  // Story 24.12: Quality measures' New quality measure opens the dialog that creates a measure, its Edit the dialog that changes one, its Copy the dialog that copies one and its Delete removes one.
  'OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureList': {
    add: STRINGS.analyticsQualityMeasureNewAction,
    update: STRINGS.agentPanelSecretWarningEdit,
    copy: STRINGS.auditDatabaseCopyConfirm,
    delete: STRINGS.actionDelete,
  },
  // Story 24.14 Batch 3: PMML models' New PMML definition opens the dialog that creates a definition class from PMML text.
  'OcuPilot.Screen.Descriptor.AnalyticsPmmlModelList': { add: STRINGS.analyticsPmmlNewAction },
  // Story 24.14 Batch 4: the Test screen's Export to cube opens the dialog that exports the model's test to a new cube.
  'OcuPilot.Screen.Descriptor.AnalyticsPmmlModelTest': { export: STRINGS.analyticsPmmlExportAction },
  // Story 24.10: Folder items' Export opens the export dialog, and its Delete removes an item for every user.
  'OcuPilot.Screen.Descriptor.AnalyticsFolderItemList': { export: STRINGS.taskExportAction, delete: STRINGS.actionDelete },
  'OcuPilot.Screen.Descriptor.AnalyticsTermListEntryList': {
    add: STRINGS.webAppPctAccessAdd,
    set: STRINGS.analyticsEntryChangeAction,
    remove: STRINGS.analyticsEntryRemoveAction,
  },
  // Story 20.6: an item's Test tab's Send test opens the dialog that builds and sends one test request.
  'OcuPilot.Screen.Descriptor.InteropItemTestTab': { test: STRINGS.interopItemTestAction },
  // Story 24.16 Batch 3: Messages' Export opens the dialog that saves the checked messages' bodies as one file.
  'OcuPilot.Screen.Descriptor.InteropMessageList': { export: STRINGS.taskExportAction },
  // Story 20.27: Data transformations' Test opens the dialog that runs the selected transformation once on a pasted message.
  'OcuPilot.Screen.Descriptor.InteropTransformList': { test: STRINGS.serverFlagTest },
  // Story 20.22: Item settings' Set value opens its dialog, and its Reset to default returns a setting to its default.
  'OcuPilot.Screen.Descriptor.InteropItemSettingList': { set: STRINGS.interopItemSettingSetAction, reset: STRINGS.interopItemSettingResetAction },
  // Story 20.5: Lookup tables' New table opens the dialog that creates a table with its first entry, its Delete removes a table and its Export
  // writes the selected one;
  // a table's entries' Add entry opens the dialog that adds one, its Set value opens the dialog that sets one, and its Remove deletes one.
  'OcuPilot.Screen.Descriptor.InteropLookupTableList': { add: STRINGS.interopLookupTableAddAction, delete: STRINGS.actionDelete, export: STRINGS.taskExportAction },
  'OcuPilot.Screen.Descriptor.InteropLookupEntryList': {
    add: STRINGS.interopLookupEntryAddAction,
    set: STRINGS.interopLookupEntrySetAction,
    remove: STRINGS.actionRemove,
  },
  // Story 20.26: Business partners' New business partner opens the dialog that adds one, its Edit opens the dialog that changes one and its
  // Remove deletes one.
  'OcuPilot.Screen.Descriptor.InteropBusinessPartnerList': {
    add: STRINGS.interopPartnerAddAction,
    edit: STRINGS.agentPanelSecretWarningEdit,
    remove: STRINGS.actionRemove,
  },
  // Story 24.15: System default settings' New default setting opens the dialog that adds one, its Edit opens the dialog that changes one and its
  // Remove deletes one.
  'OcuPilot.Screen.Descriptor.InteropDefaultSettingList': {
    add: STRINGS.interopDefaultSettingAddAction,
    edit: STRINGS.agentPanelSecretWarningEdit,
    remove: STRINGS.actionRemove,
  },
  // Story 24.15: Credentials' New credential opens the dialog that adds one, its Edit the dialog that changes one, its Set password the dialog that
  // gives one a password and its Remove deletes one.
  'OcuPilot.Screen.Descriptor.InteropCredentialList': {
    add: STRINGS.interopCredentialAddAction,
    edit: STRINGS.agentPanelSecretWarningEdit,
    password: STRINGS.userActionSetPassword,
    remove: STRINGS.actionRemove,
  },
  // Story 24.15: Schedule specs' New schedule spec opens the dialog that adds one, its Edit the dialog that changes one and its Remove deletes one.
  'OcuPilot.Screen.Descriptor.InteropScheduleList': {
    add: STRINGS.interopScheduleAddAction,
    edit: STRINGS.agentPanelSecretWarningEdit,
    remove: STRINGS.actionRemove,
  },
  // Story 24.16: Purge management data's Purge, which opens the dialog that takes the days, and Purge data settings' Set value.
  'OcuPilot.Screen.Descriptor.InteropPurgeList': { purge: STRINGS.auditDatabasePurgeConfirm },
  'OcuPilot.Screen.Descriptor.InteropPurgeSettingList': { set: STRINGS.interopItemSettingSetAction },
  // Story 24.16 Batch 4: Archive manager's Run archive, which opens the dialog that shows what the run moves, and Archive settings' Set value.
  'OcuPilot.Screen.Descriptor.InteropArchiveList': { archive: STRINGS.interopArchiveAction },
  'OcuPilot.Screen.Descriptor.InteropArchiveSettingList': { set: STRINGS.interopItemSettingSetAction },
  // Story 24.17 Batch 1: Managed alerts' Update alert, which opens the dialog that takes the changes and the reason.
  'OcuPilot.Screen.Descriptor.InteropManagedAlertList': { update: STRINGS.interopManagedAlertUpdateAction },
  // Story 24.17 Batch 2: the two logs' Purge, which opens the dialog that takes the days and the namespace's name.
  'OcuPilot.Screen.Descriptor.InteropRuleLogList': { purge: STRINGS.auditDatabasePurgeConfirm },
  'OcuPilot.Screen.Descriptor.InteropProcessLogList': { purge: STRINGS.auditDatabasePurgeConfirm },
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
    export: STRINGS.taskExportAction,
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
  // Story 21.17: the Globals list's Export acts on the selected global.
  'OcuPilot.Screen.Descriptor.ExplorerGlobalList': { export: STRINGS.taskExportAction, replace: STRINGS.explorerGlobalFindAndReplace },
  // Story 24.9: Compare namespaces' Promote, over the checked rows.
  'OcuPilot.Screen.Descriptor.ExplorerNamespaceDiff': { promote: STRINGS.explorerPromoteAction },
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
  // Story 21.10: mobile phone providers' Create provider, which opens the provider editor.
  'OcuPilot.Screen.Descriptor.PhoneProviderList': { create: STRINGS.phoneProviderCreateAction },
  // Story 18.46: the Allowed directories screen's three actions; Add and Change also title their warning dialogs.
  'OcuPilot.Screen.Descriptor.AllowedDirectoryList': {
    add: STRINGS.allowedDirectoryAddAction,
    change: STRINGS.allowedDirectoryChangeAction,
    remove: STRINGS.actionRemove,
  },
};

/** What a registration holds: what runs it, and why it cannot be taken right now. */
interface Registration {
  readonly run: ScreenActionRun;
  readonly reason?: () => string;
}

export class ScreenActions {
  private readonly handlers = new Map<string, Map<string, Registration>>();

  private readonly listeners = new Set<() => void>();

  /**
   * Register `run` for `actionId` on `descriptor`, replacing any handler already there, and
   * return the function that removes it. The remover removes only the registration it made, so
   * a stale remover called after a re-registration leaves the newer one in place, even when both
   * registered the same function.
   *
   * `reason`, where given, is the registrant's own sentence for why the action cannot be taken
   * now -- `''` while it can (AD-53). It is read at call time, so a registrant whose answer moves
   * calls `changed()` and every surface re-draws; while it is non-empty the command bar, the
   * table's row menu and empty state, and the command box draw a screen's primary or row action
   * `aria-disabled` with the sentence as its reason, and `run` runs nothing.
   */
  register(descriptor: string, actionId: string, run: ScreenActionRun, reason?: () => string): () => void {
    let forDescriptor = this.handlers.get(descriptor);
    if (forDescriptor === undefined) {
      forDescriptor = new Map();
      this.handlers.set(descriptor, forDescriptor);
    }
    const registration: Registration = reason === undefined ? { run } : { run, reason };
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

  /**
   * The registrant's sentence for why `actionId` on `descriptor` cannot be taken now, or `''` when
   * it has none, is not registered, or the registrant registered no reason. The surfaces draw it
   * ahead of any self-protection or selection reason (AD-53).
   */
  reason(descriptor: string, actionId: string): string {
    if (actionId === '') return '';
    return this.handlers.get(descriptor)?.get(actionId)?.reason?.() ?? '';
  }

  /**
   * Run the registered handler once, and report whether there was one. A registration whose reason
   * is non-empty runs nothing and answers `false`.
   */
  run(descriptor: string, actionId: string): boolean {
    if (actionId === '') return false;
    const registration = this.handlers.get(descriptor)?.get(actionId);
    if (registration === undefined) return false;
    if ((registration.reason?.() ?? '') !== '') return false;
    registration.run();
    return true;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Tell every listener that a registrant's reason moved, so the surfaces re-draw. */
  changed(): void {
    this.notify();
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}
