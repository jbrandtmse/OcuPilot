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
 *   transcribed verbatim from that table -- 51 data rows, roughly 100 distinct
 *   quoted literals once split correctly (the middle dot character appears both
 *   as the table's own separator between sibling strings *and* inside several
 *   strings themselves, so only the double quotes delimit -- never a naive split
 *   on that character).
 * - Three keys at the end are not from that table but are required verbatim by
 *   this story's own task list: `auditMarkerFailed` ("done (middle dot) audit not
 *   marked" -- see the key's own value below for the exact escaped form, AD-15 /
 *   EXPERIENCE.md:207 and DESIGN.md:1167),
 *   `accessibilityReducedMotionSpinnerWord` ("running", EXPERIENCE.md:590) and
 *   `productName` ("OcuPilot").
 * - `<user name>` in any string is the login name, as the audit database records
 *   it (EXPERIENCE.md:246) -- never a display name, never resolved here.
 * - **Scope is the Angular client only** (AD-5, AD-39 Design Notes #3). Screen
 *   descriptors' empty-state text and command-box aliases are server-side,
 *   hand-written ObjectScript; the error envelope's `reason` is minted at the
 *   port boundary. Neither belongs in this file, and this file is not their
 *   source either.
 * - Voice rules (EXPERIENCE.md:246, the Voice and Tone table) apply to every
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
 * `auditing*` is the feature banner -- and `tool*`) plus two prefixes for keys
 * that are not from the table at all (see below): `accessibility*` and `product*`.
 * Flat keeps the linter's "is this value in the source" question a single lookup.
 */
