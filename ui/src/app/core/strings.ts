/**
 * The one canonical source of every user-facing literal in the OcuPilot Angular
 * client (AD-12's "one writer" shape applied to copy). `ui/tools/client-lint.mjs`
 * fails `npm run build` on a literal text node, or a literal value on a
 * copy-bearing attribute, in any component template under `ui/src/app` that is not
 * an interpolation of a key below.
 *
 * Authority and scope (read before adding or editing a key):
 *
 * - `EXPERIENCE.md`'s *Fixed strings* section is the sole authority
 *   for every word here, canonical over `DESIGN.md` and over every inline quotation
 *   anywhere else in either document -- illustrations elsewhere may *resolve* a
 *   placeholder (as UJ-3 resolves `<user name>` to `_SYSTEM`) but may never
 *   respell the string itself. Transcribe; never paraphrase.
 * - Every key below whose doc comment cites an `EXPERIENCE.md:<line>` is
 *   transcribed verbatim from that table, one key per quoted literal once split
 *   correctly (the middle dot character appears both as the table's own separator
 *   between sibling strings *and* inside several strings themselves, so only the
 *   double quotes delimit -- never a naive split on that character).
 * - Three keys at the end are not from that table but are required verbatim by
 *   this story's own task list: `auditMarkerFailed` ("done (middle dot) audit not
 *   marked" -- see the key's own value below for the exact escaped form, AD-15 /
 *   EXPERIENCE.md "9. **Audit.** Every confirmed" and DESIGN.md:1167),
 *   `accessibilityReducedMotionSpinnerWord` ("running", EXPERIENCE.md "**Reduced motion.** The highlight") and
 *   `productName` ("OcuPilot").
 * - `<user name>` in any string is the login name, as the audit database records
 *   it (EXPERIENCE.md "**Rules.** UI copy is plain") -- never a display name, never resolved here.
 * - **Scope is the Angular client only** (AD-5, AD-39 Design Notes #3). Screen
 *   descriptors' empty-state text and command-box aliases are server-side,
 *   hand-written ObjectScript; the error envelope's `reason` is minted at the
 *   port boundary. Neither belongs in this file, and this file is not their
 *   source either.
 * - Voice rules (EXPERIENCE.md "**Rules.** UI copy is plain", the Voice and Tone table) apply to every
 *   value here: no `!`, no "Oops", no emoji, no "successfully" (case-insensitive).
 *   `ui/tools/strings.mjs`'s `checkVoiceRules` enforces this mechanically.
 * - Every non-ASCII character below is a `\uXXXX` escape, never a literal byte
 *   (Rule 14) -- this is the exact corruption Rule 14 exists to prevent: the
 *   epic file's own copy of "done (middle dot) audit not marked" was corrupted to
 *   "done - audit not marked" by a normalization pass that dropped the escape.
 *
 * Convention (Design Notes' *String keys* section): a flat object, camelCase, with a
 * domain prefix taken from the table's *Where* column (`agent*`, `auth*`,
 * `proposal*`, `table*`, `command*`, `form*`, `status*`, `action*`, `nav*`, and a
 * few more the table's own domains needed: `contextChip*`, `privilege*`,
 * `classicLink*`, `auditing*`, `connectivity*`, `taskManager*`, `home*`, `field*`, `audit*`
 * -- distinct from `auditing*`: `audit*` is the audit database screen, its criteria
 * form, its detail dialog and the marker text on one audit entry, while
 * `auditing*` is the feature banner -- `fault*`, `tool*`, `process*` and `sort*`) plus two
 * prefixes for keys that are not from the table at all (see below): `accessibility*` and
 * `product*`.
 * Flat keeps the linter's "is this value in the source" question a single lookup.
 */
