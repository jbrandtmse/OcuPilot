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
 *   EXPERIENCE.md:209 and DESIGN.md:1167),
 *   `accessibilityReducedMotionSpinnerWord` ("running", EXPERIENCE.md:605) and
 *   `productName` ("OcuPilot").
 * - `<user name>` in any string is the login name, as the audit database records
 *   it (EXPERIENCE.md:248) -- never a display name, never resolved here.
 * - **Scope is the Angular client only** (AD-5, AD-39 Design Notes #3). Screen
 *   descriptors' empty-state text and command-box aliases are server-side,
 *   hand-written ObjectScript; the error envelope's `reason` is minted at the
 *   port boundary. Neither belongs in this file, and this file is not their
 *   source either.
 * - Voice rules (EXPERIENCE.md:248, the Voice and Tone table) apply to every
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
 * -- distinct from `auditing*`: `audit*` is the marker text on one audit entry,
 * `auditing*` is the feature banner -- `fault*` and `tool*`) plus two prefixes for keys
 * that are not from the table at all (see below): `accessibility*` and `product*`.
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
  /** EXPERIENCE.md:280 */
  agentTurnLockBanner: 'A turn is in progress. Wait for it to finish before sending another message.',
  /** EXPERIENCE.md:281 */
  agentNavigationAnnouncement: 'I\'m opening <screen> for <entity> \u2014 use Back to return.',
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
  webAppColumnName: 'Name',
  /** EXPERIENCE.md:315 */
  webAppColumnType: 'Type',
  /** EXPERIENCE.md:315 */
  webAppColumnEnabled: 'Enabled',
  /** EXPERIENCE.md:315 */
  webAppColumnDispatchClass: 'Dispatch class',
  /** EXPERIENCE.md:315 */
  webAppColumnResource: 'Resource',
  /** EXPERIENCE.md:315 */
  webAppListEmpty: 'No web applications in <NAMESPACE>.',
  /** EXPERIENCE.md:315 */
  webAppListEmptyNext: 'Open another screen from the command box.',
  /** EXPERIENCE.md:316 */
  homeStarterPromptExplainScreen: 'What\'s on this screen, and what should I look at first?',
  /** EXPERIENCE.md:316 */
  homeStarterPromptExplainLog: 'Explain the most recent entries in messages.log.',
  /** EXPERIENCE.md:316 */
  homeStarterPromptChangeOneThing: 'If you could change one thing on this instance, what would it be, and why?',
  /** EXPERIENCE.md:317 */
  proposalExpectedImpactExample: 'users holding %Development can reach the application',
  /** EXPERIENCE.md:318 */
  auditMarkerDescription: 'marked as coming through the OcuPilot agent co-pilot',

  // Not from the Fixed strings table, but required verbatim by this story's task
  // list: the audit-marker-failure fallback text (AD-15 / EXPERIENCE.md:209), the
  // reduced-motion word that replaces a running spinner (EXPERIENCE.md:605), and
  // the product name (never typeset as the wordmark -- DESIGN.md -- but an ordinary
  // word wherever running text or a document <title> needs it).
  auditMarkerFailed: 'done \u00b7 audit not marked',
  accessibilityReducedMotionSpinnerWord: 'running',
  productName: 'OcuPilot',

  // The version-mismatch notice's sentence. It is a Fixed strings table row (:255), so it
  // ships like every other key here and not the way the three above do -- nothing names it
  // in `ui/tools/strings.test.mjs`'s REQUIRED_ALONGSIDE_TABLE. EXPERIENCE.md also
  // illustrates it in a State Patterns row at :441, where the version is spelled out as
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

  // The namespace switch's accessible name (EXPERIENCE.md:328, "accessible name
  // "Namespace""). This story renders it as the slot's eyebrow; Story 1.11 turns the slot
  // into the select the same name labels.
  headerNamespaceLabel: 'Namespace',

  // The header lockup's accessible name (EXPERIENCE.md:329). The separator is an em dash,
  // authored as its escape (Rule 14); `epics.md:1350` renders the same name with a hyphen,
  // and EXPERIENCE.md is the authority for every word here. DESIGN.md:287 spells the alt
  // text "OcuPilot" instead -- filed, not reconciled in a component.
  headerHomeLink: 'OcuPilot \u2014 Home',

  // The four server-flag words (EXPERIENCE.md:332, DESIGN.md:1025). The word is always
  // present, never colour alone; an instance with no mode set gets no badge rather than a
  // fifth word (DW-10).
  serverFlagLive: 'Live',
  serverFlagTest: 'Test',
  serverFlagFailover: 'Failover',
  serverFlagDevelopment: 'Development',

  // Two connectivity sentences EXPERIENCE.md publishes outside the Fixed strings table, each
  // authorized by its own targeted extractor in `ui/tools/strings.test.mjs`, never by being
  // added to REQUIRED_ALONGSIDE_TABLE, whose own comment calls that the bypass it must not
  // become.
  //
  // The unreachable banner's body, published twice and identically: the Voice and Tone table's
  // *Do* column (:235) and the Instance-unreachable State Patterns row (:450). The extractor
  // reads :450 and asserts :235 carries the same sentence, so the two cannot drift apart
  // unnoticed. Every character is ASCII, so no escape is needed (Rule 14 still applies to any
  // later edit).
  connectivityBannerUnreachable: 'The instance is unreachable. Check that IRIS is running, then retry.',

  // The generic server-fault body, from the Generic-internal-error State Patterns row (:452).
  // The browser is told this and nothing more; the detail is on the instance (AD-12, AD-39).
  connectivityServerFault: 'Something failed on the instance. Retry; if it keeps failing, check messages.log.',

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
