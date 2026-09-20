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
  auditingOffBanner: 'Agent writes are not being marked. Auditing is off on this instance.',
  /** EXPERIENCE.md:258 */
  auditingConfigurationLink: 'Auditing configuration',
  /** EXPERIENCE.md:258 */
  auditingTurnOnAction: 'Turn auditing on',
  /** EXPERIENCE.md:259 */
  proposalTargetChanged: 'target changed, re-propose',
  /** EXPERIENCE.md:260 */
  contextChipLeavesInstance: 'leaves the instance',
  /** EXPERIENCE.md:260 */
  contextChipSentToHost: 'Screen context is sent to <host>',
  /** EXPERIENCE.md:261 */
  contextChipScreenSegment: 'Users, HSCUSTOM \u00b7 6 rows',
  /** EXPERIENCE.md:262 */
  contextChipSharingOff: 'Screen context off \u2014 nothing from this screen is sent.',
  /** EXPERIENCE.md:263 */
  connectivityInstanceUnreachable: 'instance unreachable',
  /** EXPERIENCE.md:263 */
  connectivityRequestRefused: 'request refused',
  /** EXPERIENCE.md:264 */
  faultAbsentEntity: '<name> is no longer present on this instance. Return to the list to see what is there now.',
  /** EXPERIENCE.md:265 */
  statusConnectionSigningIn: 'Signing in\u2026',
  /** EXPERIENCE.md:265 */
  statusConnectionConnected: 'Connected',
  /** EXPERIENCE.md:265 */
  statusConnectionRetrying: 'Instance unreachable \u2014 retrying',
  /** EXPERIENCE.md:265 */
  statusConnectionSigningInAgain: 'Signing in again\u2026',
  /** EXPERIENCE.md:266 */
  statusSegmentServer: 'Server',
  /** EXPERIENCE.md:266 */
  statusSegmentInstance: 'Instance',
  /** EXPERIENCE.md:266 */
  statusSegmentLicensedTo: 'Licensed to',
  /** EXPERIENCE.md:267 */
  agentExplainScreenAction: 'Explain this screen',
  /** EXPERIENCE.md:268 */
  actionTestConnection: 'Test connection',
  /** EXPERIENCE.md:268 */
  actionConfirm: 'Confirm',
  /** EXPERIENCE.md:268 */
  actionCancel: 'Cancel',
  /** EXPERIENCE.md:268 */
  actionSave: 'Save',
  /** EXPERIENCE.md:268 */
  actionResume: 'Resume',
  /** EXPERIENCE.md:268 */
  actionRun: 'Run',
  /** EXPERIENCE.md:268 */
  actionSuspend: 'Suspend',
  /** EXPERIENCE.md:268 */
  actionDelete: 'Delete',
  /** EXPERIENCE.md:268 */
  actionSend: 'Send',
  /** EXPERIENCE.md:268 */
  actionStop: 'Stop',
  /** EXPERIENCE.md:268 */
  actionNewConversation: 'New conversation',
  /** EXPERIENCE.md:268 */
  actionRepropose: 'Re-propose',
  /** EXPERIENCE.md:268 */
  actionSignOut: 'Sign out',
  /** EXPERIENCE.md:268 */
  actionSignIn: 'Sign in',
  /** EXPERIENCE.md:268 */
  actionRetry: 'Retry',
  /** EXPERIENCE.md:268 */
  actionOpenMessagesLog: 'Open messages.log',
  /** EXPERIENCE.md:268 */
  actionRefresh: 'Refresh',
  /** EXPERIENCE.md:269 */
  proposalRationaleHeading: 'Agent\'s rationale',
  /** EXPERIENCE.md:269 */
  proposalExpectedImpactHeading: 'Expected impact',
  /** EXPERIENCE.md:270 */
  proposalReverseLabel: 'Reverse:',
  /** EXPERIENCE.md:271 */
  proposalCountdownLabel: 'Expires in m:ss',
  /** EXPERIENCE.md:271 */
  proposalCountdownTooltip: 'Proposals expire so a stale diff is never applied.',
  /** EXPERIENCE.md:271 */
  proposalCountdownAnnouncement: 'One minute left to confirm',
  /** EXPERIENCE.md:272 */
  proposalFooterConfirmHint: 'Confirm here; sending a message cancels this proposal',
  /** EXPERIENCE.md:272 */
  proposalFooterRunsAs: 'Runs as <user name>, with your privileges.',
  /** EXPERIENCE.md:273 */
  proposalConfirmSentence: 'Press Confirm on the card to apply it.',
  /** EXPERIENCE.md:274 */
  proposalStatusConfirmedBy: 'Confirmed by <user name> \u00b7 hh:mm:ss',
  /** EXPERIENCE.md:274 */
  proposalStatusCanceledByYou: 'Canceled \u2014 by you',
  /** EXPERIENCE.md:274 */
  proposalStatusCanceledByMessage: 'Canceled \u2014 by your message',
  /** EXPERIENCE.md:274 */
  proposalStatusCanceledSibling: 'Canceled \u2014 a sibling proposal was confirmed',
  /** EXPERIENCE.md:274 */
  proposalStatusExpired: 'Expired',
  /** EXPERIENCE.md:274 */
  proposalStatusAgentSwitchedOff: 'The agent is switched off',
  /** EXPERIENCE.md:275 */
  proposalUnchangedFieldsDisclosure: 'N unchanged fields',
  /** EXPERIENCE.md:276 */
  proposalExampleCardTitle: 'Example \u2014 this is what a proposal looks like',
  /** EXPERIENCE.md:277 */
  agentIdleGreeting: 'I\'m ready. Ask about this screen, or try one of these.',
  /** EXPERIENCE.md:277 */
  agentIdleSelectionHint: 'Click a row to select it; click its name to open it.',
  /** EXPERIENCE.md:278 */
  toolCallStoppedByYou: 'Stopped by you at <step>',
  /** EXPERIENCE.md:279 */
  agentTurnStoppedBanner: 'The turn stopped at <step>: <reason>.',
  /** EXPERIENCE.md:352 */
  agentTurnStoppedNoStepBanner: 'The turn stopped: <reason>.',
  /** EXPERIENCE.md:280 */
  agentTurnLockBanner: 'A turn is in progress. Wait for it to finish before sending another message.',
  // Story 4.5's four: from the tool-call-card Component Patterns row (:378) and the panel's
  // Busy and header rows (:424, :511), each authorized by its own targeted extractor in
  // `ui/tools/strings.test.mjs` rather than by being added to REQUIRED_ALONGSIDE_TABLE.
  toolCallStatusDone: 'done',
  toolCallStatusFailed: 'failed \u2014 <reason>',
  agentComposerLockedReason: 'A turn is in progress',
  agentNewConversationLockedReason: 'Stop the turn first',
  /** EXPERIENCE.md:351 */
  toolCallReadResultLine: '<n> rows returned \u00b7 <m> sent',
  /** EXPERIENCE.md:281 */
  agentNavigationAnnouncement: 'I\'m opening <screen> for <entity> \u2014 use Back to return.',
  /** EXPERIENCE.md:281 */
  agentNavigationAnnouncementNoEntity: 'I\'m opening <screen> \u2014 use Back to return.',
  /** EXPERIENCE.md:281 */
  agentNavigationHeadingAnnouncement: '<title> \u2014 opened by the agent; Back returns',
  /** EXPERIENCE.md:282 */
  agentAuditFollowUpQuestion: 'Shall I show you the audit entry?',
  /** EXPERIENCE.md:283 */
  agentGateReminderBanner: 'No agent definition is enabled. Configure one in Agent co-pilot \u203a Definitions.',
  /** EXPERIENCE.md:284 */
  agentGateLandingBanner: 'OcuPilot needs one agent definition before the panel can help. Anthropic is selected \u2014 paste a key and press Test connection. You can skip this and browse.',
  /** EXPERIENCE.md:285 */
  agentGateEmptyState: 'The agent isn\'t configured yet. An OcuPilot administrator can enable a definition in Agent co-pilot \u203a Definitions.',
  /** EXPERIENCE.md:286 */
  agentReadOnlyEnforcedBanner: 'Read-only mode is enforced on this instance. The agent can read and explain, not change.',
  /** EXPERIENCE.md:287 */
  agentKillSwitchBanner: 'The agent is switched off for <everyone / you>: <reason>.',
  /** EXPERIENCE.md:288 */
  statusReadOnlyOff: 'Read-only: off',
  /** EXPERIENCE.md:288 */
  statusReadOnlyEnforced: 'Read-only: on \u2014 enforced on this instance',
  /** EXPERIENCE.md:288 */
  statusReadOnlyForYou: 'Read-only: on \u2014 for you',
  /** EXPERIENCE.md:288 */
  statusReadOnlyByDefinition: 'Read-only: on \u2014 by the definition',
  /** EXPERIENCE.md:289 */
  tableChangeToastLink: 'Open in <screen>',
  /** EXPERIENCE.md:290 */
  statusAutoRefreshOff: 'Auto-refresh: off',
  /** EXPERIENCE.md:290 */
  statusAutoRefreshOn: 'Auto-refresh: every <n> s',
  /** EXPERIENCE.md:290 */
  statusAutoRefreshPaused: 'Auto-refresh paused \u2014 a proposal is awaiting confirmation',
  /** EXPERIENCE.md:290 */
  statusLastUpdate: 'Last update hh:mm:ss',
  /** EXPERIENCE.md:291 */
  commandBarFilterLabel: 'Filter rows',
  /** EXPERIENCE.md:292 */
  tableChangedTag: 'Changed',
  /** EXPERIENCE.md:293 */
  privilegeRequiresResource: 'Requires <resource>',
  /** EXPERIENCE.md:293 */
  privilegeSelectRowFirst: 'Select a row first',
  /** EXPERIENCE.md:294 */
  privilegeDeniedScreen: 'You need <resource> to open <screen>.',
  /** EXPERIENCE.md:295 */
  privilegeDeniedAction: 'You need <resource> to <action>.',
  /** EXPERIENCE.md:296 */
  navPrivilegeMapUnread: 'Your privileges couldn\'t be read, so screens you can\'t open may be listed. Retry to check again.',
  /** EXPERIENCE.md:297 */
  formTypedNameConfirm: 'Type <name> to confirm',
  /** EXPERIENCE.md:297 */
  formTypedNameMismatch: 'Does not match',
  /** EXPERIENCE.md:298 */
  formSecretStored: 'Stored. Enter a new value to replace it.',
  /** EXPERIENCE.md:299 */
  formTestConnectionResult: 'Connected. Reply: <the model\'s first words>',
  /** EXPERIENCE.md:299 */
  formTestConnectionFailure: 'The provider refused the request. Check the key and try again. Provider said: <text>',
  /** EXPERIENCE.md:299 */
  formSavedPendingTest: 'Saved \u2014 disabled until Test connection passes.',
  /** EXPERIENCE.md:300 */
  formSaved: 'Saved',
  /** EXPERIENCE.md:300 */
  formGoToHome: 'Go to Home',
  /** EXPERIENCE.md:300 */
  formLeaveWithoutSaving: 'Leave without saving?',
  /** EXPERIENCE.md:301 */
  authSignInFailed: 'Sign-in failed. Check the user name and password.',
  /** EXPERIENCE.md:301 */
  authPasswordExpired: 'The password for <user> has expired. Change it in the classic portal, or run the command in the README to clear the expiry.',
  /** EXPERIENCE.md:301 */
  authSessionEnded: 'Your session ended. Sign in to continue.',
  /** EXPERIENCE.md:301 */
  authSignedOut: 'You\'re signed out.',
  /** EXPERIENCE.md:301 */
  fieldUserName: 'User name',
  /** EXPERIENCE.md:301 */
  fieldPassword: 'Password',
  /** EXPERIENCE.md:302 */
  authSignInUnreachable: 'Sign-in couldn\'t reach the instance. Check that IRIS is running, then sign in again.',
  /** EXPERIENCE.md:303 */
  taskManagerSuspendedBanner: 'The Task Manager is suspended \u2014 no scheduled task will run until it is resumed.',
  /** EXPERIENCE.md:303 */
  taskManagerStoppedBanner: 'The Task Manager is not running \u2014 no scheduled task will run until it is started.',
  /** EXPERIENCE.md:304 */
  classicLinkCardTitle: 'More in the classic portal',
  /** EXPERIENCE.md:305 */
  classicLinkCardCaption: 'The classic portal may ask you to sign in again.',
  /** EXPERIENCE.md:306 */
  commandBoxPlaceholder: 'Search screens and commands',
  /** EXPERIENCE.md:306 */
  commandBoxNoMatch: 'No screen or action matches.',
  /** EXPERIENCE.md:306 */
  commandBoxResultCount: '<n> screens, <m> actions',
  /** EXPERIENCE.md:307 */
  commandBoxGroupScreens: 'Screens',
  /** EXPERIENCE.md:307 */
  commandBoxGroupActions: 'Actions',
  /** EXPERIENCE.md:308 */
  agentComposerCaption: 'Enter to send \u00b7 Shift+Enter for a new line \u00b7 Ctrl+I to focus',
  /** EXPERIENCE.md:309 */
  navAreaHome: 'Home',
  /** EXPERIENCE.md:309 */
  navAreaLogs: 'Logs',
  /** EXPERIENCE.md:309 */
  navAreaOsManagement: 'OS management',
  /** EXPERIENCE.md:309 */
  navAreaTasks: 'Tasks',
  /** EXPERIENCE.md:309 */
  navAreaPermissions: 'Permissions',
  /** EXPERIENCE.md:309 */
  navAreaWebApplications: 'Web applications and REST API explorer',
  /** EXPERIENCE.md:309 */
  navAreaSecurity: 'Security and secrets',
  /** EXPERIENCE.md:309 */
  navAreaAgent: 'Agent co-pilot',
  /** EXPERIENCE.md:310 */
  navRailItemTooltip: '<Area> \u00b7 Ctrl+B toggles the side bar',
  /** EXPERIENCE.md:311 */
  agentComposerLabel: 'Message to the agent',
  /** EXPERIENCE.md:311 */
  agentShareContextLabel: 'Share screen context',
  /** EXPERIENCE.md:312 */
  tableRowCapNotice: 'Showing the first <n> rows. Narrow the filter or raise the max rows.',
  /** EXPERIENCE.md:313 */
  tableRowCount: '<n> rows',
  /** EXPERIENCE.md:313 */
  tableMaxRowsLabel: 'Max rows',
  /** EXPERIENCE.md:313 */
  tableEmptyValue: '(none)',
  /** EXPERIENCE.md:313 */
  tableStatusYes: 'Yes',
  /** EXPERIENCE.md:313 */
  tableStatusNo: 'No',
  /** EXPERIENCE.md:314 */
  tableWriteCapableEmptyState: 'Or ask the agent: <a write it could propose here>.',
  /** EXPERIENCE.md:315 */
  webAppListLabel: 'Web applications',
  /** EXPERIENCE.md:315 */
  tableColumnName: 'Name',
  /** EXPERIENCE.md:315 */
  tableColumnType: 'Type',
  /** EXPERIENCE.md:315 */
  tableColumnEnabled: 'Enabled',
  /** EXPERIENCE.md:315 */
  webAppColumnDispatchClass: 'Dispatch class',
  /** EXPERIENCE.md:315 */
  webAppColumnResource: 'Resource',
  /** EXPERIENCE.md:315 */
  webAppListEmpty: 'No web applications in <NAMESPACE>.',
  /** EXPERIENCE.md:315 */
  tableReadOnlyEmptyNext: 'Open another screen from the command box.',
  /** EXPERIENCE.md:316 */
  userListLabel: 'Users',
  /** EXPERIENCE.md:316 */
  userColumnFullName: 'Full name',
  /** EXPERIENCE.md:316 */
  userColumnExpired: 'Account expired',
  /** EXPERIENCE.md:316 */
  userColumnRoles: 'Roles',
  /** EXPERIENCE.md:316 */
  userListEmpty: 'No users in <NAMESPACE>.',
  /** EXPERIENCE.md:317 */
  sslListLabel: 'SSL/TLS',
  /** EXPERIENCE.md:317 */
  tableColumnDescription: 'Description',
  /** EXPERIENCE.md:317 */
  sslListEmpty: 'No SSL/TLS configurations in <NAMESPACE>.',
  /** EXPERIENCE.md:318 */
  taskListLabel: 'Task schedule',
  /** EXPERIENCE.md:318 */
  taskColumnLastRun: 'Last run',
  /** EXPERIENCE.md:318 */
  taskColumnNextRun: 'Next run',
  /** EXPERIENCE.md:318 */
  taskListEmpty: 'No scheduled tasks on this instance.',
  /** EXPERIENCE.md:319 */
  processListLabel: 'Processes',
  /** EXPERIENCE.md:319 */
  processColumnPid: 'Process ID',
  /** EXPERIENCE.md:319 */
  processColumnUser: 'User',
  /** EXPERIENCE.md:319 */
  processColumnRoutine: 'Routine',
  /** EXPERIENCE.md:319 */
  processColumnState: 'State',
  /** EXPERIENCE.md:319 */
  processColumnCommands: 'Commands',
  /** EXPERIENCE.md:319 */
  processColumnGlobals: 'Globals',
  /** EXPERIENCE.md:319 */
  processListEmpty: 'No processes on this instance.',
  /** EXPERIENCE.md:320 */
  sortMenuLabel: 'Sort',
  /** EXPERIENCE.md:320 */
  sortDirectionAscending: 'Ascending',
  /** EXPERIENCE.md:320 */
  sortDirectionDescending: 'Descending',
  /** EXPERIENCE.md:321 */
  auditListLabel: 'Audit database',
  /** EXPERIENCE.md:321 */
  auditColumnTime: 'Time',
  /** EXPERIENCE.md:321 */
  auditColumnEventSource: 'Event source',
  /** EXPERIENCE.md:321 */
  auditColumnEventType: 'Event type',
  /** EXPERIENCE.md:321 */
  auditColumnEventName: 'Event name',
  /** EXPERIENCE.md:321 */
  auditListEmpty: 'No events match.',
  /** EXPERIENCE.md:322 */
  auditCriteriaBegin: 'Begin date and time',
  /** EXPERIENCE.md:322 */
  auditCriteriaEnd: 'End date and time',
  /** EXPERIENCE.md:322 */
  auditCriteriaAuthentication: 'Authentication',
  /** EXPERIENCE.md:322 */
  auditCriteriaSearch: 'Search',
  /** EXPERIENCE.md:322 */
  auditCriteriaAnyOption: 'Any',
  /** EXPERIENCE.md:322 */
  auditCriteriaNameHint: 'Comma-separated. * matches any name.',
  /** EXPERIENCE.md:322 */
  auditCriteriaTimeHint: 'Instance local time, as YYYY-MM-DD HH:MM:SS.',
  /** EXPERIENCE.md:323 */
  auditMarkerFilterLabel: 'Agent-marked events only',
  /** EXPERIENCE.md:324 */
  auditDialogTitle: 'Audit event',
  /** EXPERIENCE.md:324 */
  auditDialogEventData: 'Event data',
  /** EXPERIENCE.md:324 */
  auditDialogClose: 'Close',
  /** EXPERIENCE.md:325 */
  errorLogListLabel: 'Application errors',
  /** EXPERIENCE.md:325 */
  errorLogColumnDate: 'Date',
  /** EXPERIENCE.md:325 */
  errorLogColumnCount: 'Errors',
  /** EXPERIENCE.md:325 */
  errorLogColumnNumber: 'Error number',
  /** EXPERIENCE.md:325 */
  errorLogColumnText: 'Error',
  /** EXPERIENCE.md:325 */
  errorLogColumnLine: 'Code line',
  /** EXPERIENCE.md:326 */
  errorLogEmptyInstance: 'No application errors on this instance.',
  /** EXPERIENCE.md:326 */
  errorLogEmptyNamespace: 'No application errors in <NAMESPACE>.',
  /** EXPERIENCE.md:326 */
  errorLogEmptyDate: 'No application errors in <NAMESPACE> on <DATE>.',
  /** EXPERIENCE.md:327 */
  errorLogDetailExpressions: 'Expressions',
  /** EXPERIENCE.md:327 */
  errorLogDetailStack: 'Stack',
  /** EXPERIENCE.md:327 */
  errorLogDetailVariables: 'Variables',
  /** EXPERIENCE.md:327 */
  errorLogColumnExpression: 'Expression',
  /** EXPERIENCE.md:327 */
  errorLogColumnValue: 'Value',
  /** EXPERIENCE.md:327 */
  errorLogColumnLevel: 'Level',
  /** EXPERIENCE.md:327 */
  errorLogColumnFrame: 'Frame',
  /** EXPERIENCE.md:328 */
  errorLogBack: 'Back',
  /** EXPERIENCE.md:328 */
  errorLogLevelCapNotice: 'This list was cut at the row cap \u2014 older entries are not shown.',
  /** EXPERIENCE.md:328 */
  errorLogDetailCapNotice: 'This capture was cut at the row cap \u2014 some values are not shown.',
  /** EXPERIENCE.md:329 */
  errorLogRefusedNamespace: 'That namespace is no longer present in this log. Use Back to see which namespaces are.',
  /** EXPERIENCE.md:329 */
  errorLogRefusedDate: 'That date is no longer present in this log. Use Back to see which dates are.',
  /** EXPERIENCE.md:329 */
  errorLogRefusedEntry: 'That application error is no longer present in this log. Use Back to see which errors are.',
  /** EXPERIENCE.md:329 */
  errorLogRefusedAction: 'read this log',
  /** EXPERIENCE.md:353 */
  homeSuggestedView: 'Suggested view',
  /** EXPERIENCE.md:354 */
  homeSuggestedOpen: 'Open',
  /** EXPERIENCE.md:355 */
  homeSuggestedApplicationErrors: 'Application errors in <NAMESPACE>: <n> on <DATE>',
  /** EXPERIENCE.md:330 */
  homeStarterPromptExplainScreen: 'What\'s on this screen, and what should I look at first?',
  /** EXPERIENCE.md:330 */
  homeStarterPromptExplainLog: 'Explain the most recent entries in messages.log.',
  /** EXPERIENCE.md:330 */
  homeStarterPromptChangeOneThing: 'If you could change one thing on this instance, what would it be, and why?',
  /** EXPERIENCE.md:331 */
  proposalExpectedImpactExample: 'users holding %Development can reach the application',
  /** EXPERIENCE.md:332 */
  auditMarkerDescription: 'marked as coming through the OcuPilot agent co-pilot',
  /** EXPERIENCE.md:333 */
  agentDefinitionListLabel: 'Definitions',
  /** EXPERIENCE.md:333 */
  tableColumnProvider: 'Provider',
  /** EXPERIENCE.md:333 */
  tableColumnModel: 'Model',
  /** EXPERIENCE.md:333 */
  tableColumnDefault: 'Default',
  /** EXPERIENCE.md:333 */
  agentDefinitionListEmpty: 'No agent definitions yet.',
  /** EXPERIENCE.md:333 */
  agentDefinitionListEmptyAgent: 'create a definition for Claude and test the connection',
  /** EXPERIENCE.md:333 */
  agentDefinitionEnable: 'Enable',
  /** EXPERIENCE.md:333 */
  agentDefinitionDisable: 'Disable',
  /** EXPERIENCE.md:333 */
  agentDefinitionSetDefault: 'Set default',
  /** EXPERIENCE.md:334 */
  agentDefinitionFormLabel: 'Definition',
  /** EXPERIENCE.md:334 */
  agentDefinitionFieldEndpoint: 'Endpoint',
  /** EXPERIENCE.md:334 */
  agentDefinitionFieldApiKey: 'API key',
  /** EXPERIENCE.md:334 */
  agentDefinitionFieldLocalModel: 'Local model',
  /** EXPERIENCE.md:334 */
  agentDefinitionCredTypeNone: 'No API key',
  /** EXPERIENCE.md:334 */
  agentDefinitionHttpAcknowledge:
    'This endpoint is not encrypted, so the key travels across the network in clear.',
  /** EXPERIENCE.md:334 */
  agentDefinitionAdvanced: 'Advanced',
  /** EXPERIENCE.md:334 */
  agentDefinitionFieldMaxTokens: 'Maximum tokens',
  /** EXPERIENCE.md:334 */
  agentDefinitionFieldTemperature: 'Temperature',
  /** EXPERIENCE.md:334 */
  agentDefinitionFieldMaxIterations: 'Maximum iterations',
  /** EXPERIENCE.md:334 */
  agentDefinitionFieldSystemPrompt: 'System prompt override',
  /** EXPERIENCE.md:334 */
  agentDefinitionFieldRetention: 'Retention',
  /** EXPERIENCE.md:334 */
  actionCreate: 'Create',
  /** EXPERIENCE.md:335 */
  agentDefinitionShowKey: 'Show key',
  /** EXPERIENCE.md:335 */
  agentDefinitionHideKey: 'Hide key',
  /** EXPERIENCE.md:335 */
  agentDefinitionRetentionCaption: 'Transcripts are kept for <n> days.',
  /** EXPERIENCE.md:336 */
  proposalCardTitle: 'Proposal \u00b7 <entity type> <name>',
  /** EXPERIENCE.md:337 */
  proposalDiffWas: 'was',
  /** EXPERIENCE.md:337 */
  proposalDiffNow: 'now',
  /** EXPERIENCE.md:338 */
  agentTrustReads: 'It reads with your privileges.',
  /** EXPERIENCE.md:338 */
  agentTrustProposes: 'It proposes and you confirm.',
  /** EXPERIENCE.md:338 */
  agentTrustAudited: 'Every write is marked in the audit database.',
  /** EXPERIENCE.md:339 */
  agentDefinitionRefusedAction: 'change this definition',
  /** EXPERIENCE.md:340 */
  formRequiredFieldsLegend: 'Required fields are marked with an asterisk.',
  /** EXPERIENCE.md:341 */
  agentSwitchesLabel: 'Switches',
  /** EXPERIENCE.md:341 */
  agentSwitchesKillSwitch: 'Kill switch',
  /** EXPERIENCE.md:341 */
  agentSwitchesFieldReason: 'Reason',
  /** EXPERIENCE.md:341 */
  agentSwitchesEnforcedReadOnly: 'Enforced read-only',
  /** EXPERIENCE.md:341 */
  agentSwitchesHoldsHeading: 'Switched off users',
  /** EXPERIENCE.md:341 */
  agentSwitchesHoldAdd: 'Switch off a user',
  /** EXPERIENCE.md:341 */
  agentSwitchesHoldRemove: 'Switch the agent back on',
  /** EXPERIENCE.md:341 */
  agentSwitchesHoldsEmpty: 'No users are switched off.',
  /** EXPERIENCE.md:342 */
  agentSwitchesShareContext: 'Screen context is shared by default',
  /** EXPERIENCE.md:348 */
  agentSwitchesContextRowCap: 'Context rows sent with a turn',
  /** EXPERIENCE.md:343 */
  agentSwitchesRefusedAction: 'change the switches',
  /** EXPERIENCE.md:344 */
  formStaleSave:
    'Someone else changed this while you were here. Reload to see the current values, then save again.',
  // "Definitions" (:345), the administrator reminder banner's link, is the same literal as the
  // Definitions list's own label and renders `agentDefinitionListLabel`: one key per value.
  /** EXPERIENCE.md:346 */
  agentPanelFullScreen: 'Full screen',
  /** EXPERIENCE.md:347 */
  agentPanelResizeHandle: 'Resize the agent co-pilot panel',
  /** EXPERIENCE.md:349 */
  agentPanelSecretWarning: 'This looks like a password or key. Send anyway?',
  /** EXPERIENCE.md:349 */
  agentPanelSecretWarningSend: 'Send anyway',
  /** EXPERIENCE.md:349 */
  agentPanelSecretWarningEdit: 'Edit',
  /** EXPERIENCE.md:350 */
  agentContextChipSecretGlyph: 'Secret fields on this screen are never sent',
  /** EXPERIENCE.md:356 */
  restApiListLabel: 'REST API explorer',
  /** EXPERIENCE.md:356 */
  restApiColumnSpecBased: 'Spec-based',
  /** EXPERIENCE.md:356 */
  restApiListEmpty: 'No REST applications in <NAMESPACE>.',
  /** EXPERIENCE.md:357 */
  openApiViewerLabel: 'OpenAPI document',
  /** EXPERIENCE.md:357 */
  openApiColumnPath: 'Path',
  /** EXPERIENCE.md:357 */
  openApiColumnVerb: 'Verb',
  /** EXPERIENCE.md:357 */
  openApiColumnSummary: 'Summary',
  /** EXPERIENCE.md:357 */
  openApiParameters: 'Parameters',
  /** EXPERIENCE.md:357 */
  openApiResponses: 'Responses',
  /** EXPERIENCE.md:357 */
  openApiRequired: 'Required',
  /** EXPERIENCE.md:357 */
  openApiRaw: 'Raw',
  /** EXPERIENCE.md:357 */
  openApiViewerEmpty: 'This document declares no paths.',
  /** EXPERIENCE.md:357 */
  openApiRefusedAction: 'read this document',
  /** EXPERIENCE.md:357 */
  openApiCapNotice: 'This document was cut at the row cap \u2014 some operations are not shown.',
  /** EXPERIENCE.md:358 */
  roleColumnCreatedBy: 'Created by',
  /** EXPERIENCE.md:358 */
  roleColumnEscalationOnly: 'Escalation only',
  /** EXPERIENCE.md:358 */
  roleListEmpty: 'No roles on this instance.',
  /** EXPERIENCE.md:359 */
  resourceListLabel: 'Resources',
  /** EXPERIENCE.md:359 */
  resourceColumnPublicPermission: 'Public permission',
  /** EXPERIENCE.md:359 */
  resourceColumnDeletable: 'Deletable',
  /** EXPERIENCE.md:359 */
  resourceListEmpty: 'No resources on this instance.',
  /** EXPERIENCE.md:360 */
  serviceListLabel: 'Services',
  /** EXPERIENCE.md:360 */
  serviceColumnAuthentication: 'Authentication methods',
  /** EXPERIENCE.md:360 */
  serviceColumnAllowedAddresses: 'Allowed IP addresses',
  /** EXPERIENCE.md:360 */
  serviceAllowedUnrestricted: 'Unrestricted',
  /** EXPERIENCE.md:360 */
  serviceListEmpty: 'No services on this instance.',
  /** EXPERIENCE.md:361 */
  x509ListLabel: 'X.509',
  /** EXPERIENCE.md:361 */
  x509ColumnAlias: 'Alias',
  /** EXPERIENCE.md:361 */
  x509ColumnSubject: 'Subject',
  /** EXPERIENCE.md:361 */
  x509ColumnIssuer: 'Issuer',
  /** EXPERIENCE.md:361 */
  x509ColumnValidFrom: 'Valid from',
  /** EXPERIENCE.md:361 */
  x509ColumnValidUntil: 'Valid until',
  /** EXPERIENCE.md:361 */
  x509ListEmpty: 'No X.509 credentials on this instance.',
  /** EXPERIENCE.md:362 */
  ldapListLabel: 'LDAP / Kerberos',
  /** EXPERIENCE.md:362 */
  ldapListEmpty: 'No LDAP / Kerberos configurations on this instance.',
  /** EXPERIENCE.md:363 */
  walletListLabel: 'Wallet',
  /** EXPERIENCE.md:363 */
  walletColumnUseResource: 'Use resource',
  /** EXPERIENCE.md:363 */
  walletColumnEditResource: 'Edit resource',
  /** EXPERIENCE.md:363 */
  walletListEmpty: 'No wallet collections on this instance.',
  /** EXPERIENCE.md:364 */
  walletSecretListLabel: 'Secrets',
  /** EXPERIENCE.md:364 */
  walletSecretListEmpty: 'No secrets in this collection.',
  /** EXPERIENCE.md:365 */
  oauthLabel: 'OAuth 2.0',
  /** EXPERIENCE.md:365 */
  oauthTabServerDescriptions: 'Client server descriptions',
  /** EXPERIENCE.md:365 */
  oauthTabClients: 'Client configurations',
  /** EXPERIENCE.md:365 */
  oauthTabResourceServers: 'Resource servers',
  /** EXPERIENCE.md:365 */
  oauthTabServer: 'Authorization server',
  /** EXPERIENCE.md:365 */
  oauthTabServerClients: 'Server client descriptions',
  /** EXPERIENCE.md:366 */
  oauthColumnClientType: 'Client type',
  /** EXPERIENCE.md:366 */
  oauthColumnDefaultScope: 'Default scope',
  /** EXPERIENCE.md:366 */
  oauthColumnScopes: 'Scopes',
  /** EXPERIENCE.md:366 */
  oauthColumnGrantTypes: 'Grant types',
  /** EXPERIENCE.md:366 */
  oauthColumnSigningAlgorithm: 'Signing algorithm',
  /** EXPERIENCE.md:366 */
  oauthColumnEncryptionAlgorithm: 'Encryption algorithm',
  /** EXPERIENCE.md:366 */
  oauthColumnKeyAlgorithm: 'Key algorithm',
  /** EXPERIENCE.md:366 */
  oauthColumnServerCredentials: 'Server credentials',
  /** EXPERIENCE.md:366 */
  oauthColumnClientId: 'Client ID',
  /** EXPERIENCE.md:366 */
  oauthColumnRedirectUrls: 'Redirect URLs',
  /** EXPERIENCE.md:366 */
  classicRowLinkDescription: 'Opens <page> in the classic portal in a new tab.',
  /** EXPERIENCE.md:367 */
  oauthServerDescriptionsEmpty: 'No client server descriptions on this instance.',
  /** EXPERIENCE.md:367 */
  oauthClientsEmpty: 'No client configurations on this instance.',
  /** EXPERIENCE.md:367 */
  oauthResourceServersEmpty: 'No resource servers on this instance.',
  /** EXPERIENCE.md:367 */
  oauthServerEmpty: 'No authorization server is configured on this instance.',
  /** EXPERIENCE.md:367 */
  oauthServerClientsEmpty: 'No server client descriptions on this instance.',
  /** EXPERIENCE.md:368 */
  taskOnDemandLabel: 'On-demand tasks',
  /** EXPERIENCE.md:368 */
  taskOnDemandEmpty: 'No tasks on this instance can be run on demand.',
  /** EXPERIENCE.md:369 */
  taskUpcomingLabel: 'Upcoming tasks',
  /** EXPERIENCE.md:369 */
  taskUpcomingColumnAt: 'Scheduled for',
  /** EXPERIENCE.md:369 */
  taskColumnSuspended: 'Suspended',
  /** EXPERIENCE.md:369 */
  taskUpcomingHorizon: 'Scheduled to run within',
  /** EXPERIENCE.md:369 */
  taskUpcomingHours1: 'The next hour',
  /** EXPERIENCE.md:369 */
  taskUpcomingHours4: 'The next 4 hours',
  /** EXPERIENCE.md:369 */
  taskUpcomingHours12: 'The next 12 hours',
  /** EXPERIENCE.md:369 */
  taskUpcomingHours24: 'The next 24 hours',
  /** EXPERIENCE.md:369 */
  taskUpcomingHours72: 'The next 3 days',
  /** EXPERIENCE.md:369 */
  taskUpcomingHours168: 'The next 7 days',
  /** EXPERIENCE.md:369 */
  taskUpcomingUntil: 'Until a date',
  /** EXPERIENCE.md:369 */
  taskUpcomingEmpty: 'No tasks are scheduled to run within this horizon.',
  /** EXPERIENCE.md:370 */
  taskHistoryLabel: 'Task history',
  /** EXPERIENCE.md:370 */
  taskHistoryColumnStarted: 'Started',
  /** EXPERIENCE.md:370 */
  taskHistoryColumnCompleted: 'Completed',
  /** EXPERIENCE.md:370 */
  taskHistoryColumnStatus: 'Status',
  /** EXPERIENCE.md:370 */
  taskHistoryColumnResult: 'Result',
  /** EXPERIENCE.md:370 */
  taskHistoryColumnTaskId: 'Task ID',
  /** EXPERIENCE.md:370 */
  taskHistoryColumnErrDate: 'Error date',
  /** EXPERIENCE.md:370 */
  taskHistoryColumnLogged: 'Logged',
  /** EXPERIENCE.md:370 */
  taskHistorySearch: 'Contains',
  /** EXPERIENCE.md:370 */
  taskHistoryUserOnly: 'User-defined tasks only',
  /** EXPERIENCE.md:370 */
  taskHistoryEmpty: 'No task runs match.',
  /** EXPERIENCE.md:371 */
  taskRunsLabel: 'History',
  /** EXPERIENCE.md:371 */
  taskRunsEmpty: 'This task has no recorded runs.',
  /** EXPERIENCE.md:372 */
  taskDetailsLabel: 'Task details',
  /** EXPERIENCE.md:372 */
  taskDetailsGone: 'This task no longer exists.',
  /** EXPERIENCE.md:372 */
  taskDetailsTaskClass: 'Task class',
  /** EXPERIENCE.md:372 */
  taskDetailsPriority: 'Priority',
  /** EXPERIENCE.md:372 */
  taskDetailsRunAs: 'Run as',
  /** EXPERIENCE.md:372 */
  taskDetailsLastError: 'Last error',
  /** EXPERIENCE.md:372 */
  taskDetailsSchedule: 'Schedule',
  /** EXPERIENCE.md:372 */
  taskDetailsHowOften: 'How often',
  /** EXPERIENCE.md:372 */
  taskDetailsTimeOfDay: 'Time of day',
  /** EXPERIENCE.md:372 */
  taskDetailsNextSuspended: 'Not scheduled while suspended',
  /** EXPERIENCE.md:372 */
  taskDetailsEdit: 'Edit task',
  /** EXPERIENCE.md:372 */
  taskScheduleEveryDay: 'Every day',
  /** EXPERIENCE.md:372 */
  taskScheduleEveryNDays: 'Every {n} days',
  /** EXPERIENCE.md:372 */
  taskScheduleWeekly: 'Every week on {days}',
  /** EXPERIENCE.md:372 */
  taskScheduleWeeklyEveryN: 'Every {n} weeks on {days}',
  /** EXPERIENCE.md:372 */
  taskScheduleMonthlyDay: 'Every month on day {d}',
  /** EXPERIENCE.md:372 */
  taskScheduleMonthlyDayEveryN: 'Every {n} months on day {d}',
  /** EXPERIENCE.md:372 */
  taskScheduleMonthlySpecial: 'Every month on the {ordinal} {weekday}',
  /** EXPERIENCE.md:372 */
  taskScheduleMonthlySpecialEveryN: 'Every {n} months on the {ordinal} {weekday}',
  /** EXPERIENCE.md:372 */
  taskScheduleRunAfter: 'After another task completes',
  /** EXPERIENCE.md:372 */
  taskScheduleOnDemand: 'On demand only',
  /** EXPERIENCE.md:372 */
  taskScheduleOnceAt: 'Once at {time}',
  /** EXPERIENCE.md:372 */
  taskScheduleEveryMinute: 'Every minute between {start} and {end}',
  /** EXPERIENCE.md:372 */
  taskScheduleEveryNMinutes: 'Every {n} minutes between {start} and {end}',
  /** EXPERIENCE.md:372 */
  taskScheduleEveryHour: 'Every hour between {start} and {end}',
  /** EXPERIENCE.md:372 */
  taskScheduleEveryNHours: 'Every {n} hours between {start} and {end}',
  /** EXPERIENCE.md:372 */
  weekdaySunday: 'Sunday',
  /** EXPERIENCE.md:372 */
  weekdayMonday: 'Monday',
  /** EXPERIENCE.md:372 */
  weekdayTuesday: 'Tuesday',
  /** EXPERIENCE.md:372 */
  weekdayWednesday: 'Wednesday',
  /** EXPERIENCE.md:372 */
  weekdayThursday: 'Thursday',
  /** EXPERIENCE.md:372 */
  weekdayFriday: 'Friday',
  /** EXPERIENCE.md:372 */
  weekdaySaturday: 'Saturday',
  /** EXPERIENCE.md:372 */
  ordinalFirst: 'first',
  /** EXPERIENCE.md:372 */
  ordinalSecond: 'second',
  /** EXPERIENCE.md:372 */
  ordinalThird: 'third',
  /** EXPERIENCE.md:372 */
  ordinalFourth: 'fourth',
  /** EXPERIENCE.md:372 */
  ordinalFifth: 'fifth',
  /** EXPERIENCE.md:373 */
  processDetailsLabel: 'Process details',
  /** EXPERIENCE.md:373 */
  processDetailsGone: 'This process no longer exists.',
  /** EXPERIENCE.md:373 */
  processDetailsGroupGeneral: 'General',
  /** EXPERIENCE.md:373 */
  processDetailsGroupExecution: 'Execution',
  /** EXPERIENCE.md:373 */
  processDetailsGroupClientApplication: 'Client application',
  /** EXPERIENCE.md:373 */
  processDetailsParentPid: 'Parent process ID',
  /** EXPERIENCE.md:373 */
  processDetailsLoginRoles: 'Login roles',
  /** EXPERIENCE.md:373 */
  processDetailsEscalatedRoles: 'Escalated roles',
  /** EXPERIENCE.md:373 */
  processDetailsOsUser: 'OS user',
  /** EXPERIENCE.md:373 */
  processDetailsCpuTime: 'CPU time (ms)',
  /** EXPERIENCE.md:373 */
  processDetailsGlobalReferences: 'Global references',
  /** EXPERIENCE.md:373 */
  processDetailsPrivateGlobalReferences: 'Private global references',
  /** EXPERIENCE.md:373 */
  processDetailsPrivateGlobalBlocks: 'Private global blocks',
  /** EXPERIENCE.md:373 */
  processDetailsMemoryLimit: 'Memory limit (KB)',
  /** EXPERIENCE.md:373 */
  processDetailsMemoryPeak: 'Memory peak (KB)',
  /** EXPERIENCE.md:373 */
  processDetailsMemoryUsed: 'Memory used (KB)',
  /** EXPERIENCE.md:373 */
  processDetailsCurrentDevice: 'Current device',
  /** EXPERIENCE.md:373 */
  processDetailsOpenDevices: 'Open devices',
  /** EXPERIENCE.md:373 */
  processDetailsInTransaction: 'In transaction',
  /** EXPERIENCE.md:373 */
  processDetailsSourceLocation: 'Source location',
  /** EXPERIENCE.md:373 */
  processDetailsLocation: 'Location',
  /** EXPERIENCE.md:373 */
  processDetailsClientName: 'Client name',
  /** EXPERIENCE.md:373 */
  processDetailsClientExecutable: 'Client executable',
  /** EXPERIENCE.md:373 */
  processDetailsClientIpAddress: 'Client IP address',

  /** EXPERIENCE.md:374 */
  systemUsageLabel: 'System usage',
  /** EXPERIENCE.md:374 */
  systemUsageGlobalUpdates: 'Global updates',
  /** EXPERIENCE.md:374 */
  systemUsageRoutineCalls: 'Routine calls',
  /** EXPERIENCE.md:374 */
  systemUsageLogicalBlockRequests: 'Logical block requests',
  /** EXPERIENCE.md:374 */
  systemUsageBlockReads: 'Block reads',
  /** EXPERIENCE.md:374 */
  systemUsageBlockWrites: 'Block writes',
  /** EXPERIENCE.md:374 */
  systemUsageJournalEntries: 'Journal entries',
  /** EXPERIENCE.md:374 */
  systemUsageJournalBlockWrites: 'Journal block writes',
  /** EXPERIENCE.md:374 */
  systemUsageLastUpdate: 'Last update',
  /** EXPERIENCE.md:374 */
  systemUsageSharedMemory: 'Shared memory',
  /** EXPERIENCE.md:374 */
  systemUsageGlobalRefsPerSecond: 'Global references per second',
  /** EXPERIENCE.md:374 */
  systemUsageCacheEfficiency: 'Cache efficiency',
  /** EXPERIENCE.md:374 */
  systemUsageDatabaseSpace: 'Database space',
  /** EXPERIENCE.md:374 */
  systemUsageJournalSpace: 'Journal space',
  /** EXPERIENCE.md:374 */
  systemUsageLockTable: 'Lock table',
  /** EXPERIENCE.md:374 */
  systemUsageWriteDaemon: 'Write daemon',
  /** EXPERIENCE.md:374 */
  systemUsageEmpty: 'System usage is unavailable.',
  /** EXPERIENCE.md:375 */
  lockListLabel: 'Locks',
  /** EXPERIENCE.md:375 */
  lockColumnMode: 'Mode',
  /** EXPERIENCE.md:375 */
  lockColumnReference: 'Reference',
  /** EXPERIENCE.md:375 */
  lockColumnDirectory: 'Directory',
  /** EXPERIENCE.md:375 */
  lockColumnSystem: 'System',
  /** EXPERIENCE.md:375 */
  lockSystemLocal: 'This instance',
  /** EXPERIENCE.md:375 */
  lockListEmpty: 'No locks on this instance.',
  /** EXPERIENCE.md:376 */
  databaseListLabel: 'Databases',
  /** EXPERIENCE.md:376 */
  databaseFreeSpaceLabel: 'Free space',
  /** EXPERIENCE.md:376 */
  viewMenuLabel: 'View',
  /** EXPERIENCE.md:376 */
  databaseColumnSize: 'Size',
  /** EXPERIENCE.md:376 */
  databaseColumnMaxSize: 'Maximum size',
  /** EXPERIENCE.md:376 */
  databaseColumnAvailable: 'Available',
  /** EXPERIENCE.md:376 */
  databaseColumnDiskFree: 'Disk free',
  /** EXPERIENCE.md:376 */
  databaseColumnMounted: 'Mounted',
  /** EXPERIENCE.md:376 */
  databaseListEmpty: 'No databases on this instance.',
  /** EXPERIENCE.md:376 */
  databaseDetailsLabel: 'Database details',
  /** EXPERIENCE.md:376 */
  databaseDetailsGone: 'This database no longer exists.',
  /** EXPERIENCE.md:376 */
  databaseDetailsExpansionSize: 'Expansion size',
  /** EXPERIENCE.md:376 */
  databaseDetailsNewVolumeThreshold: 'New volume threshold',
  /** EXPERIENCE.md:376 */
  databaseDetailsNewVolumeDirectory: 'New volume directory',
  /** EXPERIENCE.md:376 */
  databaseDetailsKeepNewGlobals: 'Keep new globals',
  /** EXPERIENCE.md:376 */
  databaseDetailsNewGlobalCollation: 'New global collation',
  /** EXPERIENCE.md:376 */
  databaseDetailsClusterMountMode: 'Cluster mount mode',
  /** EXPERIENCE.md:376 */
  databaseDetailsReadOnly: 'Read only',
  /** EXPERIENCE.md:376 */
  databaseDetailsJournalNewGlobals: 'Journal new globals',
  /** EXPERIENCE.md:376 */
  databaseVolumeListLabel: 'Volume files',
  /** EXPERIENCE.md:376 */
  databaseVolumeColumnVolume: 'Volume',
  /** EXPERIENCE.md:376 */
  databaseVolumeColumnFile: 'File',
  /** EXPERIENCE.md:376 */
  databaseVolumeColumnDirectoryTotal: 'Directory total',
  /** EXPERIENCE.md:376 */
  databaseVolumeListEmpty: 'No volume files for this database.',
  /** EXPERIENCE.md:377 */
  deviceListLabel: 'Devices',
  /** EXPERIENCE.md:377 */
  deviceColumnPhysical: 'Physical device',
  /** EXPERIENCE.md:377 */
  deviceColumnSubtype: 'Subtype',
  /** EXPERIENCE.md:377 */
  deviceListEmpty: 'No devices on this instance.',

  // Not from the Fixed strings table, but required verbatim by this story's task
  // list: the audit-marker-failure fallback text (AD-15 / EXPERIENCE.md "9. **Audit.** Every confirmed"), the
  // reduced-motion word that replaces a running spinner (EXPERIENCE.md "**Reduced motion.** The highlight"), and
  // the product name (never typeset as the wordmark -- DESIGN.md -- but an ordinary
  // word wherever running text or a document <title> needs it).
  auditMarkerFailed: 'done \u00b7 audit not marked',
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

  // The header lockup's accessible name (EXPERIENCE.md "`imports/OcuPilot-Lockup-horizontal-reversed.png` — the mark"). The separator is an em dash,
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
  /** EXPERIENCE.md:378 */
  logViewerColumnSeverity: 'Severity',
  /** EXPERIENCE.md:378 */
  logViewerColumnMessage: 'Message',
  /** EXPERIENCE.md:378 */
  logViewerEmpty: 'No entries.',
  /** EXPERIENCE.md:378 */
  logViewerNoMatches: 'No matches.',
  /** EXPERIENCE.md:378 */
  logViewerLoadNewer: 'Load newer',
  /** EXPERIENCE.md:378 */
  logViewerJumpTop: 'Jump to top',
  /** EXPERIENCE.md:378 */
  logViewerJumpBottom: 'Jump to bottom',
  /** EXPERIENCE.md:378 */
  logSeverityDebug: 'Debug',
  /** EXPERIENCE.md:378 */
  logSeverityInfo: 'Info',
  /** EXPERIENCE.md:378 */
  logSeverityWarning: 'Warning',
  /** EXPERIENCE.md:378 */
  logSeveritySevere: 'Severe',
  /** EXPERIENCE.md:378 */
  logSeverityFatal: 'Fatal',

  // The alerts.log screen's own two, beyond the shared viewer's: its side-bar entry and title, and
  // the polite count the sticky search announces.
  /** EXPERIENCE.md:379 */
  alertLogListLabel: 'alerts.log',
  /** EXPERIENCE.md:379 */
  logViewerMatchCount: '<n> of <N>',

  // The messages.log screen's own two: its side-bar entry and title, and the control that clears
  // the severity-chip filter. Clear filter is published on this row rather than reused from
  // Component Patterns, which names it only as a `button-text` example (DW-1109).
  /** EXPERIENCE.md:380 */
  messagesLogListLabel: 'messages.log',
  /** EXPERIENCE.md:378 */
  logViewerClearFilter: 'Clear filter',

  // Story 15.1's six: the account menu's Change password item, which is also the dialog's title,
  // the two masked fields, the two names its reveal toggle takes -- they say password where
  // `agentDefinitionShowKey`/`HideKey` say key -- and the polite confirmation after the change.
  /** EXPERIENCE.md:381 */
  accountChangePassword: 'Change password',
  /** EXPERIENCE.md:381 */
  accountCurrentPasswordLabel: 'Current password',
  /** EXPERIENCE.md:381 */
  accountNewPasswordLabel: 'New password',
  /** EXPERIENCE.md:381 */
  accountShowPassword: 'Show password',
  /** EXPERIENCE.md:381 */
  accountHidePassword: 'Hide password',
  /** EXPERIENCE.md:381 */
  accountPasswordChanged: 'Password changed',

  // Story 15.2's fifteen: the two Home blocks' headings, empty states, per-row remove names and
  // Clear controls, the locator bar's favorite toggle in its two states, and the five polite
  // confirmations the two surfaces announce. The two `*RemoveNamed` values carry a <name>
  // placeholder the row resolves to the screen it removes.
  /** EXPERIENCE.md:382 */
  favoritesHeading: 'Favorites',
  /** EXPERIENCE.md:382 */
  favoritesEmpty: 'No favorites yet.',
  /** EXPERIENCE.md:382 */
  favoritesAdd: 'Add to favorites',
  /** EXPERIENCE.md:382 */
  favoritesRemove: 'Remove from favorites',
  /** EXPERIENCE.md:382 */
  favoritesRemoveNamed: 'Remove <name> from favorites',
  /** EXPERIENCE.md:382 */
  favoritesClear: 'Clear favorites',
  /** EXPERIENCE.md:382 */
  favoritesAdded: 'Added to favorites',
  /** EXPERIENCE.md:382 */
  favoritesRemoved: 'Removed from favorites',
  /** EXPERIENCE.md:382 */
  favoritesCleared: 'Favorites cleared',
  /** EXPERIENCE.md:382 */
  recentsHeading: 'Recent items',
  /** EXPERIENCE.md:382 */
  recentsEmpty: 'No recent items yet.',
  /** EXPERIENCE.md:382 */
  recentsRemoveNamed: 'Remove <name> from recent items',
  /** EXPERIENCE.md:382 */
  recentsClear: 'Clear recent items',
  /** EXPERIENCE.md:382 */
  recentsRemoved: 'Removed from recent items',
  /** EXPERIENCE.md:382 */
  recentsCleared: 'Recent items cleared',

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