export const STRINGS = {
  /** EXPERIENCE.md:252 */
  authNoAdminPrivileges: 'no administrative privileges on this instance',
  /** EXPERIENCE.md:253 */
  agentWriteBlockedByReadOnly: 'blocked by read-only mode',
  /** EXPERIENCE.md:254 */
  auditingOffBanner: 'Agent writes are not being marked. Auditing is off on this instance.',
  /** EXPERIENCE.md:254 */
  auditingConfigurationLink: 'Auditing configuration',
  /** EXPERIENCE.md:254 */
  auditingTurnOnAction: 'Turn auditing on',
  /** EXPERIENCE.md:255 */
  proposalTargetChanged: 'target changed, re-propose',
  /** EXPERIENCE.md:256 */
  contextChipLeavesInstance: 'leaves the instance',
  /** EXPERIENCE.md:256 */
  contextChipSentToHost: 'Screen context is sent to <host>',
  /** EXPERIENCE.md:257 */
  contextChipScreenSegment: 'Users, HSCUSTOM \u00b7 6 rows',
  /** EXPERIENCE.md:258 */
  contextChipSharingOff: 'Screen context off \u2014 nothing from this screen is sent.',
  /** EXPERIENCE.md:259 */
  connectivityInstanceUnreachable: 'instance unreachable',
  /** EXPERIENCE.md:259 */
  connectivityRequestRefused: 'request refused',
  /** EXPERIENCE.md:260 */
  statusConnectionSigningIn: 'Signing in\u2026',
  /** EXPERIENCE.md:260 */
  statusConnectionConnected: 'Connected',
  /** EXPERIENCE.md:260 */
  statusConnectionRetrying: 'Instance unreachable \u2014 retrying',
  /** EXPERIENCE.md:260 */
  statusConnectionSigningInAgain: 'Signing in again\u2026',
  /** EXPERIENCE.md:261 */
  agentExplainScreenAction: 'Explain this screen',
  /** EXPERIENCE.md:262 */
  actionTestConnection: 'Test connection',
  /** EXPERIENCE.md:262 */
  actionConfirm: 'Confirm',
  /** EXPERIENCE.md:262 */
  actionCancel: 'Cancel',
  /** EXPERIENCE.md:262 */
  actionSave: 'Save',
  /** EXPERIENCE.md:262 */
  actionResume: 'Resume',
  /** EXPERIENCE.md:262 */
  actionRun: 'Run',
  /** EXPERIENCE.md:262 */
  actionSuspend: 'Suspend',
  /** EXPERIENCE.md:262 */
  actionDelete: 'Delete',
  /** EXPERIENCE.md:262 */
  actionSend: 'Send',
  /** EXPERIENCE.md:262 */
  actionStop: 'Stop',
  /** EXPERIENCE.md:262 */
  actionNewConversation: 'New conversation',
  /** EXPERIENCE.md:262 */
  actionRepropose: 'Re-propose',
  /** EXPERIENCE.md:262 */
  actionSignOut: 'Sign out',
  /** EXPERIENCE.md:262 */
  actionSignIn: 'Sign in',
  /** EXPERIENCE.md:263 */
  proposalRationaleHeading: 'Agent\'s rationale',
  /** EXPERIENCE.md:263 */
  proposalExpectedImpactHeading: 'Expected impact',
  /** EXPERIENCE.md:264 */
  proposalReverseLabel: 'Reverse:',
  /** EXPERIENCE.md:265 */
  proposalCountdownLabel: 'Expires in m:ss',
  /** EXPERIENCE.md:265 */
  proposalCountdownTooltip: 'Proposals expire so a stale diff is never applied.',
  /** EXPERIENCE.md:265 */
  proposalCountdownAnnouncement: 'One minute left to confirm',
  /** EXPERIENCE.md:266 */
  proposalFooterConfirmHint: 'Confirm here; sending a message cancels this proposal',
  /** EXPERIENCE.md:266 */
  proposalFooterRunsAs: 'Runs as <user name>, with your privileges.',
  /** EXPERIENCE.md:267 */
  proposalConfirmSentence: 'Press Confirm on the card to apply it.',
  /** EXPERIENCE.md:268 */
  proposalStatusConfirmedBy: 'Confirmed by <user name> \u00b7 hh:mm:ss',
  /** EXPERIENCE.md:268 */
  proposalStatusCanceledByYou: 'Canceled \u2014 by you',
  /** EXPERIENCE.md:268 */
  proposalStatusCanceledByMessage: 'Canceled \u2014 by your message',
  /** EXPERIENCE.md:268 */
  proposalStatusCanceledSibling: 'Canceled \u2014 a sibling proposal was confirmed',
  /** EXPERIENCE.md:268 */
  proposalStatusExpired: 'Expired',
  /** EXPERIENCE.md:268 */
  proposalStatusAgentSwitchedOff: 'The agent is switched off',
  /** EXPERIENCE.md:269 */
  proposalUnchangedFieldsDisclosure: 'N unchanged fields',
  /** EXPERIENCE.md:270 */
  proposalExampleCardTitle: 'Example \u2014 this is what a proposal looks like',
  /** EXPERIENCE.md:271 */
  agentIdleGreeting: 'I\'m ready. Ask about this screen, or try one of these.',
  /** EXPERIENCE.md:271 */
  agentIdleSelectionHint: 'Click a row to select it; click its name to open it.',
  /** EXPERIENCE.md:272 */
  toolCallStoppedByYou: 'Stopped by you at <step>',
  /** EXPERIENCE.md:273 */
  agentTurnStoppedBanner: 'The turn stopped at <step>: <reason>.',
  /** EXPERIENCE.md:274 */
  agentTurnLockBanner: 'A turn is in progress. Wait for it to finish before sending another message.',
  /** EXPERIENCE.md:275 */
  agentNavigationAnnouncement: 'I\'m opening <screen> for <entity> \u2014 use Back to return.',
  /** EXPERIENCE.md:275 */
  agentNavigationHeadingAnnouncement: '<title> \u2014 opened by the agent; Back returns',
  /** EXPERIENCE.md:276 */
  agentAuditFollowUpQuestion: 'Shall I show you the audit entry?',
  /** EXPERIENCE.md:277 */
  agentGateReminderBanner: 'No agent definition is enabled. Configure one in Agent co-pilot \u203a Definitions.',
  /** EXPERIENCE.md:278 */
  agentGateLandingBanner: 'OcuPilot needs one agent definition before the panel can help. Anthropic is selected \u2014 paste a key and press Test connection. You can skip this and browse.',
  /** EXPERIENCE.md:279 */
  agentGateEmptyState: 'The agent isn\'t configured yet. An OcuPilot administrator can enable a definition in Agent co-pilot \u203a Definitions.',
  /** EXPERIENCE.md:280 */
  agentReadOnlyEnforcedBanner: 'Read-only mode is enforced on this instance. The agent can read and explain, not change.',
  /** EXPERIENCE.md:281 */
  agentKillSwitchBanner: 'The agent is switched off for <everyone / you>: <reason>.',
  /** EXPERIENCE.md:282 */
  statusReadOnlyOff: 'Read-only: off',
  /** EXPERIENCE.md:282 */
  statusReadOnlyEnforced: 'Read-only: on \u2014 enforced on this instance',
  /** EXPERIENCE.md:282 */
  statusReadOnlyForYou: 'Read-only: on \u2014 for you',
  /** EXPERIENCE.md:282 */
  statusReadOnlyByDefinition: 'Read-only: on \u2014 by the definition',
  /** EXPERIENCE.md:283 */
  tableChangeToastLink: 'Open in <screen>',
  /** EXPERIENCE.md:284 */
  statusAutoRefreshOff: 'Auto-refresh: off',
  /** EXPERIENCE.md:284 */
  statusAutoRefreshOn: 'Auto-refresh: every 10 s',
  /** EXPERIENCE.md:284 */
  statusAutoRefreshPaused: 'Auto-refresh paused \u2014 a proposal is awaiting confirmation',
  /** EXPERIENCE.md:284 */
  statusLastUpdate: 'Last update hh:mm:ss',
  /** EXPERIENCE.md:285 */
  tableChangedTag: 'Changed',
  /** EXPERIENCE.md:286 */
  privilegeRequiresResource: 'Requires <resource>',
  /** EXPERIENCE.md:286 */
  privilegeSelectRowFirst: 'Select a row first',
  /** EXPERIENCE.md:287 */
  formTypedNameConfirm: 'Type <name> to confirm',
  /** EXPERIENCE.md:287 */
  formTypedNameMismatch: 'Does not match',
  /** EXPERIENCE.md:288 */
  formSecretStored: 'Stored. Enter a new value to replace it.',
  /** EXPERIENCE.md:289 */
  formTestConnectionResult: 'Connected. Reply: <the model\'s first words>',
  /** EXPERIENCE.md:289 */
  formTestConnectionFailure: 'The provider refused the request. Check the key and try again. Provider said: <text>',
  /** EXPERIENCE.md:289 */
  formSavedPendingTest: 'Saved \u2014 disabled until Test connection passes.',
  /** EXPERIENCE.md:290 */
  formSaved: 'Saved',
  /** EXPERIENCE.md:290 */
  formGoToHome: 'Go to Home',
  /** EXPERIENCE.md:290 */
  formLeaveWithoutSaving: 'Leave without saving?',
  /** EXPERIENCE.md:291 */
  authSignInFailed: 'Sign-in failed. Check the user name and password.',
  /** EXPERIENCE.md:291 */
  authPasswordExpired: 'The password for <user> has expired. Change it in the classic portal, or run the command in the README to clear the expiry.',
  /** EXPERIENCE.md:291 */
  authSessionEnded: 'Your session ended. Sign in to continue.',
  /** EXPERIENCE.md:291 */
  authSignedOut: 'You\'re signed out.',
  /** EXPERIENCE.md:291 */
  fieldUserName: 'User name',
  /** EXPERIENCE.md:291 */
  fieldPassword: 'Password',
  /** EXPERIENCE.md:292 */
  taskManagerSuspendedBanner: 'The Task Manager is suspended \u2014 no scheduled task will run until it is resumed.',
  /** EXPERIENCE.md:293 */
  classicLinkCardTitle: 'More in the classic portal',
  /** EXPERIENCE.md:294 */
  commandBoxPlaceholder: 'Search screens and commands',
  /** EXPERIENCE.md:294 */
  commandBoxNoMatch: 'No screen or action matches.',
  /** EXPERIENCE.md:294 */
  commandBoxResultCount: '<n> screens, <m> actions',
  /** EXPERIENCE.md:295 */
  agentComposerCaption: 'Enter to send \u00b7 Shift+Enter for a new line \u00b7 Ctrl+I to focus',
  /** EXPERIENCE.md:296 */
  navRailItemTooltip: '<Area> \u00b7 Ctrl+B toggles the side bar',
  /** EXPERIENCE.md:297 */
  agentComposerLabel: 'Message to the agent',
  /** EXPERIENCE.md:297 */
  agentShareContextLabel: 'Share screen context',
  /** EXPERIENCE.md:298 */
  tableRowCapNotice: 'Showing the first 1,000 rows. Narrow the filter or raise the max rows.',
  /** EXPERIENCE.md:299 */
  tableWriteCapableEmptyState: 'Or ask the agent: <a write it could propose here>.',
  /** EXPERIENCE.md:300 */
  homeStarterPromptExplainScreen: 'What\'s on this screen, and what should I look at first?',
  /** EXPERIENCE.md:300 */
  homeStarterPromptExplainLog: 'Explain the most recent entries in messages.log.',
  /** EXPERIENCE.md:300 */
  homeStarterPromptChangeOneThing: 'If you could change one thing on this instance, what would it be, and why?',
  /** EXPERIENCE.md:301 */
  proposalExpectedImpactExample: 'users holding %Development can reach the application',
  /** EXPERIENCE.md:302 */
  auditMarkerDescription: 'marked as coming through the OcuPilot agent co-pilot',

  // Not from the Fixed strings table, but required verbatim by this story's task
  // list: the audit-marker-failure fallback text (AD-15 / EXPERIENCE.md:207), the
  // reduced-motion word that replaces a running spinner (EXPERIENCE.md:590), and
  // the product name (never typeset as the wordmark -- DESIGN.md -- but an ordinary
  // word wherever running text or a document <title> needs it).
  auditMarkerFailed: 'done \u00b7 audit not marked',
  accessibilityReducedMotionSpinnerWord: 'running',
  productName: 'OcuPilot',

  // The version-mismatch notice's sentence. It is a Fixed strings table row (:253), so it
  // ships like every other key here and not the way the three above do -- nothing names it
  // in `ui/tools/strings.test.mjs`'s REQUIRED_ALONGSIDE_TABLE. EXPERIENCE.md also
  // illustrates it in a State Patterns row at :428, where the version is spelled out as
  // "1"; the table's `<n>` is what is transcribed here, and the component substitutes the
  // reported version. The apostrophe is ASCII U+0027, transcribed byte for byte: a
  // typographic quote would respell the string.
  authAdminApiVersionMismatch: 'This instance\'s admin API is version <n>; OcuPilot needs version 2.',

} as const;