export const STRINGS = {
  /** EXPERIENCE.md:254 */
  authNoAdminPrivileges: 'no administrative privileges on this instance',
  /** EXPERIENCE.md:256 */
  authInstallStateUnreadable: 'OcuPilot can\'t read its own state on this instance, so waiting won\'t help. An administrator needs to run the install again.',
  /** EXPERIENCE.md:257 */
  agentWriteBlockedByReadOnly: 'blocked by read-only mode',
  /** EXPERIENCE.md:258 */
  auditingOffBanner: 'Agent writes are not being marked in the audit database.',
  /** EXPERIENCE.md:258 */
  auditingConfigurationLink: 'Auditing configuration',
  /** EXPERIENCE.md:258 */
  auditingTurnOnAction: 'Turn auditing on',
  /** EXPERIENCE.md:259 */
  proposalTargetChanged: 'target changed, re-propose',
  /** EXPERIENCE.md Fixed strings, tail row */
  auditMarkerReplySentence: 'This change was applied but not marked in the audit database.',
  /** EXPERIENCE.md:261 */
  contextChipLeavesInstance: 'leaves the instance',
  /** EXPERIENCE.md:261 */
  contextChipSentToHost: 'Screen context is sent to <host>',
  /** EXPERIENCE.md:262 */
  contextChipScreenSegment: 'Users, HSCUSTOM \u00b7 6 rows',
  /** EXPERIENCE.md:263 */
  contextChipSharingOff: 'Screen context off \u2014 nothing from this screen is sent.',
  /** EXPERIENCE.md:264 */
  connectivityInstanceUnreachable: 'instance unreachable',
  /** EXPERIENCE.md:264 */
  connectivityRequestRefused: 'request refused',
  /** EXPERIENCE.md:265 */
  faultAbsentEntity: '<name> is no longer present on this instance. Return to the list to see what is there now.',
  /** EXPERIENCE.md:266 */
  statusConnectionSigningIn: 'Signing in\u2026',
  /** EXPERIENCE.md:266 */
  statusConnectionConnected: 'Connected',
  /** EXPERIENCE.md:266 */
  statusConnectionRetrying: 'Instance unreachable \u2014 retrying',
  /** EXPERIENCE.md:266 */
  statusConnectionSigningInAgain: 'Signing in again\u2026',
  /** EXPERIENCE.md:267 */
  statusSegmentServer: 'Server',
  /** EXPERIENCE.md:267 */
  statusSegmentInstance: 'Instance',
  /** EXPERIENCE.md:267 */
  statusSegmentLicensedTo: 'Licensed to',
  /** EXPERIENCE.md:268 */
  agentExplainScreenAction: 'Explain this screen',
  /** EXPERIENCE.md:268 */
  agentExplainEntryAction: 'Explain this entry',
  /** EXPERIENCE.md:268 */
  agentExplainEntryMessage: 'Explain the selected entry',
  /** EXPERIENCE.md:269 */
  actionTestConnection: 'Test connection',
  /** EXPERIENCE.md:269 */
  actionConfirm: 'Confirm',
  /** EXPERIENCE.md:269 */
  actionCancel: 'Cancel',
  /** EXPERIENCE.md:269 */
  actionSave: 'Save',
  /** EXPERIENCE.md:269 */
  actionResume: 'Resume',
  /** EXPERIENCE.md:269 */
  actionRun: 'Run',
  /** EXPERIENCE.md:269 */
  actionSuspend: 'Suspend',
  /** EXPERIENCE.md:269 */
  actionDelete: 'Delete',
  /** EXPERIENCE.md:269 */
  actionSend: 'Send',
  /** EXPERIENCE.md:269 */
  actionStop: 'Stop',
  /** EXPERIENCE.md:269 */
  actionNewConversation: 'New conversation',
  /** EXPERIENCE.md:269 */
  actionRepropose: 'Re-propose',
  /** EXPERIENCE.md:269 */
  actionSignOut: 'Sign out',
  /** EXPERIENCE.md:269 */
  actionSignIn: 'Sign in',
  /** EXPERIENCE.md:269 */
  actionRetry: 'Retry',
  /** EXPERIENCE.md:269 */
  actionOpenMessagesLog: 'Open messages.log',
  /** EXPERIENCE.md:269 */
  actionRefresh: 'Refresh',
  /** EXPERIENCE.md:270 */
  proposalRationaleHeading: 'Agent\'s rationale',
  /** EXPERIENCE.md:270 */
  proposalExpectedImpactHeading: 'Expected impact',
  /** EXPERIENCE.md:271 */
  proposalReverseLabel: 'Reverse:',
  /** EXPERIENCE.md:272 */
  proposalCountdownLabel: 'Expires in m:ss',
  /** EXPERIENCE.md:272 */
  proposalCountdownTooltip: 'Proposals expire so a stale diff is never applied.',
  /** EXPERIENCE.md:272 */
  proposalCountdownAnnouncement: 'One minute left to confirm',
  /** EXPERIENCE.md:273 */
  proposalFooterConfirmHint: 'Confirm here; sending a message cancels this proposal',
  /** EXPERIENCE.md:273 */
  proposalFooterRunsAs: 'Runs as <user name>, with your privileges.',
  /** EXPERIENCE.md:274 */
  proposalConfirmSentence: 'Press Confirm on the card to apply it.',
  /** EXPERIENCE.md:275 */
  proposalStatusConfirmedBy: 'Confirmed by <user name> \u00b7 hh:mm:ss',
  /** EXPERIENCE.md:275 */
  proposalStatusCanceledByYou: 'Canceled \u2014 by you',
  /** EXPERIENCE.md:275 */
  proposalStatusCanceledByMessage: 'Canceled \u2014 by your message',
  /** EXPERIENCE.md:275 */
  proposalStatusCanceledSibling: 'Canceled \u2014 a sibling proposal was confirmed',
  /** EXPERIENCE.md:275 */
  proposalStatusExpired: 'Expired',
  /** EXPERIENCE.md:275 */
  proposalStatusAgentSwitchedOff: 'The agent is switched off',
  /** EXPERIENCE.md:275 */
  proposalStatusCanceledByDraft: 'Canceled \u2014 you took the script instead',
  /** EXPERIENCE.md:269 */
  actionTakeScript: 'Give me the script instead',
  /** EXPERIENCE.md:269 */
  actionCopyToClipboard: 'Copy to clipboard',
  /** EXPERIENCE.md:269 */
  copyAnnouncementCopied: 'Copied',
  /** EXPERIENCE.md:269 */
  copyAnnouncementUnavailable: 'The clipboard is not available here. Select the text and copy it yourself.',
  /** EXPERIENCE.md:273 */
  proposalDraftCaption: 'Nothing was changed. Fill in each value in angle brackets before you run this.',
  /** EXPERIENCE.md:276 */
  proposalUnchangedFieldsDisclosure: 'N unchanged fields',
  /** EXPERIENCE.md:277 */
  proposalExampleCardTitle: 'Example \u2014 this is what a proposal looks like',
  /** EXPERIENCE.md:278 */
  agentIdleGreeting: 'I\'m ready. Ask about this screen, or try one of these.',
  /** EXPERIENCE.md:278 */
  agentIdleSelectionHint: 'Click a row to select it; click its name to open it.',
  /** EXPERIENCE.md:279 */
  toolCallStoppedByYou: 'Stopped by you at <step>',
  /** EXPERIENCE.md:280 */
  agentTurnStoppedBanner: 'The turn stopped at <step>: <reason>.',
  /** EXPERIENCE.md:353 */
  agentTurnStoppedNoStepBanner: 'The turn stopped: <reason>.',
  /** EXPERIENCE.md:281 */
  agentTurnLockBanner: 'A turn is in progress. Wait for it to finish before sending another message.',
  /** EXPERIENCE.md:281 */
  agentTurnLimitBanner:
    'You have reached this instance\'s limit of <n> agent turns an hour. You can send again at <hh:mm>.',
  /** EXPERIENCE.md:281 */
  agentTurnLimitLine: 'This turn was not started: you have used your <n> turns for this hour.',
  /** EXPERIENCE.md:500 */
  agentJumpToLatest: 'Jump to latest',
  // Story 4.5's four: from the tool-call-card Component Patterns row (:378) and the panel's
  // Busy and header rows (:424, :511), each authorized by its own targeted extractor in
  // `ui/tools/strings.test.mjs` rather than by being added to REQUIRED_ALONGSIDE_TABLE.
  toolCallStatusDone: 'done',
  toolCallStatusFailed: 'failed \u2014 <reason>',
  agentComposerLockedReason: 'A turn is in progress',
  agentNewConversationLockedReason: 'Stop the turn first',
  /** EXPERIENCE.md:352 */
  toolCallReadResultLine: '<n> rows returned \u00b7 <m> sent',
  /** EXPERIENCE.md:282 */
  agentNavigationAnnouncement: 'I\'m opening <screen> for <entity> \u2014 use Back to return.',
  /** EXPERIENCE.md:282 */
  agentNavigationAnnouncementNoEntity: 'I\'m opening <screen> \u2014 use Back to return.',
  /** EXPERIENCE.md:282 */
  agentNavigationHeadingAnnouncement: '<title> \u2014 opened by the agent; Back returns',
  /** EXPERIENCE.md:283 */
  agentAuditFollowUpQuestion: 'Shall I show you the audit entry?',
  /** EXPERIENCE.md:284 */
  agentGateReminderBanner: 'No agent definition is enabled. Configure one in Agent co-pilot \u203a Definitions.',
  /** EXPERIENCE.md:285 */
  agentGateLandingBanner: 'OcuPilot needs one agent definition before the panel can help. Anthropic is selected \u2014 paste a key and press Test connection. You can skip this and browse.',
  /** EXPERIENCE.md:286 */
  agentGateEmptyState: 'The agent isn\'t configured yet. An OcuPilot administrator can enable a definition in Agent co-pilot \u203a Definitions.',
  /** EXPERIENCE.md:287 */
  agentReadOnlyEnforcedBanner: 'Read-only mode is enforced on this instance. The agent can read and explain, not change.',
  /** EXPERIENCE.md:288 */
  agentKillSwitchBanner: 'The agent is switched off for <everyone / you>: <reason>.',
  /** EXPERIENCE.md:289 */
  statusReadOnlyOff: 'Read-only: off',
  /** EXPERIENCE.md:289 */
  statusReadOnlyEnforced: 'Read-only: on \u2014 enforced on this instance',
  /** EXPERIENCE.md:289 */
  statusReadOnlyForYou: 'Read-only: on \u2014 for you',
  /** EXPERIENCE.md:289 */
  statusReadOnlyByDefinition: 'Read-only: on \u2014 by the definition',
  /** EXPERIENCE.md:289 */
  agentReadOnlyForYouLabel: 'Read-only for me',
  /** EXPERIENCE.md:290 */
  tableChangeToastLink: 'Open in <screen>',
  /** EXPERIENCE.md:291 */
  statusAutoRefreshOff: 'Auto-refresh: off',
  /** EXPERIENCE.md:291 */
  statusAutoRefreshOn: 'Auto-refresh: every <n> s',
  /** EXPERIENCE.md:291 */
  statusAutoRefreshPaused: 'Auto-refresh paused \u2014 a proposal is awaiting confirmation',
  /** EXPERIENCE.md:291 */
  statusLastUpdate: 'Last update hh:mm:ss',
  /** EXPERIENCE.md:292 */
  commandBarFilterLabel: 'Filter rows',
  /** EXPERIENCE.md:293 */
  tableChangedTag: 'Changed',
  /** EXPERIENCE.md:294 */
  privilegeRequiresResource: 'Requires <resource>',
  /** EXPERIENCE.md:294 */
  privilegeSelectRowFirst: 'Select a row first',
  /** EXPERIENCE.md:295 */
  privilegeDeniedScreen: 'You need <resource> to open <screen>.',
  /** EXPERIENCE.md:296 */
  privilegeDeniedAction: 'You need <resource> to <action>.',
  /** EXPERIENCE.md:522 */
  privilegeProposalHeld: 'Requires <resources>, which you hold.',
  /** EXPERIENCE.md:522 */
  privilegeProposalMissing: 'Requires <resources>. You don\'t hold <resource>.',
  /** EXPERIENCE.md:297 */
  navPrivilegeMapUnread: 'Your privileges couldn\'t be read, so screens you can\'t open may be listed. Retry to check again.',
  /** EXPERIENCE.md:298 */
  formTypedNameConfirm: 'Type <name> to confirm',
  /** EXPERIENCE.md:298 */
  formTypedNameMismatch: 'Does not match',
  /** EXPERIENCE.md:299 */
  formSecretStored: 'Stored. Enter a new value to replace it.',
  /** EXPERIENCE.md:300 */
  formTestConnectionResult: 'Connected. Reply: <the model\'s first words>',
  /** EXPERIENCE.md:300 */
  formTestConnectionFailure: 'The provider refused the request. Check the key and try again. Provider said: <text>',
  /** EXPERIENCE.md:300 */
  formSavedPendingTest: 'Saved \u2014 disabled until Test connection passes.',
  /** EXPERIENCE.md:301 */
  formSaved: 'Saved',
  /** EXPERIENCE.md:301 */
  formGoToHome: 'Go to Home',
  /** EXPERIENCE.md:301 */
  formLeaveWithoutSaving: 'Leave without saving?',
  /** EXPERIENCE.md:302 */
  authSignInFailed: 'Sign-in failed. Check the user name and password.',
  /** EXPERIENCE.md:302 */
  authPasswordExpired: 'The password for <user> has expired. Change it in the classic portal, or run the command in the README to clear the expiry.',
  /** EXPERIENCE.md:302 */
  authSessionEnded: 'Your session ended. Sign in to continue.',
  /** EXPERIENCE.md:302 */
  authSignedOut: 'You\'re signed out.',
  /** EXPERIENCE.md:302 */
  fieldUserName: 'User name',
  /** EXPERIENCE.md:302 */
  fieldPassword: 'Password',
  /** EXPERIENCE.md:303 */
  authSignInUnreachable: 'Sign-in couldn\'t reach the instance. Check that IRIS is running, then sign in again.',
  /** EXPERIENCE.md:304 */
  taskManagerSuspendedBanner: 'The Task Manager is suspended \u2014 no scheduled task will run until it is resumed.',
  /** EXPERIENCE.md:304 */
  taskManagerStoppedBanner: 'The Task Manager is not running \u2014 no scheduled task will run until it is started.',
  /** EXPERIENCE.md:305 */
  classicLinkCardTitle: 'More in the classic portal',
  /** EXPERIENCE.md:306 */
  classicLinkCardCaption: 'The classic portal may ask you to sign in again.',
  /** EXPERIENCE.md:307 */
  commandBoxPlaceholder: 'Search screens and commands',
  /** EXPERIENCE.md:307 */
  commandBoxNoMatch: 'No screen or action matches.',
  /** EXPERIENCE.md:307 */
  commandBoxResultCount: '<n> screens, <m> actions',
  /** EXPERIENCE.md:308 */
  commandBoxGroupScreens: 'Screens',
  /** EXPERIENCE.md:308 */
  commandBoxGroupActions: 'Actions',
  /** EXPERIENCE.md:309 */
  agentComposerCaption: 'Enter to send \u00b7 Shift+Enter for a new line \u00b7 Ctrl+I to focus',
  /** EXPERIENCE.md:310 */
  navAreaHome: 'Home',
  /** EXPERIENCE.md:310 */
  navAreaLogs: 'Logs',
  /** EXPERIENCE.md:310 */
  navAreaOsManagement: 'OS management',
  /** EXPERIENCE.md:310 */
  navAreaTasks: 'Tasks',
  /** EXPERIENCE.md:310 */
  navAreaPermissions: 'Permissions',
  /** EXPERIENCE.md:310 */
  navAreaWebApplications: 'Web applications and REST API explorer',
  /** EXPERIENCE.md:310 */
  navAreaSecurity: 'Security and secrets',
  /** EXPERIENCE.md:310 */
  navAreaSystemExplorer: 'System Explorer',
  /** EXPERIENCE.md:310 */
  navAreaAgent: 'Agent co-pilot',
  /** EXPERIENCE.md:311 */
  navRailItemTooltip: '<Area> \u00b7 Ctrl+B toggles the side bar',
  /** EXPERIENCE.md:312 */
  agentComposerLabel: 'Message to the agent',
  /** EXPERIENCE.md:312 */
  agentShareContextLabel: 'Share screen context',
  /** EXPERIENCE.md:313 */
  tableRowCapNotice: 'Showing the first <n> rows. Narrow the filter or raise the max rows.',
  /** EXPERIENCE.md:314 */
  tableRowCount: '<n> rows',
  /** EXPERIENCE.md:314 */
  tableMaxRowsLabel: 'Max rows',
  /** EXPERIENCE.md:314 */
  tableEmptyValue: '(none)',
  /** EXPERIENCE.md:314 */
  tableStatusYes: 'Yes',
  /** EXPERIENCE.md:314 */
  tableStatusNo: 'No',
  /** EXPERIENCE.md:315 */
  tableWriteCapableEmptyState: 'Or ask the agent: <a write it could propose here>.',
  /** EXPERIENCE.md:316 */
  webAppListLabel: 'Web applications',
  /** EXPERIENCE.md:316 */
  tableColumnName: 'Name',
  /** EXPERIENCE.md:316 */
  tableColumnType: 'Type',
  /** EXPERIENCE.md:316 */
  tableColumnEnabled: 'Enabled',
  /** EXPERIENCE.md:316 */
  webAppColumnDispatchClass: 'Dispatch class',
  /** EXPERIENCE.md:316 */
  webAppColumnResource: 'Resource',
  /** EXPERIENCE.md:316 */
  webAppListEmpty: 'No web applications in <NAMESPACE>.',
  /** EXPERIENCE.md:316 */
  tableReadOnlyEmptyNext: 'Open another screen from the command box.',
  /** EXPERIENCE.md:317 */
  userListLabel: 'Users',
  /** EXPERIENCE.md:317 */
  userColumnFullName: 'Full name',
  /** EXPERIENCE.md:317 */
  userColumnExpired: 'Account expired',
  /** EXPERIENCE.md:317 */
  userColumnRoles: 'Roles',
  /** EXPERIENCE.md:317 */
  userListEmpty: 'No users in <NAMESPACE>.',
  /** EXPERIENCE.md:318 */
  sslListLabel: 'SSL/TLS',
  /** EXPERIENCE.md:318 */
  tableColumnDescription: 'Description',
  /** EXPERIENCE.md:318 */
  sslListEmpty: 'No SSL/TLS configurations in <NAMESPACE>.',
  /** EXPERIENCE.md:319 */
  taskListLabel: 'Task schedule',
  /** EXPERIENCE.md:319 */
  taskColumnLastRun: 'Last run',
  /** EXPERIENCE.md:319 */
  taskColumnNextRun: 'Next run',
  /** EXPERIENCE.md:319 */
  taskListEmpty: 'No scheduled tasks on this instance.',
  // Story 16.4: Task schedule's Export and Import dialogs.
  /** EXPERIENCE.md:319 */
  taskExportAction: 'Export',
  /** EXPERIENCE.md:319 */
  taskExportTitle: 'Export <task>',
  /** EXPERIENCE.md:319 */
  taskImportTitle: 'Import tasks',
  /** EXPERIENCE.md:319 */
  taskExportNote: 'The file holds the task\'s definition and settings, and a password setting in it is encoded, not encrypted.',
  /** EXPERIENCE.md:319 */
  taskExportReplaces: 'A file already at this name is replaced.',
  /** EXPERIENCE.md:319 */
  taskExportDone: 'Exported <task> to <path>.',
  /** EXPERIENCE.md:319 */
  taskImportDone: 'Imported the tasks in <path>. Any already on this instance were skipped.',
  /** EXPERIENCE.md:319 */
  taskImportRefused: 'Nothing was imported: task <task> cannot be created here. <reason>',
  /** EXPERIENCE.md:320 */
  processListLabel: 'Processes',
  /** EXPERIENCE.md:320 */
  processColumnPid: 'Process ID',
  /** EXPERIENCE.md:320 */
  processColumnUser: 'User',
  /** EXPERIENCE.md:320 */
  processColumnRoutine: 'Routine',
  /** EXPERIENCE.md:320 */
  processColumnState: 'State',
  /** EXPERIENCE.md:320 */
  processColumnCommands: 'Commands',
  /** EXPERIENCE.md:320 */
  processColumnGlobals: 'Globals',
  /** EXPERIENCE.md:320 */
  processListEmpty: 'No processes on this instance.',
  /** EXPERIENCE.md:321 */
  sortMenuLabel: 'Sort',
  /** EXPERIENCE.md:321 */
  sortDirectionAscending: 'Ascending',
  /** EXPERIENCE.md:321 */
  sortDirectionDescending: 'Descending',
  /** EXPERIENCE.md:322 */
  auditListLabel: 'Audit database',
  /** EXPERIENCE.md:322 */
  auditColumnTime: 'Time',
  /** EXPERIENCE.md:322 */
  auditColumnEventSource: 'Event source',
  /** EXPERIENCE.md:322 */
  auditColumnEventType: 'Event type',
  /** EXPERIENCE.md:322 */
  auditColumnEventName: 'Event name',
  /** EXPERIENCE.md:322 */
  auditListEmpty: 'No events match.',
  /** EXPERIENCE.md:323 */
  auditCriteriaBegin: 'Begin date and time',
  /** EXPERIENCE.md:323 */
  auditCriteriaEnd: 'End date and time',
  /** EXPERIENCE.md:323 */
  auditCriteriaAuthentication: 'Authentication',
  /** EXPERIENCE.md:323 */
  auditCriteriaSearch: 'Search',
  /** EXPERIENCE.md:323 */
  auditCriteriaAnyOption: 'Any',
  /** EXPERIENCE.md:323 */
  auditCriteriaNameHint: 'Comma-separated. * matches any name.',
  /** EXPERIENCE.md:323 */
  auditCriteriaTimeHint: 'Instance local time, as YYYY-MM-DD HH:MM:SS.',
  /** EXPERIENCE.md:324 */
  auditMarkerFilterLabel: 'Agent-marked events only',
  /** EXPERIENCE.md:325 */
  auditDialogTitle: 'Audit event',
  /** EXPERIENCE.md:325 */
  auditDialogEventData: 'Event data',
  /** EXPERIENCE.md:325 */
  auditDialogClose: 'Close',
  /** EXPERIENCE.md:326 */
  errorLogListLabel: 'Application errors',
  /** EXPERIENCE.md:326 */
  errorLogColumnDate: 'Date',
  /** EXPERIENCE.md:326 */
  errorLogColumnCount: 'Errors',
  /** EXPERIENCE.md:326 */
  errorLogColumnNumber: 'Error number',
  /** EXPERIENCE.md:326 */
  errorLogColumnText: 'Error',
  /** EXPERIENCE.md:326 */
  errorLogColumnLine: 'Code line',
  /** EXPERIENCE.md:327 */
  errorLogEmptyInstance: 'No application errors on this instance.',
  /** EXPERIENCE.md:327 */
  errorLogEmptyNamespace: 'No application errors in <NAMESPACE>.',
  /** EXPERIENCE.md:327 */
  errorLogEmptyDate: 'No application errors in <NAMESPACE> on <DATE>.',
  /** EXPERIENCE.md:328 */
  errorLogDetailExpressions: 'Expressions',
  /** EXPERIENCE.md:328 */
  errorLogDetailStack: 'Stack',
  /** EXPERIENCE.md:328 */
  errorLogDetailVariables: 'Variables',
  /** EXPERIENCE.md:328 */
  errorLogColumnExpression: 'Expression',
  /** EXPERIENCE.md:328 */
  errorLogColumnValue: 'Value',
  /** EXPERIENCE.md:328 */
  errorLogColumnLevel: 'Level',
  /** EXPERIENCE.md:328 */
  errorLogColumnFrame: 'Frame',
  /** EXPERIENCE.md:329 */
  errorLogBack: 'Back',
  /** EXPERIENCE.md:329 */
  errorLogLevelCapNotice: 'This list was cut at the row cap \u2014 older entries are not shown.',
  /** EXPERIENCE.md:329 */
  errorLogDetailCapNotice: 'This capture was cut at the row cap \u2014 some values are not shown.',
  /** EXPERIENCE.md:330 */
  errorLogRefusedNamespace: 'That namespace is no longer present in this log. Use Back to see which namespaces are.',
  /** EXPERIENCE.md:330 */
  errorLogRefusedDate: 'That date is no longer present in this log. Use Back to see which dates are.',
  /** EXPERIENCE.md:330 */
  errorLogRefusedEntry: 'That application error is no longer present in this log. Use Back to see which errors are.',
  /** EXPERIENCE.md:330 */
  errorLogRefusedAction: 'read this log',
  /** EXPERIENCE.md:354 */
  homeSuggestedView: 'Suggested view',
  /** EXPERIENCE.md:355 */
  homeSuggestedOpen: 'Open',
  /** EXPERIENCE.md:356 */
  homeSuggestedApplicationErrors: 'Application errors in <NAMESPACE>: <n> on <DATE>',
  /** EXPERIENCE.md:331 */
  homeStarterPromptExplainScreen: 'What\'s on this screen, and what should I look at first?',
  /** EXPERIENCE.md:331 */
  homeStarterPromptExplainLog: 'Explain the most recent entries in messages.log.',
  /** EXPERIENCE.md:331 */
  homeStarterPromptChangeOneThing: 'If you could change one thing on this instance, what would it be, and why?',
  /** EXPERIENCE.md:332 */
  proposalExpectedImpactExample: 'users holding %Development can reach the application',
  /** EXPERIENCE.md:333 */
  auditMarkerDescription: 'marked as coming through the OcuPilot agent co-pilot',
  /** EXPERIENCE.md:334 */
  agentDefinitionListLabel: 'Definitions',
  /** EXPERIENCE.md:334 */
  tableColumnProvider: 'Provider',
  /** EXPERIENCE.md:334 */
  tableColumnModel: 'Model',
  /** EXPERIENCE.md:334 */
  tableColumnDefault: 'Default',
  /** EXPERIENCE.md:334 */
  agentDefinitionListEmpty: 'No agent definitions yet.',
  /** EXPERIENCE.md:334 */
  agentDefinitionListEmptyAgent: 'create a definition for Claude and test the connection',
  /** EXPERIENCE.md:334 */
  agentDefinitionEnable: 'Enable',
  /** EXPERIENCE.md:334 */
  agentDefinitionDisable: 'Disable',
  /** EXPERIENCE.md:334 */
  agentDefinitionSetDefault: 'Set default',
  /** EXPERIENCE.md:335 */
  agentDefinitionFormLabel: 'Definition',
  /** EXPERIENCE.md:335 */
  agentDefinitionFieldEndpoint: 'Endpoint',
  /** EXPERIENCE.md:335 */
  agentDefinitionFieldApiKey: 'API key',
  /** EXPERIENCE.md:335 */
  agentDefinitionFieldLocalModel: 'Local model',
  /** EXPERIENCE.md:335 */
  agentDefinitionCredTypeNone: 'No API key',
  /** EXPERIENCE.md:335 */
  agentDefinitionHttpAcknowledge:
    'This endpoint is not encrypted, so the key travels across the network in clear.',
  /** EXPERIENCE.md:335 */
  agentDefinitionAdvanced: 'Advanced',
  /** EXPERIENCE.md:335 */
  agentDefinitionFieldMaxTokens: 'Maximum tokens',
  /** EXPERIENCE.md:335 */
  agentDefinitionFieldTemperature: 'Temperature',
  // Story 10.4: the Temperature field's placeholder where the provider takes one, and its
  // placeholder and caption where it does not.
  /** EXPERIENCE.md:465 */
  agentDefinitionTemperatureProviderDefault: 'Provider default',
  /** EXPERIENCE.md:465 */
  agentDefinitionTemperatureNotApplicable: 'Not applicable',
  /** EXPERIENCE.md:465 */
  agentDefinitionTemperatureNotApplicableCaption:
    'This provider\'s current models refuse sampling settings, so OcuPilot sends none and the model uses its own.',
  // Story 10.5: the Test connection failure line when the test waited its bound with no answer,
  // for a definition marked local and otherwise. The server's reasons are pinned equal to these.
  /** EXPERIENCE.md:466 */
  agentDefinitionTestTimeoutLocal:
    'The model did not answer within <n> seconds. A local model may still be loading; test again in a minute.',
  /** EXPERIENCE.md:466 */
  agentDefinitionTestTimeout:
    'The provider (<provider>) did not answer within <n> seconds. Check the endpoint and the provider\'s status, then test again.',
  /** EXPERIENCE.md:335 */
  agentDefinitionFieldMaxIterations: 'Maximum iterations',
  /** EXPERIENCE.md:335 */
  agentDefinitionFieldSystemPrompt: 'System prompt override',
  /** EXPERIENCE.md:335 */
  agentDefinitionFieldRetention: 'Retention',
  /** EXPERIENCE.md:335 */
  actionCreate: 'Create',
  /** EXPERIENCE.md:335 */
  agentDefinitionFieldReadOnly: 'Read-only',
  /** EXPERIENCE.md:336 */
  agentDefinitionShowKey: 'Show key',
  /** EXPERIENCE.md:336 */
  agentDefinitionHideKey: 'Hide key',
  /** EXPERIENCE.md:336 */
  agentDefinitionRetentionCaption: 'Transcripts are kept for <n> days.',
  // Story 14.4: the Transcripts list, its columns, empty state and prompts, and the transcript
  // page's screen-context disclosure and its withheld sentence's action slot.
  /** EXPERIENCE.md:336 */
  agentTranscriptsLabel: 'Transcripts',
  /** EXPERIENCE.md:336 */
  agentTranscriptLabel: 'Transcript',
  /** EXPERIENCE.md:336 */
  agentTranscriptsColumnTurns: 'Turns',
  /** EXPERIENCE.md:336 */
  agentTranscriptsColumnLastActivity: 'Last activity',
  /** EXPERIENCE.md:336 */
  agentTranscriptsColumnTitle: 'First message',
  /** EXPERIENCE.md:336 */
  agentTranscriptsEmpty: 'No conversations are kept for you yet.',
  /** EXPERIENCE.md:336 */
  transcriptScreenContext: 'Screen context',
  /** EXPERIENCE.md:336 */
  transcriptNoContext: 'No screen context was sent with this turn.',
  /** EXPERIENCE.md:336 */
  transcriptRefusedAction: 'see this transcript\'s tool results and screen context',
  /** EXPERIENCE.md:336 */
  agentTranscriptsPrompt1: 'Which conversations did I have today?',
  /** EXPERIENCE.md:336 */
  agentTranscriptsPrompt2: 'Which of my conversations ran the most turns?',
  /** EXPERIENCE.md:336 */
  agentTranscriptsPrompt3: 'When did I last talk to the agent?',
  /** EXPERIENCE.md:337 */
  proposalCardTitle: 'Proposal \u00b7 <entity type> <name>',
  /** EXPERIENCE.md:338 */
  proposalDiffWas: 'was',
  /** EXPERIENCE.md:338 */
  proposalDiffNow: 'now',
  /** EXPERIENCE.md:339 */
  agentTrustReads: 'It reads with your privileges.',
  /** EXPERIENCE.md:339 */
  agentTrustProposes: 'It proposes and you confirm.',
  /** EXPERIENCE.md:339 */
  agentTrustAudited: 'Every write is marked in the audit database.',
  /** EXPERIENCE.md:340 */
  agentDefinitionRefusedAction: 'change this definition',
  /** EXPERIENCE.md:341 */
  formRequiredFieldsLegend: 'Required fields are marked with an asterisk.',
  /** EXPERIENCE.md:342 */
  agentSwitchesLabel: 'Switches',
  /** EXPERIENCE.md:342 */
  agentSwitchesKillSwitch: 'Kill switch',
  /** EXPERIENCE.md:342 */
  agentSwitchesFieldReason: 'Reason',
  /** EXPERIENCE.md:342 */
  agentSwitchesEnforcedReadOnly: 'Enforced read-only',
  /** EXPERIENCE.md:342 */
  agentSwitchesHoldsHeading: 'Switched off users',
  /** EXPERIENCE.md:342 */
  agentSwitchesHoldAdd: 'Switch off a user',
  /** EXPERIENCE.md:342 */
  agentSwitchesHoldRemove: 'Switch the agent back on',
  /** EXPERIENCE.md:342 */
  agentSwitchesHoldsEmpty: 'No users are switched off.',
  /** EXPERIENCE.md:343 */
  agentSwitchesShareContext: 'Screen context is shared by default',
  /** EXPERIENCE.md:349 */
  agentSwitchesContextRowCap: 'Context rows sent with a turn',
  /** EXPERIENCE.md:349 */
  agentSwitchesTurnsPerHour: 'Agent turns per user an hour',
  /** EXPERIENCE.md:349 */
  agentSwitchesTurnsPerHourHint: '0 means no limit.',
  /** EXPERIENCE.md:349 */
  agentSwitchesConcurrentTurns: 'Agent turns running at once per user',
  /** EXPERIENCE.md:349 */
  agentSwitchesConcurrentTurnsReason:
    'Fixed at 1: the conversation lock and the panel\'s single transcript assume one turn at a time per user.',
  /** EXPERIENCE.md:344 */
  agentSwitchesRefusedAction: 'change the switches',
  // Story 14.2: the Governance policy screen, its refusal action, the governance tool refusal, the
  // purge card's consequence and the screen's prompts. "None", "Read-only" and "Enabled" reuse
  // `sslVerifyPeerNone`, `agentDefinitionFieldReadOnly` and `tableColumnEnabled`.
  /** EXPERIENCE.md:342 */
  agentGovernanceLabel: 'Governance policy',
  /** EXPERIENCE.md:342 */
  agentGovernancePreset: 'Preset',
  /** EXPERIENCE.md:342 */
  agentGovernancePresetFull: 'Full',
  /** EXPERIENCE.md:342 */
  agentGovernanceColumnTool: 'Write tool',
  /** EXPERIENCE.md:342 */
  agentGovernanceColumnBaseline: 'Baseline',
  /** EXPERIENCE.md:342 */
  agentGovernanceColumnSetting: 'Setting',
  /** EXPERIENCE.md:342 */
  agentGovernanceColumnEffect: 'In effect',
  /** EXPERIENCE.md:342 */
  agentGovernanceSettingInherit: 'Inherit',
  /** EXPERIENCE.md:342 */
  agentGovernanceDisabled: 'Disabled',
  /** EXPERIENCE.md:342 */
  agentGovernanceSourceSetting: 'by this setting',
  /** EXPERIENCE.md:342 */
  agentGovernanceSourcePreset: 'by the preset',
  /** EXPERIENCE.md:342 */
  agentGovernanceSourceBaseline: 'by the baseline',
  /** EXPERIENCE.md:342 */
  agentGovernanceBaselineAbsent: 'not in the baseline',
  /** EXPERIENCE.md:344 */
  agentGovernanceRefusedAction: 'change the governance policy',
  /** EXPERIENCE.md:257 */
  governanceToolDisabled: 'This tool is disabled by policy.',
  /** EXPERIENCE.md:516 */
  auditPurgeMarkersEffect:
    'This removes audit records, including the markers that record the agent\'s own writes. It cannot be undone.',
  /** EXPERIENCE.md:526 */
  agentGovernancePrompt1: 'What does the read-only preset change?',
  /** EXPERIENCE.md:526 */
  agentGovernancePrompt2: 'What happens when the agent calls a tool the policy disables?',
  /** EXPERIENCE.md:526 */
  agentGovernancePrompt3: 'Why is the audit purge disabled by default?',
  /** EXPERIENCE.md:345 */
  formStaleSave:
    'Someone else changed this while you were here. Reload to see the current values, then save again.',
  // "Definitions" (:345), the administrator reminder banner's link, is the same literal as the
  // Definitions list's own label and renders `agentDefinitionListLabel`: one key per value.
  /** EXPERIENCE.md:347 */
  agentPanelFullScreen: 'Full screen',
  /** EXPERIENCE.md:348 */
  agentPanelResizeHandle: 'Resize the agent co-pilot panel',
  /** EXPERIENCE.md:350 */
  agentPanelSecretWarning: 'This looks like a password or key. Send anyway?',
  /** EXPERIENCE.md:350 */
  agentPanelSecretWarningSend: 'Send anyway',
  /** EXPERIENCE.md:350 */
  agentPanelSecretWarningEdit: 'Edit',
  /** EXPERIENCE.md:351 */
  agentContextChipSecretGlyph: 'Secret fields on this screen are never sent',
  /** EXPERIENCE.md:357 */
  restApiListLabel: 'REST API explorer',
  /** EXPERIENCE.md:357 */
  restApiColumnSpecBased: 'Spec-based',
  /** EXPERIENCE.md:357 */
  restApiListEmpty: 'No REST applications in <NAMESPACE>.',
  /** EXPERIENCE.md:358 */
  openApiViewerLabel: 'OpenAPI document',
  /** EXPERIENCE.md:358 */
  openApiColumnPath: 'Path',
  /** EXPERIENCE.md:358 */
  openApiColumnVerb: 'Verb',
  /** EXPERIENCE.md:358 */
  openApiColumnSummary: 'Summary',
  /** EXPERIENCE.md:358 */
  openApiParameters: 'Parameters',
  /** EXPERIENCE.md:358 */
  openApiResponses: 'Responses',
  /** EXPERIENCE.md:358 */
  openApiRequired: 'Required',
  /** EXPERIENCE.md:358 */
  openApiRaw: 'Raw',
  /** EXPERIENCE.md:358 */
  openApiViewerEmpty: 'This document declares no paths.',
  /** EXPERIENCE.md:358 */
  openApiRefusedAction: 'read this document',
  /** EXPERIENCE.md:358 */
  openApiCapNotice: 'This document was cut at the row cap \u2014 some operations are not shown.',
  /** EXPERIENCE.md:359 */
  roleColumnCreatedBy: 'Created by',
  /** EXPERIENCE.md:359 */
  roleColumnEscalationOnly: 'Escalation only',
  /** EXPERIENCE.md:359 */
  roleListEmpty: 'No roles on this instance.',
  /** EXPERIENCE.md:360 */
  resourceListLabel: 'Resources',
  /** EXPERIENCE.md:360 */
  resourceColumnPublicPermission: 'Public permission',
  /** EXPERIENCE.md:360 */
  resourceColumnDeletable: 'Deletable',
  /** EXPERIENCE.md:360 */
  resourceListEmpty: 'No resources on this instance.',
  /** EXPERIENCE.md:361 */
  serviceListLabel: 'Services',
  /** EXPERIENCE.md:361 */
  serviceColumnAuthentication: 'Authentication methods',
  /** EXPERIENCE.md:361 */
  serviceColumnAllowedAddresses: 'Allowed IP addresses',
  /** EXPERIENCE.md:361 */
  serviceAllowedUnrestricted: 'Unrestricted',
  /** EXPERIENCE.md:361 */
  serviceListEmpty: 'No services on this instance.',
  /** EXPERIENCE.md:362 */
  x509ListLabel: 'X.509',
  /** EXPERIENCE.md:362 */
  x509ColumnAlias: 'Alias',
  /** EXPERIENCE.md:362 */
  x509ColumnSubject: 'Subject',
  /** EXPERIENCE.md:362 */
  x509ColumnIssuer: 'Issuer',
  /** EXPERIENCE.md:362 */
  x509ColumnValidFrom: 'Valid from',
  /** EXPERIENCE.md:362 */
  x509ColumnValidUntil: 'Valid until',
  /** EXPERIENCE.md:362 */
  x509ListEmpty: 'No X.509 credentials on this instance.',
  /** EXPERIENCE.md:363 */
  ldapListLabel: 'LDAP / Kerberos',
  /** EXPERIENCE.md:363 */
  ldapListEmpty: 'No LDAP / Kerberos configurations on this instance.',
  /** EXPERIENCE.md:364 */
  walletListLabel: 'Wallet',
  /** EXPERIENCE.md:364 */
  walletColumnUseResource: 'Use resource',
  /** EXPERIENCE.md:364 */
  walletColumnEditResource: 'Edit resource',
  /** EXPERIENCE.md:364 */
  walletListEmpty: 'No wallet collections on this instance.',
  /** EXPERIENCE.md:364 */
  allowedDirectoriesLabel: 'Allowed directories',
  /** EXPERIENCE.md:364 */
  allowedDirectoriesColumnRestricted: 'Restricted',
  /** EXPERIENCE.md:364 */
  allowedDirectoriesEmpty: 'The instance\'s allow-list names no directory.',
  /** EXPERIENCE.md:364 */
  allowedDirectoryListPrompt1: 'Which server directories can a file or directory field choose from?',
  /** EXPERIENCE.md:364 */
  allowedDirectoryListPrompt2: 'Does this instance restrict the directories its file dialogs can reach?',
  /** EXPERIENCE.md:364 */
  allowedDirectoryListPrompt3: 'Is the manager directory one of the allowed directories?',
  /** EXPERIENCE.md:364 */
  pathPickerRootLabel: 'Allowed directory',
  /** EXPERIENCE.md:364 */
  pathPickerSubdirectoryLabel: 'Subdirectory',
  /** EXPERIENCE.md:364 */
  pathPickerFileLabel: 'File name',
  /** EXPERIENCE.md:364 */
  pathPickerResolvesTo: 'Resolves to <path>',
  /** EXPERIENCE.md:364 */
  pathPickerLoading: 'Reading the allowed directories\u2026',
  /** EXPERIENCE.md:364 */
  pathPickerTruncated: 'Only the first <n> allowed directories are listed.',
  /** EXPERIENCE.md:365 */
  walletSecretListLabel: 'Secrets',
  /** EXPERIENCE.md:365 */
  walletSecretListEmpty: 'No secrets in this collection.',
  /** EXPERIENCE.md:366 */
  oauthLabel: 'OAuth 2.0',
  /** EXPERIENCE.md:366 */
  oauthTabServerDescriptions: 'Client server descriptions',
  /** EXPERIENCE.md:366 */
  oauthTabClients: 'Client configurations',
  /** EXPERIENCE.md:366 */
  oauthTabResourceServers: 'Resource servers',
  /** EXPERIENCE.md:366 */
  oauthTabServer: 'Authorization server',
  /** EXPERIENCE.md:366 */
  oauthTabServerClients: 'Server client descriptions',
  /** EXPERIENCE.md:367 */
  oauthColumnClientType: 'Client type',
  /** EXPERIENCE.md:367 */
  oauthColumnDefaultScope: 'Default scope',
  /** EXPERIENCE.md:367 */
  oauthColumnScopes: 'Scopes',
  /** EXPERIENCE.md:367 */
  oauthColumnGrantTypes: 'Grant types',
  /** EXPERIENCE.md:367 */
  oauthColumnSigningAlgorithm: 'Signing algorithm',
  /** EXPERIENCE.md:367 */
  oauthColumnEncryptionAlgorithm: 'Encryption algorithm',
  /** EXPERIENCE.md:367 */
  oauthColumnKeyAlgorithm: 'Key algorithm',
  /** EXPERIENCE.md:367 */
  oauthColumnServerCredentials: 'Server credentials',
  /** EXPERIENCE.md:367 */
  oauthColumnClientId: 'Client ID',
  /** EXPERIENCE.md:367 */
  oauthColumnRedirectUrls: 'Redirect URLs',
  /** EXPERIENCE.md:367 */
  classicRowLinkDescription: 'Opens <page> in the classic portal in a new tab.',
  /** EXPERIENCE.md:368 */
  oauthServerDescriptionsEmpty: 'No client server descriptions on this instance.',
  /** EXPERIENCE.md:368 */
  oauthClientsEmpty: 'No client configurations on this instance.',
  /** EXPERIENCE.md:368 */
  oauthResourceServersEmpty: 'No resource servers on this instance.',
  /** EXPERIENCE.md:368 */
  oauthServerEmpty: 'No authorization server is configured on this instance.',
  /** EXPERIENCE.md:368 */
  oauthServerClientsEmpty: 'No server client descriptions on this instance.',
  /** EXPERIENCE.md:369 */
  taskOnDemandLabel: 'On-demand tasks',
  /** EXPERIENCE.md:369 */
  taskOnDemandEmpty: 'No tasks on this instance can be run on demand.',
  /** EXPERIENCE.md:370 */
  taskUpcomingLabel: 'Upcoming tasks',
  /** EXPERIENCE.md:370 */
  taskUpcomingColumnAt: 'Scheduled for',
  /** EXPERIENCE.md:370 */
  taskColumnSuspended: 'Suspended',
  /** EXPERIENCE.md:370 */
  taskUpcomingHorizon: 'Scheduled to run within',
  /** EXPERIENCE.md:370 */
  taskUpcomingHours1: 'The next hour',
  /** EXPERIENCE.md:370 */
  taskUpcomingHours4: 'The next 4 hours',
  /** EXPERIENCE.md:370 */
  taskUpcomingHours12: 'The next 12 hours',
  /** EXPERIENCE.md:370 */
  taskUpcomingHours24: 'The next 24 hours',
  /** EXPERIENCE.md:370 */
  taskUpcomingHours72: 'The next 3 days',
  /** EXPERIENCE.md:370 */
  taskUpcomingHours168: 'The next 7 days',
  /** EXPERIENCE.md:370 */
  taskUpcomingUntil: 'Until a date',
  /** EXPERIENCE.md:370 */
  taskUpcomingEmpty: 'No tasks are scheduled to run within this horizon.',
  /** EXPERIENCE.md:371 */
  taskHistoryLabel: 'Task history',
  /** EXPERIENCE.md:371 */
  taskHistoryColumnStarted: 'Started',
  /** EXPERIENCE.md:371 */
  taskHistoryColumnCompleted: 'Completed',
  /** EXPERIENCE.md:371 */
  taskHistoryColumnStatus: 'Status',
  /** EXPERIENCE.md:371 */
  taskHistoryColumnResult: 'Result',
  /** EXPERIENCE.md:371 */
  taskHistoryColumnTaskId: 'Task ID',
  /** EXPERIENCE.md:371 */
  taskHistoryColumnErrDate: 'Error date',
  /** EXPERIENCE.md:371 */
  taskHistoryColumnLogged: 'Logged',
  /** EXPERIENCE.md:371 */
  taskHistorySearch: 'Contains',
  /** EXPERIENCE.md:371 */
  taskHistoryUserOnly: 'User-defined tasks only',
  /** EXPERIENCE.md:371 */
  taskHistorySince: 'Logged since',
  /** EXPERIENCE.md:371 */
  taskHistoryEmpty: 'No task runs match.',
  /** EXPERIENCE.md:372 */
  taskRunsLabel: 'History',
  /** EXPERIENCE.md:372 */
  taskRunsEmpty: 'This task has no recorded runs.',
  /** EXPERIENCE.md:373 */
  taskDetailsLabel: 'Task details',
  /** EXPERIENCE.md:373 */
  taskDetailsGone: 'This task no longer exists.',
  /** EXPERIENCE.md:373 */
  taskDetailsTaskClass: 'Task class',
  /** EXPERIENCE.md:373 */
  taskDetailsPriority: 'Priority',
  /** EXPERIENCE.md:373 */
  taskDetailsRunAs: 'Run as',
  /** EXPERIENCE.md:373 */
  taskDetailsLastError: 'Last error',
  /** EXPERIENCE.md:373 */
  taskDetailsSchedule: 'Schedule',
  /** EXPERIENCE.md:373 */
  taskDetailsHowOften: 'How often',
  /** EXPERIENCE.md:373 */
  taskDetailsTimeOfDay: 'Time of day',
  /** EXPERIENCE.md:373 */
  taskDetailsNextSuspended: 'Not scheduled while suspended',
  /** EXPERIENCE.md:373 */
  taskDetailsEdit: 'Edit task',
  /** EXPERIENCE.md:373 */
  taskScheduleEveryDay: 'Every day',
  /** EXPERIENCE.md:373 */
  taskScheduleEveryNDays: 'Every {n} days',
  /** EXPERIENCE.md:373 */
  taskScheduleWeekly: 'Every week on {days}',
  /** EXPERIENCE.md:373 */
  taskScheduleWeeklyEveryN: 'Every {n} weeks on {days}',
  /** EXPERIENCE.md:373 */
  taskScheduleMonthlyDay: 'Every month on day {d}',
  /** EXPERIENCE.md:373 */
  taskScheduleMonthlyDayEveryN: 'Every {n} months on day {d}',
  /** EXPERIENCE.md:373 */
  taskScheduleMonthlySpecial: 'Every month on the {ordinal} {weekday}',
  /** EXPERIENCE.md:373 */
  taskScheduleMonthlySpecialEveryN: 'Every {n} months on the {ordinal} {weekday}',
  /** EXPERIENCE.md:373 */
  taskScheduleRunAfter: 'After another task completes',
  /** EXPERIENCE.md:373 */
  taskScheduleOnDemand: 'On demand only',
  /** EXPERIENCE.md:373 */
  taskScheduleOnceAt: 'Once at {time}',
  /** EXPERIENCE.md:373 */
  taskScheduleEveryMinute: 'Every minute between {start} and {end}',
  /** EXPERIENCE.md:373 */
  taskScheduleEveryNMinutes: 'Every {n} minutes between {start} and {end}',
  /** EXPERIENCE.md:373 */
  taskScheduleEveryHour: 'Every hour between {start} and {end}',
  /** EXPERIENCE.md:373 */
  taskScheduleEveryNHours: 'Every {n} hours between {start} and {end}',
  /** EXPERIENCE.md:373 */
  weekdaySunday: 'Sunday',
  /** EXPERIENCE.md:373 */
  weekdayMonday: 'Monday',
  /** EXPERIENCE.md:373 */
  weekdayTuesday: 'Tuesday',
  /** EXPERIENCE.md:373 */
  weekdayWednesday: 'Wednesday',
  /** EXPERIENCE.md:373 */
  weekdayThursday: 'Thursday',
  /** EXPERIENCE.md:373 */
  weekdayFriday: 'Friday',
  /** EXPERIENCE.md:373 */
  weekdaySaturday: 'Saturday',
  /** EXPERIENCE.md:373 */
  ordinalFirst: 'first',
  /** EXPERIENCE.md:373 */
  ordinalSecond: 'second',
  /** EXPERIENCE.md:373 */
  ordinalThird: 'third',
  /** EXPERIENCE.md:373 */
  ordinalFourth: 'fourth',
  /** EXPERIENCE.md:373 */
  ordinalFifth: 'fifth',
  /** EXPERIENCE.md:374 */
  processDetailsLabel: 'Process details',
  /** EXPERIENCE.md:374 */
  processDetailsGone: 'This process no longer exists.',
  /** EXPERIENCE.md:374 */
  processDetailsGroupGeneral: 'General',
  /** EXPERIENCE.md:374 */
  processDetailsGroupExecution: 'Execution',
  /** EXPERIENCE.md:374 */
  processDetailsGroupClientApplication: 'Client application',
  /** EXPERIENCE.md:374 */
  processDetailsParentPid: 'Parent process ID',
  /** EXPERIENCE.md:374 */
  processDetailsLoginRoles: 'Login roles',
  /** EXPERIENCE.md:374 */
  processDetailsEscalatedRoles: 'Escalated roles',
  /** EXPERIENCE.md:374 */
  processDetailsOsUser: 'OS user',
  /** EXPERIENCE.md:374 */
  processDetailsCpuTime: 'CPU time (ms)',
  /** EXPERIENCE.md:374 */
  processDetailsGlobalReferences: 'Global references',
  /** EXPERIENCE.md:374 */
  processDetailsPrivateGlobalReferences: 'Private global references',
  /** EXPERIENCE.md:374 */
  processDetailsPrivateGlobalBlocks: 'Private global blocks',
  /** EXPERIENCE.md:374 */
  processDetailsMemoryLimit: 'Memory limit (KB)',
  /** EXPERIENCE.md:374 */
  processDetailsMemoryPeak: 'Memory peak (KB)',
  /** EXPERIENCE.md:374 */
  processDetailsMemoryUsed: 'Memory used (KB)',
  /** EXPERIENCE.md:374 */
  processDetailsCurrentDevice: 'Current device',
  /** EXPERIENCE.md:374 */
  processDetailsOpenDevices: 'Open devices',
  /** EXPERIENCE.md:374 */
  processDetailsInTransaction: 'In transaction',
  /** EXPERIENCE.md:374 */
  processDetailsSourceLocation: 'Source location',
  /** EXPERIENCE.md:374 */
  processDetailsLocation: 'Location',
  /** EXPERIENCE.md:374 */
  processDetailsClientName: 'Client name',
  /** EXPERIENCE.md:374 */
  processDetailsClientExecutable: 'Client executable',
  /** EXPERIENCE.md:374 */
  processDetailsClientIpAddress: 'Client IP address',

  /** EXPERIENCE.md:375 */
  systemUsageLabel: 'System usage',
  /** EXPERIENCE.md:375 */
  systemUsageGlobalUpdates: 'Global updates',
  /** EXPERIENCE.md:375 */
  systemUsageRoutineCalls: 'Routine calls',
  /** EXPERIENCE.md:375 */
  systemUsageLogicalBlockRequests: 'Logical block requests',
  /** EXPERIENCE.md:375 */
  systemUsageBlockReads: 'Block reads',
  /** EXPERIENCE.md:375 */
  systemUsageBlockWrites: 'Block writes',
  /** EXPERIENCE.md:375 */
  systemUsageJournalEntries: 'Journal entries',
  /** EXPERIENCE.md:375 */
  systemUsageJournalBlockWrites: 'Journal block writes',
  /** EXPERIENCE.md:375 */
  systemUsageLastUpdate: 'Last update',
  /** EXPERIENCE.md:375 */
  systemUsageSharedMemory: 'Shared memory',
  /** EXPERIENCE.md:375 */
  systemUsageGlobalRefsPerSecond: 'Global references per second',
  /** EXPERIENCE.md:375 */
  systemUsageCacheEfficiency: 'Cache efficiency',
  /** EXPERIENCE.md:375 */
  systemUsageDatabaseSpace: 'Database space',
  /** EXPERIENCE.md:375 */
  systemUsageJournalSpace: 'Journal space',
  /** EXPERIENCE.md:375 */
  systemUsageLockTable: 'Lock table',
  /** EXPERIENCE.md:375 */
  systemUsageWriteDaemon: 'Write daemon',
  /** EXPERIENCE.md:375 */
  systemUsageEmpty: 'System usage is unavailable.',
  /** EXPERIENCE.md:376 */
  lockListLabel: 'Locks',
  /** EXPERIENCE.md:376 */
  lockColumnMode: 'Mode',
  /** EXPERIENCE.md:376 */
  lockColumnReference: 'Reference',
  /** EXPERIENCE.md:376 */
  lockColumnDirectory: 'Directory',
  /** EXPERIENCE.md:376 */
  lockColumnSystem: 'System',
  /** EXPERIENCE.md:376 */
  lockSystemLocal: 'This instance',
  /** EXPERIENCE.md:376 */
  lockListEmpty: 'No locks on this instance.',
  /** EXPERIENCE.md:377 */
  databaseListLabel: 'Databases',
  /** EXPERIENCE.md:377 */
  databaseFreeSpaceLabel: 'Free space',
  /** EXPERIENCE.md:377 */
  viewMenuLabel: 'View',
  /** EXPERIENCE.md:377 */
  databaseColumnSize: 'Size',
  /** EXPERIENCE.md:377 */
  databaseColumnMaxSize: 'Maximum size',
  /** EXPERIENCE.md:377 */
  databaseColumnAvailable: 'Available',
  /** EXPERIENCE.md:377 */
  databaseColumnDiskFree: 'Disk free',
  /** EXPERIENCE.md:377 */
  databaseColumnMounted: 'Mounted',
  /** EXPERIENCE.md:377 */
  databaseListEmpty: 'No databases on this instance.',
  /** EXPERIENCE.md:377 */
  databaseDetailsLabel: 'Database details',
  /** EXPERIENCE.md:377 */
  databaseDetailsGone: 'This database no longer exists.',
  /** EXPERIENCE.md:377 */
  databaseDetailsExpansionSize: 'Expansion size',
  /** EXPERIENCE.md:377 */
  databaseDetailsNewVolumeThreshold: 'New volume threshold',
  /** EXPERIENCE.md:377 */
  databaseDetailsNewVolumeDirectory: 'New volume directory',
  /** EXPERIENCE.md:377 */
  databaseDetailsKeepNewGlobals: 'Keep new globals',
  /** EXPERIENCE.md:377 */
  databaseDetailsNewGlobalCollation: 'New global collation',
  /** EXPERIENCE.md:377 */
  databaseDetailsClusterMountMode: 'Cluster mount mode',
  /** EXPERIENCE.md:377 */
  databaseDetailsReadOnly: 'Read only',
  /** EXPERIENCE.md:377 */
  databaseDetailsJournalNewGlobals: 'Journal new globals',
  /** EXPERIENCE.md:377 */
  databaseVolumeListLabel: 'Volume files',
  /** EXPERIENCE.md:377 */
  databaseVolumeColumnVolume: 'Volume',
  /** EXPERIENCE.md:377 */
  databaseVolumeColumnFile: 'File',
  /** EXPERIENCE.md:377 */
  databaseVolumeColumnDirectoryTotal: 'Directory total',
  /** EXPERIENCE.md:377 */
  databaseVolumeListEmpty: 'No volume files for this database.',
  /** EXPERIENCE.md:378 */
  deviceListLabel: 'Devices',
  /** EXPERIENCE.md:378 */
  deviceColumnPhysical: 'Physical device',
  /** EXPERIENCE.md:378 */
  deviceColumnSubtype: 'Subtype',
  /** EXPERIENCE.md:378 */
  deviceListEmpty: 'No devices on this instance.',

  // Not from the Fixed strings table, but required verbatim by this story's task
  // list: the audit-marker-failure fallback text (AD-15 / EXPERIENCE.md "9. **Audit.** Every confirmed"), the
  // reduced-motion word that replaces a running spinner (EXPERIENCE.md "**Reduced motion.** The highlight"), and
  // the product name (never typeset as the wordmark -- DESIGN.md -- but an ordinary
  // word wherever running text or a document <title> needs it).
  auditMarkerFailed: 'done \u00b7 audit not marked',
  auditMarkerMarked: 'done \u00b7 audit marked',
  accessibilityReducedMotionSpinnerWord: 'running',
  productName: 'OcuPilot',

  // The version-mismatch notice's sentence. It is a Fixed strings table row (:255), so it
  // ships like every other key here and not the way the three above do -- nothing names it
  // in `ui/tools/strings.test.mjs`'s REQUIRED_ALONGSIDE_TABLE. EXPERIENCE.md also
  // illustrates it in a State Patterns row at :446, where the version is spelled out as
  // "1"; the table's `<n>` is what is transcribed here, and the component substitutes the
  // reported version. The apostrophe is ASCII U+0027, transcribed byte for byte: a
  // typographic quote would respell the string.
  authAdminApiVersionMismatch: 'This instance\'s admin API is version <n>; OcuPilot needs version 2.',

  // The two navigation landmarks' accessible names, transcribed from EXPERIENCE.md's
  // Accessibility Floor -- "rail and side-bar = navigation (named "Areas" and "<Area>
  // screens")". They are authorized by a targeted extractor in `ui/tools/strings.test.mjs`
  // rather than by being named in `REQUIRED_ALONGSIDE_TABLE`, and the side bar's `<Area>` is
  // resolved in TypeScript from the same area name the rail renders.
  navRailLandmark: 'Areas',
  navSideBarLandmark: '<Area> screens',

  // Story 1.10's seven, every one re-derived from a UX document by its own targeted
  // extractor in `ui/tools/strings.test.mjs`, never by being added to
  // REQUIRED_ALONGSIDE_TABLE, whose own comment calls that the bypass it must not become.
  //
  // The locator bar's landmark name, from the same Landmarks line the two above come from:
  // "locator-bar = navigation "Breadcrumb"".
  navLocatorLandmark: 'Breadcrumb',

  // The skip link's label, from the same Landmarks line: "A "Skip to content" link is the first
  // Tab stop". Authorized by its own targeted extractor in `ui/tools/strings.test.mjs`.
  navSkipToContent: 'Skip to content',

  // The namespace switch's accessible name (EXPERIENCE.md "`{spacing.header-height}` band", "accessible name
  // "Namespace""). This story renders it as the slot's eyebrow; Story 1.11 turns the slot
  // into the select the same name labels.
  headerNamespaceLabel: 'Namespace',

  // The header lockup's accessible name (EXPERIENCE.md "the navy wordmark at 28 px on a white rounded tile with even padding"). The separator is an em dash,
  // authored as its escape (Rule 14); `epics.md:1350` renders the same name with a hyphen,
  // and EXPERIENCE.md is the authority for every word here. DESIGN.md:287 spells the alt
  // text "OcuPilot" instead -- filed, not reconciled in a component.
  headerHomeLink: 'OcuPilot \u2014 Home',

  // The four server-flag words (EXPERIENCE.md "status-bar; Home instance line", DESIGN.md:1025). The word is always
  // present, never colour alone; an instance with no mode set gets no badge rather than a
  // fifth word (DW-10).
  serverFlagLive: 'Live',
  serverFlagTest: 'Test',
  serverFlagFailover: 'Failover',
  serverFlagDevelopment: 'Development',

  // The log viewer both log screens share -- built by Story 6.13's alerts.log screen and declared
  // by Story 6.14's messages.log screen, which adds no string of its own.
  //
  // The severity words are the vendor's own five-level scale (`irissys/%sySystem.inc`: -2 and -1
  // debug, 0 informational, 1 warning, 2 severe, 3 fatal), one more than the four the archetype
  // row lists, and every rendered severity carries its word so colour is never alone.
  /** EXPERIENCE.md:379 */
  logViewerColumnSeverity: 'Severity',
  /** EXPERIENCE.md:379 */
  logViewerColumnMessage: 'Message',
  /** EXPERIENCE.md:379 */
  logViewerEmpty: 'No entries.',
  /** EXPERIENCE.md:379 */
  logViewerNoMatches: 'No matches.',
  /** EXPERIENCE.md:379 */
  logViewerLoadNewer: 'Load newer',
  /** EXPERIENCE.md:379 */
  logViewerJumpTop: 'Jump to top',
  /** EXPERIENCE.md:379 */
  logViewerJumpBottom: 'Jump to bottom',
  /** EXPERIENCE.md:379 */
  logSeverityDebug: 'Debug',
  /** EXPERIENCE.md:379 */
  logSeverityInfo: 'Info',
  /** EXPERIENCE.md:379 */
  logSeverityWarning: 'Warning',
  /** EXPERIENCE.md:379 */
  logSeveritySevere: 'Severe',
  /** EXPERIENCE.md:379 */
  logSeverityFatal: 'Fatal',

  // The alerts.log screen's own two, beyond the shared viewer's: its side-bar entry and title, and
  // the polite count the sticky search announces.
  /** EXPERIENCE.md:380 */
  alertLogListLabel: 'alerts.log',
  /** EXPERIENCE.md:380 */
  logViewerMatchCount: '<n> of <N>',

  // The messages.log screen's own two: its side-bar entry and title, and the control that clears
  // the severity-chip filter. Clear filter is published on this row rather than reused from
  // Component Patterns, which names it only as a `button-text` example (DW-1109).
  /** EXPERIENCE.md:381 */
  messagesLogListLabel: 'messages.log',
  /** EXPERIENCE.md:379 */
  logViewerClearFilter: 'Clear filter',

  // Story 15.1's six: the account menu's Change password item, which is also the dialog's title,
  // the two masked fields, the two names its reveal toggle takes -- they say password where
  // `agentDefinitionShowKey`/`HideKey` say key -- and the polite confirmation after the change.
  /** EXPERIENCE.md:382 */
  accountChangePassword: 'Change password',
  /** EXPERIENCE.md:382 */
  accountCurrentPasswordLabel: 'Current password',
  /** EXPERIENCE.md:382 */
  accountNewPasswordLabel: 'New password',
  /** EXPERIENCE.md:382 */
  accountShowPassword: 'Show password',
  /** EXPERIENCE.md:382 */
  accountHidePassword: 'Hide password',
  /** EXPERIENCE.md:382 */
  accountPasswordChanged: 'Password changed',

  // Story 15.2's fifteen: the two Home blocks' headings, empty states, per-row remove names and
  // Clear controls, the locator bar's favorite toggle in its two states, and the five polite
  // confirmations the two surfaces announce. The two `*RemoveNamed` values carry a <name>
  // placeholder the row resolves to the screen it removes.
  /** EXPERIENCE.md:383 */
  favoritesHeading: 'Favorites',
  /** EXPERIENCE.md:383 */
  favoritesEmpty: 'No favorites yet.',
  /** EXPERIENCE.md:383 */
  favoritesAdd: 'Add to favorites',
  /** EXPERIENCE.md:383 */
  favoritesRemove: 'Remove from favorites',
  /** EXPERIENCE.md:383 */
  favoritesRemoveNamed: 'Remove <name> from favorites',
  /** EXPERIENCE.md:383 */
  favoritesClear: 'Clear favorites',
  /** EXPERIENCE.md:383 */
  favoritesAdded: 'Added to favorites',
  /** EXPERIENCE.md:383 */
  favoritesRemoved: 'Removed from favorites',
  /** EXPERIENCE.md:383 */
  favoritesCleared: 'Favorites cleared',
  /** EXPERIENCE.md:383 */
  recentsHeading: 'Recent items',
  /** EXPERIENCE.md:383 */
  recentsEmpty: 'No recent items yet.',
  /** EXPERIENCE.md:383 */
  recentsRemoveNamed: 'Remove <name> from recent items',
  /** EXPERIENCE.md:383 */
  recentsClear: 'Clear recent items',
  /** EXPERIENCE.md:383 */
  recentsRemoved: 'Removed from recent items',
  /** EXPERIENCE.md:383 */
  recentsCleared: 'Recent items cleared',

  // Story 15.3's twenty-three: the account menu's About item, which is also the dialog's title,
  // the twelve field labels on its definition list -- the thirteenth reuses
  // `statusSegmentLicensedTo` and its dismissing action reuses `auditDialogClose`, because a value
  // already published belongs to one key -- Home's Shortcuts and Links blocks with the three
  // destinations the links panel names, the locator bar's Help control in its two names, and
  // DW-3's stale-bundle prompt with its one action.
  /** EXPERIENCE.md:384 */
  aboutTitle: 'About',
  /** EXPERIENCE.md:384 */
  aboutVersion: 'Version',
  /** EXPERIENCE.md:384 */
  aboutComponents: 'Components',
  /** EXPERIENCE.md:384 */
  aboutConfiguration: 'Configuration',
  /** EXPERIENCE.md:384 */
  aboutDatabaseCache: 'Database cache (MB)',
  /** EXPERIENCE.md:384 */
  aboutRoutineCache: 'Routine cache (MB)',
  /** EXPERIENCE.md:384 */
  aboutJournalFile: 'Journal file',
  /** EXPERIENCE.md:384 */
  aboutSuperServerPort: 'Superserver port',
  /** EXPERIENCE.md:384 */
  aboutWebServerPort: 'Web server port',
  /** EXPERIENCE.md:384 */
  aboutLicenseServer: 'License server',
  /** EXPERIENCE.md:384 */
  aboutEncryptionKeyId: 'Encryption key identifier',
  /** EXPERIENCE.md:384 */
  aboutLocale: 'Locale',
  /** EXPERIENCE.md:384 */
  aboutBuild: 'Build',
  /** EXPERIENCE.md:384 */
  shortcutsHeading: 'Shortcuts',
  /** EXPERIENCE.md:384 */
  shortcutsEmpty: 'No shortcuts available.',
  /** EXPERIENCE.md:384 */
  linksHeading: 'Links',
  /** EXPERIENCE.md:384 */
  linksDocumentation: 'Documentation',
  /** EXPERIENCE.md:384 */
  linksSupport: 'Support',
  /** EXPERIENCE.md:384 */
  linksInterSystems: 'InterSystems',
  /** EXPERIENCE.md:384 */
  helpLabel: 'Help',
  /** EXPERIENCE.md:384 */
  helpForScreen: 'Help for this screen',
  /** EXPERIENCE.md:384 */
  staleBundleNotice: 'A newer version of OcuPilot is installed. Reload to use it.',
  /** EXPERIENCE.md:384 */
  actionReload: 'Reload',

  // Story 15.4's seven: Home's System Information block heading, five of its seven row labels,
  // and the word a row shows when the instance reports no value for it. The other two labels are
  // keys that already exist -- `lockListLabel` for "Locks" and `systemUsageWriteDaemon` for
  // "Write daemon" -- because a value already published belongs to one key. Neither the four
  // alert words nor the mirror and production states are strings here: they are the source's own
  // and are rendered as it reports them.
  /** EXPERIENCE.md:385 */
  systemInfoHeading: 'System information',
  /** EXPERIENCE.md:385 */
  systemInfoUptime: 'Uptime',
  /** EXPERIENCE.md:385 */
  systemInfoMirror: 'Mirror',
  /** EXPERIENCE.md:385 */
  systemInfoDatabase: 'Database',
  /** EXPERIENCE.md:385 */
  systemInfoJournal: 'Journal',
  /** EXPERIENCE.md:385 */
  systemInfoProduction: 'Production',
  /** EXPERIENCE.md:385 */
  systemInfoNotReported: 'Not reported',

  // Story 15.5's one: the empty state a Home block shows when every row the instance holds for it
  // names a screen this build does not serve (DW-1328). One value for both blocks, so neither
  // republishes it, and the block keeps its Clear control beside it.
  /** EXPERIENCE.md:386 */
  rememberedNoScreensHere: 'No screens this instance still serves.',

  // Two connectivity sentences EXPERIENCE.md publishes outside the Fixed strings table, each
  // authorized by its own targeted extractor in `ui/tools/strings.test.mjs`, never by being
  // added to REQUIRED_ALONGSIDE_TABLE, whose own comment calls that the bypass it must not
  // become.
  //
  // The unreachable banner's body, published twice and identically: the Voice and Tone table's
  // *Do* column (:235) and the Instance-unreachable State Patterns row (:455). The extractor
  // reads :455 and asserts :235 carries the same sentence, so the two cannot drift apart
  // unnoticed. Every character is ASCII, so no escape is needed (Rule 14 still applies to any
  // later edit).
  connectivityBannerUnreachable: 'The instance is unreachable. Check that IRIS is running, then retry.',

  // The generic server-fault body, from the Generic-internal-error State Patterns row (:457).
  // The browser is told this and nothing more; the detail is on the instance (AD-12, AD-39).
  connectivityServerFault: 'Something failed on the instance. Retry; if it keeps failing, check messages.log.',

  // The transcript's accessible name, from the panel's Body rule: `role="log"`, polite,
  // `aria-label="Conversation"`. Authorized by its own targeted extractor in
  // `ui/tools/strings.test.mjs`.
  agentConversationLabel: 'Conversation',

  // The composer caption as macOS spells its chord: the table's caption row carries "(\u2318I on
  // macOS)" beside the Ctrl+I form, and the extractor derives this value from that row.
  agentComposerCaptionMac: 'Enter to send \u00b7 Shift+Enter for a new line \u00b7 \u2318I to focus',

  // Two Fixed strings rows this story adds (Story 5.2), gated like every other table literal.
  //
  // The entity noun is the singular the card title needs: the wire carries the slug
  // `web-application` and the mirror's `labelKey` is the plural screen label, so a screen
  // descriptor declares this key and the card resolves it through `stringFor`.
  /** EXPERIENCE.md:387 */
  proposalEntityWebApplication: 'Web application',
  /** EXPERIENCE.md:388 */
  proposalAuditWarning: 'Agent writes will no longer be marked in the audit database.',

  // Story 5.7's five. The first three are AD-14's closed action set as published sentences: the
  // off-screen toast renders one, and the panel appends the same one to a confirmed write's reply
  // so the record outlives a toast that expired or was never raised. `<entity>` resolves to the
  // entity's own id; the noun is on the toast's own link, which names the screen. A data table
  // announces the same sentence when a change marks one of its rows.
  /** EXPERIENCE.md:390 */
  tableChangeCreated: '<entity> was created',
  /** EXPERIENCE.md:390 */
  tableChangeUpdated: '<entity> was updated',
  /** EXPERIENCE.md:390 */
  tableChangeDeleted: '<entity> was deleted',
  /** EXPERIENCE.md:391 */
  tableChangeToastRegion: 'Changes',
  /** EXPERIENCE.md:391 */
  tableChangeToastDismiss: 'Dismiss',

  // Story 5.8's one. The direction word completes the pair "was"/"now" carries on a changed row:
  // an unchanged row has one value and no arrow, so the word is what says the payload sends the
  // field as the instance holds it. The audit-entry offer the panel appends needs no new key --
  // `agentAuditFollowUpQuestion` above is that published sentence already.
  /** EXPERIENCE.md:393 */
  proposalDiffUnchanged: 'unchanged',

  // Story 5.10's one (DW-1232). Confirm was `aria-disabled` while a declared secret the write
  // sends was still empty, with nothing saying so: the reason is published here and wired through
  // `aria-describedby`, so a screen reader is told why the button refuses rather than only that it
  // does.
  /** EXPERIENCE.md:394 */
  proposalSecretsRequired: 'Fill in every masked field to confirm.',

  // Story 5.13's three. The first two are the diff-row pattern's removal forms, stated in prose
  // rather than in the Fixed strings table: `proposalDiffRemovedValue` is what the after cell
  // draws, and `proposalDiffRemoved` is the visually hidden direction word that replaces "now", so
  // the row reads "<field>: <value>, removed". The marker itself is `aria-hidden`, which is what
  // keeps the two from being spoken twice.
  proposalDiffRemovedValue: '(removed)',
  proposalDiffRemoved: 'removed',

  // The residue sentence AD-48 requires of a delete proposal's card: the card lists the errors the
  // confirm removes, and this says that errors logged after the proposal are not among them. `<n>`
  // resolves to how many rows the card lists.
  /** EXPERIENCE.md:260 */
  proposalResidue:
    'Removes exactly the <n> errors listed here. Any logged since the proposal will remain.',

  // Story 8.1's twelve. The Web applications list becomes write-capable, so its empty state
  // invites the agent instead of naming a next step, and the create form beside it publishes the
  // labels the classic editor's own field order carries. Every other label the form draws is a key
  // that already exists: the name, description, namespace, enabled, dispatch class and
  // resource columns, the Services list's own "Authentication methods" heading, the
  // required-fields legend, Save, Cancel and the saved confirmation.
  /** EXPERIENCE.md:395 */
  webAppListEmptyAgent: 'create a web application for a REST API',
  /** EXPERIENCE.md:396 */
  webAppFormLabel: 'New web application',
  /** EXPERIENCE.md:396 */
  webAppFormType: 'Application type',
  /** EXPERIENCE.md:396 */
  webAppFormTypeCsp: 'CSP/ZEN',
  /** EXPERIENCE.md:396 */
  webAppFormTypeRest: 'REST',
  /** EXPERIENCE.md:396 */
  webAppFormTypePython: 'Python (WSGI or ASGI)',
  /** EXPERIENCE.md:396 */
  webAppFormPythonProtocol: 'Python protocol type',
  /** EXPERIENCE.md:396 */
  webAppFormPythonFile: 'Application file',
  /** EXPERIENCE.md:396 */
  webAppFormPythonCallable: 'Callable name',
  /** EXPERIENCE.md:396 */
  webAppFormPythonDirectory: 'Application directory',
  /** EXPERIENCE.md:396 */
  webAppFormRecurse: 'Include subdirectories',
  /** EXPERIENCE.md:396 */
  webAppFormRefusedAction: 'create a web application',

  // Story 8.2. The Users list becomes write-capable, so its empty state invites the agent (the
  // create-a-user form's privilege refusal names the same action), and the form publishes the
  // labels the classic editor carries that no existing key holds.
  // Name, full name, password and roles are keys that already exist (`tableColumnName`,
  // `userColumnFullName`, `fieldPassword`, `userColumnRoles`). The last two are the web-application
  // form's resolved Python directory line and the unauthenticated effect, which the proposal card
  // reads too.
  /** EXPERIENCE.md:397 */
  userListEmptyAgent: 'create a user',
  /** EXPERIENCE.md:398 */
  userFormLabel: 'New user',
  /** EXPERIENCE.md:398 */
  userFormExpiry: 'Account expiration date',
  /** EXPERIENCE.md:398 */
  userFormNamespace: 'Startup namespace',
  /** EXPERIENCE.md:398 */
  userFormRoutine: 'Startup tag^routine',
  /** EXPERIENCE.md:399 */
  webAppFormPythonDirectoryResolved: 'Resolved directory on this instance',
  /** EXPERIENCE.md:400 */
  webAppUnauthenticatedEffect:
    'Anyone who can reach this address can use the application without signing in.',

  // Story 8.3. The Roles list becomes write-capable, so its empty state invites the agent (the
  // create-a-role form's privilege refusal names the same action), and the form and its grant
  // dialog publish the labels no existing key holds. Name, description, the Resources heading, the
  // resource picker's label, the permissions group and Edit are keys that already exist
  // (`tableColumnName`, `tableColumnDescription`, `resourceListLabel`, `webAppColumnResource`,
  // `navAreaPermissions`, `agentPanelSecretWarningEdit`).
  /** EXPERIENCE.md:401 */
  roleListEmptyAgent: 'create a role',
  /** EXPERIENCE.md:402 */
  roleFormLabel: 'New role',
  /** EXPERIENCE.md:402 */
  roleFormGrantedRoles: 'Granted roles',
  /** EXPERIENCE.md:402 */
  roleGrantAdd: 'Add a grant',
  /** EXPERIENCE.md:402 */
  roleGrantDialogAdd: 'Add a resource grant',
  /** EXPERIENCE.md:402 */
  roleGrantDialogEdit: 'Edit the grant on <resource>',
  /** EXPERIENCE.md:402 */
  roleGrantCurrent: 'Current grant',
  /** EXPERIENCE.md:402 */
  roleGrantResulting: 'Resulting grant',
  /** EXPERIENCE.md:402 */
  roleGrantNone: 'No grant',
  /** EXPERIENCE.md:402 */
  permissionRead: 'Read',
  /** EXPERIENCE.md:402 */
  permissionWrite: 'Write',
  /** EXPERIENCE.md:402 */
  permissionUse: 'Use',
  /** EXPERIENCE.md:402 */
  actionRemove: 'Remove',

  // Story 8.3, AD-10: a privilege grant is permitted at the strongest confirmation. The form states
  // its consequence at the field and the proposal card at the diff; the second replaces both it and
  // `webAppUnauthenticatedEffect` on an unauthenticated web application.
  /** EXPERIENCE.md:403 */
  privilegedGrantEffect:
    'This grants %All or an administrative privilege. Whoever holds it can administer this instance.',
  /** EXPERIENCE.md:404 */
  privilegedGrantEffectUnauthenticated:
    'Anyone who can reach this address runs with %All or an administrative privilege without signing in. With %All, that is full control of this instance.',
  /** EXPERIENCE.md:405 */
  webAppFormApplicationRoles: 'Application roles',

  // Story 8.4: the Resources list's agent invitation, and the resource editor dialog's two headings.
  /** EXPERIENCE.md:406 */
  resourceListEmptyAgent: 'create a resource',
  /** EXPERIENCE.md:407 */
  resourceEditorCreate: 'New resource',
  resourceEditorEdit: 'Edit resource <name>',

  // Story 8.5: the X.509 list's Import, its agent invitation, the X.509 credential form's labels and
  // helpers, and the proposal card's mark on a secret the confirm may leave empty.
  /** EXPERIENCE.md:408 */
  actionImport: 'Import',
  /** EXPERIENCE.md:409 */
  x509ListEmptyAgent: 'import a certificate',
  /** EXPERIENCE.md:410 */
  x509FormLabel: 'X.509 credential',
  x509FieldCertificate: 'Certificate',
  x509FieldPrivateKey: 'Private key',
  x509FieldPrivateKeyPassword: 'Private key password',
  x509FieldOwnerList: 'Authorized users',
  x509FieldPeerNames: 'Intended peers',
  x509FieldCaFile: 'Trusted CA file',
  x509FieldHasPrivateKey: 'Private key present',
  x509LoadFromFile: 'Load from file',
  /** EXPERIENCE.md:411 */
  x509PasswordHelp: 'Only for an encrypted key.',
  x509ListHelp: 'Comma-separated.',
  /** EXPERIENCE.md:412 */
  proposalSecretOptional: 'optional',

  // Story 8.6: the Secrets list's agent invitation, the wallet secret form's title, labels, uses and
  // helpers, and what its read-only view says of a secret type it does not edit.
  /** EXPERIENCE.md:413 */
  walletSecretListEmptyAgent: 'store a secret',
  /** EXPERIENCE.md:414 */
  walletSecretFormLabel: 'Secret',
  walletFieldCollection: 'Collection',
  walletFieldUsage: 'Usage',
  walletFieldRequireTls: 'Require TLS',
  walletFieldAllowedHosts: 'Allowed hosts',
  walletUsageHttp: 'HTTP',
  walletUsageSql: 'SQL gateway',
  walletUsageSoap: 'SOAP',
  walletUsageCustom: 'Custom',
  /** EXPERIENCE.md:415 */
  walletValueHelp: 'Stored as typed. For HTTP, SOAP or SQL use, enter a JSON object with user and password members.',
  walletHostsHelp: 'Comma-separated. Applies only when TLS is required.',
  /** EXPERIENCE.md:416 */
  walletTypeReadOnly: 'Only key-value secrets are edited here.',
  walletTypeElsewhere: 'Manage RSA and symmetric-key secrets through the %Wallet classes. The classic portal has no wallet page.',

  // Story 8.8: the Devices list's agent invitation, the device editor's title, the labels of the
  // fields the list does not carry, and its type and prompt choices.
  /** EXPERIENCE.md:417 */
  deviceListEmptyAgent: 'create a device',
  /** EXPERIENCE.md:418 */
  deviceFormLabel: 'Device',
  deviceFieldOpenParameters: 'Open parameters',
  deviceFieldAlternate: 'Alternate device',
  deviceFieldPrompt: 'Prompt',
  /** EXPERIENCE.md:419 */
  deviceTypeTerminal: 'Terminal',
  deviceTypeSpool: 'Spooling device',
  deviceTypeMagTape: 'Magnetic tape drive',
  deviceTypeCartridge: 'Cartridge tape drive',
  deviceTypeIpc: 'Interprocess communication',
  deviceTypeOther: 'Other',
  /** EXPERIENCE.md:420 */
  devicePromptShow: 'Show device prompt',
  devicePromptAuto: 'Use this device automatically when it is the current device',
  devicePromptPredefined: 'Use this device automatically with predefined settings',
  /** EXPERIENCE.md:421 */
  deviceFormRefusedAction: 'change this device',
  /** EXPERIENCE.md:422 */
  agentDefinitionFieldEnvVar: 'Environment variable',
  /** EXPERIENCE.md:422 */
  agentDefinitionEnvVarCaption:
    'The key is read from this variable on the instance\u2019s host. Set it there; this form never takes the key.',
  /** EXPERIENCE.md:423 */
  agentGateLandingBannerEnv:
    'OcuPilot needs one agent definition before the panel can help. Anthropic is selected \u2014 set the environment variable named below on the instance\u2019s host and press Test connection. You can skip this and browse.',

  // The self-protection refusal for OcuPilot's own web applications, and the delete dialog's
  // consequence body. The refusal is one sentence for two surfaces -- the row action drawn
  // disabled before a click, and the envelope `reason` after one -- so the server holds the same
  // literal in `Prohibited.SERVINGPATHREASON`, `ui/tools/self-protection.test.mjs` pins the two
  // equal, and OcuPilot.Test.RefusalCopy holds the instance's own half (AD-53, AD-39).
  /** EXPERIENCE.md:424 */
  webAppServesOcuPilotRefusal:
    'OcuPilot serves itself through this web application. Disabling or deleting it would cut off every user, including you.',
  /** EXPERIENCE.md:425 */
  webAppDeleteConsequence:
    'Deleting this web application stops every request it serves. This cannot be undone.',

  // The phrase that resolves `tableWriteCapableEmptyState`'s placeholder on the Web applications
  // list, which Story 7.1 makes write-capable by declaring its three row actions.

  // Story 7.2: the Users list's row actions. The four account refusals are caller-neutral because
  // one predicate refuses the agent and the screen alike (AD-10, AD-53); each is held once on the
  // server beside the other refusal reasons and pinned equal to this copy.
  /** EXPERIENCE.md:426 */
  userRefusalCurrentUser:
    'This is the account you are signed in as. Disabling or deleting it would lock you out.',
  /** EXPERIENCE.md:427 */
  userRefusalSystemAccount:
    '_SYSTEM is the instance\'s own predefined account. Disabling or deleting it is not available here.',
  /** EXPERIENCE.md:428 */
  userRefusalServiceAccount:
    'The instance\'s own services run as this account. Disabling or deleting it would stop them, OcuPilot included.',
  /** EXPERIENCE.md:429 */
  userRefusalLastAllHolder:
    'This is the last account that holds %All. Disabling it, deleting it or taking the role off it would leave nobody able to administer this instance.',
  /** EXPERIENCE.md:430 */
  userDeleteConsequence:
    'Deleting this user removes the account and every role it holds. This cannot be undone.',
  /** EXPERIENCE.md:431 */
  userActionSetPassword: 'Set password',
  /** EXPERIENCE.md:431 */
  userPasswordChangeOnLogin: 'Require a password change at next sign-in',
  /** EXPERIENCE.md:431 */
  userActionAddRole: 'Add role',
  /** EXPERIENCE.md:431 */
  userActionRemoveRole: 'Remove role',
  /** EXPERIENCE.md:431 */
  userRoleField: 'Role',
  // The phrase that resolves `tableWriteCapableEmptyState`'s placeholder on the Users list; Story
  // 8.2 declares the same key with the same value.

  // Story 7.3: the two OAuth 2.0 tabs' delete row action.
  /** EXPERIENCE.md:432 */
  oauthClientDeleteConsequence:
    'Deleting this client configuration removes every token stored for it, and applications that use it can no longer obtain new ones. This cannot be undone.',
  /** EXPERIENCE.md:433 */
  oauthServerClientDeleteConsequence:
    'Deleting this server client description revokes every access token issued to it, and the client can no longer obtain new ones from this authorization server. This cannot be undone.',
  /** EXPERIENCE.md:434 */
  oauthClientsEmptyAgent: 'create an OAuth 2.0 client configuration',
  /** EXPERIENCE.md:435 */
  oauthServerClientsEmptyAgent: 'create a server client description',

  // Story 7.4: the Auditing configuration screen and its two embedded event lists.
  /** EXPERIENCE.md:436 */
  auditingTurnOffAction: 'Turn auditing off',
  /** EXPERIENCE.md:436 */
  actionProceed: 'Proceed',
  /** EXPERIENCE.md:437 */
  auditingStatusOn: 'Auditing is on.',
  /** EXPERIENCE.md:437 */
  auditingStatusOff: 'Auditing is off.',
  /** EXPERIENCE.md:438 */
  auditSystemEventListLabel: 'System events',
  /** EXPERIENCE.md:438 */
  auditUserEventListLabel: 'User events',
  /** EXPERIENCE.md:439 */
  auditEventColumnTotal: 'Total',
  /** EXPERIENCE.md:439 */
  auditEventColumnWritten: 'Written',
  /** EXPERIENCE.md:439 */
  auditEventColumnLost: 'Lost',
  /** EXPERIENCE.md:440 */
  auditSystemEventListEmpty: 'No system events.',
  /** EXPERIENCE.md:440 */
  auditUserEventListEmpty: 'No user events.',

  // Story 7.5: running an on-demand task.
  /** EXPERIENCE.md:441 */
  taskOnDemandEmptyAgent: 'create a task that runs on demand',
  /** EXPERIENCE.md:442 */
  proposalEntityTask: 'Task',

  // Story 7.6: the Task schedule's row actions.
  /** EXPERIENCE.md:443 */
  taskDeleteConsequence:
    'Deleting this task removes it from the schedule, so it no longer runs. Its history is kept. This cannot be undone.',
  /** EXPERIENCE.md:444 */
  taskScheduleEmptyAgent: 'create a task that runs on a schedule',
  /** EXPERIENCE.md:445 */
  taskSystemDeleteConsequence:
    'This is one of the instance\'s own system tasks, and the instance relies on it. The classic portal does not allow deleting it.',

  // Story 7.8: process terminate, suspend and resume from the list and the details page.
  /** EXPERIENCE.md:446 */
  actionTerminate: 'Terminate',
  /** EXPERIENCE.md:447 */
  processTerminateConsequence:
    'Terminating this process stops it at once, and it does not finish what it was doing. This cannot be undone.',
  /** EXPERIENCE.md:448 */
  processTerminateErrorFlag: 'Log a <RESJOB> error in its namespace\'s application error log',
  /** EXPERIENCE.md:449 */
  processRefusalOcuPilot:
    'OcuPilot itself is running in this process, for this request or for an agent turn. It cannot be suspended, resumed or terminated from OcuPilot.',
  /** EXPERIENCE.md:450 */
  processRefusalSystem:
    'This is an IRIS system process, and the instance relies on it. It cannot be suspended, resumed or terminated from OcuPilot.',
  /** EXPERIENCE.md:451 */
  processListEmptyAgent: 'suspend or terminate a process that has stopped responding',
  /** EXPERIENCE.md:452 */
  proposalEntityProcess: 'Process',

  // Story 7.10: the application error log's three delete scopes.
  /** EXPERIENCE.md:453 */
  errorDeleteEveryVerb: 'Delete the errors in',
  /** EXPERIENCE.md:453 */
  errorDeleteDateVerb: 'Delete the errors of',
  /** EXPERIENCE.md:453 */
  errorDeleteOneVerb: 'Delete error',
  /** EXPERIENCE.md:454 */
  errorDeleteEveryConsequence:
    'Deleting removes every application error this namespace has logged, on every date, and everything each one captured. Errors logged after you confirm are kept. This cannot be undone.',
  /** EXPERIENCE.md:455 */
  errorDeleteDateConsequence:
    'Deleting removes every application error this namespace logged on this date, and everything each one captured. Errors logged after you confirm are kept. This cannot be undone.',
  /** EXPERIENCE.md:456 */
  errorDeleteOneConsequence:
    'Deleting removes this application error and everything it captured. This cannot be undone.',

  // Story 7.11: system and user audit event configuration, and selective SQL auditing.
  /** EXPERIENCE.md:457 */
  actionResetCounters: 'Reset counters',
  /** EXPERIENCE.md:458 */
  auditUserEventDeleteConsequence:
    'Deleting this event removes its registration, and the instance discards every record raised for it until it is registered again. This cannot be undone.',
  /** EXPERIENCE.md:459 */
  auditSystemEventListEmptyAgent: 'enable an event this instance should record',
  /** EXPERIENCE.md:460 */
  auditUserEventListEmptyAgent: 'register an audit event for an application',
  /** EXPERIENCE.md:461 */
  auditSqlWizardAction: 'Selective SQL auditing',
  /** EXPERIENCE.md:461 */
  auditSqlWizardPrompt: 'Which SQL statement types and sources should this instance audit?',
  /** EXPERIENCE.md:462 */
  auditSqlSourceDynamic: 'Dynamic',
  /** EXPERIENCE.md:462 */
  auditSqlSourceEmbedded: 'Embedded',
  /** EXPERIENCE.md:462 */
  auditSqlSourceXdbc: 'XDBC',
  /** EXPERIENCE.md:462 */
  auditSqlKindQuery: 'Query',
  /** EXPERIENCE.md:462 */
  auditSqlKindDdl: 'DDL',
  /** EXPERIENCE.md:462 */
  auditSqlKindDml: 'DML',
  /** EXPERIENCE.md:462 */
  auditSqlKindUtility: 'Utility',
  /** EXPERIENCE.md:463 */
  actionApply: 'Apply',
  /** EXPERIENCE.md:463 */
  auditSqlWizardStopped: 'Not every change was applied. The list shows each event as it is now.',
  /** EXPERIENCE.md:467 */
  userRefusalServiceAccountSignIn:
    'The instance\'s own services sign in as this account. A new password or a required password change would stop them, OcuPilot included.',
  /** EXPERIENCE.md:468 */
  userFieldComment: 'Comment',
  /** EXPERIENCE.md:468 */
  userFieldPasswordNeverExpires: 'Password never expires',
  /** EXPERIENCE.md:468 */
  userFieldAccountNeverExpires: 'Account never expires',
  /** EXPERIENCE.md:468 */
  userFieldEmail: 'Email address',
  /** EXPERIENCE.md:468 */
  userFieldPhoneProvider: 'Mobile phone service provider',
  /** EXPERIENCE.md:468 */
  userFieldPhoneNumber: 'Mobile phone number',
  /** EXPERIENCE.md:468 */
  userFieldTwoFactor: 'Two-factor authentication',
  /** EXPERIENCE.md:468 */
  userFieldTwoFactorSms: 'SMS text',
  /** EXPERIENCE.md:468 */
  userFieldTwoFactorTotp: 'Time-based one-time password',
  /** EXPERIENCE.md:468 */
  userFieldShowQrCode: 'Show the QR code at next sign-in',
  /** EXPERIENCE.md:468 */
  userRolesEmpty: 'This account holds no roles.',
  /** EXPERIENCE.md:469 */
  formTabErrorOne: '<tab>, 1 error',
  /** EXPERIENCE.md:469 */
  formTabErrorMany: '<tab>, <n> errors',
  /** EXPERIENCE.md:470 */
  userPromptGroupSignIn: 'Sign-in',
  /** EXPERIENCE.md:470 */
  userPromptGroupAccess: 'Access',
  /** EXPERIENCE.md:470 */
  userPromptSignIn: 'Why can this user not sign in?',
  /** EXPERIENCE.md:470 */
  userPromptPrivilege: 'Which of this user\'s roles grant %All or an administrative privilege?',
  /** EXPERIENCE.md:470 */
  userPromptTwoFactor: 'Turn on two-factor sign-in for this user.',

  // Story 15.6: the account menu's theme toggle.
  /** EXPERIENCE.md:464 */
  accountDarkTheme: 'Dark theme',

  // Story 9.2: the web application editor. Its title, General and Application roles tabs, and every
  // other label it draws reuse keys that already exist.
  /** EXPERIENCE.md:471 */
  webAppFieldDefaultApplication: 'Namespace default application',
  /** EXPERIENCE.md:471 */
  webAppFieldPackage: 'Package name',
  /** EXPERIENCE.md:471 */
  webAppFieldSuperClass: 'Default superclass',
  /** EXPERIENCE.md:471 */
  webAppFieldGroupById: 'Group by ID',
  /** EXPERIENCE.md:471 */
  webAppFieldTimeout: 'Session timeout (seconds)',
  /** EXPERIENCE.md:471 */
  webAppFieldJwt: 'JWT authentication',
  /** EXPERIENCE.md:471 */
  webAppFieldJwtAccessTimeout: 'JWT access token timeout (seconds)',
  /** EXPERIENCE.md:471 */
  webAppFieldJwtRefreshTimeout: 'JWT refresh token timeout (seconds)',
  /** EXPERIENCE.md:471 */
  webAppFieldLockCspName: 'Lock CSP name',
  /** EXPERIENCE.md:471 */
  webAppFieldAutoCompile: 'Automatic compilation',
  /** EXPERIENCE.md:471 */
  webAppFieldServeFiles: 'Serve files',
  /** EXPERIENCE.md:471 */
  webAppFieldServeFilesTimeout: 'Serve files timeout (seconds)',
  /** EXPERIENCE.md:471 */
  webAppFieldPath: 'Physical path',
  /** EXPERIENCE.md:471 */
  webAppTabMatchingRoles: 'Matching roles',
  /** EXPERIENCE.md:471 */
  webAppTabCors: 'Cross-origin settings',
  /** EXPERIENCE.md:471 */
  webAppFieldCorsAllowlist: 'Allowed origins',
  /** EXPERIENCE.md:471 */
  webAppFieldCorsCredentials: 'Allow credentials',
  /** EXPERIENCE.md:471 */
  webAppFieldCorsHeaders: 'Allowed headers',
  /** EXPERIENCE.md:471 */
  webAppCorsListCaption: 'One entry per line.',
  /** EXPERIENCE.md:471 */
  webAppFieldMatchRole: 'Matching role',
  /** EXPERIENCE.md:471 */
  webAppRoleAssign: 'Assign',
  /** EXPERIENCE.md:471 */
  webAppApplicationRolesEmpty: 'This application grants no application roles.',
  /** EXPERIENCE.md:471 */
  webAppMatchingRolesEmpty: 'This application grants no matching roles.',
  /** EXPERIENCE.md:472 */
  webAppEditorFixedFields: 'Where this application\'s files live is set when it is created.',
  /** EXPERIENCE.md:473 */
  webAppNoResourceEffect: 'No resource guards this application now, so anyone who can sign in can use it.',
  /** EXPERIENCE.md:474 */
  webAppRepointedEffect: 'A different class now answers this address.',
  /** EXPERIENCE.md:475 */
  webAppPrivilegeGrantRefusal:
    'OcuPilot\'s own web applications carry only the roles its installer gives them. A role set there would run every OcuPilot request with it.',
  /** EXPERIENCE.md:476 */
  agentCredTypeUnavailable:
    'The credential store is not available in this namespace. Read the key from an environment variable instead.',
  /** EXPERIENCE.md:477 */
  webAppPromptGroupCode: 'Code',
  /** EXPERIENCE.md:477 */
  webAppPromptAccess: 'Who can use this web application, and what does it grant them?',
  /** EXPERIENCE.md:477 */
  webAppPromptUnauthenticated: 'Is this web application reachable without signing in?',
  /** EXPERIENCE.md:477 */
  webAppPromptCode: 'Which code answers at this web application\'s address?',

  // Story 9.3: the role editor, the role and resource deletes, and their refusals.
  /** EXPERIENCE.md:478 */
  roleEditorTabMembers: 'Members',
  /** EXPERIENCE.md:478 */
  roleEditorTabAssignedTo: 'Assigned to',
  /** EXPERIENCE.md:478 */
  roleMemberTypeUser: 'Account',
  /** EXPERIENCE.md:478 */
  roleMemberTypeEscalation: 'Account (escalation)',
  /** EXPERIENCE.md:478 */
  roleMembersEmpty: 'No account or role holds this role.',
  /** EXPERIENCE.md:478 */
  roleAssignedToEmpty: 'This role carries no other role.',
  /** EXPERIENCE.md:479 */
  roleDeleteConsequence: 'Deleting this role takes it from every account and role that holds it. This cannot be undone.',
  /** EXPERIENCE.md:479 */
  resourceDeleteConsequence: 'Every role that grants this resource loses it. This cannot be undone.',
  /** EXPERIENCE.md:480 */
  roleRefusalSystem: 'A name beginning with % belongs to one of the instance\'s own roles.',
  /** EXPERIENCE.md:480 */
  resourceRefusalSystem: 'This is a system resource. IRIS does not allow it to be deleted.',
  /** EXPERIENCE.md:481 */
  uncoveredFieldRefusal: 'Only some of this kind of object\'s settings can be changed here, and that is not one of them.',
  /** EXPERIENCE.md:481 */
  roleRefusalOcuPilot:
    'This role belongs to OcuPilot, which stops working without what it grants. Only OcuPilot\'s installer changes or removes it.',
  /** EXPERIENCE.md:481 */
  resourceRefusalOcuPilot:
    'This resource guards OcuPilot\'s own data or administration. It cannot be deleted or opened to every user; only OcuPilot\'s installer changes it.',
  /** EXPERIENCE.md:482 */
  rolePromptHolders: 'Who holds this role, and what does it grant them?',
  /** EXPERIENCE.md:482 */
  rolePromptPrivilege: 'Does this role grant any administrative privilege?',
  /** EXPERIENCE.md:482 */
  rolePromptGrantedRoles: 'Which other roles does this role carry?',
  /** EXPERIENCE.md:483 */
  sslFormLabel: 'SSL/TLS configuration',
  /** EXPERIENCE.md:483 */
  sslTabVerification: 'Verification',
  /** EXPERIENCE.md:483 */
  sslTabCredentials: 'Credentials',
  /** EXPERIENCE.md:483 */
  sslTabCryptography: 'Cryptographic settings',
  /** EXPERIENCE.md:483 */
  sslTabOcsp: 'OCSP settings',
  /** EXPERIENCE.md:483 */
  sslTypeClient: 'Client',
  /** EXPERIENCE.md:483 */
  sslFieldVerifyPeer: 'Peer certificate verification',
  /** EXPERIENCE.md:483 */
  sslVerifyPeerNone: 'None',
  /** EXPERIENCE.md:483 */
  sslVerifyPeerRequest: 'Request',
  /** EXPERIENCE.md:483 */
  sslVerifyPeerRequire: 'Require',
  /** EXPERIENCE.md:483 */
  sslFieldVerifyDepth: 'Verification depth',
  /** EXPERIENCE.md:483 */
  sslCaFileOsStore: 'The operating system\'s certificate store',
  /** EXPERIENCE.md:483 */
  sslFieldCaPath: 'Trusted CA directory',
  /** EXPERIENCE.md:483 */
  sslFieldAuthorizeCn: 'Pre-authorize the mirror backup member',
  /** EXPERIENCE.md:483 */
  sslFieldCertificateFile: 'Certificate file',
  /** EXPERIENCE.md:483 */
  sslFieldPrivateKeyFile: 'Private key file',
  /** EXPERIENCE.md:483 */
  sslFieldPrivateKeyType: 'Private key type',
  /** EXPERIENCE.md:483 */
  sslKeyTypeRsa: 'RSA',
  /** EXPERIENCE.md:483 */
  sslKeyTypeEcdsa: 'ECDSA',
  /** EXPERIENCE.md:483 */
  sslKeyTypeDsa: 'DSA',
  /** EXPERIENCE.md:483 */
  sslFieldTlsMin: 'Minimum TLS version',
  /** EXPERIENCE.md:483 */
  sslFieldTlsMax: 'Maximum TLS version',
  /** EXPERIENCE.md:483 */
  sslTls10: 'TLS 1.0',
  /** EXPERIENCE.md:483 */
  sslTls11: 'TLS 1.1',
  /** EXPERIENCE.md:483 */
  sslTls12: 'TLS 1.2',
  /** EXPERIENCE.md:483 */
  sslTls13: 'TLS 1.3',
  /** EXPERIENCE.md:483 */
  sslFieldCipherList: 'TLS 1.2 cipher list',
  /** EXPERIENCE.md:483 */
  sslFieldCiphersuites: 'TLS 1.3 cipher suites',
  /** EXPERIENCE.md:483 */
  sslFieldDiffieHellmanBits: 'Diffie-Hellman bits',
  /** EXPERIENCE.md:483 */
  sslFieldOcsp: 'OCSP stapling',
  /** EXPERIENCE.md:483 */
  sslFieldOcspIssuerCert: 'OCSP issuer certificate file',
  /** EXPERIENCE.md:483 */
  sslFieldOcspResponseFile: 'OCSP response file',
  /** EXPERIENCE.md:483 */
  sslFieldOcspTimeout: 'OCSP update timeout (seconds)',
  /** EXPERIENCE.md:483 */
  sslFieldOcspUrl: 'OCSP responder URL',
  /** EXPERIENCE.md:484 */
  sslOwnRole:
    'OcuPilot\'s agent makes every call to its model provider through this configuration. OcuPilot\'s installer sets its type, peer verification, trusted certificates and whether it is enabled, and restores them at every start.',
  /** EXPERIENCE.md:485 */
  sslRefusalOcuPilot:
    'OcuPilot\'s installer sets this setting of its own provider configuration and restores it at every start, so it cannot be changed here.',
  /** EXPERIENCE.md:486 */
  sslFileClassicOnly:
    'File locations are set on the classic portal\'s SSL/TLS Configuration page.',
  /** EXPERIENCE.md:486 */
  sslCrlDeprecated:
    'Certificate revocation lists are deprecated on this instance and are not set on a configuration.',
  /** EXPERIENCE.md:487 */
  sslEffectNoPeerCheck:
    'The server\'s certificate will no longer be checked, so a connection can reach an impostor.',
  /** EXPERIENCE.md:488 */
  sslTestHost: 'Host',
  /** EXPERIENCE.md:488 */
  sslTestPort: 'Port',
  /** EXPERIENCE.md:488 */
  sslTestPassed: 'The instance connected.',
  /** EXPERIENCE.md:488 */
  sslTestFailed: 'The instance could not connect.',
  /** EXPERIENCE.md:489 */
  sslListEmptyAgent: 'create an SSL/TLS configuration for outbound HTTPS',
  /** EXPERIENCE.md:490 */
  x509DeleteConsequence:
    'Anything that names this credential can no longer use it. This cannot be undone.',
  /** EXPERIENCE.md:490 */
  walletSecretDeleteConsequence:
    'Anything that reads this secret by name can no longer find it. This cannot be undone.',
  /** EXPERIENCE.md:490 */
  sslDeleteConsequence:
    'Anything that connects through this configuration can no longer use it. This cannot be undone.',
  /** EXPERIENCE.md:491 */
  faultAbsentEntityNoList: '<name> is no longer present on this instance.',
  /** EXPERIENCE.md:492 */
  sslPromptGroupConnections: 'Connections',
  /** EXPERIENCE.md:492 */
  sslPromptVerifies: 'Does this configuration check the certificate of the server it connects to?',
  /** EXPERIENCE.md:492 */
  sslPromptProtocols: 'Which TLS versions and ciphers does this configuration allow?',
  /** EXPERIENCE.md:492 */
  sslPromptOutbound: 'Is this configuration ready for outbound HTTPS?',

  /** EXPERIENCE.md:642 */
  taskCreate: 'Create task',
  /** EXPERIENCE.md:493 */
  taskFormLabel: 'New task',
  /** EXPERIENCE.md:493 */
  taskStepBasics: 'Basics',
  /** EXPERIENCE.md:493 */
  taskStepType: 'Task type and settings',
  /** EXPERIENCE.md:493 */
  taskStepOptions: 'Options and notifications',
  /** EXPERIENCE.md:493 */
  actionNext: 'Next',
  /** EXPERIENCE.md:493 */
  taskFieldTaskClass: 'Task type',
  /** EXPERIENCE.md:493 */
  taskChooseType: 'Choose a task type',
  /** EXPERIENCE.md:493 */
  taskNoSettings: 'This task type has no settings.',
  /** EXPERIENCE.md:494 */
  taskPeriodDaily: 'Daily',
  /** EXPERIENCE.md:494 */
  taskPeriodWeekly: 'Weekly',
  /** EXPERIENCE.md:494 */
  taskPeriodMonthly: 'Monthly',
  /** EXPERIENCE.md:494 */
  taskPeriodMonthlySpecial: 'Monthly, on a weekday',
  /** EXPERIENCE.md:494 */
  taskEveryDays: 'Days between runs',
  /** EXPERIENCE.md:494 */
  taskEveryWeeks: 'Weeks between runs',
  /** EXPERIENCE.md:494 */
  taskEveryMonths: 'Months between runs',
  /** EXPERIENCE.md:494 */
  taskRunDays: 'Days to run on',
  /** EXPERIENCE.md:494 */
  taskDayOfMonth: 'Day of the month',
  /** EXPERIENCE.md:494 */
  taskDayOfMonthCaption: '31 runs on the last day of the month.',
  /** EXPERIENCE.md:494 */
  taskWeekOfMonth: 'Week of the month',
  /** EXPERIENCE.md:494 */
  taskDayOfWeek: 'Day of the week',
  /** EXPERIENCE.md:494 */
  ordinalLast: 'last',
  /** EXPERIENCE.md:494 */
  taskRunAfterField: 'Task to run after',
  /** EXPERIENCE.md:494 */
  taskRunsPerDay: 'Runs per day',
  /** EXPERIENCE.md:494 */
  taskFrequencyOnce: 'Once',
  /** EXPERIENCE.md:494 */
  taskFrequencySeveral: 'Several times',
  /** EXPERIENCE.md:494 */
  taskIntervalUnit: 'Interval unit',
  /** EXPERIENCE.md:494 */
  taskUnitMinutes: 'Minutes',
  /** EXPERIENCE.md:494 */
  taskUnitHours: 'Hours',
  /** EXPERIENCE.md:494 */
  taskUnitDays: 'Days',
  /** EXPERIENCE.md:494 */
  taskInterval: 'Interval',
  /** EXPERIENCE.md:494 */
  taskStartTime: 'Start time',
  /** EXPERIENCE.md:494 */
  taskEndTime: 'End time',
  /** EXPERIENCE.md:494 */
  taskStartDate: 'Start date',
  /** EXPERIENCE.md:494 */
  taskEndDate: 'End date',
  /** EXPERIENCE.md:494 */
  taskExpires: 'A run expires if it has not started in time',
  /** EXPERIENCE.md:495 */
  taskRunAsCaption: 'Leave empty to run as you.',
  /** EXPERIENCE.md:495 */
  taskPriorityNormal: 'Normal',
  /** EXPERIENCE.md:495 */
  taskPriorityLow: 'Low',
  /** EXPERIENCE.md:495 */
  taskPriorityHigh: 'High',
  /** EXPERIENCE.md:495 */
  taskIsBatch: 'Run in batch mode',
  /** EXPERIENCE.md:495 */
  taskMirrorStatus: 'Mirror members that run it',
  /** EXPERIENCE.md:495 */
  taskMirrorPrimary: 'Primary',
  /** EXPERIENCE.md:495 */
  taskMirrorNonPrimary: 'Non-primary',
  /** EXPERIENCE.md:495 */
  taskOpenOutputFile: 'Write the output to a file',
  /** EXPERIENCE.md:495 */
  taskOutputFilename: 'Output file name',
  /** EXPERIENCE.md:495 */
  taskOutputFileCaption: 'One file name ending in .txt, written to the instance\'s manager directory.',
  /** EXPERIENCE.md:495 */
  taskOutputFileIsBinary: 'Email the output file as binary',
  /** EXPERIENCE.md:495 */
  taskEmailOutput: 'Email the output file on completion',
  /** EXPERIENCE.md:495 */
  taskSuspendOnError: 'Suspend the task if a run fails',
  /** EXPERIENCE.md:495 */
  taskSuspendTerminated: 'Suspend the task if a shutdown ends a run',
  /** EXPERIENCE.md:495 */
  taskRescheduleOnStart: 'Reschedule a pending run after a restart',
  /** EXPERIENCE.md:495 */
  taskEmailOnCompletion: 'Email on completion',
  /** EXPERIENCE.md:495 */
  taskEmailOnError: 'Email on error',
  /** EXPERIENCE.md:495 */
  taskEmailOnExpiration: 'Email on expiry',
  /** EXPERIENCE.md:495 */
  taskEmailCaption: 'Addresses separated by commas.',
  /** EXPERIENCE.md:496 */
  taskStepError: 'This step needs attention: <reason>',
  /** EXPERIENCE.md:497 */
  taskRunAsOtherEffect: 'The task will run as this account, with its privileges, not yours.',
  /** EXPERIENCE.md:498 */
  taskSettingClassicOnly:
    'Only the classic portal\'s Task Scheduler Wizard sets these settings of this type: <settings>.',
  /** EXPERIENCE.md:499 */
  taskPromptGroupSchedule: 'Scheduling',
  /** EXPERIENCE.md:499 */
  taskPromptNightly: 'Create a task that purges task history every night.',
  /** EXPERIENCE.md:499 */
  taskPromptWeekly: 'How do I run a task on weekdays only?',
  /** EXPERIENCE.md:499 */
  taskPromptWhichType: 'Which task type checks database integrity?',
  /** EXPERIENCE.md:501 */
  taskEditFixed: 'A task\'s type and namespace are fixed once it is created. To change them, create a new task.',
  /** EXPERIENCE.md:502 */
  taskOutputFileClassicOnly:
    'This task writes its output to a folder only the classic portal\'s Task Scheduler Wizard sets, so change its output file there.',

  /** EXPERIENCE.md:503 */
  serviceFormLabel: 'Service',
  /** EXPERIENCE.md:503 */
  serviceFieldEnabled: 'Service enabled',
  /** EXPERIENCE.md:503 */
  serviceFieldClientSystems: 'Allowed incoming connections',
  /** EXPERIENCE.md:503 */
  serviceAddressField: 'Address to allow',
  /** EXPERIENCE.md:503 */
  serviceAddressAdd: 'Add address',
  /** EXPERIENCE.md:503 */
  serviceAddressAnyCaption: 'With no address listed, any address may connect.',
  /** EXPERIENCE.md:503 */
  serviceAddressNoRoles: 'Enter one address, with no roles.',
  /** EXPERIENCE.md:504 */
  ldapFormLabel: 'LDAP configuration',
  /** EXPERIENCE.md:504 */
  ldapFieldEnabled: 'LDAP enabled',
  /** EXPERIENCE.md:504 */
  ldapFieldHostNames: 'Host names',
  /** EXPERIENCE.md:504 */
  ldapHostField: 'Host name to add',
  /** EXPERIENCE.md:504 */
  ldapHostAdd: 'Add host name',
  /** EXPERIENCE.md:504 */
  ldapHostCaption: 'One host name per entry, optionally followed by :port.',
  /** EXPERIENCE.md:504 */
  ldapFieldSearchUsername: 'Search username',
  /** EXPERIENCE.md:504 */
  ldapFieldBaseDn: 'Base DN',
  /** EXPERIENCE.md:504 */
  ldapFieldUniqueAttribute: 'Unique search attribute',
  /** EXPERIENCE.md:505 */
  serviceFormBare: 'Open a service from the Services list to change it.',
  /** EXPERIENCE.md:505 */
  serviceGone: 'This service no longer exists.',
  /** EXPERIENCE.md:505 */
  ldapGone: 'This LDAP configuration no longer exists.',
  /** EXPERIENCE.md:506 */
  serviceRefusalServing: 'OcuPilot is served through this service. Turning it off would cut off every user, including you.',
  /** EXPERIENCE.md:507 */
  serviceEffectServesOcuPilot: 'OcuPilot itself is served through this service, so a change here can cut off every user, including you.',
  /** EXPERIENCE.md:507 */
  serviceEffectUnauthenticated: 'Anyone who reaches this service can use it without signing in.',
  /** EXPERIENCE.md:508 */
  servicePromptWhoConnects: 'Which addresses may connect to this service?',
  /** EXPERIENCE.md:508 */
  servicePromptEnabled: 'Which services are enabled on this instance?',
  /** EXPERIENCE.md:508 */
  servicePromptUnauthenticated: 'Does any service allow unauthenticated access?',
  /** EXPERIENCE.md:508 */
  ldapPromptEnabled: 'Is this LDAP configuration enabled?',
  /** EXPERIENCE.md:508 */
  ldapPromptServers: 'Which LDAP servers does this configuration use?',
  /** EXPERIENCE.md:508 */
  ldapPromptUsers: 'How does this configuration find a user?',
  // Story 9.10: the user audit event editor, its refusals and the User events list's prompts.
  /** EXPERIENCE.md:509 */
  auditUserEventEditorCreate: 'New user event',
  /** EXPERIENCE.md:509 */
  auditUserEventEditorEdit: 'Edit user event <name>',
  /** EXPERIENCE.md:509 */
  auditEventFieldSource: 'Source',
  /** EXPERIENCE.md:510 */
  auditEventRefusalPartRequired: 'Enter a value. An audit event is named by its source, type and name.',
  /** EXPERIENCE.md:510 */
  auditEventRefusalPartLength: 'Use 64 characters or fewer.',
  /** EXPERIENCE.md:510 */
  auditEventRefusalPartSlash:
    'Remove the slash. An event\'s source, type and name are joined with slashes, so none of them can contain one.',
  /** EXPERIENCE.md:510 */
  auditEventRefusalPartReserved:
    'Start with a character other than %. A source or type beginning with % is reserved for the instance\'s own system events.',
  /** EXPERIENCE.md:510 */
  auditEventRefusalDescriptionLength: 'Use 256 characters or fewer.',
  /** EXPERIENCE.md:510 */
  auditEventRefusalEventNameShape: 'Name the event as source/type/name: three parts, none containing a slash.',
  /** EXPERIENCE.md:511 */
  auditEventRefusalSystem: 'This is one of the instance\'s own system events. Change it on the System events list.',
  /** EXPERIENCE.md:511 */
  auditEventRefusalUser: 'This is a user event. Change it on the User events list.',
  /** EXPERIENCE.md:511 */
  auditEventRefusalTaken: 'This instance already has an audit event with this source, type and name.',
  /** EXPERIENCE.md:511 */
  auditEventRefusalAbsent: 'This audit event no longer exists.',
  /** EXPERIENCE.md:512 */
  auditUserEventPromptGroup: 'Auditing',
  /** EXPERIENCE.md:512 */
  auditUserEventPromptEnabled: 'Which user events are enabled?',
  /** EXPERIENCE.md:512 */
  auditUserEventPromptBusiest: 'Which user events have recorded the most?',
  /** EXPERIENCE.md:512 */
  auditUserEventPromptRegister: 'Register an audit event for my application.',
  /** EXPERIENCE.md:513 */
  tableColumnResizeShortcut: 'Resize the active column',
  /** EXPERIENCE.md:513 */
  tableColumnResizeKeys: 'Alt/Option+Shift+Left or Right',
  /** EXPERIENCE.md:513 */
  tableColumnWidthAnnouncement: '<column> column, <n> px wide',
  // Story 11.3: the prompt task groups, every built screen's suggested prompts, and the
  // application-errors line a refused or failed read answers.
  /** EXPERIENCE.md:523 */
  promptGroupTroubleshooting: 'Troubleshooting',
  /** EXPERIENCE.md:523 */
  promptGroupCapacity: 'Capacity',
  /** EXPERIENCE.md:523 */
  promptGroupAgentSetup: 'Agent setup',
  /** EXPERIENCE.md:523 */
  promptGroupGettingStarted: 'Getting started',
  /** EXPERIENCE.md:524 */
  agentDefinitionListPrompt1: 'Which agent definition is the default, and which model does it use?',
  /** EXPERIENCE.md:524 */
  agentDefinitionListPrompt2: 'Is any agent definition disabled or not yet verified?',
  /** EXPERIENCE.md:524 */
  agentDefinitionListPrompt3: 'Where does each definition send screen context?',
  /** EXPERIENCE.md:525 */
  agentDefinitionFormPrompt1: 'What does each setting on this definition control?',
  /** EXPERIENCE.md:525 */
  agentDefinitionFormPrompt2: 'Does this definition send data off this instance?',
  /** EXPERIENCE.md:525 */
  agentDefinitionFormPrompt3: 'Which model suits this provider for everyday questions?',
  /** EXPERIENCE.md:526 */
  agentSwitchesPrompt1: 'Is the agent read-only or switched off right now?',
  /** EXPERIENCE.md:526 */
  agentSwitchesPrompt2: 'What does the kill switch stop?',
  /** EXPERIENCE.md:526 */
  agentSwitchesPrompt3: 'How many rows of screen context does the agent send?',
  /** EXPERIENCE.md:527 */
  logAlertViewerPrompt1: 'Which alerts are the most recent, and what caused them?',
  /** EXPERIENCE.md:527 */
  logAlertViewerPrompt2: 'Are any alerts repeating?',
  /** EXPERIENCE.md:527 */
  logAlertViewerPrompt3: 'Which of these alerts need action?',
  /** EXPERIENCE.md:528 */
  logMessageViewerPrompt1: 'Summarize the warnings and errors in messages.log.',
  /** EXPERIENCE.md:528 */
  logMessageViewerPrompt2: 'Did the instance restart recently, and why?',
  /** EXPERIENCE.md:528 */
  logMessageViewerPrompt3: 'Which messages point to a configuration problem?',
  /** EXPERIENCE.md:529 */
  logErrorListPrompt1: 'Which namespace has the most application errors?',
  /** EXPERIENCE.md:529 */
  logErrorListPrompt2: 'What is the most common application error here, and where does it come from?',
  /** EXPERIENCE.md:529 */
  logErrorListPrompt3: 'Which of these errors can I safely delete?',
  /** EXPERIENCE.md:530 */
  auditListPrompt1: 'Were there any failed sign-ins recently?',
  /** EXPERIENCE.md:530 */
  auditListPrompt2: 'Which changes did the agent make?',
  /** EXPERIENCE.md:530 */
  auditListPrompt3: 'Who changed security settings today?',
  /** EXPERIENCE.md:531 */
  auditingConfigPrompt1: 'Is auditing turned on for this instance?',
  /** EXPERIENCE.md:531 */
  auditingConfigPrompt2: 'What stops being recorded if auditing is turned off?',
  /** EXPERIENCE.md:531 */
  auditingConfigPrompt3: 'Which audit events are turned off?',
  /** EXPERIENCE.md:532 */
  auditSystemEventListPrompt1: 'Which system events are enabled?',
  /** EXPERIENCE.md:532 */
  auditSystemEventListPrompt2: 'Which system events record failed sign-ins?',
  /** EXPERIENCE.md:532 */
  auditSystemEventListPrompt3: 'Which system events have recorded the most?',
  /** EXPERIENCE.md:533 */
  ldapConfigListPrompt1: 'Which LDAP configurations are enabled?',
  /** EXPERIENCE.md:533 */
  ldapConfigListPrompt2: 'Which LDAP configuration do users sign in through?',
  /** EXPERIENCE.md:533 */
  ldapConfigListPrompt3: 'Does any LDAP configuration connect without TLS?',
  /** EXPERIENCE.md:534 */
  sslConfigListPrompt1: 'Which SSL/TLS configurations are enabled?',
  /** EXPERIENCE.md:534 */
  sslConfigListPrompt2: 'Which configurations do not verify the server certificate?',
  /** EXPERIENCE.md:534 */
  sslConfigListPrompt3: 'Which configuration does OcuPilot use to reach its provider?',
  /** EXPERIENCE.md:535 */
  x509CredentialListPrompt1: 'Which X.509 credentials expire soonest?',
  /** EXPERIENCE.md:535 */
  x509CredentialListPrompt2: 'Has any credential already expired?',
  /** EXPERIENCE.md:535 */
  x509CredentialListPrompt3: 'Which credentials carry a private key?',
  /** EXPERIENCE.md:536 */
  x509FormPrompt1: 'When does this credential expire?',
  /** EXPERIENCE.md:536 */
  x509FormPrompt2: 'Who issued this certificate?',
  /** EXPERIENCE.md:536 */
  x509FormPrompt3: 'Does this credential carry a private key?',
  /** EXPERIENCE.md:537 */
  walletCollectionListPrompt1: 'Which wallet collections hold secrets?',
  /** EXPERIENCE.md:537 */
  walletCollectionListPrompt2: 'Who can use the secrets in each collection?',
  /** EXPERIENCE.md:537 */
  walletCollectionListPrompt3: 'What is the secrets wallet for?',
  /** EXPERIENCE.md:538 */
  walletSecretListPrompt1: 'Which secrets does this collection hold?',
  /** EXPERIENCE.md:538 */
  walletSecretListPrompt2: 'Which hosts may use these secrets?',
  /** EXPERIENCE.md:538 */
  walletSecretListPrompt3: 'Which of these secrets require TLS?',
  /** EXPERIENCE.md:539 */
  walletSecretFormPrompt1: 'What kind of secret is this?',
  /** EXPERIENCE.md:539 */
  walletSecretFormPrompt2: 'Which hosts may use this secret?',
  /** EXPERIENCE.md:539 */
  walletSecretFormPrompt3: 'Does this secret require a TLS connection?',
  /** EXPERIENCE.md:540 */
  oAuthServerDescriptionTabPrompt1: 'Which OAuth 2.0 servers does this instance trust?',
  /** EXPERIENCE.md:540 */
  oAuthServerDescriptionTabPrompt2: 'Which server descriptions have no client configured?',
  /** EXPERIENCE.md:540 */
  oAuthServerDescriptionTabPrompt3: 'What is an OAuth 2.0 server description for?',
  /** EXPERIENCE.md:541 */
  oAuthClientTabPrompt1: 'Which OAuth 2.0 clients are configured, and for which servers?',
  /** EXPERIENCE.md:541 */
  oAuthClientTabPrompt2: 'Which clients are confidential and which are public?',
  /** EXPERIENCE.md:541 */
  oAuthClientTabPrompt3: 'Which scopes does each client ask for by default?',
  /** EXPERIENCE.md:542 */
  oAuthResourceServerTabPrompt1: 'Which resource servers are configured?',
  /** EXPERIENCE.md:542 */
  oAuthResourceServerTabPrompt2: 'Which server does each resource server accept tokens from?',
  /** EXPERIENCE.md:542 */
  oAuthResourceServerTabPrompt3: 'What does an OAuth 2.0 resource server do?',
  /** EXPERIENCE.md:543 */
  oAuthServerTabPrompt1: 'Is this instance acting as an OAuth 2.0 authorization server?',
  /** EXPERIENCE.md:543 */
  oAuthServerTabPrompt2: 'Which grant types does this server allow?',
  /** EXPERIENCE.md:543 */
  oAuthServerTabPrompt3: 'How long do access tokens from this server last?',
  /** EXPERIENCE.md:544 */
  oAuthServerClientTabPrompt1: 'Which clients are registered with this authorization server?',
  /** EXPERIENCE.md:544 */
  oAuthServerClientTabPrompt2: 'Which redirect addresses does each client use?',
  /** EXPERIENCE.md:544 */
  oAuthServerClientTabPrompt3: 'Which clients may use the client credentials grant?',
  /** EXPERIENCE.md:545 */
  userListPrompt1: 'Which accounts are disabled or expired?',
  /** EXPERIENCE.md:545 */
  userListPrompt2: 'Which users hold %All?',
  /** EXPERIENCE.md:545 */
  userListPrompt3: 'Which users hold an administrative role?',
  /** EXPERIENCE.md:546 */
  roleListPrompt1: 'Which roles grant %All?',
  /** EXPERIENCE.md:546 */
  roleListPrompt2: 'Which roles does no user hold?',
  /** EXPERIENCE.md:546 */
  roleListPrompt3: 'Which roles grant write access to a database?',
  /** EXPERIENCE.md:547 */
  resourceListPrompt1: 'Which resources grant access to everyone?',
  /** EXPERIENCE.md:547 */
  resourceListPrompt2: 'Which resources protect databases?',
  /** EXPERIENCE.md:547 */
  resourceListPrompt3: 'Which resource guards the Management Portal?',
  /** EXPERIENCE.md:548 */
  serviceListPrompt1: 'Which services are turned off?',
  /** EXPERIENCE.md:548 */
  serviceListPrompt2: 'Which services accept a sign-in without a password?',
  /** EXPERIENCE.md:548 */
  serviceListPrompt3: 'Which services limit the addresses that may connect?',
  /** EXPERIENCE.md:549 */
  webAppListPrompt1: 'Which web applications can be reached without signing in?',
  /** EXPERIENCE.md:549 */
  webAppListPrompt2: 'Which web applications grant %All to their users?',
  /** EXPERIENCE.md:549 */
  webAppListPrompt3: 'Which class answers each REST web application?',
  /** EXPERIENCE.md:550 */
  restApiListPrompt1: 'Which REST APIs does this namespace publish?',
  /** EXPERIENCE.md:550 */
  restApiListPrompt2: 'Which web application serves each REST API?',
  /** EXPERIENCE.md:550 */
  restApiListPrompt3: 'Which REST APIs have an OpenAPI document?',
  /** EXPERIENCE.md:551 */
  openApiViewerPrompt1: 'Summarize the operations this API offers.',
  /** EXPERIENCE.md:551 */
  openApiViewerPrompt2: 'Which operations change data?',
  /** EXPERIENCE.md:551 */
  openApiViewerPrompt3: 'Which operations need authentication?',
  /** EXPERIENCE.md:552 */
  databaseListPrompt1: 'Which databases are close to their maximum size?',
  /** EXPERIENCE.md:552 */
  databaseListPrompt2: 'Which databases are not journaled?',
  /** EXPERIENCE.md:552 */
  databaseListPrompt3: 'Which databases are mounted read-only?',
  /** EXPERIENCE.md:553 */
  databaseDetailsPrompt1: 'How much free space does this database have?',
  /** EXPERIENCE.md:553 */
  databaseDetailsPrompt2: 'Is this database journaled?',
  /** EXPERIENCE.md:553 */
  databaseDetailsPrompt3: 'Can this database be written, or is it read-only?',
  /** EXPERIENCE.md:554 */
  databaseVolumeListPrompt1: 'How many volumes does this database have?',
  /** EXPERIENCE.md:554 */
  databaseVolumeListPrompt2: 'Which volume is the largest?',
  /** EXPERIENCE.md:554 */
  databaseVolumeListPrompt3: 'Where are the volume files for this database?',
  /** EXPERIENCE.md:555 */
  databaseFreeSpacePrompt1: 'Which database has the least free space?',
  /** EXPERIENCE.md:555 */
  databaseFreeSpacePrompt2: 'How much disk space is free for each database?',
  /** EXPERIENCE.md:555 */
  databaseFreeSpacePrompt3: 'Which databases could be compacted?',
  /** EXPERIENCE.md:556 */
  deviceListPrompt1: 'What is each device on this list used for?',
  /** EXPERIENCE.md:556 */
  deviceListPrompt2: 'Which devices are printers?',
  /** EXPERIENCE.md:556 */
  deviceListPrompt3: 'Which devices write to a file?',
  /** EXPERIENCE.md:557 */
  deviceFormPrompt1: 'What does this device type mean?',
  /** EXPERIENCE.md:557 */
  deviceFormPrompt2: 'Which settings on this device matter most?',
  /** EXPERIENCE.md:557 */
  deviceFormPrompt3: 'Which open mode should this device use?',
  /** EXPERIENCE.md:558 */
  lockListPrompt1: 'Which processes hold the most locks?',
  /** EXPERIENCE.md:558 */
  lockListPrompt2: 'Is any process waiting for a lock?',
  /** EXPERIENCE.md:558 */
  lockListPrompt3: 'Which globals are locked right now?',
  /** EXPERIENCE.md:559 */
  processListPrompt1: 'Which processes are doing the most work right now?',
  /** EXPERIENCE.md:559 */
  processListPrompt2: 'Is any process stuck or waiting?',
  /** EXPERIENCE.md:559 */
  processListPrompt3: 'Which processes belong to users rather than the system?',
  /** EXPERIENCE.md:560 */
  processDetailsPrompt1: 'What is this process doing right now?',
  /** EXPERIENCE.md:560 */
  processDetailsPrompt2: 'Is this process waiting on something?',
  /** EXPERIENCE.md:560 */
  processDetailsPrompt3: 'Is it safe to terminate this process?',
  /** EXPERIENCE.md:561 */
  systemUsagePrompt1: 'Is this instance under load right now?',
  /** EXPERIENCE.md:561 */
  systemUsagePrompt2: 'Which figure here should I watch most closely?',
  /** EXPERIENCE.md:561 */
  systemUsagePrompt3: 'Is the license close to its limit?',
  /** EXPERIENCE.md:562 */
  taskScheduleListPrompt1: 'Which tasks are suspended, and why?',
  /** EXPERIENCE.md:562 */
  taskScheduleListPrompt2: 'Which tasks run tonight?',
  /** EXPERIENCE.md:562 */
  taskScheduleListPrompt3: 'Which tasks failed on their last run?',
  /** EXPERIENCE.md:563 */
  taskDetailsPrompt1: 'When does this task run next?',
  /** EXPERIENCE.md:563 */
  taskDetailsPrompt2: 'Why did this task last fail?',
  /** EXPERIENCE.md:563 */
  taskDetailsPrompt3: 'What does this task do?',
  /** EXPERIENCE.md:564 */
  taskRunListPrompt1: 'Has this task failed recently?',
  /** EXPERIENCE.md:564 */
  taskRunListPrompt2: 'How long does this task usually take?',
  /** EXPERIENCE.md:564 */
  taskRunListPrompt3: 'When did this task last succeed?',
  /** EXPERIENCE.md:565 */
  taskOnDemandListPrompt1: 'What does each on-demand task do?',
  /** EXPERIENCE.md:565 */
  taskOnDemandListPrompt2: 'Which on-demand tasks have never run?',
  /** EXPERIENCE.md:565 */
  taskOnDemandListPrompt3: 'Which on-demand task ran most recently?',
  /** EXPERIENCE.md:566 */
  taskUpcomingListPrompt1: 'What runs in the next hour?',
  /** EXPERIENCE.md:566 */
  taskUpcomingListPrompt2: 'Which tasks run overnight?',
  /** EXPERIENCE.md:566 */
  taskUpcomingListPrompt3: 'Do any upcoming tasks run at the same time?',
  /** EXPERIENCE.md:567 */
  taskHistoryListPrompt1: 'Which task runs failed this week?',
  /** EXPERIENCE.md:567 */
  taskHistoryListPrompt2: 'Which task takes the longest to run?',
  /** EXPERIENCE.md:567 */
  taskHistoryListPrompt3: 'Did any task stop with an error today?',
  /** EXPERIENCE.md:568 */
  oAuthServerDescriptionFormPrompt1: 'What does each setting on this server description control?',
  /** EXPERIENCE.md:568 */
  oAuthServerDescriptionFormPrompt2: 'Which issuer endpoint does this server description point to?',
  /** EXPERIENCE.md:568 */
  oAuthServerDescriptionFormPrompt3: 'Which client configurations use this server description?',
  /** EXPERIENCE.md:569 */
  oAuthClientFormPrompt1: 'What does each setting on this client configuration control?',
  /** EXPERIENCE.md:569 */
  oAuthClientFormPrompt2: 'Should this client be confidential or public?',
  /** EXPERIENCE.md:569 */
  oAuthClientFormPrompt3: 'Which scopes does this client ask for?',
  /** EXPERIENCE.md:570 */
  oAuthResourceServerFormPrompt1: 'What does each setting on this resource server control?',
  /** EXPERIENCE.md:570 */
  oAuthResourceServerFormPrompt2: 'Which audiences does this resource server accept?',
  /** EXPERIENCE.md:570 */
  oAuthResourceServerFormPrompt3: 'How does this resource server check the tokens it receives?',
  /** EXPERIENCE.md:571 */
  oAuthServerFormPrompt1: 'What does each setting on this authorization server control?',
  /** EXPERIENCE.md:571 */
  oAuthServerFormPrompt2: 'Which scopes does this authorization server support?',
  /** EXPERIENCE.md:571 */
  oAuthServerFormPrompt3: 'What happens if I rotate this server\'s keys?',
  /** EXPERIENCE.md:572 */
  oAuthServerClientFormPrompt1: 'What does each setting on this server client description control?',
  /** EXPERIENCE.md:572 */
  oAuthServerClientFormPrompt2: 'Which redirect URLs does this client use?',
  /** EXPERIENCE.md:572 */
  oAuthServerClientFormPrompt3: 'What must change if this client\'s secret is regenerated?',
  /** EXPERIENCE.md:356 */
  homeSuggestedApplicationErrorsUnread: 'Application errors in <NAMESPACE>: could not be read',

  // Story 12.1: the X.509 credential form's certificate-details group and its serial number.
  /** EXPERIENCE.md:514 */
  x509CertificateDetails: 'Certificate details',
  /** EXPERIENCE.md:514 */
  x509FieldSerialNumber: 'Serial number',

  // Story 12.2: the Users list's token revoke row action and its typed-name dialog's consequence.
  /** EXPERIENCE.md:515 */
  userActionRevokeTokens: 'Revoke OAuth 2.0 tokens',
  /** EXPERIENCE.md:515 */
  userRevokeTokensConsequence:
    'Revoking deletes every OAuth 2.0 access token this instance issued under this user name, and applications holding one must sign the user in again. This cannot be undone.',

  // Story 12.3: the Auditing screen's audit database group, its copy and purge dialogs, and the
  // status line while either runs on the instance.
  /** EXPERIENCE.md:516 */
  auditDatabaseCopyAction: 'Copy to namespace',
  /** EXPERIENCE.md:516 */
  auditDatabasePurgeAction: 'Purge old records',
  /** EXPERIENCE.md:516 */
  auditDatabaseCopyTitle: 'Copy audit records',
  /** EXPERIENCE.md:516 */
  auditDatabaseCopyConsequence:
    'Copies every record in the audit database into this namespace. Anyone who can read that namespace\'s database can read the copy. The originals stay where they are.',
  /** EXPERIENCE.md:516 */
  auditDatabaseCopyConfirm: 'Copy',
  /** EXPERIENCE.md:516 */
  auditDatabasePurgeTitle: 'Purge audit records',
  /** EXPERIENCE.md:516 */
  auditDatabasePurgeDays: 'Older than (days)',
  /** EXPERIENCE.md:516 */
  auditDatabasePurgeConsequence:
    'Removes every audit record on this instance dated before <date> 00:00, instance time, including the agent\'s audit markers from that period. This cannot be undone.',
  /** EXPERIENCE.md:516 */
  auditDatabasePurgeConfirm: 'Purge',
  /** EXPERIENCE.md:516 */
  auditDatabaseCopyRunning: 'Copying to <namespace> on the instance since <time>',
  /** EXPERIENCE.md:516 */
  auditDatabasePurgeRunning: 'Purging records dated before <date> on the instance since <time>',
  /** EXPERIENCE.md:516 */
  auditDatabaseCopyDone: 'Copied the audit database to <namespace>.',
  /** EXPERIENCE.md:516 */
  auditDatabasePurgeDone: 'Purged audit records dated before <date>.',
  /** EXPERIENCE.md:516 */
  auditDatabaseStillRunning: 'Still running on the instance. It finishes in the background.',

  // Story 12.4: the OAuth 2.0 client server description editor, its tab's Create, Delete and
  // Update JWKS, and the phrase that resolves the tab's agent invitation.
  /** EXPERIENCE.md:517 */
  oauthServerFormLabel: 'Server description',
  /** EXPERIENCE.md:517 */
  oauthServerFieldIssuer: 'Issuer endpoint',
  /** EXPERIENCE.md:517 */
  oauthServerFieldToken: 'Registration access token',
  /** EXPERIENCE.md:517 */
  oauthServerTokenHint: 'Leave empty to keep the stored token.',
  /** EXPERIENCE.md:517 */
  oauthServerFieldAuthorization: 'Authorization endpoint',
  /** EXPERIENCE.md:517 */
  oauthServerFieldTokenEndpoint: 'Token endpoint',
  /** EXPERIENCE.md:517 */
  oauthServerFieldUserinfo: 'Userinfo endpoint',
  /** EXPERIENCE.md:517 */
  oauthServerFieldIntrospection: 'Token introspection endpoint',
  /** EXPERIENCE.md:517 */
  oauthServerFieldRevocation: 'Token revocation endpoint',
  /** EXPERIENCE.md:517 */
  oauthServerFieldEndSession: 'End session endpoint',
  /** EXPERIENCE.md:517 */
  oauthServerGroupJwt: 'JSON Web Token (JWT) settings',
  /** EXPERIENCE.md:517 */
  oauthServerJwtUrl: 'JWKS from URL',
  /** EXPERIENCE.md:517 */
  oauthServerJwtX509: 'X.509 certificate',
  /** EXPERIENCE.md:517 */
  oauthServerGroupMetadata: 'Metadata',
  /** EXPERIENCE.md:517 */
  oauthServerDiscover: 'Discover',
  /** EXPERIENCE.md:517 */
  oauthServerUpdateJwks: 'Update JWKS',
  /** EXPERIENCE.md:517 */
  oauthServerDiscovered: 'Fetched the metadata published at <issuer>. Review it, then Save.',
  /** EXPERIENCE.md:517 */
  oauthServerJwksUpdated: 'Updated the key set from <url>.',
  /** EXPERIENCE.md:517 */
  oauthServerTokenRefused: 'Saved. The registration access token was not stored: <reason>',
  /** EXPERIENCE.md:517 */
  oauthServerDeleteConsequence:
    'Deletes this server description and its metadata. A resource server that uses it is left without one. A client configuration that uses it blocks the delete.',
  /** EXPERIENCE.md:517 */
  oauthServerDescriptionsEmptyAgent: 'add a server description',
  /** EXPERIENCE.md:517 */
  oauthServerFormRefusedAction: 'change this server description',

  // Story 12.5: the OAuth 2.0 client configuration editor, its tab's Create, Register and Rotate
  // Keys, and the phrase a privilege refusal names.
  /** EXPERIENCE.md:518 */
  oauthClientFormLabel: 'Client configuration',
  /** EXPERIENCE.md:518 */
  oauthClientSectionClientInformation: 'Client Information',
  /** EXPERIENCE.md:518 */
  oauthClientSectionJwt: 'JWT Settings',
  /** EXPERIENCE.md:518 */
  oauthClientSectionCredentials: 'Client Credentials',
  /** EXPERIENCE.md:518 */
  oauthClientFieldName: 'Application name',
  /** EXPERIENCE.md:518 */
  oauthClientTypeConfidential: 'Confidential',
  /** EXPERIENCE.md:518 */
  oauthClientTypePublic: 'Public',
  /** EXPERIENCE.md:518 */
  oauthClientTypeResource: 'Resource server',
  /** EXPERIENCE.md:518 */
  oauthClientFieldRedirect: 'Redirect URL',
  /** EXPERIENCE.md:518 */
  oauthClientFieldLogoutUri: 'Front-channel logout URL',
  /** EXPERIENCE.md:518 */
  oauthClientFieldLogoutSession: 'Front-channel session required',
  /** EXPERIENCE.md:518 */
  oauthClientGrantAuthorizationCode: 'Authorization code',
  /** EXPERIENCE.md:518 */
  oauthClientGrantImplicit: 'Implicit',
  /** EXPERIENCE.md:518 */
  oauthClientGrantPassword: 'Resource owner password credentials',
  /** EXPERIENCE.md:518 */
  oauthClientGrantClientCredentials: 'Client credentials',
  /** EXPERIENCE.md:518 */
  oauthClientGrantJwt: 'JWT authorization',
  /** EXPERIENCE.md:518 */
  oauthClientFieldAuthMethod: 'Authentication method',
  /** EXPERIENCE.md:518 */
  oauthClientFieldAuthSigning: 'Authentication signing algorithm',
  /** EXPERIENCE.md:518 */
  oauthClientFieldAudience: 'Audience',
  /** EXPERIENCE.md:518 */
  oauthClientFieldLogo: 'Logo URL',
  /** EXPERIENCE.md:518 */
  oauthClientFieldHome: 'Client home page URL',
  /** EXPERIENCE.md:518 */
  oauthClientFieldPolicy: 'Policy URL',
  /** EXPERIENCE.md:518 */
  oauthClientFieldTos: 'Terms of service URL',
  /** EXPERIENCE.md:518 */
  oauthClientFieldContacts: 'Contacts (comma-separated)',
  /** EXPERIENCE.md:518 */
  oauthClientFieldMaxAge: 'Default max age (seconds)',
  /** EXPERIENCE.md:518 */
  oauthClientFieldInterval: 'JWT interval (seconds)',
  /** EXPERIENCE.md:518 */
  oauthClientFieldCredentials: 'X.509 credentials',
  /** EXPERIENCE.md:518 */
  oauthClientAlgIdToken: 'ID token algorithms',
  /** EXPERIENCE.md:518 */
  oauthClientAlgUserinfo: 'Userinfo algorithms',
  /** EXPERIENCE.md:518 */
  oauthClientAlgAccessToken: 'Access token algorithms',
  /** EXPERIENCE.md:518 */
  oauthClientAlgRequest: 'Request object algorithms',
  /** EXPERIENCE.md:518 */
  oauthClientAlgSigning: 'Signing',
  /** EXPERIENCE.md:518 */
  oauthClientAlgEncryption: 'Encryption',
  /** EXPERIENCE.md:518 */
  oauthClientAlgKey: 'Key',
  /** EXPERIENCE.md:518 */
  oauthClientFieldSecret: 'Client secret',
  /** EXPERIENCE.md:518 */
  oauthClientFieldInitialToken: 'Initial access token',
  /** EXPERIENCE.md:518 */
  oauthClientSecretHint: 'Leave empty to keep the stored value.',
  /** EXPERIENCE.md:518 */
  oauthClientFieldIssuedAt: 'Client ID issued at',
  /** EXPERIENCE.md:518 */
  oauthClientFieldExpiresAt: 'Client secret expires at',
  /** EXPERIENCE.md:518 */
  oauthClientFieldRegistrationUri: 'Registration client URI',
  /** EXPERIENCE.md:518 */
  oauthClientNotSet: 'Not set',
  /** EXPERIENCE.md:518 */
  oauthClientRegister: 'Register',
  /** EXPERIENCE.md:518 */
  oauthClientRotateKeys: 'Rotate Keys',
  /** EXPERIENCE.md:518 */
  oauthClientRegistered: 'Registered with <issuer>. Client ID: <clientId>.',
  /** EXPERIENCE.md:518 */
  oauthClientKeysRotated: 'Rotated this client\'s keys.',
  /** EXPERIENCE.md:518 */
  oauthClientSecretsRefused: 'Saved. The secrets were not stored: <reason>',
  /** EXPERIENCE.md:518 */
  oauthClientRegistrationNotUpdated: 'Saved. <issuer> was not updated: <reason>',
  /** EXPERIENCE.md:518 */
  oauthClientFormRefusedAction: 'change this client configuration',
  /** EXPERIENCE.md:519 */
  oauthResourceServerTabToken: 'Access token validation',
  /** EXPERIENCE.md:519 */
  oauthResourceServerTabAuthenticator: 'Authenticator',
  /** EXPERIENCE.md:519 */
  oauthResourceServerTabMappings: 'Mappings',
  /** EXPERIENCE.md:519 */
  oauthResourceServerFieldAudiences: 'Audiences',
  /** EXPERIENCE.md:519 */
  oauthResourceServerAddAudience: 'Add audience',
  /** EXPERIENCE.md:519 */
  oauthResourceServerFieldScope: 'Required scope',
  /** EXPERIENCE.md:519 */
  oauthResourceServerFieldJwt: 'JWT',
  /** EXPERIENCE.md:519 */
  oauthResourceServerFieldIntrospection: 'Call introspection',
  /** EXPERIENCE.md:519 */
  oauthResourceServerFieldOidc: 'OpenID Connect',
  /** EXPERIENCE.md:519 */
  oauthResourceServerMethodBasic: 'HTTP Basic',
  /** EXPERIENCE.md:519 */
  oauthResourceServerMethodPost: 'Form post',
  /** EXPERIENCE.md:519 */
  oauthResourceServerMethodNone: 'none',
  /** EXPERIENCE.md:519 */
  oauthResourceServerFieldImplementation: 'Implementation',
  /** EXPERIENCE.md:519 */
  oauthResourceServerGatewayMappings: 'Web Gateway mappings',
  /** EXPERIENCE.md:519 */
  oauthResourceServerBindingsMappings: 'ODBC/JDBC mappings',
  /** EXPERIENCE.md:519 */
  oauthResourceServerFieldApplication: 'Application',
  /** EXPERIENCE.md:519 */
  oauthResourceServerDefaultKey: '* (Default)',
  /** EXPERIENCE.md:519 */
  oauthResourceServerAddMapping: 'Add mapping',
  /** EXPERIENCE.md:519 */
  oauthResourceServerMoves: 'Moves this mapping from <server>.',
  /** EXPERIENCE.md:519 */
  oauthResourceServerMoveEffect: 'Moves this service mapping from the resource server that holds it.',
  /** EXPERIENCE.md:519 */
  oauthResourceServerSecretRefused: 'Saved. The client secret was not stored: <reason>',
  /** EXPERIENCE.md:519 */
  oauthResourceServerMappingsRefused: 'Saved. <count> service mappings were not changed: <reason>',
  /** EXPERIENCE.md:519 */
  oauthResourceServerDeleteConsequence: 'This also deletes the resource server\'s service mappings.',
  /** EXPERIENCE.md:519 */
  oauthResourceServersEmptyAgent: 'create an OAuth 2.0 resource server',
  /** EXPERIENCE.md:519 */
  oauthResourceServerFormRefusedAction: 'change this resource server',
  /** EXPERIENCE.md:519 */
  oauthResourceServerAuthenticatorNote: 'Changing the namespace or implementation replaces these settings with that implementation\'s defaults.',
  /** EXPERIENCE.md:519 */
  oauthResourceServerAuthenticatorResetEffect: 'Changes the authenticator\'s namespace or implementation, so every setting this change does not name takes that implementation\'s default.',
  /** EXPERIENCE.md:520 */
  oauthAuthServerTabIntervals: 'Intervals',
  /** EXPERIENCE.md:520 */
  oauthAuthServerTabCustomization: 'Customization',
  /** EXPERIENCE.md:520 */
  oauthAuthServerIssuerHint: 'The server answers at this endpoint with /oauth2 appended.',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldAudRequired: 'Audience required',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldSupportSession: 'Support user session',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldPublicRefresh: 'Allow public client refresh',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldPkcePublic: 'Enforce PKCE for public clients',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldPkceConfidential: 'Enforce PKCE for confidential clients',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldFrontChannel: 'Support front-channel logout',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldFrontChannelSession: 'Send the session ID with front-channel logout',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldReturnRefresh: 'Return refresh token',
  /** EXPERIENCE.md:520 */
  oauthAuthServerRefreshRequired: 'Only as OpenID Connect requires',
  /** EXPERIENCE.md:520 */
  oauthAuthServerRefreshAlways: 'Always',
  /** EXPERIENCE.md:520 */
  oauthAuthServerRefreshConfidential: 'To a confidential client',
  /** EXPERIENCE.md:520 */
  oauthAuthServerRefreshOffline: 'When offline_access is requested',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldServiceDocs: 'Service documentation URL',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldScope: 'Scope',
  /** EXPERIENCE.md:520 */
  oauthAuthServerAddScope: 'Add scope',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldUnsupportedScope: 'Allow unsupported scope',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldAccessTokenInterval: 'Access token interval (seconds)',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldCodeInterval: 'Authorization code interval (seconds)',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldRefreshInterval: 'Refresh token interval (seconds)',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldSessionInterval: 'Session termination interval (seconds)',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldSecretInterval: 'Client secret expiration interval (seconds)',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldAuthenticateClass: 'Authenticate class',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldValidateUserClass: 'Validate user class',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldSessionClass: 'Session maintenance class',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldGenerateTokenClass: 'Generate token class',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFieldRevokeTokenClass: 'Revoke token class',
  /** EXPERIENCE.md:520 */
  oauthAuthServerRotated: 'Rotated the authorization server\'s keys.',
  /** EXPERIENCE.md:520 */
  oauthAuthServerPasswordRefused: 'Saved. The key password was not stored: <reason>',
  /** EXPERIENCE.md:520 */
  oauthAuthServerDeleteConsequence: 'This also deletes every client registered with this authorization server.',
  /** EXPERIENCE.md:520 */
  oauthAuthServerClientsEffect: 'Every client registered with this authorization server gets its tokens from it, so this change reaches each of them.',
  /** EXPERIENCE.md:520 */
  oauthAuthServerClientsHiddenEffect: 'This change reaches every client registered with this authorization server, and this account cannot list them.',
  /** EXPERIENCE.md:520 */
  oauthAuthServerClientsDeletedEffect: 'Deleting the authorization server configuration also deletes every client registered with it.',
  /** EXPERIENCE.md:520 */
  oauthAuthServerClientsDeletedHiddenEffect: 'Deleting the authorization server configuration also deletes every client registered with it, and this account cannot list them.',
  /** EXPERIENCE.md:520 */
  oauthAuthServerCustomizationEffect: 'The customization code runs with the roles this adds, and they include %All or an administrative role.',
  /** EXPERIENCE.md:520 */
  oauthAuthServerClientsPrivilegedEffect: 'Every client registered with this authorization server gets its tokens from it, so this change reaches each of them. The customization code runs with the roles this adds, and they include %All or an administrative role.',
  /** EXPERIENCE.md:520 */
  oauthAuthServerClientsHiddenPrivilegedEffect: 'This change reaches every client registered with this authorization server, and this account cannot list them. The customization code runs with the roles this adds, and they include %All or an administrative role.',
  /** EXPERIENCE.md:520 */
  oauthAuthServerEmptyAgent: 'configure this instance\'s OAuth 2.0 authorization server',
  /** EXPERIENCE.md:520 */
  oauthAuthServerFormRefusedAction: 'change the authorization server configuration',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientTitle: 'Server client description',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientFieldResponseTypes: 'Response types',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientFieldAuthType: 'Authentication type',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientFieldLaunchUrl: 'Launch URL',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientFieldContacts: 'Contact emails (comma-separated)',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientFieldLogoutSessionRequired: 'Front-channel logout session required',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientFieldKeySource: 'Public key source',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientKeySourceJwks: 'JWKS URL',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientAddRedirect: 'Add redirect URL',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientGenerate: 'Generate',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientShow: 'Show',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientHide: 'Hide',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientJwksUpdated: 'Updated the client\'s public keys from its JWKS URL.',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientSecretEffect: 'The client\'s application must use the new secret from now on.',
  /** EXPERIENCE.md:521 */
  oauthRegisteredClientFormRefusedAction: 'change this server client description',
  /** EXPERIENCE.md:573 */
  citationAbsent: '<name> is no longer present on this instance, so there is nothing to select.',
  // The try-it console (Story 16.1). "Send" is `actionSend` and "Request" is `sslVerifyPeerRequest`:
  // one key per value.
  /** EXPERIENCE.md:574 */
  tryItToggle: 'Try it',
  /** EXPERIENCE.md:574 */
  tryItResponse: 'Response',
  /** EXPERIENCE.md:574 */
  tryItBody: 'Body',
  /** EXPERIENCE.md:574 */
  tryItConfirmTitle: 'Send <VERB> <URL>?',
  /** EXPERIENCE.md:574 */
  tryItOwnApplication: 'This request goes to one of OcuPilot\'s own applications, so the console does not send it.',
  /** EXPERIENCE.md:574 */
  tryItAdminWrite: 'The console does not send changes to the admin API; OcuPilot\'s own screens make them.',
  /** EXPERIENCE.md:574 */
  tryItTraversal: 'A path parameter cannot be a single or double dot.',
  /** EXPERIENCE.md:574 */
  tryItNoAddress: 'This operation has no address on this instance, so it cannot be tried here.',
  /** EXPERIENCE.md:574 */
  tryItFailed: 'No complete answer came back: the connection failed, or something between the browser and the instance stopped it.',
  /** EXPERIENCE.md:574 */
  tryItRedirected: 'The request did not reach the application: something between the browser and the instance, such as a proxy, answered it with a redirect, which the console does not follow.',
  /** EXPERIENCE.md:574 */
  tryItRedirectedWrite: 'The answer was a redirect, which the console does not follow, so the outcome is unknown: the instance may have acted on this request. Check before you send it again.',
  /** EXPERIENCE.md:574 */
  tryItUnsent: 'The browser would not build this request, so nothing was sent to the instance.',
  /** EXPERIENCE.md:574 */
  tryItCut: 'The response was cut at 256 KB.',
  /** EXPERIENCE.md:574 */
  tryItBinary: '<n> bytes, not shown as text.',
  /** EXPERIENCE.md:575 */
  readBackMatches: 'Read back: matches',
  /** EXPERIENCE.md:575 */
  readBackDiffers: 'Read back: differs in <fields>',
  /** EXPERIENCE.md:575 */
  readBackNotFound: 'Read back: not found',
  /** EXPERIENCE.md:575 */
  readBackPresent: 'Read back: still present',
  /** EXPERIENCE.md:575 */
  readBackWritten: 'Read back: <fields> written, not read back',
  /** EXPERIENCE.md:575 */
  readBackWrittenClause: '<fields> written, not read back',
  /** EXPERIENCE.md:575 */
  readBackNothingSent: 'Read back: nothing sent to compare',
  /** EXPERIENCE.md:575 */
  readBackRunning: 'Read back: not checked, the write is still running',
  /** EXPERIENCE.md:575 */
  readBackUnreadable: 'Read back: could not be read',
  /** EXPERIENCE.md:575 */
  readBackMore: ' and <n> more',
  /** EXPERIENCE.md:576 */
  performanceHeading: 'Performance',
  /** EXPERIENCE.md:576 */
  performanceDiskReads: 'Disk reads',
  /** EXPERIENCE.md:576 */
  performanceDiskWrites: 'Disk writes',
  /** EXPERIENCE.md:576 */
  performanceRateUnit: '/s',
  /** EXPERIENCE.md:576 */
  performanceCacheUnit: 'refs per block read or write',
  /** EXPERIENCE.md:576 */
  performanceSparklineLabel: 'Global references per second, last ten minutes',
  /** EXPERIENCE.md:577 */
  impactLine: 'Impact: <parts>.',
  /** EXPERIENCE.md:577 */
  impactHolders: '<n> users hold it: <names>',
  /** EXPERIENCE.md:577 */
  impactHoldersOne: '1 user holds it: <names>',
  /** EXPERIENCE.md:577 */
  impactHoldersNone: 'no user holds it',
  /** EXPERIENCE.md:577 */
  impactGrantingApplications: '<n> web applications grant it: <names>',
  /** EXPERIENCE.md:577 */
  impactGrantingApplicationsOne: '1 web application grants it: <names>',
  /** EXPERIENCE.md:577 */
  impactGrantingApplicationsNone: 'no web application grants it',
  /** EXPERIENCE.md:577 */
  impactGrantingRoles: '<n> roles grant it: <names>',
  /** EXPERIENCE.md:577 */
  impactGrantingRolesOne: '1 role grants it: <names>',
  /** EXPERIENCE.md:577 */
  impactGrantingRolesNone: 'no role grants it',
  /** EXPERIENCE.md:577 */
  impactGuardedApplications: 'it guards <n> web applications: <names>',
  /** EXPERIENCE.md:577 */
  impactGuardedApplicationsOne: 'it guards 1 web application: <names>',
  /** EXPERIENCE.md:577 */
  impactGuardedApplicationsNone: 'it guards no web application',
  /** EXPERIENCE.md:577 */
  impactGuardedDatabases: 'it guards <n> databases: <names>',
  /** EXPERIENCE.md:577 */
  impactGuardedDatabasesOne: 'it guards 1 database: <names>',
  /** EXPERIENCE.md:577 */
  impactGuardedDatabasesNone: 'it guards no database',
  /** EXPERIENCE.md:577 */
  impactLoses: '<user> loses <names>',
  /** EXPERIENCE.md:577 */
  impactLosesNone: '<user> loses nothing their other roles do not still grant',
  /** EXPERIENCE.md:577 */
  impactHoldersUnchecked: 'who holds it was not checked',
  /** EXPERIENCE.md:577 */
  impactGrantingApplicationsUnchecked: 'which web applications grant it was not checked',
  /** EXPERIENCE.md:577 */
  impactGrantingRolesUnchecked: 'which roles grant it was not checked',
  /** EXPERIENCE.md:577 */
  impactGuardedApplicationsUnchecked: 'which web applications it guards was not checked',
  /** EXPERIENCE.md:577 */
  impactGuardedDatabasesUnchecked: 'which databases it guards was not checked',
  /** EXPERIENCE.md:577 */
  impactLosesUnchecked: 'what <user> loses was not checked',
  /** EXPERIENCE.md:577 */
  impactRequires: ' (requires <pair>)',
  /** EXPERIENCE.md:577 */
  impactTooMany: ' (too many to check)',
  /** EXPERIENCE.md:578 */
  logViewerFileOption: '<name> \u00b7 <size> KB \u00b7 <modified>',
  /** EXPERIENCE.md:578 */
  logViewerFileGone: 'That file is no longer in the manager directory.',
  /** EXPERIENCE.md:579 */
  findingsHeading: 'Findings',
  /** EXPERIENCE.md:579 */
  findingsSecurity: 'Security',
  /** EXPERIENCE.md:579 */
  findingsOperations: 'Operations',
  /** EXPERIENCE.md:579 */
  findingsNothing: 'Nothing to report.',
  /** EXPERIENCE.md:579 */
  findingsNotChecked: 'Not checked: <check>',
  /** EXPERIENCE.md:579 */
  findingsCouldNotRead: ' (could not be read)',
  /** EXPERIENCE.md:579 */
  findingsFix: 'Fix it',
  /** EXPERIENCE.md:580 */
  findingsCheckWebappOpen: 'web applications open without signing in',
  /** EXPERIENCE.md:580 */
  findingsCheckMonitorOpen: 'the monitoring API',
  /** EXPERIENCE.md:580 */
  findingsCheckAllHolder: 'accounts holding %All',
  /** EXPERIENCE.md:580 */
  findingsCheckCertificate: 'X.509 certificates',
  /** EXPERIENCE.md:580 */
  findingsCheckAuditingOff: 'auditing',
  /** EXPERIENCE.md:580 */
  findingsCheckDatabaseDismounted: 'database mounts',
  /** EXPERIENCE.md:580 */
  findingsCheckDatabaseFull: 'database sizes',
  /** EXPERIENCE.md:580 */
  findingsCheckTaskManager: 'the Task Manager',
  /** EXPERIENCE.md:580 */
  findingsCheckTaskError: 'suspended tasks',
  /** EXPERIENCE.md:581 */
  findingWebappOpen: '<name> can be reached without signing in and holds a database or administrative role.',
  /** EXPERIENCE.md:581 */
  findingWebappOpenWhy: 'Anyone who can reach this address can use that privilege.',
  /** EXPERIENCE.md:581 */
  findingWebappOpenDo: 'Require a password to sign in, or remove the role.',
  /** EXPERIENCE.md:581 */
  findingMonitorOpen: 'The monitoring API, <name>, answers without signing in.',
  /** EXPERIENCE.md:581 */
  findingMonitorOpenWhy: 'Anyone who can reach the instance can read its metrics.',
  /** EXPERIENCE.md:581 */
  findingMonitorOpenDo: 'Require a password, and give your metrics collector an account.',
  /** EXPERIENCE.md:581 */
  findingAllHolder: '<name> holds %All.',
  /** EXPERIENCE.md:581 */
  findingAllHolderWhy: 'Whoever signs in as this account can do anything on this instance.',
  /** EXPERIENCE.md:581 */
  findingAllHolderDo: 'Take %All off every account that does not need it.',
  /** EXPERIENCE.md:581 */
  findingCertificateExpired: 'The certificate <name> expired on <date>.',
  /** EXPERIENCE.md:581 */
  findingCertificate: 'The certificate <name> expires on <date>.',
  /** EXPERIENCE.md:581 */
  findingCertificateWhy: 'Connections that rely on it fail once it has expired.',
  /** EXPERIENCE.md:581 */
  findingCertificateDo: 'Import a renewed certificate.',
  /** EXPERIENCE.md:581 */
  findingAuditingOffWhy: 'Nothing that happens on this instance is recorded, OcuPilot\'s own changes included.',
  /** EXPERIENCE.md:581 */
  findingAuditingOffDo: 'Turn auditing on.',
  /** EXPERIENCE.md:581 */
  findingDatabaseDismounted: 'The database <name> is dismounted.',
  /** EXPERIENCE.md:581 */
  findingDatabaseDismountedWhy: 'Nothing can read or write it until it is mounted.',
  /** EXPERIENCE.md:581 */
  findingDatabaseDismountedDo: 'Mount it from its details.',
  /** EXPERIENCE.md:581 */
  findingDatabaseFull: 'The database <name> is at <percent>% of its maximum size.',
  /** EXPERIENCE.md:581 */
  findingDatabaseFullWhy: 'Writes to it fail once it is full.',
  /** EXPERIENCE.md:581 */
  findingDatabaseFullDo: 'Raise its maximum size, or free space in it.',
  /** EXPERIENCE.md:581 */
  findingTaskManagerSuspendedDo: 'Resume the Task Manager.',
  /** EXPERIENCE.md:581 */
  findingTaskManagerStoppedDo: 'Start the Task Manager.',
  /** EXPERIENCE.md:581 */
  findingTaskError: 'The task <name> was suspended after an error.',
  /** EXPERIENCE.md:581 */
  findingTaskErrorWhy: 'It does not run again until it is resumed.',
  /** EXPERIENCE.md:581 */
  findingTaskErrorDo: 'Read its error, then resume it.',
  /** EXPERIENCE.md:582 */
  findingFixWebappOpen: 'This web application can be reached without signing in and holds a database or administrative role. Propose requiring a password to sign in to it.',
  /** EXPERIENCE.md:582 */
  findingFixMonitorOpen: 'The monitoring API answers without signing in. Propose requiring a password to sign in to it.',
  /** EXPERIENCE.md:582 */
  findingFixAllHolder: 'This account holds %All. Propose taking %All off it.',
  /** EXPERIENCE.md:582 */
  findingFixAuditingOff: 'Auditing is off on this instance. Propose turning it on.',
  /** EXPERIENCE.md:582 */
  findingFixTaskError: 'This task was suspended after an error. Propose resuming it.',
  // Story 16.22: the Guardrails page.
  /** EXPERIENCE.md:583 */
  agentGuardrailsLabel: 'Guardrails',
  /** EXPERIENCE.md:583 */
  agentGuardrailsIntro: 'What the agent refuses, what waits for your Confirm and what it never sees, read from the rules this instance enforces.',
  /** EXPERIENCE.md:583 */
  agentGuardrailsRefusedHeading: 'Refused outright',
  /** EXPERIENCE.md:583 */
  agentGuardrailsRefusedNote: 'Neither the agent nor a screen can make these changes, whoever asks.',
  /** EXPERIENCE.md:583 */
  agentGuardrailsKillSwitchOff: 'Kill switch: off',
  /** EXPERIENCE.md:583 */
  agentGuardrailsKillSwitchEveryone: 'Kill switch: on for everyone',
  /** EXPERIENCE.md:583 */
  agentGuardrailsKillSwitchYou: 'Kill switch: on for you',
  /** EXPERIENCE.md:583 */
  agentGuardrailsReadOnlyOff: 'Enforced read-only: off',
  /** EXPERIENCE.md:583 */
  agentGuardrailsReadOnlyOn: 'Enforced read-only: on',
  /** EXPERIENCE.md:583 */
  agentGuardrailsSwitchesNote: 'The kill switch stops the agent. Enforced read-only lets it read and explain but not propose a change. Neither stops what you do on a screen yourself.',
  /** EXPERIENCE.md:583 */
  agentGuardrailsConfirmHeading: 'Always needs your Confirm',
  /** EXPERIENCE.md:583 */
  agentGuardrailsConfirmNote: 'These are the agent\'s tools that change the instance. Each one only proposes its change, and nothing happens until you press Confirm.',
  /** EXPERIENCE.md:583 */
  agentGuardrailsNeverHeading: 'Never sent to the agent',
  /** EXPERIENCE.md:583 */
  agentGuardrailsNeverSecrets: 'Fields declared secret, such as passwords, keys and tokens, never leave the instance for the agent: its reads drop them, and you type them yourself at Confirm.',
  /** EXPERIENCE.md:583 */
  agentGuardrailsNeverErrorVariables: 'An application error reaches the agent as its summary only, never the variables captured with it.',
  /** EXPERIENCE.md:583 */
  agentGuardrailsNeverDeclared: 'The fields each tool declares secret, which the agent never sees:',
  /** EXPERIENCE.md:583 */
  agentGuardrailsContextLimits: 'Each turn carries at most <rows> rows of the screen you are on, <total> characters in all and <field> characters a field.',
  /** EXPERIENCE.md:583 */
  agentGuardrailsPrompt1: 'Which of your tools can change this instance?',
  /** EXPERIENCE.md:583 */
  agentGuardrailsPrompt2: 'Are you read-only on this instance right now?',
  /** EXPERIENCE.md:583 */
  agentGuardrailsPrompt3: 'What happens between your proposal and a change on the instance?',

  // Story 16.23: the data table's Download CSV control in the command bar, and its description at the cap.
  /** EXPERIENCE.md:313 */
  tableDownloadCsv: 'Download CSV',
  /** EXPERIENCE.md:313 */
  tableDownloadCsvCapped: 'The file holds the first <n> rows only.',

  // Story 16.8: the six secondary log viewers' side-bar entries and titles, and the log viewer's two
  // match controls (DW-1102).
  /** EXPERIENCE.md:584 */
  systemMonitorLogListLabel: 'System Monitor log',
  /** EXPERIENCE.md:584 */
  taskErrorLogListLabel: 'Background task error log',
  /** EXPERIENCE.md:584 */
  xdbcErrorLogListLabel: 'xDBC error log',
  /** EXPERIENCE.md:584 */
  sqlDiagnosticsLogListLabel: 'SQL diagnostics log',
  /** EXPERIENCE.md:584 */
  eventLogListLabel: 'Interoperability event log',
  /** EXPERIENCE.md:584 */
  analyticsLogListLabel: 'Analytics log',
  /** EXPERIENCE.md:584 */
  logViewerNextMatch: 'Next match',
  /** EXPERIENCE.md:584 */
  logViewerPreviousMatch: 'Previous match',

  // Story 16.8: the six secondary log viewers' suggested prompts, three per screen.
  /** EXPERIENCE.md:585 */
  logSystemMonitorViewerPrompt1: 'What has the System Monitor reported recently?',
  /** EXPERIENCE.md:585 */
  logSystemMonitorViewerPrompt2: 'Did the System Monitor raise alerts today?',
  /** EXPERIENCE.md:585 */
  logSystemMonitorViewerPrompt3: 'When did the System Monitor last start?',
  /** EXPERIENCE.md:585 */
  logTaskErrorViewerPrompt1: 'Which background tasks failed, and why?',
  /** EXPERIENCE.md:585 */
  logTaskErrorViewerPrompt2: 'Which namespace did each failed background task run in?',
  /** EXPERIENCE.md:585 */
  logTaskErrorViewerPrompt3: 'Did any recent import or link task report errors?',
  /** EXPERIENCE.md:585 */
  logXdbcViewerPrompt1: 'Which xDBC connections hit an SQL error recently?',
  /** EXPERIENCE.md:585 */
  logXdbcViewerPrompt2: 'What does the most recent xDBC error mean?',
  /** EXPERIENCE.md:585 */
  logXdbcViewerPrompt3: 'Which namespaces are these xDBC errors in?',
  /** EXPERIENCE.md:585 */
  logSqlDiagnosticsViewerPrompt1: 'Which SQL loads reported errors?',
  /** EXPERIENCE.md:585 */
  logSqlDiagnosticsViewerPrompt2: 'What went wrong in the most recent failed load?',
  /** EXPERIENCE.md:585 */
  logSqlDiagnosticsViewerPrompt3: 'Did the latest load finish without errors?',
  /** EXPERIENCE.md:585 */
  logEventViewerPrompt1: 'Which production items logged errors recently?',
  /** EXPERIENCE.md:585 */
  logEventViewerPrompt2: 'Are any warnings repeating in the event log?',
  /** EXPERIENCE.md:585 */
  logEventViewerPrompt3: 'Summarize the interoperability errors by namespace.',
  /** EXPERIENCE.md:585 */
  logAnalyticsViewerPrompt1: 'Did any cube build or synchronization fail recently?',
  /** EXPERIENCE.md:585 */
  logAnalyticsViewerPrompt2: 'Summarize the recent analytics log entries by namespace.',
  /** EXPERIENCE.md:585 */
  logAnalyticsViewerPrompt3: 'Which analytics errors need attention?',

  // Story 16.9: the unified log hub -- its label, its two sections, the Sources list's two column
  // headers, the not-shown notice, and the sentence a log viewer shows when the hub's entry has
  // left its loaded range.
  /** EXPERIENCE.md:584 */
  logHubLabel: 'Unified log hub',
  /** EXPERIENCE.md:584 */
  logHubSourcesHeading: 'Sources',
  /** EXPERIENCE.md:584 */
  logHubTimelineHeading: 'Timeline',
  /** EXPERIENCE.md:584 */
  logHubColumnEntries: 'Entries',
  /** EXPERIENCE.md:584 */
  logHubColumnLastEntry: 'Last entry',
  /** EXPERIENCE.md:584 */
  logHubNotShown: 'Not shown: <source> \u2014 requires <resource>.',
  /** EXPERIENCE.md:584 */
  logViewerEntryGone: 'That entry is no longer in the loaded range.',

  // Story 16.9: the unified log hub's suggested prompts.
  /** EXPERIENCE.md:585 */
  logHubPrompt1: 'Which logs recorded errors in the last hour?',
  /** EXPERIENCE.md:585 */
  logHubPrompt2: 'What happened just before the most recent error, across every log?',
  /** EXPERIENCE.md:585 */
  logHubPrompt3: 'Which log should I open first to investigate, and why?',

  // Story 16.24: the try-it console's Copy as curl. "Copied" is `copyAnnouncementCopied`, the
  // clipboard sentence `copyAnnouncementUnavailable`, and the refusals the four `tryIt*` above.
  /** EXPERIENCE.md:574 */
  tryItCopyCurl: 'Copy as curl',
  /** EXPERIENCE.md:574 */
  tryItCurlAccessToken: '<AccessToken>',
  /** EXPERIENCE.md:574 */
  tryItCurlNote: 'The command replaces your access token, and each value this console masks in its record of the request, with a name in angle brackets for you to fill in. Check the command for any other secret before you share it.',

  // Story 16.3: the user editor's Effective privileges tab, and the permission check on the Users
  // and Roles lists and both editors. An unread section's suffix is `impactRequires` or
  // `impactTooMany`, and a yes's role may take `userEffectiveThrough`.
  /** EXPERIENCE.md:468 */
  userEffectiveTab: 'Effective privileges',
  /** EXPERIENCE.md:468 */
  userEffectiveIntro: 'What this account holds through its roles, the roles they grant, and public permissions. Escalation roles are not counted until used.',
  /** EXPERIENCE.md:468 */
  userEffectiveAll: 'Holds every privilege: <role> is or grants %All.',
  /** EXPERIENCE.md:468 */
  userEffectiveThrough: ' (through <role>)',
  /** EXPERIENCE.md:468 */
  userEffectiveUnchecked: 'Not checked',
  /** EXPERIENCE.md:468 */
  permissionCheckAction: 'Check permission',
  /** EXPERIENCE.md:468 */
  permissionCheckField: 'Permission',
  /** EXPERIENCE.md:468 */
  permissionCheckRun: 'Check',
  /** EXPERIENCE.md:468 */
  permissionCheckIncomplete: 'Enter a name and a resource first.',
  /** EXPERIENCE.md:468 */
  permissionCheckYes: 'Yes. <name> holds <pair>, granted by <role>.',
  /** EXPERIENCE.md:468 */
  permissionCheckPublic: 'Yes. Every account holds <pair> publicly.',
  /** EXPERIENCE.md:468 */
  permissionCheckNo: 'No. <name> does not hold <pair>.',

  // Story 16.16: the Agent audit ledger. Its Time, User, Name and Status columns, the dialog's
  // Result label and the criteria form's Begin, End, hint, Search and Any reuse existing keys.
  /** EXPERIENCE.md:336 */
  agentLedgerLabel: 'Agent audit ledger',
  /** EXPERIENCE.md:336 */
  agentLedgerEmpty: 'No agent activity matches.',
  /** EXPERIENCE.md:336 */
  agentLedgerColumnKind: 'Kind',
  /** EXPERIENCE.md:336 */
  agentLedgerColumnScreen: 'Screen',
  /** EXPERIENCE.md:336 */
  agentLedgerColumnTarget: 'Target',
  /** EXPERIENCE.md:336 */
  agentLedgerArguments: 'Arguments',
  /** EXPERIENCE.md:336 */
  agentLedgerKindModel: 'Model call',
  /** EXPERIENCE.md:336 */
  agentLedgerKindTool: 'Tool call',
  /** EXPERIENCE.md:336 */
  agentLedgerKindWrite: 'Confirmed write',
  /** EXPERIENCE.md:336 */
  agentLedgerKindAccess: 'Transcript read',
  /** EXPERIENCE.md:336 */
  agentLedgerWithheld: '<n> rows withheld: each records a privilege you do not hold.',
  /** EXPERIENCE.md:336 */
  agentLedgerDropped: '<n> calls were counted and not stored.',
  /** EXPERIENCE.md:336 */
  agentLedgerDeniedAction: 'see another user\'s agent activity',
  /** EXPERIENCE.md:336 */
  agentLedgerPrompt1: 'Who used the agent to change anything this week?',
  /** EXPERIENCE.md:336 */
  agentLedgerPrompt2: 'Which web applications did the agent change this week?',
  /** EXPERIENCE.md:336 */
  agentLedgerPrompt3: 'Did the agent change any user or role today?',

  // Story 18.2: the Namespaces list and its form -- the list's title, its three database column
  // headers (the form's select labels), its empty state and agent invitation, the edit's refused
  // action and six suggested prompts; the Delete dialog's consequence; the kernel's install-namespace
  // refusal; and the namespace delete's impact phrases. The form's title reuses `headerNamespaceLabel`.
  /** EXPERIENCE.md:378 */
  namespaceListLabel: 'Namespaces',
  /** EXPERIENCE.md:378 */
  namespaceColumnGlobals: 'Globals database',
  /** EXPERIENCE.md:378 */
  namespaceColumnRoutines: 'Routines database',
  /** EXPERIENCE.md:378 */
  namespaceColumnTemp: 'Temporary database',
  /** EXPERIENCE.md:378 */
  namespaceListEmpty: 'No namespaces on this instance.',
  /** EXPERIENCE.md:378 */
  namespaceListEmptyAgent: 'create a namespace',
  /** EXPERIENCE.md:378 */
  namespaceFormRefusedAction: 'change this namespace',
  /** EXPERIENCE.md:378 */
  namespaceListPrompt1: 'Which databases does each namespace use for its globals and routines?',
  /** EXPERIENCE.md:378 */
  namespaceListPrompt2: 'Which namespaces share a database?',
  /** EXPERIENCE.md:378 */
  namespaceListPrompt3: 'What would deleting a namespace take with it?',
  /** EXPERIENCE.md:378 */
  namespaceFormPrompt1: 'Which database should a new namespace use for its globals?',
  /** EXPERIENCE.md:378 */
  namespaceFormPrompt2: 'What changes if this namespace reads its routines from another database?',
  /** EXPERIENCE.md:378 */
  namespaceFormPrompt3: 'Which web applications run in this namespace?',
  /** EXPERIENCE.md:479 */
  namespaceDeleteConsequence:
    'Deleting this namespace also deletes its mappings and every web application that runs in it. Its databases stay. This cannot be undone.',
  /** EXPERIENCE.md:481 */
  namespaceRefusalOcuPilot:
    'OcuPilot or the instance itself runs in this namespace. It cannot be deleted, and its globals and routines databases cannot be changed.',
  /** EXPERIENCE.md:577 */
  impactBoundApplications: '<n> web applications run in it and are deleted with it: <names>',
  /** EXPERIENCE.md:577 */
  impactBoundApplicationsOne: '1 web application runs in it and is deleted with it: <names>',
  /** EXPERIENCE.md:577 */
  impactBoundApplicationsNone: 'no web application runs in it',
  /** EXPERIENCE.md:577 */
  impactBoundApplicationsUnchecked: 'which web applications run in it was not checked',
  /** EXPERIENCE.md:577 */
  impactDatabasesStay: 'it uses <n> databases, which stay: <names>',
  /** EXPERIENCE.md:577 */
  impactDatabasesStayOne: 'it uses 1 database, which stays: <names>',
  // Story 16.2: Web sessions, the third Web applications entry. Its Process ID, User and
  // Application column headers reuse existing keys.
  /** EXPERIENCE.md:357 */
  webSessionListLabel: 'Web sessions',
  /** EXPERIENCE.md:357 */
  webSessionColumnSession: 'Session',
  /** EXPERIENCE.md:357 */
  webSessionColumnExpires: 'Expires (UTC)',
  /** EXPERIENCE.md:357 */
  webSessionListEmpty: 'No web sessions on this instance.',
  /** EXPERIENCE.md:357 */
  webSessionListEmptyAgent: 'end a web session that is stuck or unwanted',
  /** EXPERIENCE.md:357 */
  webSessionEndAction: 'End session',
  /** EXPERIENCE.md:357 */
  webSessionEndConsequence:
    'Ending this session discards what its application kept for it, and its next request starts a new session. This cannot be undone.',
  /** EXPERIENCE.md:357 */
  webSessionRefusalOcuPilot: 'OcuPilot itself is running in this session. It cannot be ended from OcuPilot.',
  /** EXPERIENCE.md:357 */
  proposalEntityWebSession: 'Web session',
  /** EXPERIENCE.md:357 */
  webSessionListPrompt1: 'Which web sessions are open on this instance, and for which applications?',
  /** EXPERIENCE.md:357 */
  webSessionListPrompt2: 'Which users have more than one web session open?',
  /** EXPERIENCE.md:357 */
  webSessionListPrompt3: 'Which web sessions expire soonest?',
  /** EXPERIENCE.md:357 */
  webSessionRefusalPreserved:
    'This session\'s own process holds its lock, so it cannot be ended while that process runs. Terminate the process in Process details, then end the session.',

  // Story 16.5: Background tasks, the fifth Tasks entry. Its Source, Task, Status, Namespace and
  // Start time column headers and its Resume row action reuse existing keys.
  /** EXPERIENCE.md:371 */
  backgroundTaskListLabel: 'Background tasks',
  /** EXPERIENCE.md:371 */
  backgroundTaskColumnDetails: 'Details',
  /** EXPERIENCE.md:371 */
  backgroundTaskColumnErrorCount: 'Error count',
  /** EXPERIENCE.md:371 */
  actionPause: 'Pause',
  /** EXPERIENCE.md:371 */
  backgroundTaskCancelAction: 'Cancel task',
  /** EXPERIENCE.md:371 */
  backgroundTaskListEmpty: 'No background tasks.',
  /** EXPERIENCE.md:371 */
  backgroundTaskListEmptyAgent: 'cancel, pause or resume a background task',
  /** EXPERIENCE.md:371 */
  backgroundTaskCancelConsequence: 'Canceling stops this task where it is. What it has done stays done, and it cannot be resumed.',
  /** EXPERIENCE.md:371 */
  backgroundTaskRefusalState: 'This background task\'s current state does not allow that.',
  /** EXPERIENCE.md:371 */
  proposalEntityBackgroundTask: 'Background task',
  /** EXPERIENCE.md:371 */
  backgroundTaskListPrompt1: 'Which background tasks are running, and since when?',
  /** EXPERIENCE.md:371 */
  backgroundTaskListPrompt2: 'Which background tasks ended with errors?',
  /** EXPERIENCE.md:371 */
  backgroundTaskListPrompt3: 'Is a database compact or defragment running?',

  // Story 18.14: a namespace's global, routine and package mappings -- each list's and form's title,
  // the global list's two extra column headers, each list's empty state and agent invitation, the
  // edit's refused action, the system-global consequence under a global's Name, eighteen suggested
  // prompts; the Namespaces list's Copy mappings action, its dialog's consequence and its running and
  // done lines; each mapping Delete's consequence; and the kernel's refusal of OcuPilot's own
  // mappings. The Mappings line's label reuses `oauthResourceServerTabMappings`, the Copy button
  // `auditDatabaseCopyConfirm` and a copy that outlasts the wait `auditDatabaseStillRunning`.
  /** EXPERIENCE.md:378 */
  globalMappingListLabel: 'Global mappings',
  /** EXPERIENCE.md:378 */
  routineMappingListLabel: 'Routine mappings',
  /** EXPERIENCE.md:378 */
  packageMappingListLabel: 'Package mappings',
  /** EXPERIENCE.md:378 */
  globalMappingFormLabel: 'Global mapping',
  /** EXPERIENCE.md:378 */
  routineMappingFormLabel: 'Routine mapping',
  /** EXPERIENCE.md:378 */
  packageMappingFormLabel: 'Package mapping',
  /** EXPERIENCE.md:378 */
  mappingColumnLockDatabase: 'Lock database',
  /** EXPERIENCE.md:378 */
  mappingColumnCollation: 'Collation',
  /** EXPERIENCE.md:378 */
  globalMappingListEmpty: 'This namespace has no global mappings.',
  /** EXPERIENCE.md:378 */
  routineMappingListEmpty: 'This namespace has no routine mappings.',
  /** EXPERIENCE.md:378 */
  packageMappingListEmpty: 'This namespace has no package mappings.',
  /** EXPERIENCE.md:378 */
  globalMappingListEmptyAgent: 'map a global',
  /** EXPERIENCE.md:378 */
  routineMappingListEmptyAgent: 'map routines',
  /** EXPERIENCE.md:378 */
  packageMappingListEmptyAgent: 'map a package',
  /** EXPERIENCE.md:378 */
  mappingFormRefusedAction: 'change this mapping',
  /** EXPERIENCE.md:378 */
  mappingSystemGlobalConsequence:
    'This maps a system global. Code in this namespace that uses it reads the mapped database instead of the system\'s own.',
  /** EXPERIENCE.md:378 */
  namespaceCopyMappingsAction: 'Copy mappings',
  /** EXPERIENCE.md:378 */
  namespaceCopyMappingsConsequence:
    'Copies every mapping of the chosen namespace into this one. A mapping this namespace already has under the same name is replaced; its other mappings stay.',
  /** EXPERIENCE.md:378 */
  namespaceCopyMappingsRunning:
    'Copying mappings from <source> into <namespace> on the instance since <time>',
  /** EXPERIENCE.md:378 */
  namespaceCopyMappingsDone: 'Copied the mappings of <source> into <namespace>.',
  /** EXPERIENCE.md:378 */
  globalMappingListPrompt1: 'Which globals does this namespace read from another database?',
  /** EXPERIENCE.md:378 */
  globalMappingListPrompt2: 'Is any system global mapped in this namespace?',
  /** EXPERIENCE.md:378 */
  globalMappingListPrompt3: 'Which database holds this namespace\'s mapped globals?',
  /** EXPERIENCE.md:378 */
  routineMappingListPrompt1: 'Which routines does this namespace run from another database?',
  /** EXPERIENCE.md:378 */
  routineMappingListPrompt2: 'Which routine mappings use a wildcard?',
  /** EXPERIENCE.md:378 */
  routineMappingListPrompt3: 'Where do this namespace\'s mapped routines come from?',
  /** EXPERIENCE.md:378 */
  packageMappingListPrompt1: 'Which packages does this namespace load from another database?',
  /** EXPERIENCE.md:378 */
  packageMappingListPrompt2: 'Is any package here mapped to a database outside this namespace?',
  /** EXPERIENCE.md:378 */
  packageMappingListPrompt3: 'Which database does this package load from here?',
  /** EXPERIENCE.md:378 */
  globalMappingFormPrompt1: 'What does mapping a global to another database change?',
  /** EXPERIENCE.md:378 */
  globalMappingFormPrompt2: 'When should a global mapping name a subscript range?',
  /** EXPERIENCE.md:378 */
  globalMappingFormPrompt3: 'What does a global mapping\'s lock database do?',
  /** EXPERIENCE.md:378 */
  routineMappingFormPrompt1: 'What does mapping routines to another database change?',
  /** EXPERIENCE.md:378 */
  routineMappingFormPrompt2: 'How do I map only one routine type?',
  /** EXPERIENCE.md:378 */
  routineMappingFormPrompt3: 'Can a routine mapping use a wildcard?',
  /** EXPERIENCE.md:378 */
  packageMappingFormPrompt1: 'What does mapping a package to another database change?',
  /** EXPERIENCE.md:378 */
  packageMappingFormPrompt2: 'Does a package mapping include its subpackages?',
  /** EXPERIENCE.md:378 */
  packageMappingFormPrompt3: 'Which database should this package mapping name?',
  /** EXPERIENCE.md:479 */
  globalMappingDeleteConsequence:
    'This namespace stops reading these globals from the mapped database and reads its default database again. No data is deleted. This cannot be undone.',
  /** EXPERIENCE.md:479 */
  routineMappingDeleteConsequence:
    'This namespace stops running these routines from the mapped database. The routines themselves stay. This cannot be undone.',
  /** EXPERIENCE.md:479 */
  packageMappingDeleteConsequence:
    'This namespace stops loading this package\'s classes from the mapped database. The classes themselves stay. This cannot be undone.',
  /** EXPERIENCE.md:481 */
  mappingRefusalOcuPilot:
    'A mapping whose name or pattern covers OcuPilot\'s own names decides where OcuPilot\'s globals and code are found. In the namespace OcuPilot runs in, and in %ALL, such a mapping cannot be added, changed, removed or copied in.',

  // Story 18.15: the Namespaces list's Enable interoperability -- its row action, the typed-name
  // dialog's verb and consequence, which is also the agent's card line, the running and done lines,
  // and the tool's refusal of %SYS and %ALL. An enable that outlasts the wait reads
  // `auditDatabaseStillRunning`.
  /** EXPERIENCE.md:378 */
  namespaceEnableInteropAction: 'Enable interoperability',
  /** EXPERIENCE.md:378 */
  namespaceEnableInteropVerb: 'Enable interoperability in',
  /** EXPERIENCE.md:378 */
  namespaceEnableInteropConsequence:
    'Enabling interoperability maps the interoperability code into this namespace, creates its portal applications and gives the interoperability roles access to its databases. On InterSystems IRIS for Health it also runs the HealthShare Foundation install, which changes the whole instance: it maps the HealthShare libraries into this namespace; grants the Admin user the %HS_BFC_Administrator role, which holds %Admin_Manage, %Admin_Secure, %Admin_Task and %Admin_OAuth2_Client; creates HealthShare roles and resources and changes %HS_Administrator\'s resources; schedules the FHIR purge task and starts the FHIR_Validation_Server Java language server; and gives the new applications access to the HSCUSTOM database, and /bulkfhir/api access to IRISSYS and %HS_ImpersonateUser. Elsewhere it creates two databases, ENSTEMP and SECONDARY, beside this namespace\'s globals database. This cannot be undone.',
  /** EXPERIENCE.md:378 */
  namespaceEnableInteropRunning: 'Enabling interoperability in <namespace> on the instance since <time>',
  /** EXPERIENCE.md:378 */
  namespaceEnableInteropDone: 'Enabled interoperability in <namespace>.',
  /** EXPERIENCE.md:378 */
  namespaceEnableInteropSystem: 'Interoperability cannot be enabled in %SYS or %ALL.',

  // Story 16.6: Processes' Broadcast over the checked rows, its dialog and refusal, and the data
  // table's checked set. The dialog's field label and buttons reuse `logViewerColumnMessage`,
  // `actionSend`, `actionCancel` and `auditDialogClose`.
  /** EXPERIENCE.md:320 */
  processBroadcastAction: 'Broadcast',
  /** EXPERIENCE.md:320 */
  processBroadcastTitle: 'Broadcast to <n> processes',
  /** EXPERIENCE.md:320 */
  processBroadcastTitleOne: 'Broadcast to 1 process',
  /** EXPERIENCE.md:320 */
  processBroadcastHint: 'At most 255 characters, on one line. A broadcast reaches at most <n> processes.',
  /** EXPERIENCE.md:320 */
  processBroadcastSent: 'Message sent.',
  /** EXPERIENCE.md:320 */
  processBroadcastIneligible: 'Only a terminal session can receive a broadcast.',
  /** EXPERIENCE.md:320 */
  processBroadcastRefusalRecipient: 'At least one of these processes has ended or is not a terminal session, so nothing was sent.',
  /** EXPERIENCE.md:294 */
  tableCheckRowsFirst: 'Check one or more rows first',
  /** EXPERIENCE.md:294 */
  tableCheckAtMost: 'Check at most <n> rows',
  /** EXPERIENCE.md:294 */
  tableCheckAll: 'Check all',
  /** EXPERIENCE.md:375 */
  licenseUsageLabel: 'License usage',
  /** EXPERIENCE.md:375 */
  licenseUsageByProcess: 'By process',
  /** EXPERIENCE.md:375 */
  licenseUsageByUser: 'By user',
  /** EXPERIENCE.md:375 */
  licenseUsageDistributed: 'Distributed',
  /** EXPERIENCE.md:375 */
  licenseUsageUnitUse: 'License unit use',
  /** EXPERIENCE.md:375 */
  licenseUsageLocal: 'Local',
  /** EXPERIENCE.md:375 */
  licenseUsageLoginId: 'Login ID',
  /** EXPERIENCE.md:375 */
  licenseUsageUserId: 'User ID',
  /** EXPERIENCE.md:375 */
  licenseUsageActiveTime: 'Active time',
  /** EXPERIENCE.md:375 */
  licenseUsageUnits: 'Units',
  /** EXPERIENCE.md:375 */
  licenseUsageGraceTime: 'Grace time',
  /** EXPERIENCE.md:375 */
  licenseUsageMaxConnections: 'Maximum connections',
  /** EXPERIENCE.md:375 */
  licenseUsageLicenseUnits: 'License units',
  /** EXPERIENCE.md:375 */
  licenseUsageServerIp: 'Server IP',
  /** EXPERIENCE.md:375 */
  licenseUsageSummaryEmpty: 'The instance reports no license summary.',
  /** EXPERIENCE.md:375 */
  licenseUsageProcessesEmpty: 'No process holds a license unit.',
  /** EXPERIENCE.md:375 */
  licenseUsageUsersEmpty: 'No user holds a license unit.',
  /** EXPERIENCE.md:375 */
  licenseUsageDistributedEmpty: 'The instance reports no license connections.',
  /** EXPERIENCE.md:375 */
  licenseUsagePrompt1: 'How many license units are in use, and how close is that to the limit?',
  /** EXPERIENCE.md:375 */
  licenseUsagePrompt2: 'Which processes and users hold license units right now?',
  /** EXPERIENCE.md:375 */
  licenseUsagePrompt3: 'Is this instance connected to a license server?',
  /** EXPERIENCE.md:375 */
  dashboardLabel: 'Dashboard',
  /** EXPERIENCE.md:375 */
  dashboardGroupEcp: 'ECP and shadowing',
  /** EXPERIENCE.md:375 */
  dashboardGroupStatus: 'System status',
  /** EXPERIENCE.md:375 */
  dashboardGroupAlerts: 'Errors and alerts',
  /** EXPERIENCE.md:375 */
  dashboardGroupLicensing: 'Licensing',
  /** EXPERIENCE.md:375 */
  dashboardGroupTasks: 'Task manager',
  /** EXPERIENCE.md:375 */
  dashboardCpu: 'CPU',
  /** EXPERIENCE.md:375 */
  dashboardRoutineReferences: 'Routine references',
  /** EXPERIENCE.md:375 */
  dashboardApplicationServers: 'Application servers',
  /** EXPERIENCE.md:375 */
  dashboardApplicationServerTraffic: 'Application server traffic',
  /** EXPERIENCE.md:375 */
  dashboardDataServers: 'Data servers',
  /** EXPERIENCE.md:375 */
  dashboardDataServerTraffic: 'Data server traffic',
  /** EXPERIENCE.md:375 */
  dashboardShadowSource: 'Shadow source',
  /** EXPERIENCE.md:375 */
  dashboardShadowServer: 'Shadow server',
  /** EXPERIENCE.md:375 */
  dashboardLastBackup: 'Last backup',
  /** EXPERIENCE.md:375 */
  dashboardDatabaseJournal: 'Database journal',
  /** EXPERIENCE.md:375 */
  dashboardSeriousAlerts: 'Serious alerts',
  /** EXPERIENCE.md:375 */
  dashboardLicenseLimit: 'License limit',
  /** EXPERIENCE.md:375 */
  dashboardLicenseUse: 'Current license use',
  /** EXPERIENCE.md:375 */
  dashboardLicenseUseHigh: 'Highest license use',
  /** EXPERIENCE.md:375 */
  dashboardBytesPerSecond: 'bytes/s',
  /** EXPERIENCE.md:375 */
  dashboardLicenseUnitsUnit: 'license units',
  /** EXPERIENCE.md:375 */
  dashboardEmpty: 'The dashboard is unavailable.',
  /** EXPERIENCE.md:375 */
  dashboardPrompt1: 'Is any dashboard meter in a warning or troubled state?',
  /** EXPERIENCE.md:375 */
  dashboardPrompt2: 'How busy is the instance right now, and how much CPU is it using?',
  /** EXPERIENCE.md:375 */
  dashboardPrompt3: 'Have serious alerts or application errors been raised?',
  /** EXPERIENCE.md:377 */
  localDatabaseListLabel: 'Local databases',
  /** EXPERIENCE.md:377 */
  localDatabaseListEmpty: 'No local databases on this instance.',
  /** EXPERIENCE.md:377 */
  localDatabaseListEmptyAgent: 'create a database',
  /** EXPERIENCE.md:377 */
  localDatabaseFormRefusedAction: 'change this database',
  /** EXPERIENCE.md:377 */
  localDatabaseListPrompt1: 'Which databases does this instance define, and where are their files?',
  /** EXPERIENCE.md:377 */
  localDatabaseListPrompt2: 'Which databases could a new namespace use?',
  /** EXPERIENCE.md:377 */
  localDatabaseListPrompt3: 'What would deleting a database take with it?',
  /** EXPERIENCE.md:377 */
  localDatabaseFormPrompt1: 'Which resource guards this database?',
  /** EXPERIENCE.md:377 */
  localDatabaseFormPrompt3: 'What changes if this database becomes read only?',
  /** EXPERIENCE.md:377 */
  databaseWizardStepName: 'Name and directory',
  /** EXPERIENCE.md:377 */
  databaseWizardStepSize: 'Size and journaling',
  /** EXPERIENCE.md:377 */
  databaseInitialSize: 'Initial size (MB)',
  /** EXPERIENCE.md:377 */
  databaseResourceNew: 'Create the resource <name>',
  /** EXPERIENCE.md:377 */
  databaseResourceExisting: 'Use an existing resource',
  /** EXPERIENCE.md:377 */
  databaseGroupMounting: 'Mounting',
  /** EXPERIENCE.md:377 */
  databaseMountAtStartup: 'Mount at startup',
  /** EXPERIENCE.md:377 */
  databaseMountRequired: 'Mount required at startup',
  /** EXPERIENCE.md:377 */
  databaseCreateLink: 'Create a database',
  /** EXPERIENCE.md:377 */
  databaseDirectoryChange: 'Change',
  /** EXPERIENCE.md:377 */
  localDatabaseDeleteFileOption: 'Also delete the database file and its volume files',
  /** EXPERIENCE.md:377 */
  databaseTasksNone: 'No background task is running against this database.',
  /** EXPERIENCE.md:377 */
  databaseTasksTruncated: 'Only the newest <n> background tasks were checked.',
  /** EXPERIENCE.md:479 */
  localDatabaseDeleteConsequence:
    'Deleting this database removes it from the instance\'s configuration. Its file stays unless you also delete it here. This cannot be undone.',
  // Story 18.16: Remote databases, its form and the bounded listing of a data server's databases.
  /** EXPERIENCE.md:377 */
  remoteDatabaseListLabel: 'Remote databases',
  /** EXPERIENCE.md:377 */
  remoteDatabaseListEmpty: 'No remote databases on this instance.',
  /** EXPERIENCE.md:377 */
  remoteDatabaseListEmptyAgent: 'create a remote database',
  /** EXPERIENCE.md:377 */
  remoteDatabaseFormRefusedAction: 'change this remote database',
  /** EXPERIENCE.md:377 */
  remoteDatabaseFormLabel: 'Remote database',
  /** EXPERIENCE.md:377 */
  remoteDatabaseServer: 'Data server',
  /** EXPERIENCE.md:377 */
  remoteDatabaseStreamLocation: 'Stream location',
  /** EXPERIENCE.md:377 */
  remoteDatabaseListAgain: 'List databases',
  /** EXPERIENCE.md:377 */
  remoteDatabaseListHint: 'Choosing a data server lists its databases over ECP, which can take up to <n> seconds.',
  /** EXPERIENCE.md:377 */
  remoteDatabaseListRunning: 'Listing the databases on <server> since <time>',
  /** EXPERIENCE.md:377 */
  remoteDatabaseListNone: '<server> lists no databases.',
  /** EXPERIENCE.md:377 */
  remoteDatabaseListConsequence:
    'Confirming lists the databases on <server> to check the directory, which can take up to <n> seconds.',
  /** EXPERIENCE.md:377 */
  remoteDatabaseListPrompt1: 'Which remote databases does this instance define, and on which data servers?',
  /** EXPERIENCE.md:377 */
  remoteDatabaseListPrompt2: 'Which namespaces use a remote database?',
  /** EXPERIENCE.md:377 */
  remoteDatabaseListPrompt3: 'What would removing a remote database take with it?',
  /** EXPERIENCE.md:377 */
  remoteDatabaseFormPrompt1: 'Which data server is this database\'s file on?',
  /** EXPERIENCE.md:377 */
  remoteDatabaseFormPrompt2: 'Which namespaces use this remote database?',
  /** EXPERIENCE.md:377 */
  remoteDatabaseFormPrompt3: 'What happens to this database\'s file when it is removed here?',
  /** EXPERIENCE.md:479 */
  remoteDatabaseDeleteConsequence:
    'Deleting this remote database removes it from this instance\'s configuration. Its file on the data server stays. This cannot be undone.',
  /** EXPERIENCE.md:481 */
  databaseRefusalOcuPilot:
    'OcuPilot or the instance itself depends on this database. It cannot be deleted or dismounted, and its directory, resource and read-only setting cannot be changed.',
  /** EXPERIENCE.md:577 */
  impactNamespacesUse: '<n> namespaces use it and must stop using it first: <names>',
  /** EXPERIENCE.md:577 */
  impactNamespacesUseOne: '1 namespace uses it and must stop using it first: <names>',
  /** EXPERIENCE.md:577 */
  impactNamespacesUseNone: 'no namespace uses it',
  /** EXPERIENCE.md:577 */
  impactNamespacesUseUnchecked: 'which namespaces use it was not checked',
  /** EXPERIENCE.md:577 */
  impactApplicationsInThem: '<n> web applications run in those namespaces: <names>',
  /** EXPERIENCE.md:577 */
  impactApplicationsInThemOne: '1 web application runs in those namespaces: <names>',
  /** EXPERIENCE.md:577 */
  impactSharedFile: '<n> other databases share its file, which stays: <names>',
  /** EXPERIENCE.md:577 */
  impactSharedFileOne: '1 other database shares its file, which stays: <names>',
  /** EXPERIENCE.md:577 */
  impactSharedFileUnchecked: 'whether another database shares its file was not checked',
  // Story 16.10, External language servers. The Port column reuses `sslTestPort`, and the Name and
  // Type columns `tableColumnName` and `tableColumnType`, because a value already published belongs
  // to one key.
  /** EXPERIENCE.md:584 */
  languageServersLabel: 'External language servers',
  /** EXPERIENCE.md:584 */
  languageServerColumnRunning: 'Running',
  /** EXPERIENCE.md:584 */
  languageServerActivityLabel: 'Activity log',
  /** EXPERIENCE.md:584 */
  actionStart: 'Start',
  /** EXPERIENCE.md:584 */
  languageServerRefusalRunning: 'This server is already running.',
  /** EXPERIENCE.md:584 */
  languageServerRefusalStopped: 'This server is not running.',
  /** EXPERIENCE.md:584 */
  languageServerStopConsequence: 'Stopping it ends every connection to it at once.',
  /** EXPERIENCE.md:584 */
  languageServerStartFailed: 'The server did not start. Its activity log records why.',
  /** EXPERIENCE.md:584 */
  languageServerListEmpty: 'No external language servers on this instance.',
  /** EXPERIENCE.md:584 */
  languageServerListEmptyAgent: 'start or stop an external language server',
  /** EXPERIENCE.md:585 */
  languageServerListPrompt1: 'Which external language servers are running?',
  /** EXPERIENCE.md:585 */
  languageServerListPrompt2: 'Which servers share a port with another server?',
  /** EXPERIENCE.md:585 */
  languageServerListPrompt3: 'Which server should I check first when a gateway call fails?',
  /** EXPERIENCE.md:585 */
  languageServerActivityPrompt1: 'What does this server\'s activity log say about its last start?',
  /** EXPERIENCE.md:585 */
  languageServerActivityPrompt2: 'Did this server log any errors?',
  /** EXPERIENCE.md:585 */
  languageServerActivityPrompt3: 'When was this server last started or stopped?',
  /** EXPERIENCE.md:584 */
  languageServerFormLabel: 'External language server',
  /** EXPERIENCE.md:584 */
  languageServerFormNew: 'New external language server',
  /** EXPERIENCE.md:584 */
  languageServerFieldBindAddress: 'Bind address',
  /** EXPERIENCE.md:584 */
  languageServerFieldConnectionTimeout: 'Connection timeout (seconds)',
  /** EXPERIENCE.md:584 */
  languageServerFieldInitializationTimeout: 'Initialization timeout (seconds)',
  /** EXPERIENCE.md:584 */
  languageServerFieldSharedMemory: 'Use shared memory',
  /** EXPERIENCE.md:584 */
  languageServerFieldServerTls: 'Server TLS configuration',
  /** EXPERIENCE.md:584 */
  languageServerFieldClientTls: 'Client TLS configuration',
  /** EXPERIENCE.md:584 */
  languageServerFieldVerifyHostName: 'Verify the server\'s host name',
  /** EXPERIENCE.md:584 */
  languageServerFieldLogFile: 'Log file',
  /** EXPERIENCE.md:584 */
  languageServerFieldClassPath: 'Class path',
  /** EXPERIENCE.md:584 */
  languageServerFieldJavaHome: 'Java home',
  /** EXPERIENCE.md:584 */
  languageServerFieldFilePath: 'File path',
  /** EXPERIENCE.md:584 */
  languageServerFieldPythonPath: 'Python executable',
  /** EXPERIENCE.md:584 */
  languageServerFieldJvmArgs: 'JVM arguments',
  /** EXPERIENCE.md:584 */
  languageServerFieldDotNetVersion: '.NET version',
  /** EXPERIENCE.md:584 */
  languageServerFieldExec32: 'Run as 32-bit',
  /** EXPERIENCE.md:584 */
  languageServerFieldPythonOptions: 'Python options',
  /** EXPERIENCE.md:584 */
  languageServerFieldAddress: 'Address',
  /** EXPERIENCE.md:584 */
  languageServerPathClassicOnly: 'File locations are set on the classic portal\'s External Language Server page.',
  /** EXPERIENCE.md:584 */
  languageServerRefusalRunningEdit: 'This server is running. Stop it before changing or deleting it.',
  /** EXPERIENCE.md:584 */
  languageServerPythonConsequence: 'Saving this also turns the server\'s virtual environment back on and clears its PYTHONPATH, which only the classic portal shows.',
  /** EXPERIENCE.md:584 */
  languageServerNameTaken: 'A server with this name already exists.',
  /** EXPERIENCE.md:479 */
  languageServerDeleteConsequence: 'Deleting it removes this server\'s definition from the instance.',
  /** EXPERIENCE.md:585 */
  languageServerFormPrompt1: 'What does each setting on this server do?',
  /** EXPERIENCE.md:585 */
  languageServerFormPrompt2: 'Why might this server fail to start?',
  /** EXPERIENCE.md:585 */
  languageServerFormPrompt3: 'Which resource should protect this server?',
  // Story 18.4: the disk operations on Database details, the editor's size and Add a volume, the
  // Check integrity flow and the Integrity log. The flow's Databases and Globals steps reuse
  // `databaseListLabel` and `processColumnGlobals`, Add a volume's field `databaseInitialSize`, and a
  // run past the port's wait `auditDatabaseStillRunning`.
  /** EXPERIENCE.md:377 */
  databaseActionMount: 'Mount',
  /** EXPERIENCE.md:377 */
  databaseActionDismount: 'Dismount',
  /** EXPERIENCE.md:377 */
  databaseActionTruncate: 'Truncate',
  /** EXPERIENCE.md:377 */
  databaseActionCompact: 'Compact',
  /** EXPERIENCE.md:377 */
  databaseActionDefragment: 'Defragment',
  /** EXPERIENCE.md:377 */
  databaseIntegrityLabel: 'Check integrity',
  /** EXPERIENCE.md:377 */
  databaseIntegrityCheck: 'Integrity check',
  /** EXPERIENCE.md:377 */
  databaseIntegrityLogLabel: 'Integrity log',
  /** EXPERIENCE.md:377 */
  databaseIntegrityStepReport: 'Report',
  /** EXPERIENCE.md:377 */
  databaseIntegrityGlobalsOnly: 'Only these globals',
  /** EXPERIENCE.md:377 */
  databaseExpandAction: 'Add a volume',
  /** EXPERIENCE.md:377 */
  databaseSizeField: 'Size (MB)',
  /** EXPERIENCE.md:377 */
  databaseMountReadOnly: 'Mount read-only',
  /** EXPERIENCE.md:377 */
  databaseMountConsequence: 'Mounting makes this database available again to every namespace that uses it.',
  /** EXPERIENCE.md:377 */
  databaseDismountConsequence: 'Dismounting this database stops every process from reading or writing it until it is mounted again.',
  /** EXPERIENCE.md:377 */
  databaseTruncateConsequence: 'Truncating returns the unused space at the end of the database\'s file to the operating system. No data is removed.',
  /** EXPERIENCE.md:377 */
  databaseCompactConsequence: 'Compacting moves the database\'s free space to the end of its file, where Truncate can return it.',
  /** EXPERIENCE.md:377 */
  databaseDefragmentConsequence: 'Defragmenting can grow the database to make room while it works, and it cannot be paused.',
  /** EXPERIENCE.md:377 */
  databaseExpandConsequence: 'The new volume file is created in the database\'s new volume directory.',
  /** EXPERIENCE.md:377 */
  databaseTargetSizeLabel: 'Target file size (MB)',
  /** EXPERIENCE.md:377 */
  databaseTargetSizeHint: '0 returns all unused space. Otherwise enter less than the current size.',
  /** EXPERIENCE.md:377 */
  databaseTargetFreeLabel: 'Target free space at end of file (MB)',
  /** EXPERIENCE.md:377 */
  databaseTargetFreeHint: 'Enter a number from 0 to the database\'s free space.',
  /** EXPERIENCE.md:377 */
  databaseGlobalsHint: 'One name per line. Leave empty to check every global.',
  /** EXPERIENCE.md:377 */
  databaseGlobalsOneDatabase: 'Globals can be chosen when one database is checked.',
  /** EXPERIENCE.md:377 */
  databaseOperationRunning: '<operation> running on the instance since <time>',
  /** EXPERIENCE.md:377 */
  databaseOperationFinished: '<operation> finished.',
  /** EXPERIENCE.md:377 */
  databaseIntegrityOpenLog: 'Open the integrity log',
  /** EXPERIENCE.md:377 */
  databaseExpandDirty: 'Save your changes before adding a volume.',
  /** EXPERIENCE.md:377 */
  databaseIntegrityRunning: 'This check is still running.',
  /** EXPERIENCE.md:377 */
  databaseIntegrityNone: 'This instance holds no integrity check.',
  /** EXPERIENCE.md:377 */
  databaseListEmptyAgent: 'check the integrity of a database',
  /** EXPERIENCE.md:377 */
  databaseDetailsEmptyAgent: 'mount, dismount, truncate, compact or defragment a database',
  /** EXPERIENCE.md:377 */
  databaseIntegrityPrompt1: 'Which databases can I check for integrity?',
  /** EXPERIENCE.md:377 */
  databaseIntegrityPrompt2: 'What does an integrity check read?',
  /** EXPERIENCE.md:377 */
  databaseIntegrityPrompt3: 'Can an integrity check run while a database is in use?',
  /** EXPERIENCE.md:377 */
  databaseIntegrityLogPrompt1: 'Did the last integrity check find any errors?',
  /** EXPERIENCE.md:377 */
  databaseIntegrityLogPrompt2: 'Which databases did the last check cover?',
  /** EXPERIENCE.md:377 */
  databaseIntegrityLogPrompt3: 'When did the last integrity check run?',
  /** EXPERIENCE.md:377 */
  databaseInitialSizeHint: 'Enter a number of 1 or more, up to the new volume threshold when one is set.',
  // Story 16.11: the Task Manager's three actions, the suspend's warning, the refusals of a Task Manager
  // action in the wrong state and of a task row action whose type needs a privilege (DW-1638), the
  // Task schedule's fourth prompt and Home's Fix it sentence.
  /** EXPERIENCE.md:269 */
  taskManagerSuspendAction: 'Suspend Task Manager',
  /** EXPERIENCE.md:269 */
  taskManagerResumeAction: 'Resume Task Manager',
  /** EXPERIENCE.md:269 */
  taskManagerStartAction: 'Start Task Manager',
  /** EXPERIENCE.md:304 */
  taskManagerSuspendConsequence: 'No scheduled task will run until it is resumed.',
  /** EXPERIENCE.md:304 */
  taskManagerRefusalRunning: 'The Task Manager is already running.',
  /** EXPERIENCE.md:304 */
  taskManagerRefusalSuspended: 'The Task Manager is already suspended.',
  /** EXPERIENCE.md:304 */
  taskManagerRefusalSuspendedStart: 'The Task Manager is suspended. Resume it instead.',
  /** EXPERIENCE.md:304 */
  taskManagerRefusalStopped: 'The Task Manager is not running. Start it first.',
  /** EXPERIENCE.md:304 */
  taskTypePrivilegeRefusal: 'This task type needs a privilege you do not hold.',
  /** EXPERIENCE.md:562 */
  taskScheduleListPrompt4: 'What would stop running while the Task Manager is suspended?',
  /** EXPERIENCE.md:582 */
  findingFixTaskManager: 'The Task Manager is not running scheduled tasks. Propose resuming it, or starting it if it is stopped.',
  // Story 16.12: the Locks list's Remove locks dialog, its three scopes, the in-transaction warning,
  // the refusals it and the agent share, and the list's agent invitation.
  /** EXPERIENCE.md:376 */
  lockRemoveAction: 'Remove locks',
  /** EXPERIENCE.md:376 */
  lockRemoveTitle: 'Remove locks held by <PID>',
  /** EXPERIENCE.md:376 */
  lockRemoveScopeLegend: 'What to remove',
  /** EXPERIENCE.md:376 */
  lockRemoveScopeLock: 'This lock: <REFERENCE>',
  /** EXPERIENCE.md:376 */
  lockRemoveScopeProcess: 'Every lock this process holds',
  /** EXPERIENCE.md:376 */
  lockRemoveScopeClient: 'Every lock its remote client holds',
  /** EXPERIENCE.md:376 */
  lockRemoveConsequence: 'Removing a lock lets another process take it at once, whatever its owner was using it to protect. This cannot be undone.',
  /** EXPERIENCE.md:376 */
  lockRemoveInTransaction: 'Its owner is in an open transaction. Removing the lock leaves that transaction running without it.',
  /** EXPERIENCE.md:376 */
  lockRemoveAnyway: 'Remove anyway',
  /** EXPERIENCE.md:376 */
  lockRemoveRefusalRemote: 'Its owner is a remote client, not a process on this instance.',
  /** EXPERIENCE.md:376 */
  lockRemoveRefusalLocal: 'Its owner is a process on this instance, not a remote client.',
  /** EXPERIENCE.md:376 */
  lockRemoveTooMany: 'This owner holds more than 200 locks, and one removal names at most 200.',
  /** EXPERIENCE.md:376 */
  lockRefusalOcuPilot: 'This lock keeps OcuPilot\'s own state consistent. It cannot be removed from OcuPilot.',
  /** EXPERIENCE.md:376 */
  lockListEmptyAgent: 'remove a lock that a stuck process still holds',
  /** EXPERIENCE.md:503 */
  serviceAddressRolesEdit: 'Edit roles',
  /** EXPERIENCE.md:503 */
  serviceAddressRolesTitle: 'Roles for <address>',
  // Story 16.14: the LDAP and Kerberos editor, its Test authentication dialog, and the list's Create and Delete.
  /** EXPERIENCE.md:504 */
  ldapFieldCopyFrom: 'Copy settings from',
  /** EXPERIENCE.md:504 */
  ldapFieldKerberos: 'Kerberos configuration',
  /** EXPERIENCE.md:504 */
  ldapFieldActiveDirectory: 'Active Directory server',
  /** EXPERIENCE.md:504 */
  ldapFieldSearchPassword: 'Search password',
  /** EXPERIENCE.md:504 */
  ldapPasswordLeave: 'Leave as is',
  /** EXPERIENCE.md:504 */
  ldapPasswordEnter: 'Enter a new password',
  /** EXPERIENCE.md:504 */
  ldapPasswordClear: 'Clear the password',
  /** EXPERIENCE.md:504 */
  ldapFieldPasswordConfirm: 'Confirm password',
  /** EXPERIENCE.md:504 */
  ldapPasswordMismatch: 'The two passwords do not match.',
  /** EXPERIENCE.md:504 */
  ldapFieldBaseDnGroups: 'Base DN for nested groups',
  /** EXPERIENCE.md:504 */
  ldapFieldServerTimeout: 'Server timeout',
  /** EXPERIENCE.md:504 */
  ldapFieldClientTimeout: 'Client timeout',
  /** EXPERIENCE.md:504 */
  ldapFieldTls: 'Use TLS/SSL encryption for LDAP sessions',
  /** EXPERIENCE.md:504 */
  ldapFieldCaFile: 'CA certificate file',
  /** EXPERIENCE.md:504 */
  ldapFieldAllowEnv: 'Allow ISC_LDAP_CONFIGURATION environment variable',
  /** EXPERIENCE.md:504 */
  ldapTabGroups: 'Groups',
  /** EXPERIENCE.md:504 */
  ldapFieldUseGroups: 'Use LDAP groups for roles, routines and namespaces',
  /** EXPERIENCE.md:504 */
  ldapFieldNestedGroups: 'Search nested groups',
  /** EXPERIENCE.md:504 */
  ldapFieldOrganizationId: 'Organization ID prefix',
  /** EXPERIENCE.md:504 */
  ldapFieldGroupId: 'Group ID prefix',
  /** EXPERIENCE.md:504 */
  ldapFieldInstanceId: 'Instance ID prefix',
  /** EXPERIENCE.md:504 */
  ldapFieldRoleId: 'Role ID prefix',
  /** EXPERIENCE.md:504 */
  ldapFieldEscalationRoleId: 'Escalation role ID prefix',
  /** EXPERIENCE.md:504 */
  ldapFieldNamespaceId: 'Namespace ID prefix',
  /** EXPERIENCE.md:504 */
  ldapFieldRoutineId: 'Routine ID prefix',
  /** EXPERIENCE.md:504 */
  ldapFieldDelimiterId: 'Delimiter',
  /** EXPERIENCE.md:504 */
  ldapFieldUniversalGroups: 'Allow universal group authorization',
  /** EXPERIENCE.md:504 */
  ldapExampleUniversal: 'Universal group examples',
  /** EXPERIENCE.md:504 */
  ldapFieldLdapGroupId: 'Authorization group ID',
  /** EXPERIENCE.md:504 */
  ldapExampleGroup: 'Authorization group examples',
  /** EXPERIENCE.md:504 */
  ldapFieldLdapInstanceId: 'Authorization instance ID',
  /** EXPERIENCE.md:504 */
  ldapExampleInstance: 'Authorization instance examples',
  /** EXPERIENCE.md:504 */
  ldapTabAttributes: 'Attributes',
  /** EXPERIENCE.md:504 */
  ldapAttributeNamespace: 'User attribute to retrieve default namespace',
  /** EXPERIENCE.md:504 */
  ldapAttributeRoutine: 'User attribute to retrieve default routine',
  /** EXPERIENCE.md:504 */
  ldapAttributeRoles: 'User attribute to retrieve roles',
  /** EXPERIENCE.md:504 */
  ldapAttributeEscalationRoles: 'User attribute to retrieve escalation roles',
  /** EXPERIENCE.md:504 */
  ldapAttributeComment: 'User attribute to retrieve comment',
  /** EXPERIENCE.md:504 */
  ldapAttributeFullName: 'User attribute to retrieve full name',
  /** EXPERIENCE.md:504 */
  ldapAttributeMail: 'User attribute to retrieve mail address',
  /** EXPERIENCE.md:504 */
  ldapAttributeMobile: 'User attribute to retrieve mobile phone',
  /** EXPERIENCE.md:504 */
  ldapAttributeMobileProvider: 'User attribute to retrieve mobile provider',
  /** EXPERIENCE.md:504 */
  ldapFieldAttributes: 'Attributes to retrieve for each user',
  /** EXPERIENCE.md:504 */
  ldapAttributeField: 'Attribute to add',
  /** EXPERIENCE.md:504 */
  ldapAttributeAdd: 'Add attribute',
  /** EXPERIENCE.md:505 */
  ldapPasswordRefused: 'Saved. The search password was not stored: <reason>',
  /** EXPERIENCE.md:505 */
  ldapTestAction: 'Test authentication',
  /** EXPERIENCE.md:505 */
  ldapTestOutput: 'Output from the instance',
  /** EXPERIENCE.md:505 */
  ldapTestNoAnswer: 'The request ended before the instance answered, so there is no output to show.',
  /** EXPERIENCE.md:505 */
  ldapTestSaveFirst: 'Save your changes before testing.',
  /** EXPERIENCE.md:363 */
  ldapListEmptyAgent: 'create an LDAP configuration',
  /** EXPERIENCE.md:490 */
  ldapDeleteConsequence: 'Anyone who signs in through this configuration can no longer sign in. This cannot be undone.',
  /** EXPERIENCE.md:261 */
  egressLineLeft: 'This turn\'s screen context went to <provider> at <host> and left the instance.',
  /** EXPERIENCE.md:261 */
  egressLineStayed: 'This turn\'s screen context went to <provider> at <host> and did not leave the instance.',
  /** EXPERIENCE.md:261 */
  egressLineNone: 'This turn sent no screen context to <provider>.',
  /** EXPERIENCE.md:335 */
  agentDefinitionModelUnused: 'This endpoint has no {model} placeholder, so Model is not used; calls go to the model the endpoint names.',
  // Story 19.1: System Explorer's lists, viewers and prompts.
  /** EXPERIENCE.md:586 */
  explorerClassListLabel: 'Classes',
  /** EXPERIENCE.md:586 */
  explorerRoutineListLabel: 'Routines',
  /** EXPERIENCE.md:586 */
  explorerClassPatternLabel: 'Class name',
  /** EXPERIENCE.md:586 */
  explorerRoutinePatternLabel: 'Routine and include files',
  /** EXPERIENCE.md:586 */
  explorerSystemLabel: 'System items',
  /** EXPERIENCE.md:586 */
  explorerGeneratedLabel: 'Generated items',
  /** EXPERIENCE.md:586 */
  explorerMappedLabel: 'Mapped items',
  /** EXPERIENCE.md:586 */
  explorerColumnModified: 'Last modified',
  /** EXPERIENCE.md:586 */
  explorerColumnGenerated: 'Generated',
  /** EXPERIENCE.md:586 */
  explorerClassListEmpty: 'No classes in <NAMESPACE> match.',
  /** EXPERIENCE.md:586 */
  explorerRoutineListEmpty: 'No routines in <NAMESPACE> match.',
  /** EXPERIENCE.md:587 */
  explorerClassDocumentLabel: 'Class',
  /** EXPERIENCE.md:587 */
  explorerFormLabel: 'Form',
  /** EXPERIENCE.md:587 */
  explorerColumnFlags: 'Flags',
  /** EXPERIENCE.md:587 */
  explorerViewXml: 'XML',
  /** EXPERIENCE.md:587 */
  explorerViewInt: 'Intermediate code',
  /** EXPERIENCE.md:587 */
  explorerViewStructure: 'Structure',
  /** EXPERIENCE.md:587 */
  explorerGenerates: 'Generates',
  /** EXPERIENCE.md:587 */
  explorerSourceNotAvailable: 'The instance keeps no source for this document.',
  /** EXPERIENCE.md:587 */
  explorerXmlNotAvailable: 'The instance keeps no XML form of this document.',
  /** EXPERIENCE.md:587 */
  explorerIntNotAvailable: 'This document generates no intermediate code.',
  /** EXPERIENCE.md:587 */
  explorerRoutineNoStructure: 'A routine has no class structure.',
  /** EXPERIENCE.md:587 */
  explorerNoDocumentation: 'This class carries no documentation.',
  /** EXPERIENCE.md:587 */
  explorerClassDocumentEmpty: 'This class no longer exists.',
  /** EXPERIENCE.md:587 */
  explorerRoutineDocumentEmpty: 'This routine no longer exists.',
  /** EXPERIENCE.md:588 */
  explorerClassListPrompt1: 'Which classes in this namespace changed most recently?',
  /** EXPERIENCE.md:588 */
  explorerClassListPrompt2: 'Which classes here are mapped from another database?',
  /** EXPERIENCE.md:588 */
  explorerClassListPrompt3: 'Which packages hold the most classes?',
  /** EXPERIENCE.md:588 */
  explorerRoutineListPrompt1: 'Which routines changed most recently?',
  /** EXPERIENCE.md:588 */
  explorerRoutineListPrompt2: 'Which include files does this namespace hold?',
  /** EXPERIENCE.md:588 */
  explorerRoutineListPrompt3: 'Which routines here are generated?',
  /** EXPERIENCE.md:588 */
  explorerClassDocumentPrompt1: 'Summarize what this class does.',
  /** EXPERIENCE.md:588 */
  explorerClassDocumentPrompt2: 'Which methods does this class define?',
  /** EXPERIENCE.md:588 */
  explorerClassDocumentPrompt3: 'Which members are deprecated or internal?',
  /** EXPERIENCE.md:588 */
  explorerRoutineDocumentPrompt1: 'When did this routine last change?',
  /** EXPERIENCE.md:588 */
  explorerRoutineDocumentPrompt2: 'Which database holds this routine?',
  /** EXPERIENCE.md:588 */
  explorerRoutineDocumentPrompt3: 'Which intermediate routines does this routine generate?',
  // Story 19.2: System Explorer's compile and delete, and their published refusals.
  /** EXPERIENCE.md:589 */
  explorerCompileAction: 'Compile',
  /** EXPERIENCE.md:589 */
  explorerCompileTitle: 'Compile <n> documents',
  /** EXPERIENCE.md:589 */
  explorerCompileTitleOne: 'Compile 1 document',
  /** EXPERIENCE.md:589 */
  explorerCompileKeepSource: 'Keep generated source code',
  /** EXPERIENCE.md:589 */
  explorerCompileDependents: 'Compile dependent classes',
  /** EXPERIENCE.md:589 */
  explorerCompileSkipUpToDate: 'Skip documents that are up to date',
  /** EXPERIENCE.md:589 */
  explorerOutputLabel: 'Output',
  /** EXPERIENCE.md:589 */
  explorerCompileRunning: 'Compiling <i> of <n> \u00b7 <name>',
  /** EXPERIENCE.md:589 */
  explorerCompileSummary: 'Compiled <done> of <n> documents, <errors> with errors.',
  /** EXPERIENCE.md:589 */
  explorerCompileStopped: 'Stopped after <done> of <n> documents.',
  /** EXPERIENCE.md:589 */
  explorerDocumentResult: '<name>: <reason>',
  /** EXPERIENCE.md:589 */
  explorerDeleteDeleted: '<name>: deleted',
  /** EXPERIENCE.md:589 */
  explorerDeleteRunning: 'Deleting <n> documents',
  /** EXPERIENCE.md:589 */
  explorerDeleteSummary: 'Deleted <done> of <n> documents.',
  /** EXPERIENCE.md:589 */
  explorerDeleteConsequence: 'The document\'s source and compiled code are removed and cannot be restored from OcuPilot. A persistent class\'s stored data is kept.',
  /** EXPERIENCE.md:589 */
  explorerDeleteSetConsequence: 'Deletes <n> documents. Each one\'s source and compiled code are removed and cannot be restored from OcuPilot, and a persistent class\'s stored data is kept.',
  /** EXPERIENCE.md:589 */
  explorerClassListEmptyAgent: 'compile classes',
  /** EXPERIENCE.md:589 */
  explorerRoutineListEmptyAgent: 'compile routines',
  /** EXPERIENCE.md:589 */
  explorerViewerObjectOnly: 'This instance holds only this routine\'s object code, so it has no source to show.',
  /** EXPERIENCE.md:590 */
  explorerRefusalOcuPilot: 'This is OcuPilot\'s own code. It cannot be compiled, deleted or replaced from OcuPilot.',
  /** EXPERIENCE.md:590 */
  explorerDocumentAbsent: 'This namespace no longer holds a document this change names.',
  /** EXPERIENCE.md:590 */
  explorerImportUnreadable: 'The file holds no document this instance can read.',
  /** EXPERIENCE.md:590 */
  explorerImportChanged: 'The file, or a document it would replace, has changed since this import was proposed.',
  /** EXPERIENCE.md:590 */
  explorerImportTooLarge: 'The file is longer than 3,000,000 characters, the most one import reads.',
  /** EXPERIENCE.md:590 */
  explorerDeleteAccess: 'This account cannot change the database that holds this document.',
  /** EXPERIENCE.md:590 */
  explorerDeleteLocked: 'Another process is editing this document.',
  /** EXPERIENCE.md:590 */
  explorerDeleteAbsent: 'This namespace no longer holds this document.',
  /** EXPERIENCE.md:590 */
  explorerDeleteFailed: 'The source code API could not delete this document.',
  /** EXPERIENCE.md:591 */
  explorerExportTitle: 'Export <n> documents',
  /** EXPERIENCE.md:591 */
  explorerExportTitleOne: 'Export 1 document',
  /** EXPERIENCE.md:591 */
  explorerTransferServer: 'A file on the server',
  /** EXPERIENCE.md:591 */
  explorerTransferBrowser: 'This browser',
  /** EXPERIENCE.md:591 */
  explorerTransferLocal: 'A file on this computer',
  /** EXPERIENCE.md:591 */
  explorerImportCompile: 'Compile imported documents',
  /** EXPERIENCE.md:591 */
  explorerImportReplaces: 'Importing replaces each document of the same name in this namespace, without asking.',
  /** EXPERIENCE.md:591 */
  explorerExportDone: 'Exported <n> documents to <path>.',
  /** EXPERIENCE.md:591 */
  explorerExportSaved: 'Saved <n> documents as <file>.',
  /** EXPERIENCE.md:591 */
  explorerImportRunning: 'Importing <file>',
  /** EXPERIENCE.md:591 */
  explorerImportDone: 'Imported <n> documents.',
  /** EXPERIENCE.md:591 */
  explorerImportDoneErrors: 'Imported <n> documents, with compile errors.',
  /** EXPERIENCE.md:591 */
  explorerExportDirectory: 'There is no such directory under that allowed directory.',
  /** EXPERIENCE.md:592 */
  explorerRoutineDeleteConsequence: 'The routine\'s source and compiled code are removed and cannot be restored from OcuPilot.',
  /** EXPERIENCE.md:592 */
  explorerRoutineDeleteSetConsequence: 'Deletes <n> documents. Each one\'s source and compiled code are removed and cannot be restored from OcuPilot.',
  /** EXPERIENCE.md:593 */
  explorerEditSource: 'Edit source',
  /** EXPERIENCE.md:593 */
  explorerClassEditorLabel: 'Edit class',
  /** EXPERIENCE.md:593 */
  explorerRoutineEditorLabel: 'Edit routine',
  /** EXPERIENCE.md:593 */
  explorerCompileAfterSaving: 'Compile after saving',
  /** EXPERIENCE.md:593 */
  explorerEditorTextLabel: 'Text of <name>',
  /** EXPERIENCE.md:593 */
  explorerDocumentConflict: 'Someone else changed this document after you opened it, so it was not saved. Copy your changes, then reopen the document to see the current text.',
  /** EXPERIENCE.md:593 */
  explorerSaveHeader: 'The first line no longer names this document, so the text was not saved.',
  /** EXPERIENCE.md:593 */
  explorerSaveTooLarge: 'The text is longer than 3,000,000 characters, the most one save sends.',
  /** EXPERIENCE.md:593 */
  explorerSaveRefused: 'The instance refused this text, so nothing was saved.',
  /** EXPERIENCE.md:593 */
  explorerEditorRefusedAction: 'save this document',
  // Story 18.5: Journals, Journal file details and Journal file databases -- titles, column headers,
  // empty states and prompts; the two screen-level switches and the integrity check, their warnings
  // (also the agent's card lines), the check's flag and its two verdicts. Size, Reason, Maximum size,
  // Database, Check integrity and its running and finished lines reuse 18.4's and earlier keys.
  /** EXPERIENCE.md:378 */
  journalListLabel: 'Journals',
  /** EXPERIENCE.md:378 */
  journalColumnCreated: 'Created',
  /** EXPERIENCE.md:378 */
  journalColumnDataSize: 'Data size',
  /** EXPERIENCE.md:378 */
  journalListEmpty: 'No journal files on this instance.',
  /** EXPERIENCE.md:378 */
  journalListEmptyAgent: 'switch the journal file or check a journal file\'s integrity',
  /** EXPERIENCE.md:378 */
  journalSwitchFileAction: 'Switch file',
  /** EXPERIENCE.md:378 */
  journalSwitchDirectoryAction: 'Switch directory',
  /** EXPERIENCE.md:378 */
  journalSwitchFileConsequence: 'The instance closes <file> and starts a new journal file.',
  /** EXPERIENCE.md:378 */
  journalSwitchDirectoryConsequence: 'The instance starts writing its journal in the other configured journal directory.',
  /** EXPERIENCE.md:378 */
  journalIntegrityConsequence: 'The instance reads <file>. Checking every record takes longer.',
  /** EXPERIENCE.md:378 */
  journalIntegrityEveryRecord: 'Check every record',
  /** EXPERIENCE.md:378 */
  journalIntegrityClean: 'No errors were found in <file>.',
  /** EXPERIENCE.md:378 */
  journalIntegrityErrors: 'Errors were found in <file>.',
  /** EXPERIENCE.md:378 */
  journalSwitchNewFile: 'A new journal file',
  /** EXPERIENCE.md:378 */
  journalFileDetailsLabel: 'Journal file details',
  /** EXPERIENCE.md:378 */
  journalFileDetailsGone: 'This journal file is no longer listed.',
  /** EXPERIENCE.md:378 */
  journalDetailsGuid: 'File GUID',
  /** EXPERIENCE.md:378 */
  journalDetailsFileCount: 'File count',
  /** EXPERIENCE.md:378 */
  journalDetailsFirstRecord: 'First record',
  /** EXPERIENCE.md:378 */
  journalDetailsLastRecord: 'Last record',
  /** EXPERIENCE.md:378 */
  journalDetailsEnd: 'End offset',
  /** EXPERIENCE.md:378 */
  journalDetailsEncryption: 'Encryption key',
  /** EXPERIENCE.md:378 */
  journalDetailsNotEncrypted: 'Not encrypted',
  /** EXPERIENCE.md:378 */
  journalDetailsMinTransCount: 'Minimum transaction file count',
  /** EXPERIENCE.md:378 */
  journalDetailsMinTransIndex: 'Minimum transaction file index',
  /** EXPERIENCE.md:378 */
  journalDetailsClusterStart: 'Cluster start time',
  /** EXPERIENCE.md:378 */
  journalDetailsPrevious: 'Previous file',
  /** EXPERIENCE.md:378 */
  journalDetailsNext: 'Next file',
  /** EXPERIENCE.md:378 */
  journalFileDatabaseListLabel: 'Journal file databases',
  /** EXPERIENCE.md:378 */
  journalColumnSfn: 'System file number',
  /** EXPERIENCE.md:378 */
  journalFileDatabaseListEmpty: 'This journal file holds no database records.',
  /** EXPERIENCE.md:378 */
  journalListPrompt1: 'Which journal file is the instance writing now?',
  /** EXPERIENCE.md:378 */
  journalListPrompt2: 'How much space do the journal files use?',
  /** EXPERIENCE.md:378 */
  journalListPrompt3: 'Why was the journal last switched?',
  /** EXPERIENCE.md:378 */
  journalFileDetailsPrompt1: 'When was this journal file created?',
  /** EXPERIENCE.md:378 */
  journalFileDetailsPrompt2: 'Which journal files come before and after this one?',
  /** EXPERIENCE.md:378 */
  journalFileDetailsPrompt3: 'Is this journal file encrypted?',
  /** EXPERIENCE.md:378 */
  journalFileDatabaseListPrompt1: 'Which databases have records in this journal file?',
  /** EXPERIENCE.md:378 */
  journalFileDatabaseListPrompt2: 'How many databases does this journal file cover?',
  /** EXPERIENCE.md:378 */
  journalFileDatabaseListPrompt3: 'Does this journal file hold records for IRISSYS?',
  /** EXPERIENCE.md:594 */
  explorerCompareLabel: 'Compare',
  /** EXPERIENCE.md:594 */
  explorerMacroLabel: 'Macros',
  /** EXPERIENCE.md:594 */
  explorerSearchTextLabel: 'Text',
  /** EXPERIENCE.md:594 */
  explorerSearchScopeLabel: 'Look in',
  /** EXPERIENCE.md:594 */
  explorerSearchScopeAll: 'Classes and routines',
  /** EXPERIENCE.md:594 */
  explorerSearchCaseLabel: 'Match case',
  /** EXPERIENCE.md:594 */
  explorerColumnDocument: 'Document',
  /** EXPERIENCE.md:594 */
  explorerColumnMember: 'Member',
  /** EXPERIENCE.md:594 */
  explorerColumnLine: 'Line',
  /** EXPERIENCE.md:594 */
  explorerColumnMatch: 'Match',
  /** EXPERIENCE.md:594 */
  explorerColumnMacro: 'Macro',
  /** EXPERIENCE.md:594 */
  explorerCompareFirst: 'First document',
  /** EXPERIENCE.md:594 */
  explorerCompareSecond: 'Second document',
  /** EXPERIENCE.md:594 */
  explorerCompareWith: 'Compare with\u2026',
  /** EXPERIENCE.md:594 */
  explorerLookUpMacro: 'Look up a macro',
  /** EXPERIENCE.md:594 */
  explorerMacroDefinedIn: 'Defined in <document>, line <n>',
  /** EXPERIENCE.md:594 */
  explorerCompareIdentical: 'The two documents are identical.',
  /** EXPERIENCE.md:594 */
  explorerCompareSummary: '<n> lines removed \u00b7 <m> lines added',
  /** EXPERIENCE.md:594 */
  explorerCompareUnchanged: '<n> unchanged lines',
  /** EXPERIENCE.md:594 */
  explorerDiffAdded: 'added',
  /** EXPERIENCE.md:594 */
  explorerCompareTooLarge: 'These documents differ in more than 1,000 lines, so they are not compared line by line.',
  /** EXPERIENCE.md:594 */
  explorerSearchEmpty: 'Nothing in this namespace matches that text.',
  /** EXPERIENCE.md:594 */
  explorerSearchInvite: 'Enter text to find in this namespace\'s classes and routines.',
  /** EXPERIENCE.md:594 */
  explorerMacroUndefined: '<macro> is not defined where <document> can see it.',
  /** EXPERIENCE.md:594 */
  explorerSearchTextReason: 'Name the text to search for: 1 to 256 characters, with no control character.',
  /** EXPERIENCE.md:594 */
  explorerSearchScopeReason: 'scope must be all, classes or routines.',
  /** EXPERIENCE.md:594 */
  explorerSearchCaseReason: 'case must be yes or no.',
  /** EXPERIENCE.md:594 */
  explorerMacroReason: 'Name a class or routine as the macro\'s context, and a macro, as Name or $$$Name.',
  /** EXPERIENCE.md:594 */
  explorerSearchPrompt1: 'Which classes in this namespace call ##class(%File)?',
  /** EXPERIENCE.md:594 */
  explorerSearchPrompt2: 'Where does this namespace\'s code mention TODO?',
  /** EXPERIENCE.md:594 */
  explorerSearchPrompt3: 'Which routines mention ^ERRORS?',
  /** EXPERIENCE.md:594 */
  explorerComparePrompt1: 'Which classes changed in the last day?',
  /** EXPERIENCE.md:594 */
  explorerComparePrompt2: 'Which routines changed in the last day?',
  /** EXPERIENCE.md:594 */
  explorerComparePrompt3: 'Which documents in this namespace mention TODO?',
  /** EXPERIENCE.md:594 */
  explorerMacroPrompt1: 'What does $$$ISERR expand to?',
  /** EXPERIENCE.md:594 */
  explorerMacroPrompt2: 'Where is $$$OK defined?',
  /** EXPERIENCE.md:594 */
  explorerMacroPrompt3: 'What does $$$ThrowOnError do?',
  // Story 18.18: Journal settings -- its title, the form's labels, the shown-only hint and its two
  // read-only values, the directory line, the Freeze on error consequence (also the agent's card line)
  // and the prompts. Change, Cancel, Saved, "(none)", "Not set", the leave guard and the picker reuse
  // earlier keys.
  /** EXPERIENCE.md:378 */
  journalSettingsLabel: 'Journal settings',
  /** EXPERIENCE.md:378 */
  journalSettingsPrimary: 'Primary journal directory',
  /** EXPERIENCE.md:378 */
  journalSettingsAlternate: 'Alternate journal directory',
  /** EXPERIENCE.md:378 */
  journalSettingsFileSize: 'Start a new journal file every (MB)',
  /** EXPERIENCE.md:378 */
  journalSettingsPrefix: 'Journal file prefix',
  /** EXPERIENCE.md:378 */
  journalSettingsArchive: 'Archive target',
  /** EXPERIENCE.md:378 */
  journalSettingsPurgeArchived: 'Purge as soon as they are copied to the archive',
  /** EXPERIENCE.md:378 */
  journalSettingsPurgeDays: 'Purge after this many days',
  /** EXPERIENCE.md:378 */
  journalSettingsPurgeBackups: 'Purge after this many backups',
  /** EXPERIENCE.md:378 */
  journalSettingsFreeze: 'Freeze on error',
  /** EXPERIENCE.md:378 */
  journalSettingsCspSession: 'Journal web sessions',
  /** EXPERIENCE.md:378 */
  journalSettingsCompress: 'Compress journal files',
  /** EXPERIENCE.md:378 */
  journalSettingsWijDirectory: 'Write image journal directory',
  /** EXPERIENCE.md:378 */
  journalSettingsWijSize: 'Write image journal target size (MB)',
  /** EXPERIENCE.md:378 */
  journalSettingsWijManager: 'The manager directory',
  /** EXPERIENCE.md:378 */
  journalSettingsShownOnly: 'Shown here only. Change it on the classic Journal Settings page.',
  /** EXPERIENCE.md:378 */
  journalSettingsFreezeConsequence: 'With Freeze on error on, a journal write error blocks every process that journals until it is fixed.',
  /** EXPERIENCE.md:378 */
  journalSettingsDirectoryNewFile: 'Saving a changed journal directory starts a new journal file.',
  /** EXPERIENCE.md:378 */
  journalSettingsPrompt1: 'Where does this instance write its journal files?',
  /** EXPERIENCE.md:378 */
  journalSettingsPrompt2: 'When are old journal files purged?',
  /** EXPERIENCE.md:378 */
  journalSettingsPrompt3: 'Does a journal write error freeze the instance?',
  /** EXPERIENCE.md:378 */
  journalSettingsRefusedAction: 'change the journal settings',
  /** EXPERIENCE.md:595 */
  explorerSqlSchemasLabel: 'SQL schemas',
  /** EXPERIENCE.md:595 */
  explorerSqlTablesLabel: 'SQL tables',
  /** EXPERIENCE.md:595 */
  explorerSqlViewsLabel: 'SQL views',
  /** EXPERIENCE.md:595 */
  explorerSqlProceduresLabel: 'SQL procedures',
  /** EXPERIENCE.md:595 */
  explorerSqlTableLabel: 'SQL table',
  /** EXPERIENCE.md:595 */
  explorerSqlTabInfo: 'Table info',
  /** EXPERIENCE.md:595 */
  explorerSqlTabFields: 'Fields',
  /** EXPERIENCE.md:595 */
  explorerSqlTabIndices: 'Maps/Indices',
  /** EXPERIENCE.md:595 */
  explorerSqlTabTriggers: 'Triggers',
  /** EXPERIENCE.md:595 */
  explorerSqlTabConstraints: 'Constraints',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnSchema: 'Schema',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnTables: 'Tables',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnViews: 'Views',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnProcedures: 'Procedures',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnTable: 'Table',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnOwner: 'Owner',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnSharded: 'Sharded',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnPartitioned: 'Partitioned',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnUpdatable: 'Updatable',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnCheckOption: 'Check option',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnProcedure: 'Procedure',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnMethod: 'Method',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnLastCompiled: 'Last compiled',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnExternal: 'External',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnExtentSize: 'Extent size',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnExternalType: 'External type',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnField: 'Field',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnNumber: 'Column',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnUnique: 'Unique',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnHidden: 'Hidden',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnMaxLength: 'Maximum length',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnReferenceTo: 'References',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnSelectivity: 'Selectivity',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnIndex: 'Index',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnMap: 'Map',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnColumns: 'Columns',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnInherited: 'Inherited',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnGlobal: 'Global',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnTrigger: 'Trigger',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnEvent: 'Event',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnOrder: 'Order',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnConstraint: 'Constraint',
  /** EXPERIENCE.md:595 */
  explorerSqlColumnConstraintData: 'Constraint data',
  /** EXPERIENCE.md:595 */
  explorerSqlSchemasEmpty: 'No SQL schemas in <NAMESPACE> match.',
  /** EXPERIENCE.md:595 */
  explorerSqlTablesEmpty: 'No SQL tables in <NAMESPACE> match.',
  /** EXPERIENCE.md:595 */
  explorerSqlViewsEmpty: 'No SQL views in <NAMESPACE> match.',
  /** EXPERIENCE.md:595 */
  explorerSqlProceduresEmpty: 'No SQL procedures in <NAMESPACE> match.',
  /** EXPERIENCE.md:595 */
  explorerSqlTableEmpty: 'This table no longer exists.',
  /** EXPERIENCE.md:595 */
  explorerSqlFieldsEmpty: 'This table has no fields this account can see.',
  /** EXPERIENCE.md:595 */
  explorerSqlIndicesEmpty: 'This table has no maps or indices.',
  /** EXPERIENCE.md:595 */
  explorerSqlTriggersEmpty: 'This table has no triggers.',
  /** EXPERIENCE.md:595 */
  explorerSqlConstraintsEmpty: 'This table has no constraints.',
  /** EXPERIENCE.md:595 */
  explorerSqlSchemaReason: 'schema must be 1 to 128 characters, with no control character.',
  /** EXPERIENCE.md:595 */
  explorerSqlSystemReason: 'system must be yes or no.',
  /** EXPERIENCE.md:595 */
  explorerSqlTableReason: 'Name one table, as Schema.Table.',
  /** EXPERIENCE.md:595 */
  explorerSqlAmbiguousReason: 'That name matches more than one table in this namespace.',
  /** EXPERIENCE.md:595 */
  explorerSqlNotFoundReason: 'This namespace holds no table by that name that this account can see.',
  /** EXPERIENCE.md:595 */
  explorerSqlSchemasPrompt1: 'Which schemas in this namespace hold tables?',
  /** EXPERIENCE.md:595 */
  explorerSqlSchemasPrompt2: 'Which schemas hold stored procedures but no tables?',
  /** EXPERIENCE.md:595 */
  explorerSqlSchemasPrompt3: 'Which schemas hold views?',
  /** EXPERIENCE.md:595 */
  explorerSqlTablesPrompt1: 'Which tables does this namespace hold?',
  /** EXPERIENCE.md:595 */
  explorerSqlTablesPrompt2: 'Which classes project these tables?',
  /** EXPERIENCE.md:595 */
  explorerSqlTablesPrompt3: 'Which tables here are partitioned or sharded?',
  /** EXPERIENCE.md:595 */
  explorerSqlViewsPrompt1: 'Which views does this namespace hold?',
  /** EXPERIENCE.md:595 */
  explorerSqlViewsPrompt2: 'Which of these views can be updated?',
  /** EXPERIENCE.md:595 */
  explorerSqlViewsPrompt3: 'Which classes define these views?',
  /** EXPERIENCE.md:595 */
  explorerSqlProceduresPrompt1: 'Which stored procedures does this namespace hold?',
  /** EXPERIENCE.md:595 */
  explorerSqlProceduresPrompt2: 'Which of these are functions rather than procedures?',
  /** EXPERIENCE.md:595 */
  explorerSqlProceduresPrompt3: 'Which class methods do these procedures call?',
  /** EXPERIENCE.md:595 */
  explorerSqlTablePrompt1: 'When was this table last compiled?',
  /** EXPERIENCE.md:595 */
  explorerSqlTablePrompt2: 'Which class projects this table?',
  /** EXPERIENCE.md:595 */
  explorerSqlTablePrompt3: 'Is this table read-only or external?',
  /** EXPERIENCE.md:595 */
  explorerSqlFieldsPrompt1: 'Which fields of this table are required?',
  /** EXPERIENCE.md:595 */
  explorerSqlFieldsPrompt2: 'Which fields reference another table?',
  /** EXPERIENCE.md:595 */
  explorerSqlFieldsPrompt3: 'Which fields of this table are unique?',
  /** EXPERIENCE.md:595 */
  explorerSqlIndicesPrompt1: 'Which indices does this table have?',
  /** EXPERIENCE.md:595 */
  explorerSqlIndicesPrompt2: 'Which global holds this table\'s data?',
  /** EXPERIENCE.md:595 */
  explorerSqlIndicesPrompt3: 'How large is each index of this table?',
  /** EXPERIENCE.md:595 */
  explorerSqlTriggersPrompt1: 'Which triggers run on this table?',
  /** EXPERIENCE.md:595 */
  explorerSqlTriggersPrompt2: 'What does each trigger of this table do?',
  /** EXPERIENCE.md:595 */
  explorerSqlTriggersPrompt3: 'In what order do this table\'s triggers run?',
  /** EXPERIENCE.md:595 */
  explorerSqlConstraintsPrompt1: 'Which constraints does this table enforce?',
  /** EXPERIENCE.md:595 */
  explorerSqlConstraintsPrompt2: 'What is this table\'s primary key?',
  /** EXPERIENCE.md:595 */
  explorerSqlConstraintsPrompt3: 'Which foreign keys does this table declare?',
  /** EXPERIENCE.md:596 */
  explorerSqlTabPartitions: 'Partitions',
  /** EXPERIENCE.md:596 */
  explorerSqlTabPartitionMappings: 'Partition mappings',
  /** EXPERIENCE.md:596 */
  explorerSqlTabCachedQueries: 'Cached queries',
  /** EXPERIENCE.md:596 */
  explorerSqlTabStatements: 'SQL statements',
  /** EXPERIENCE.md:596 */
  explorerSqlViewLabel: 'SQL view',
  /** EXPERIENCE.md:596 */
  explorerSqlTabViewInfo: 'View info',
  /** EXPERIENCE.md:596 */
  explorerSqlProcedureLabel: 'SQL procedure',
  /** EXPERIENCE.md:596 */
  explorerSqlTabProcedureInfo: 'Stored procedure info',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnPartition: 'Partition',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnBuckets: 'Buckets',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnRows: 'Rows',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnEstimatedSize: 'Estimated size',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnRule: 'Rule',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnCachedQuery: 'Cached query',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnQueryType: 'Query type',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnFeatures: 'Statement features',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnStatement: 'Statement',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnPlanState: 'Plan state',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnNewPlan: 'New plan',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnExecutions: 'Executions',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnTotalTime: 'Total time',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnAverageTime: 'Average time',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnStdDevTime: 'Standard deviation',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnRowCount: 'Row count',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnFirstSeen: 'First seen',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnClassType: 'Class type',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnLength: 'Length',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnPrecision: 'Precision',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnScale: 'Scale',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnStream: 'Stream',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnInputs: 'Inputs',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnInOuts: 'Inputs and outputs',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnOutputs: 'Outputs',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnInterface: 'Interface',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnColumnCount: 'Column count',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnInputParameters: 'Input parameters',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnInOutParameters: 'Input and output parameters',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnOutputParameters: 'Output parameters',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnResultColumns: 'Result columns',
  /** EXPERIENCE.md:596 */
  explorerSqlColumnReturnValue: 'Return value',
  /** EXPERIENCE.md:596 */
  explorerSqlPartitionsEmpty: 'This table has no partitions.',
  /** EXPERIENCE.md:596 */
  explorerSqlPartitionMappingsEmpty: 'This table has no partition mappings.',
  /** EXPERIENCE.md:596 */
  explorerSqlCachedQueriesEmpty: 'This table has no cached queries this account can run.',
  /** EXPERIENCE.md:596 */
  explorerSqlTableStatementsEmpty: 'No SQL statements reference this table.',
  /** EXPERIENCE.md:596 */
  explorerSqlViewEmpty: 'This view no longer exists.',
  /** EXPERIENCE.md:596 */
  explorerSqlViewFieldsEmpty: 'This view has no fields this account can see.',
  /** EXPERIENCE.md:596 */
  explorerSqlViewStatementsEmpty: 'No SQL statements reference this view.',
  /** EXPERIENCE.md:596 */
  explorerSqlProcedureEmpty: 'This procedure no longer exists.',
  /** EXPERIENCE.md:596 */
  explorerSqlProcedureStatementsEmpty: 'No SQL statements reference this procedure.',
  /** EXPERIENCE.md:596 */
  explorerSqlViewReason: 'Name one view, as Schema.View.',
  /** EXPERIENCE.md:596 */
  explorerSqlProcedureReason: 'Name one procedure, as Schema.Procedure.',
  /** EXPERIENCE.md:596 */
  explorerSqlViewAmbiguousReason: 'That name matches more than one view in this namespace.',
  /** EXPERIENCE.md:596 */
  explorerSqlProcedureAmbiguousReason: 'That name matches more than one procedure in this namespace.',
  /** EXPERIENCE.md:596 */
  explorerSqlViewNotFoundReason: 'This namespace holds no view by that name that this account can see.',
  /** EXPERIENCE.md:596 */
  explorerSqlProcedureNotFoundReason: 'This namespace holds no procedure by that name that this account can see.',
  /** EXPERIENCE.md:596 */
  explorerSqlPartitionsPrompt1: 'Is this table partitioned, and into how many partitions?',
  /** EXPERIENCE.md:596 */
  explorerSqlPartitionsPrompt2: 'How many rows does each partition of this table hold?',
  /** EXPERIENCE.md:596 */
  explorerSqlPartitionsPrompt3: 'Which database does each partition of this table map to?',
  /** EXPERIENCE.md:596 */
  explorerSqlPartitionMappingsPrompt1: 'Which partition mappings does this table have?',
  /** EXPERIENCE.md:596 */
  explorerSqlPartitionMappingsPrompt2: 'Where do this table\'s partition ranges map to?',
  /** EXPERIENCE.md:596 */
  explorerSqlPartitionMappingsPrompt3: 'How large is each partition range of this table?',
  /** EXPERIENCE.md:596 */
  explorerSqlCachedQueriesPrompt1: 'Which cached queries use this table?',
  /** EXPERIENCE.md:596 */
  explorerSqlCachedQueriesPrompt2: 'When was each cached query on this table created?',
  /** EXPERIENCE.md:596 */
  explorerSqlCachedQueriesPrompt3: 'Which of these cached queries are dynamic SQL?',
  /** EXPERIENCE.md:596 */
  explorerSqlTableStatementsPrompt1: 'Which SQL statements use this table?',
  /** EXPERIENCE.md:596 */
  explorerSqlTableStatementsPrompt2: 'Which statements on this table run most often?',
  /** EXPERIENCE.md:596 */
  explorerSqlTableStatementsPrompt3: 'Which statements on this table have a frozen plan?',
  /** EXPERIENCE.md:596 */
  explorerSqlViewPrompt1: 'What does this view select?',
  /** EXPERIENCE.md:596 */
  explorerSqlViewPrompt2: 'Can this view be updated?',
  /** EXPERIENCE.md:596 */
  explorerSqlViewPrompt3: 'Which class projects this view?',
  /** EXPERIENCE.md:596 */
  explorerSqlViewFieldsPrompt1: 'Which columns does this view have?',
  /** EXPERIENCE.md:596 */
  explorerSqlViewFieldsPrompt2: 'What type is each column of this view?',
  /** EXPERIENCE.md:596 */
  explorerSqlViewFieldsPrompt3: 'Which columns of this view are streams?',
  /** EXPERIENCE.md:596 */
  explorerSqlViewStatementsPrompt1: 'Which SQL statements use this view?',
  /** EXPERIENCE.md:596 */
  explorerSqlViewStatementsPrompt2: 'Which statements on this view run most often?',
  /** EXPERIENCE.md:596 */
  explorerSqlViewStatementsPrompt3: 'Where is this view queried from?',
  /** EXPERIENCE.md:596 */
  explorerSqlProcedurePrompt1: 'What does this procedure do?',
  /** EXPERIENCE.md:596 */
  explorerSqlProcedurePrompt2: 'Which parameters does this procedure take?',
  /** EXPERIENCE.md:596 */
  explorerSqlProcedurePrompt3: 'What does this procedure return?',
  /** EXPERIENCE.md:596 */
  explorerSqlProcedureStatementsPrompt1: 'Which SQL statements call this procedure?',
  /** EXPERIENCE.md:596 */
  explorerSqlProcedureStatementsPrompt2: 'How often is this procedure called?',
  /** EXPERIENCE.md:596 */
  explorerSqlProcedureStatementsPrompt3: 'Where is this procedure called from?',
  // Story 18.19: Journal records -- its title and entity noun, Journal file details' View records,
  // the criteria form's heading, labels and option words, Next records, the empty state, the record
  // dialog's title and field labels, and the prompts. Time, Process, Type, In transaction, Database,
  // Value, Search and Close reuse earlier keys.
  /** EXPERIENCE.md:378 */
  journalRecordListLabel: 'Journal records',
  /** EXPERIENCE.md:378 */
  aboutJournalRecord: 'Journal record',
  /** EXPERIENCE.md:378 */
  journalFileDetailsViewRecords: 'View records',
  /** EXPERIENCE.md:378 */
  journalRecordsHeading: 'Records of <file>',
  /** EXPERIENCE.md:378 */
  journalRecordsNext: 'Next records',
  /** EXPERIENCE.md:378 */
  journalRecordListEmpty: 'No records match.',
  /** EXPERIENCE.md:378 */
  journalRecordOffset: 'Offset',
  /** EXPERIENCE.md:378 */
  journalRecordOldestFirst: 'Oldest first',
  /** EXPERIENCE.md:378 */
  journalRecordNewestFirst: 'Newest first',
  /** EXPERIENCE.md:378 */
  journalRecordComparison: 'Comparison',
  /** EXPERIENCE.md:378 */
  journalRecordExtendedType: 'Extended type',
  /** EXPERIENCE.md:378 */
  journalRecordGlobalNode: 'Global node',
  /** EXPERIENCE.md:378 */
  journalRecordMirrorDatabase: 'Mirror database',
  /** EXPERIENCE.md:378 */
  journalRecordOpEquals: 'equals',
  /** EXPERIENCE.md:378 */
  journalRecordOpNotEquals: 'does not equal',
  /** EXPERIENCE.md:378 */
  journalRecordOpSortsAfter: 'sorts after',
  /** EXPERIENCE.md:378 */
  journalRecordOpNotSortsAfter: 'does not sort after',
  /** EXPERIENCE.md:378 */
  journalRecordOpContains: 'contains',
  /** EXPERIENCE.md:378 */
  journalRecordOpNotContains: 'does not contain',
  /** EXPERIENCE.md:378 */
  journalRecordDialogTitle: 'Journal record <offset>',
  /** EXPERIENCE.md:378 */
  journalRecordGlobalReference: 'Global reference',
  /** EXPERIENCE.md:378 */
  journalRecordNewValue: 'New value',
  /** EXPERIENCE.md:378 */
  journalRecordOldValue: 'Old value',
  /** EXPERIENCE.md:378 */
  journalRecordPrevious: 'Previous record',
  /** EXPERIENCE.md:378 */
  journalRecordNext: 'Next record',
  /** EXPERIENCE.md:378 */
  journalRecordListPrompt1: 'Which processes wrote these journal records?',
  /** EXPERIENCE.md:378 */
  journalRecordListPrompt2: 'Which globals changed in these records?',
  /** EXPERIENCE.md:378 */
  journalRecordListPrompt3: 'Are any of these records inside a transaction?',
  /** EXPERIENCE.md:596 */
  explorerSqlStatementsNote: 'Statistics are as of the instance\'s last aggregation, so a recently run statement can read blank.',
  // Story 18.6: License key and License servers -- their titles, License key's twelve field labels
  // beyond License usage's "License units", the authorization-key line, the activate dialog's
  // labels, validity, restart and reduction sentences and consequence, Print and its printed-by
  // line, the license server form's hints, the multi-key consequence (the agent's card line) and
  // the prompts. Name, Address, Port, Load from file, "(none)", Save, Cancel and Delete reuse
  // earlier keys.
  /** EXPERIENCE.md:375 */
  licenseKeyLabel: 'License key',
  /** EXPERIENCE.md:375 */
  licenseKeyLicenseCapacity: 'License capacity',
  /** EXPERIENCE.md:375 */
  licenseKeyCustomerName: 'Customer name',
  /** EXPERIENCE.md:375 */
  licenseKeyOrderNumber: 'Order number',
  /** EXPERIENCE.md:375 */
  licenseKeyProduct: 'Product',
  /** EXPERIENCE.md:375 */
  licenseKeyLicenseType: 'License type',
  /** EXPERIENCE.md:375 */
  licenseKeyServer: 'Key server',
  /** EXPERIENCE.md:375 */
  licenseKeyPlatform: 'Platform',
  /** EXPERIENCE.md:375 */
  licenseKeyCoresLicensed: 'Cores licensed',
  /** EXPERIENCE.md:375 */
  licenseKeyCoresEnforced: 'Cores enforced',
  /** EXPERIENCE.md:375 */
  licenseKeyExpirationDate: 'Expiration date',
  /** EXPERIENCE.md:375 */
  licenseKeyExtendedFeatures: 'Extended features',
  /** EXPERIENCE.md:375 */
  licenseKeyAuthorizedApplications: 'Authorized applications',
  /** EXPERIENCE.md:375 */
  licenseKeyAuthorizationHidden: 'The authorization key is not shown here.',
  /** EXPERIENCE.md:375 */
  licenseKeyEmpty: 'The instance reports no license key.',
  /** EXPERIENCE.md:375 */
  licenseKeyEmptyAgent: 'explain this instance\'s license',
  /** EXPERIENCE.md:375 */
  licenseKeyActivateAction: 'Activate new key',
  /** EXPERIENCE.md:375 */
  licenseKeyActivateTitle: 'Activate a new license key',
  /** EXPERIENCE.md:375 */
  licenseKeyText: 'License key text',
  /** EXPERIENCE.md:375 */
  licenseKeyValidate: 'Validate',
  /** EXPERIENCE.md:375 */
  licenseKeyActivate: 'Activate',
  /** EXPERIENCE.md:375 */
  actionPrint: 'Print',
  /** EXPERIENCE.md:375 */
  licenseKeyValid: 'This key is valid for this instance.',
  /** EXPERIENCE.md:375 */
  licenseKeyRestart: 'Activating this key requires restarting the instance.',
  /** EXPERIENCE.md:375 */
  licenseKeyReductions: 'Activating this key will:',
  /** EXPERIENCE.md:375 */
  licenseKeyReductionCores: 'Lower the licensed cores from <from> to <to>.',
  /** EXPERIENCE.md:375 */
  licenseKeyReductionUsers: 'Lower the license units from <from> to <to>.',
  /** EXPERIENCE.md:375 */
  licenseKeyReductionServer: 'Change the key server type from <from> to <to>.',
  /** EXPERIENCE.md:375 */
  licenseKeyReductionLicenseType: 'Change the license type from <from> to <to>.',
  /** EXPERIENCE.md:375 */
  licenseKeyReductionProduct: 'Lower the product level from <from> to <to>.',
  /** EXPERIENCE.md:375 */
  licenseKeyReductionFeatures: 'Remove these features: <features>.',
  /** EXPERIENCE.md:375 */
  licenseKeyActivateConsequence: 'Activating replaces this instance\'s license key. This cannot be undone here.',
  /** EXPERIENCE.md:375 */
  licenseKeyPrintedBy: 'Printed by <user> on <time>.',
  /** EXPERIENCE.md:375 */
  licenseKeyPrompt1: 'When does this instance\'s license key expire?',
  /** EXPERIENCE.md:375 */
  licenseKeyPrompt2: 'How many cores and license units does this key allow?',
  /** EXPERIENCE.md:375 */
  licenseKeyPrompt3: 'Which features does this license key enable?',
  /** EXPERIENCE.md:375 */
  licenseServerListLabel: 'License servers',
  /** EXPERIENCE.md:375 */
  licenseServerListEmpty: 'No license servers on this instance.',
  /** EXPERIENCE.md:375 */
  licenseServerListEmptyAgent: 'create a license server',
  /** EXPERIENCE.md:375 */
  licenseServerFormRefusedAction: 'change this license server',
  /** EXPERIENCE.md:375 */
  licenseServerKeyDirectory: 'Key directory',
  /** EXPERIENCE.md:375 */
  licenseServerAddressHint: 'Host name or IP address',
  /** EXPERIENCE.md:375 */
  licenseServerKeyDirectoryHint: 'Set on the classic License Servers page.',
  /** EXPERIENCE.md:375 */
  licenseServerMultiKeyConsequence:
    'This instance\'s license key is a multi-server key. Removing a license server it uses can leave it unable to obtain license units.',
  /** EXPERIENCE.md:375 */
  licenseServerListPrompt1: 'Which license servers is this instance configured to use?',
  /** EXPERIENCE.md:375 */
  licenseServerListPrompt2: 'Does this instance\'s license key need a license server?',
  /** EXPERIENCE.md:375 */
  licenseServerListPrompt3: 'Where does this instance ask for its license units?',
  /** EXPERIENCE.md:375 */
  licenseServerFormPrompt1: 'What address and port should this license server use?',
  /** EXPERIENCE.md:375 */
  licenseServerFormPrompt2: 'What does a license server do for this instance?',
  /** EXPERIENCE.md:375 */
  licenseServerFormPrompt3: 'What would deleting this license server change?',
  /** EXPERIENCE.md:479 */
  licenseServerDeleteConsequence:
    'Deleting this license server removes it from this instance\'s configuration. This cannot be undone.',
  /** EXPERIENCE.md:597 */
  explorerSqlQueryLabel: 'SQL query',
  /** EXPERIENCE.md:597 */
  explorerSqlExplainPlan: 'Explain plan',
  /** EXPERIENCE.md:597 */
  explorerSqlPlanHeading: 'Plan',
  /** EXPERIENCE.md:597 */
  explorerSqlValueLabel: 'Value <n>',
  /** EXPERIENCE.md:597 */
  explorerSqlConfirmTitle: 'Run this statement?',
  /** EXPERIENCE.md:597 */
  explorerSqlConfirmDml: 'It changes rows in <tables>, and cannot be undone from OcuPilot.',
  /** EXPERIENCE.md:597 */
  explorerSqlConfirmDdl: 'It changes this namespace\'s schema, and cannot be undone from OcuPilot.',
  /** EXPERIENCE.md:597 */
  explorerSqlConfirmCall: 'It runs a stored procedure, which can change anything this account may change.',
  /** EXPERIENCE.md:597 */
  explorerSqlConfirmOther: 'The instance does not say what this statement changes.',
  /** EXPERIENCE.md:597 */
  explorerSqlRowsCut: '<n> rows are shown; the answer holds more.',
  /** EXPERIENCE.md:597 */
  explorerSqlRowsChanged: '<n> rows changed',
  /** EXPERIENCE.md:597 */
  explorerSqlDone: 'Done',
  /** EXPERIENCE.md:597 */
  explorerSqlStopped: 'Stopped after <s> seconds.',
  /** EXPERIENCE.md:597 */
  explorerSqlStoppedUndone: 'Stopped after <s> seconds; its changes were undone.',
  /** EXPERIENCE.md:597 */
  explorerSqlTakesValues: 'This statement takes <n> values.',
  /** EXPERIENCE.md:597 */
  explorerSqlNoPlan: 'This kind of statement has no plan.',
  /** EXPERIENCE.md:597 */
  explorerSqlCode: 'SQLCODE <code>',
  /** EXPERIENCE.md:597 */
  explorerSqlEmpty: 'Write one SQL statement, then Run.',
  /** EXPERIENCE.md:597 */
  explorerSqlRolledBack: 'The statement left a transaction open, so its changes were undone.',
  /** EXPERIENCE.md:597 */
  explorerSqlInputReason: 'Send one statement of up to 100,000 characters, at most 100 values of up to 32,767 characters each, and Max rows from 1 to 1,000.',
  /** EXPERIENCE.md:597 */
  explorerSqlSessionReason: 'This statement controls a server process (a transaction, lock, option, cursor, namespace or running query) and is not run here.',
  /** EXPERIENCE.md:597 */
  explorerSqlAdministrationReason: 'Users, roles, privileges and databases are changed on Permissions and OS management, where OcuPilot checks each change; this statement is not run here.',
  /** EXPERIENCE.md:597 */
  explorerSqlServerFilesReason: 'This statement reads a server file or another server, which OcuPilot does not let a caller name.',
  /** EXPERIENCE.md:597 */
  explorerSqlPasswordReason: 'A statement that sets a password is not prepared here, because the instance keeps a prepared statement\'s text; set passwords on the Users list in Permissions.',
  /** EXPERIENCE.md:597 */
  explorerSqlReadsReason: 'This statement only reads, so it runs without confirming.',
  /** EXPERIENCE.md:597 */
  explorerSqlParametersReason: 'Give one value for each ? in the statement.',
  /** EXPERIENCE.md:597 */
  explorerSqlUnrecordedReason: 'The instance keeps no record of the tables this statement uses before it runs, so OcuPilot cannot check what it reads or changes and does not run it here; writing SELECT %NORUNTIME may let a query be checked.',
  /** EXPERIENCE.md:597 */
  explorerSqlRefusalOcuPilot: 'This statement reads or changes OcuPilot\'s own tables or code, which OcuPilot does not offer.',
  /** EXPERIENCE.md:597 */
  explorerSqlQueryPrompt1: 'What does this statement\'s plan say about the indices it uses?',
  /** EXPERIENCE.md:597 */
  explorerSqlQueryPrompt2: 'How do I pass a value to a ? in a statement?',
  /** EXPERIENCE.md:597 */
  explorerSqlQueryPrompt3: 'Why was my statement refused here?',
  // Story 19.15: SQL query's Run in background, its section's heading and two status lines, and the
  // background run's five refusals. Its ended status reuses 19.6's lines and its Cancel "Cancel".
  /** EXPERIENCE.md:597 */
  explorerSqlRunInBackground: 'Run in background',
  /** EXPERIENCE.md:597 */
  explorerSqlBackgroundHeading: 'Background run',
  /** EXPERIENCE.md:597 */
  explorerSqlBackgroundRunning: 'Running in the background.',
  /** EXPERIENCE.md:597 */
  explorerSqlBackgroundCanceled: 'Canceled.',
  /** EXPERIENCE.md:597 */
  explorerSqlBackgroundQueryOnlyReason: 'Only a query runs in the background; use Run for a statement that changes something.',
  /** EXPERIENCE.md:597 */
  explorerSqlBackgroundBusyReason: 'A query you started is already running in the background; cancel it or wait for it to end.',
  /** EXPERIENCE.md:597 */
  explorerSqlBackgroundFullReason: 'As many background queries as this instance allows are running; try again when one ends.',
  /** EXPERIENCE.md:597 */
  explorerSqlBackgroundNotFoundReason: 'No background run of yours has this id; an ended run is kept for 15 minutes.',
  /** EXPERIENCE.md:597 */
  explorerSqlBackgroundLostReason: 'The background run ended without an answer; run it again.',
  // Story 19.7: Data browser's title, its tree, filter row, pager and grid labels, its status and
  // empty lines, its two refusals and its prompts. Refresh, the yes and no words, the tree's "View"
  // marker and the stopped and SQLCODE lines are reused.
  /** EXPERIENCE.md:598 */
  explorerSqlDataLabel: 'Data browser',
  /** EXPERIENCE.md:598 */
  explorerSqlDataTree: 'Tables and views',
  /** EXPERIENCE.md:598 */
  explorerSqlDataFilters: 'Column filters',
  /** EXPERIENCE.md:598 */
  explorerSqlDataFilterColumn: 'Filter <column>',
  /** EXPERIENCE.md:598 */
  explorerSqlDataClearFilters: 'Clear filters',
  /** EXPERIENCE.md:598 */
  explorerSqlDataFirstPage: 'First page',
  /** EXPERIENCE.md:598 */
  explorerSqlDataPreviousPage: 'Previous page',
  /** EXPERIENCE.md:598 */
  explorerSqlDataNextPage: 'Next page',
  /** EXPERIENCE.md:598 */
  explorerSqlDataLastPage: 'Last page',
  /** EXPERIENCE.md:598 */
  explorerSqlDataPage: 'Page',
  /** EXPERIENCE.md:598 */
  explorerSqlDataOfPages: 'of <n>',
  /** EXPERIENCE.md:598 */
  explorerSqlDataRowsPerPage: 'Rows per page',
  /** EXPERIENCE.md:598 */
  explorerSqlDataNull: 'NULL',
  /** EXPERIENCE.md:598 */
  explorerSqlDataKeyColumn: 'Key column',
  /** EXPERIENCE.md:598 */
  explorerSqlDataPick: 'Pick a table or view in the tree to see its rows.',
  /** EXPERIENCE.md:598 */
  explorerSqlDataSchemaEmpty: 'This schema holds no table or view this account can see.',
  /** EXPERIENCE.md:598 */
  explorerSqlDataTreeCut: 'Only the first 1,000 are listed.',
  /** EXPERIENCE.md:598 */
  explorerSqlDataFilterHint: 'Filters match the whole value: * stands for any run of characters and ? for one character.',
  /** EXPERIENCE.md:598 */
  explorerSqlDataRowsOf: 'Rows <first>\u2013<last> of <total>',
  /** EXPERIENCE.md:598 */
  explorerSqlDataRows: 'Rows <first>\u2013<last>',
  /** EXPERIENCE.md:598 */
  explorerSqlDataNoRows: 'No rows.',
  /** EXPERIENCE.md:598 */
  explorerSqlDataNoMatch: 'No rows match the filters.',
  /** EXPERIENCE.md:598 */
  explorerSqlDataSortedAscending: 'Sorted by <column>, ascending.',
  /** EXPERIENCE.md:598 */
  explorerSqlDataSortedDescending: 'Sorted by <column>, descending.',
  /** EXPERIENCE.md:598 */
  explorerSqlDataSortCleared: 'Sort cleared.',
  /** EXPERIENCE.md:598 */
  explorerSqlDataPageRange: 'Enter a page from 1 to <n>.',
  /** EXPERIENCE.md:598 */
  explorerSqlDataInputReason: 'Name a table or view as the tree shows it; filters of up to 1,000 characters on its listed columns that are not streams or binary; a sort on one such column, ascending or descending; an offset from 0; and a page size of 50, 100, 250 or 500.',
  /** EXPERIENCE.md:598 */
  explorerSqlDataNotFoundReason: 'This namespace holds no table or view by that name that this account can see.',
  /** EXPERIENCE.md:598 */
  explorerSqlDataPrompt1: 'How do I filter rows with * and ? here?',
  /** EXPERIENCE.md:598 */
  explorerSqlDataPrompt2: 'Why does this table show fewer columns than its class defines?',
  /** EXPERIENCE.md:598 */
  explorerSqlDataPrompt3: 'Which column is this table\'s key, and how is it found?',
  // Story 18.20: ECP data servers, OS management's seventeenth entry, its form, its Change status
  // dialog, its delete body and the delete's impact phrases.
  /** EXPERIENCE.md:375 */
  ecpDataServerListLabel: 'ECP data servers',
  /** EXPERIENCE.md:375 */
  aboutEcpDataServer: 'ECP data server',
  /** EXPERIENCE.md:375 */
  ecpDataServerListEmpty: 'No ECP data servers on this instance.',
  /** EXPERIENCE.md:375 */
  ecpDataServerListEmptyAgent: 'create an ECP data server',
  /** EXPERIENCE.md:375 */
  ecpDataServerFormRefusedAction: 'change this ECP data server',
  /** EXPERIENCE.md:375 */
  ecpDataServerMirrorConnection: 'Mirror connection',
  /** EXPERIENCE.md:375 */
  ecpDataServerUseSsl: 'Use SSL/TLS',
  /** EXPERIENCE.md:375 */
  ecpDataServerBatchMode: 'Batch mode',
  /** EXPERIENCE.md:375 */
  ecpDataServerMirrorHint: 'Connects to the mirror\'s primary. Once set, it cannot be turned off here.',
  /** EXPERIENCE.md:375 */
  ecpDataServerSslHint: 'Uses the %ECPClient SSL/TLS configuration.',
  /** EXPERIENCE.md:375 */
  ecpDataServerChangeStatus: 'Change status',
  /** EXPERIENCE.md:375 */
  ecpDataServerStatusTitle: 'Change the status of <name>',
  /** EXPERIENCE.md:375 */
  ecpDataServerCurrentStatus: 'Current status: <status>',
  /** EXPERIENCE.md:375 */
  ecpDataServerNotConnected: 'Not connected',
  /** EXPERIENCE.md:375 */
  ecpDataServerCurrentReason: 'This is its current status.',
  /** EXPERIENCE.md:375 */
  ecpLicenseRefusal: 'This instance\'s license does not include ECP.',
  /** EXPERIENCE.md:375 */
  ecpDataServerDisconnectConsequence:
    'Setting a data server to Not connected or Disabled sends an error to every application awaiting its replies, purges its cached blocks, releases its locks and rolls back its transactions.',
  /** EXPERIENCE.md:375 */
  ecpDataServerConnectConsequence: 'Setting this data server to Normal connects this instance to it.',
  /** EXPERIENCE.md:375 */
  ecpDataServerStatusCaveat: 'Each status is what the instance reported when this list was read.',
  /** EXPERIENCE.md:375 */
  ecpDataServerListPrompt1: 'Which ECP data servers is this instance configured to connect to?',
  /** EXPERIENCE.md:375 */
  ecpDataServerListPrompt2: 'What does each ECP data server\'s status mean?',
  /** EXPERIENCE.md:375 */
  ecpDataServerListPrompt3: 'Which remote databases use each ECP data server?',
  /** EXPERIENCE.md:375 */
  ecpDataServerFormPrompt1: 'What address and port should this ECP data server use?',
  /** EXPERIENCE.md:375 */
  ecpDataServerFormPrompt2: 'When should an ECP data server use a mirror connection?',
  /** EXPERIENCE.md:375 */
  ecpDataServerFormPrompt3: 'What does batch mode change for an ECP data server?',
  /** EXPERIENCE.md:479 */
  ecpDataServerDeleteConsequence:
    'Deleting this ECP data server removes it from this instance\'s configuration. This cannot be undone.',
  /** EXPERIENCE.md:577 */
  impactRemoteDatabasesUse: '<n> remote databases use it and must be deleted or moved first: <names>',
  /** EXPERIENCE.md:577 */
  impactRemoteDatabasesUseOne: '1 remote database uses it and must be deleted or moved first: <names>',
  /** EXPERIENCE.md:577 */
  impactRemoteDatabasesUseNone: 'no remote database uses it',
  /** EXPERIENCE.md:577 */
  impactRemoteDatabasesUseUnchecked: 'which remote databases use it was not checked',
  // Story 19.8: Data browser's row actions, the staged and deleted marks and the status column, the
  // save dialog, the editing, staging, undo, discard and save lines, the read-only line, the cap and
  // the namespace discard, the editors' refusals and hints, each row's outcome, and the save's two
  // refusals. "Changed", "Saved", "Change", the SQLCODE and stopped lines, the yes and no words,
  // "NULL" and "Leave without saving?" are reused.
  /** EXPERIENCE.md:599 */
  explorerSqlDataAddRow: 'Add row',
  /** EXPERIENCE.md:599 */
  explorerSqlDataDuplicateRow: 'Duplicate row',
  /** EXPERIENCE.md:599 */
  explorerSqlDataDeleteRow: 'Delete row',
  /** EXPERIENCE.md:599 */
  explorerSqlDataRestoreRow: 'Restore row',
  /** EXPERIENCE.md:599 */
  explorerSqlDataSaveChanges: 'Save changes (<n>)',
  /** EXPERIENCE.md:599 */
  explorerSqlDataDiscard: 'Discard changes',
  /** EXPERIENCE.md:599 */
  explorerSqlDataNew: 'New',
  /** EXPERIENCE.md:599 */
  explorerSqlDataDeleted: 'Deleted',
  /** EXPERIENCE.md:599 */
  explorerSqlDataSaveTitle: 'Save changes to <table>?',
  /** EXPERIENCE.md:599 */
  explorerSqlDataSaveConsequence: '<u> rows change, <i> are added and <d> are deleted in <table>, and this cannot be undone from OcuPilot.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataEditing: 'Editing <column>.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataWaiting: '<n> changes waiting to be saved.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataUndone: 'Change undone.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataDiscarded: '<n> changes discarded.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataSavedSummary: 'Saved <a> of <n> changes; <b> rolled back.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataReadOnly: 'Rows here are read-only: a view, or a table without a key this account can see, is not changed here.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataCap: 'A save carries at most 100 rows; save or discard some first.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataScopeDiscarded: 'Changes were discarded because the namespace changed.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataNotNull: 'This column cannot be NULL.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataNotEditable: 'This cell cannot be edited here.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataOutcomeChanged: 'Not saved: the row changed or was removed after it was read.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataOutcomeRefused: 'Not saved: this account may not make this change.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataOutcomeGone: 'Already removed.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataOutcomeSkipped: 'Not run: the save stopped first.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataHintInteger: 'Enter a whole number.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataHintNumber: 'Enter a number.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataHintDate: 'Enter a date such as 2026-10-04.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataHintTime: 'Enter a time such as 14:30:00.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataHintTimestamp: 'Enter a date and time such as 2026-10-04 14:30:00.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataChangesReason: 'Name each row\'s key, and change only listed columns that are not keys, identities, computed, streams or binary.',
  /** EXPERIENCE.md:599 */
  explorerSqlDataReadOnlyReason: 'This is a view, or a table without a key this account can see, so its rows are not changed here.',
  /** EXPERIENCE.md:375 */
  ecpSettingsLabel: 'ECP settings',
  /** EXPERIENCE.md:375 */
  ecpAppServersLabel: 'ECP application servers',
  /** EXPERIENCE.md:375 */
  ecpSslConnectionsLabel: 'SSL/TLS authorizations',
  /** EXPERIENCE.md:375 */
  ecpSslConnectionEntity: 'ECP SSL/TLS authorization',
  /** EXPERIENCE.md:375 */
  ecpSettingsAppServerLegend: 'This instance as an ECP application server',
  /** EXPERIENCE.md:375 */
  ecpSettingsDataServerLegend: 'This instance as an ECP data server',
  /** EXPERIENCE.md:375 */
  ecpSettingsMaxServers: 'Maximum number of data servers',
  /** EXPERIENCE.md:375 */
  ecpSettingsReconnectDuration: 'Time to wait for recovery (seconds)',
  /** EXPERIENCE.md:375 */
  ecpSettingsReconnectInterval: 'Time between reconnections (seconds)',
  /** EXPERIENCE.md:375 */
  ecpSettingsMaxServerConn: 'Maximum number of application servers',
  /** EXPERIENCE.md:375 */
  ecpSettingsTroubleDuration: 'Time interval for Troubled state (seconds)',
  /** EXPERIENCE.md:375 */
  ecpSettingsSslSupport: 'ECP SSL/TLS support',
  /** EXPERIENCE.md:375 */
  ecpSettingsRestart:
    'A changed maximum number of application servers takes effect only after the instance restarts.',
  /** EXPERIENCE.md:375 */
  ecpSettingsServerSsl: 'Create and enable the %ECPServer SSL/TLS configuration before using SSL/TLS.',
  /** EXPERIENCE.md:375 */
  ecpSettingsCountRange: 'Enter a whole number from 0 to 254.',
  /** EXPERIENCE.md:375 */
  ecpSettingsRecoveryRange: 'Enter a whole number of seconds from 10 to 65535.',
  /** EXPERIENCE.md:375 */
  ecpSettingsIntervalRange: 'Enter a whole number of seconds from 1 to 60.',
  /** EXPERIENCE.md:375 */
  ecpSettingsTroubleRange: 'Enter a whole number of seconds from 20 to 65535.',
  /** EXPERIENCE.md:375 */
  ecpSettingsSslChoice: 'Choose Disabled, Enabled or Required.',
  /** EXPERIENCE.md:375 */
  ecpSettingsServersBelow:
    'This instance defines more ECP data servers than that. Delete one first, or enter a larger number.',
  /** EXPERIENCE.md:375 */
  ecpSettingsRefusedAction: 'change the ECP settings',
  /** EXPERIENCE.md:375 */
  ecpClientIp: 'Client IP',
  /** EXPERIENCE.md:375 */
  ecpSslComputerName: 'SSL computer name',
  /** EXPERIENCE.md:375 */
  ecpAppServerListEmpty: 'No application servers are connected to this instance.',
  /** EXPERIENCE.md:375 */
  ecpSslConnectionListEmpty: 'No SSL/TLS authorizations on this instance.',
  /** EXPERIENCE.md:375 */
  ecpSslConnectionListEmptyAgent: 'explain how an ECP application server is authorized',
  /** EXPERIENCE.md:375 */
  ecpSslAuthorize: 'Authorize',
  /** EXPERIENCE.md:375 */
  ecpSslReject: 'Reject',
  /** EXPERIENCE.md:375 */
  ecpSslAuthorizeConsequence:
    'Authorizing lets the application server that presents this certificate connect to this instance over ECP.',
  /** EXPERIENCE.md:375 */
  ecpSslRejectConsequence: 'Rejecting refuses this application server\'s pending connection.',
  /** EXPERIENCE.md:375 */
  ecpSslRefusalNotPending: 'This application server is not waiting for authorization.',
  /** EXPERIENCE.md:375 */
  ecpSslRefusalNotAuthorized: 'This application server is not authorized.',
  /** EXPERIENCE.md:375 */
  ecpSettingsPrompt1: 'What do the ECP settings on this instance control?',
  /** EXPERIENCE.md:375 */
  ecpSettingsPrompt2: 'When does a changed maximum number of application servers take effect?',
  /** EXPERIENCE.md:375 */
  ecpSettingsPrompt3: 'What does ECP SSL/TLS support need before it can be enabled?',
  /** EXPERIENCE.md:375 */
  ecpAppServersPrompt1: 'Which ECP application servers are connected to this instance?',
  /** EXPERIENCE.md:375 */
  ecpAppServersPrompt2: 'What does each application server status mean?',
  /** EXPERIENCE.md:375 */
  ecpAppServersPrompt3: 'How does this instance act as an ECP data server?',
  /** EXPERIENCE.md:375 */
  ecpSslConnectionsPrompt1: 'Which ECP application servers are authorized to connect over SSL/TLS?',
  /** EXPERIENCE.md:375 */
  ecpSslConnectionsPrompt2: 'What happens when I authorize an ECP application server?',
  /** EXPERIENCE.md:375 */
  ecpSslConnectionsPrompt3: 'What does deleting an SSL/TLS authorization change?',
  /** EXPERIENCE.md:479 */
  ecpSslConnectionDeleteConsequence:
    'Deleting this authorization means the application server that presents this certificate must be authorized again the next time it connects. Its current connection is not affected. This cannot be undone.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileLabel: 'Encryption key files',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileFormLabel: 'Create encryption key file',
  /** EXPERIENCE.md:364 */
  aboutEncryptionKeyFile: 'Encryption key file',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAdminsTitle: 'Administrators in this key file',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileKeysTitle: 'Encryption keys in this key file',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileColumnAdmin: 'Administrator',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileColumnId: 'Key ID',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileColumnKeyLen: 'Key length (bits)',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileCreateAction: 'Create key file',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAddAdminAction: 'Add administrator',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAddKeyAction: 'Add key',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAddAdminTitle: 'Add an administrator',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAddKeyTitle: 'Add an encryption key',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileExistingAdmin: 'Existing administrator name',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileExistingPassword: 'Existing administrator password',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileNewAdmin: 'New administrator name',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAdminName: 'Administrator name',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileCipherLevel: 'Cipher security level',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileCipher128: '128-bit',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileCipher192: '192-bit',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileCipher256: '256-bit',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileKeyDescription: 'Key description',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAdminNameHint: 'The key file\'s first administrator. It defaults to your user name.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFilePasswordHint: 'Keep a written record of this password in a secure place.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileNewKeyId: 'New encryption key ID: <id>',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileNotActivated: 'This key has not been activated.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileRecommendAdmin: 'Add an emergency recovery administrator to this key file.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileRecommendBackup:
    'Make a backup copy of the key file and keep it apart from this instance.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileRecommendStore:
    'Store the copy with a written record of the recovery password in a secure place.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileKeysEmpty: 'Open a key file to see its keys.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAdminsEmpty: 'Open a key file to see its administrators.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileEmptyAgent: 'explain what an encryption key file holds',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileCreateRefusedAction: 'create an encryption key file',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileValidation: 'The key file request was refused.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileDirectory: 'Choose a folder that already exists for the key file.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileKeyLen: 'Choose 128, 192 or 256 bits.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAdminNameRule: 'Enter an administrator name of up to 50 characters.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFilePasswordRule: 'Enter a password of at least 3 characters.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileCredentials: 'That administrator name and password do not open this key file.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileUnreadable: 'This file is not an encryption key file.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileNewKeyConsequence:
    'The new key is unique: no existing encrypted database or file can use it. If every key file containing it is lost, all data encrypted with it is permanently inaccessible. Make a backup copy of the key file.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileRemoveKeyLoss:
    'If this is the only key file containing this key, all data encrypted with this key will be permanently inaccessible.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAdminTaken: 'This key file already has an administrator of that name.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAdminLast: 'A key file keeps at least one administrator.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAdminAbsent: 'This administrator is not in this key file.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileKeyAbsent: 'This key is not in this key file.',
  /** EXPERIENCE.md:364 */
  keyRefusalOcuPilot:
    'OcuPilot or the instance itself depends on data this key encrypts, so it is not removed from a key file here.',
  /** EXPERIENCE.md:364 */
  encryptionKeyFilePrompt1: 'What does an encryption key file hold?',
  /** EXPERIENCE.md:364 */
  encryptionKeyFilePrompt2: 'What happens if I remove the only copy of a key?',
  /** EXPERIENCE.md:364 */
  encryptionKeyFilePrompt3: 'How do I add a key to an existing key file?',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAdminsPrompt1: 'Who can open this encryption key file?',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAdminsPrompt2: 'Why should a key file have more than one administrator?',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileAdminsPrompt3: 'What does removing a key file administrator change?',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileFormPrompt1: 'Where should I keep a new encryption key file?',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileFormPrompt2: 'Which cipher security level should I choose?',
  /** EXPERIENCE.md:364 */
  encryptionKeyFileFormPrompt3: 'What should I do with a key file after I create it?',
  /** EXPERIENCE.md:490 */
  encryptionKeyFileRemoveAdminConsequence:
    'Removing this administrator means its name and password no longer open this key file. This cannot be undone.',
  /** EXPERIENCE.md:490 */
  encryptionKeyFileRemoveKeyConsequence:
    'If this is the only key file containing this key, all data encrypted with this key will be permanently inaccessible. This cannot be undone.',
  // Story 19.16: Data browser's tab strip, Close tab and its line, the tab cap, Go to row with its
  // field, Go, its range line and its no-row line, the export line, the Keyboard shortcuts dialog's
  // title, scope note and the labels and keys it lists. "Download CSV", "Add row", "Duplicate row",
  // "Delete row", "<n> changes waiting to be saved.", "Leave without saving?", "Confirm", "Cancel",
  // "Close" and the namespace discard line are reused.
  /** EXPERIENCE.md:600 */
  explorerSqlDataOpenTables: 'Open tables',
  /** EXPERIENCE.md:600 */
  explorerSqlDataCloseTab: 'Close tab',
  /** EXPERIENCE.md:600 */
  explorerSqlDataGoToRow: 'Go to row',
  /** EXPERIENCE.md:600 */
  explorerSqlDataRowNumber: 'Row number',
  /** EXPERIENCE.md:600 */
  explorerSqlDataGo: 'Go',
  /** EXPERIENCE.md:600 */
  explorerSqlDataShortcuts: 'Keyboard shortcuts',
  /** EXPERIENCE.md:600 */
  explorerSqlDataSaveShortcut: 'Save changes',
  /** EXPERIENCE.md:600 */
  explorerSqlDataPageShortcut: 'Next or previous page',
  /** EXPERIENCE.md:600 */
  explorerSqlDataTabShortcut: 'Next or previous tab',
  /** EXPERIENCE.md:600 */
  explorerSqlDataTabClosed: '<table> closed.',
  /** EXPERIENCE.md:600 */
  explorerSqlDataTabCap: 'At most <n> tables can be open; close one first.',
  /** EXPERIENCE.md:600 */
  explorerSqlDataRowRange: 'Enter a row from 1 to <n>.',
  /** EXPERIENCE.md:600 */
  explorerSqlDataNoRow: 'No row <n> here.',
  /** EXPERIENCE.md:600 */
  explorerSqlDataExported: 'Saved rows <first>\u2013<last> to <file>, as the instance read them.',
  /** EXPERIENCE.md:600 */
  explorerSqlDataShortcutsScope: 'These work while focus is in Data browser and no dialog or editor is open.',
  /** EXPERIENCE.md:600 */
  explorerSqlDataKeysHelp: 'Ctrl/Cmd+/',
  /** EXPERIENCE.md:600 */
  explorerSqlDataKeysSave: 'Ctrl/Cmd+S',
  /** EXPERIENCE.md:600 */
  explorerSqlDataKeysGoToRow: 'Ctrl/Cmd+G',
  /** EXPERIENCE.md:600 */
  explorerSqlDataKeysExport: 'Ctrl/Cmd+E',
  /** EXPERIENCE.md:600 */
  explorerSqlDataKeysAddRow: 'Alt/Option+Shift+N',
  /** EXPERIENCE.md:600 */
  explorerSqlDataKeysDuplicateRow: 'Alt/Option+Shift+D',
  /** EXPERIENCE.md:600 */
  explorerSqlDataKeysDeleteRow: 'Alt/Option+Shift+Delete or Backspace',
  /** EXPERIENCE.md:600 */
  explorerSqlDataKeysPage: 'Alt/Option+PageDown or PageUp',
  /** EXPERIENCE.md:600 */
  explorerSqlDataKeysTab: 'Alt/Option+Shift+PageDown or PageUp',
  /** EXPERIENCE.md:600 */
  explorerSqlDataKeysCloseTab: 'Alt/Option+Shift+W, or Delete on a tab',
  /** EXPERIENCE.md:601 */
  explorerViewClassReference: 'Class reference',
  /** EXPERIENCE.md:601 */
  explorerClassReferenceTitle: 'Class reference for <class>',
  /** EXPERIENCE.md:601 */
  explorerClassReferenceNote: 'This is the instance\'s own class reference for <class>, shown with your browser\'s sign-in to the instance. Links inside it do not open here.',
  /** EXPERIENCE.md:601 */
  explorerClassReferenceRestored: 'That link does not open here; the class reference shows <class> again.',
} as const;

/**
 * One canonical string by the key a screen descriptor names, or `''` for a key this source
 * does not hold.
 *
 * A descriptor's `labelKey` is data read out of a generated mirror, so it reaches the client as
 * a `string` rather than as one of `STRINGS`' own literal keys and cannot be a property access.
 * Returning `''` rather than throwing is deliberate: a descriptor naming a key that does not
 * exist is caught by `ui/tools/screen-mirror.test.mjs` against this source, where the file and
 * the key can both be named -- not at render time, where the only thing to do about it is
 * blank the label.
 */
export function stringFor(key: string): string {
  const table: Record<string, string> = STRINGS;
  return Object.prototype.hasOwnProperty.call(table, key) ? table[key] : '';
}
