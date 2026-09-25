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
  /** EXPERIENCE.md:336 */
  agentDefinitionShowKey: 'Show key',
  /** EXPERIENCE.md:336 */
  agentDefinitionHideKey: 'Hide key',
  /** EXPERIENCE.md:336 */
  agentDefinitionRetentionCaption: 'Transcripts are kept for <n> days.',
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
  /** EXPERIENCE.md:344 */
  agentSwitchesRefusedAction: 'change the switches',
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

  // Story 5.7's six. The first three are AD-14's closed action set as published sentences: the
  // off-screen toast renders one, and the panel appends the same one to a confirmed write's reply
  // so the record outlives a toast that expired or was never raised. `<entity>` resolves to the
  // entity's own id; the noun is on the toast's own link, which names the screen.
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
  /** EXPERIENCE.md:392 */
  tableChangeAnnouncement: 'Updated: <entity> <action>',

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
  roleDeleteHolders: '<n> users hold this role.',
  /** EXPERIENCE.md:479 */
  roleDeleteHoldersOne: '1 user holds this role.',
  /** EXPERIENCE.md:479 */
  roleDeleteHoldersNone: 'No user holds this role.',
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

  /** EXPERIENCE.md:553 */
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
  serviceAddressNoRoles: 'Enter one address. Roles for an address are set in the classic portal.',
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
  ldapFormBare: 'Open an LDAP configuration from the LDAP / Kerberos list to change it.',
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
