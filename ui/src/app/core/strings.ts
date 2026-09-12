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
 *   `accessibilityReducedMotionSpinnerWord` ("running", EXPERIENCE.md:591) and
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
  /** EXPERIENCE.md:254 */
  agentWriteBlockedByReadOnly: 'blocked by read-only mode',
  /** EXPERIENCE.md:255 */
  auditingOffBanner: 'Agent writes are not being marked. Auditing is off on this instance.',
  /** EXPERIENCE.md:255 */
  auditingConfigurationLink: 'Auditing configuration',
  /** EXPERIENCE.md:255 */
  auditingTurnOnAction: 'Turn auditing on',
  /** EXPERIENCE.md:256 */
  proposalTargetChanged: 'target changed, re-propose',
  /** EXPERIENCE.md:257 */
  contextChipLeavesInstance: 'leaves the instance',
  /** EXPERIENCE.md:257 */
  contextChipSentToHost: 'Screen context is sent to <host>',
  /** EXPERIENCE.md:258 */
  contextChipScreenSegment: 'Users, HSCUSTOM \u00b7 6 rows',
  /** EXPERIENCE.md:259 */
  contextChipSharingOff: 'Screen context off \u2014 nothing from this screen is sent.',
  /** EXPERIENCE.md:260 */
  connectivityInstanceUnreachable: 'instance unreachable',
  /** EXPERIENCE.md:260 */
  connectivityRequestRefused: 'request refused',
  /** EXPERIENCE.md:261 */
  statusConnectionSigningIn: 'Signing in\u2026',
  /** EXPERIENCE.md:261 */
  statusConnectionConnected: 'Connected',
  /** EXPERIENCE.md:261 */
  statusConnectionRetrying: 'Instance unreachable \u2014 retrying',
  /** EXPERIENCE.md:261 */
  statusConnectionSigningInAgain: 'Signing in again\u2026',
  /** EXPERIENCE.md:262 */
  agentExplainScreenAction: 'Explain this screen',
  /** EXPERIENCE.md:263 */
  actionTestConnection: 'Test connection',
  /** EXPERIENCE.md:263 */
  actionConfirm: 'Confirm',
  /** EXPERIENCE.md:263 */
  actionCancel: 'Cancel',
  /** EXPERIENCE.md:263 */
  actionSave: 'Save',
  /** EXPERIENCE.md:263 */
  actionResume: 'Resume',
  /** EXPERIENCE.md:263 */
  actionRun: 'Run',
  /** EXPERIENCE.md:263 */
  actionSuspend: 'Suspend',
  /** EXPERIENCE.md:263 */
  actionDelete: 'Delete',
  /** EXPERIENCE.md:263 */
  actionSend: 'Send',
  /** EXPERIENCE.md:263 */
  actionStop: 'Stop',
  /** EXPERIENCE.md:263 */
  actionNewConversation: 'New conversation',
  /** EXPERIENCE.md:263 */
  actionRepropose: 'Re-propose',
  /** EXPERIENCE.md:263 */
  actionSignOut: 'Sign out',
  /** EXPERIENCE.md:263 */
  actionSignIn: 'Sign in',
  /** EXPERIENCE.md:264 */
  proposalRationaleHeading: 'Agent\'s rationale',
  /** EXPERIENCE.md:264 */
  proposalExpectedImpactHeading: 'Expected impact',
  /** EXPERIENCE.md:265 */
  proposalReverseLabel: 'Reverse:',
  /** EXPERIENCE.md:266 */
  proposalCountdownLabel: 'Expires in m:ss',
  /** EXPERIENCE.md:266 */
  proposalCountdownTooltip: 'Proposals expire so a stale diff is never applied.',
  /** EXPERIENCE.md:266 */
  proposalCountdownAnnouncement: 'One minute left to confirm',
  /** EXPERIENCE.md:267 */
  proposalFooterConfirmHint: 'Confirm here; sending a message cancels this proposal',
  /** EXPERIENCE.md:267 */
  proposalFooterRunsAs: 'Runs as <user name>, with your privileges.',
  /** EXPERIENCE.md:268 */
  proposalConfirmSentence: 'Press Confirm on the card to apply it.',
  /** EXPERIENCE.md:269 */
  proposalStatusConfirmedBy: 'Confirmed by <user name> \u00b7 hh:mm:ss',
  /** EXPERIENCE.md:269 */
  proposalStatusCanceledByYou: 'Canceled \u2014 by you',
  /** EXPERIENCE.md:269 */
  proposalStatusCanceledByMessage: 'Canceled \u2014 by your message',
  /** EXPERIENCE.md:269 */
  proposalStatusCanceledSibling: 'Canceled \u2014 a sibling proposal was confirmed',
  /** EXPERIENCE.md:269 */
  proposalStatusExpired: 'Expired',
  /** EXPERIENCE.md:269 */
  proposalStatusAgentSwitchedOff: 'The agent is switched off',
  /** EXPERIENCE.md:270 */
  proposalUnchangedFieldsDisclosure: 'N unchanged fields',
  /** EXPERIENCE.md:271 */
  proposalExampleCardTitle: 'Example \u2014 this is what a proposal looks like',
  /** EXPERIENCE.md:272 */
  agentIdleGreeting: 'I\'m ready. Ask about this screen, or try one of these.',
  /** EXPERIENCE.md:272 */
  agentIdleSelectionHint: 'Click a row to select it; click its name to open it.',
  /** EXPERIENCE.md:273 */
  toolCallStoppedByYou: 'Stopped by you at <step>',
  /** EXPERIENCE.md:274 */
  agentTurnStoppedBanner: 'The turn stopped at <step>: <reason>.',
  /** EXPERIENCE.md:275 */
  agentTurnLockBanner: 'A turn is in progress. Wait for it to finish before sending another message.',
  /** EXPERIENCE.md:276 */
  agentNavigationAnnouncement: 'I\'m opening <screen> for <entity> \u2014 use Back to return.',
  /** EXPERIENCE.md:276 */
  agentNavigationHeadingAnnouncement: '<title> \u2014 opened by the agent; Back returns',
  /** EXPERIENCE.md:277 */
  agentAuditFollowUpQuestion: 'Shall I show you the audit entry?',
  /** EXPERIENCE.md:278 */
  agentGateReminderBanner: 'No agent definition is enabled. Configure one in Agent co-pilot \u203a Definitions.',
  /** EXPERIENCE.md:279 */
  agentGateLandingBanner: 'OcuPilot needs one agent definition before the panel can help. Anthropic is selected \u2014 paste a key and press Test connection. You can skip this and browse.',
  /** EXPERIENCE.md:280 */
  agentGateEmptyState: 'The agent isn\'t configured yet. An OcuPilot administrator can enable a definition in Agent co-pilot \u203a Definitions.',
  /** EXPERIENCE.md:281 */
  agentReadOnlyEnforcedBanner: 'Read-only mode is enforced on this instance. The agent can read and explain, not change.',
  /** EXPERIENCE.md:282 */
  agentKillSwitchBanner: 'The agent is switched off for <everyone / you>: <reason>.',
  /** EXPERIENCE.md:283 */
  statusReadOnlyOff: 'Read-only: off',
  /** EXPERIENCE.md:283 */
  statusReadOnlyEnforced: 'Read-only: on \u2014 enforced on this instance',
  /** EXPERIENCE.md:283 */
  statusReadOnlyForYou: 'Read-only: on \u2014 for you',
  /** EXPERIENCE.md:283 */
  statusReadOnlyByDefinition: 'Read-only: on \u2014 by the definition',
  /** EXPERIENCE.md:284 */
  tableChangeToastLink: 'Open in <screen>',
  /** EXPERIENCE.md:285 */
  statusAutoRefreshOff: 'Auto-refresh: off',
  /** EXPERIENCE.md:285 */
  statusAutoRefreshOn: 'Auto-refresh: every 10 s',
  /** EXPERIENCE.md:285 */
  statusAutoRefreshPaused: 'Auto-refresh paused \u2014 a proposal is awaiting confirmation',
  /** EXPERIENCE.md:285 */
  statusLastUpdate: 'Last update hh:mm:ss',
  /** EXPERIENCE.md:286 */
  tableChangedTag: 'Changed',
  /** EXPERIENCE.md:287 */
  privilegeRequiresResource: 'Requires <resource>',
  /** EXPERIENCE.md:287 */
  privilegeSelectRowFirst: 'Select a row first',
  /** EXPERIENCE.md:288 */
  formTypedNameConfirm: 'Type <name> to confirm',
  /** EXPERIENCE.md:288 */
  formTypedNameMismatch: 'Does not match',
  /** EXPERIENCE.md:289 */
  formSecretStored: 'Stored. Enter a new value to replace it.',
  /** EXPERIENCE.md:290 */
  formTestConnectionResult: 'Connected. Reply: <the model\'s first words>',
  /** EXPERIENCE.md:290 */
  formTestConnectionFailure: 'The provider refused the request. Check the key and try again. Provider said: <text>',
  /** EXPERIENCE.md:290 */
  formSavedPendingTest: 'Saved \u2014 disabled until Test connection passes.',
  /** EXPERIENCE.md:291 */
  formSaved: 'Saved',
  /** EXPERIENCE.md:291 */
  formGoToHome: 'Go to Home',
  /** EXPERIENCE.md:291 */
  formLeaveWithoutSaving: 'Leave without saving?',
  /** EXPERIENCE.md:292 */
  authSignInFailed: 'Sign-in failed. Check the user name and password.',
  /** EXPERIENCE.md:292 */
  authPasswordExpired: 'The password for <user> has expired. Change it in the classic portal, or run the command in the README to clear the expiry.',
  /** EXPERIENCE.md:292 */
  authSessionEnded: 'Your session ended. Sign in to continue.',
  /** EXPERIENCE.md:292 */
  authSignedOut: 'You\'re signed out.',
  /** EXPERIENCE.md:292 */
  fieldUserName: 'User name',
  /** EXPERIENCE.md:292 */
  fieldPassword: 'Password',
  /** EXPERIENCE.md:293 */
  taskManagerSuspendedBanner: 'The Task Manager is suspended \u2014 no scheduled task will run until it is resumed.',
  /** EXPERIENCE.md:294 */
  classicLinkCardTitle: 'More in the classic portal',
  /** EXPERIENCE.md:295 */
  commandBoxPlaceholder: 'Search screens and commands',
  /** EXPERIENCE.md:295 */
  commandBoxNoMatch: 'No screen or action matches.',
  /** EXPERIENCE.md:295 */
  commandBoxResultCount: '<n> screens, <m> actions',
  /** EXPERIENCE.md:296 */
  agentComposerCaption: 'Enter to send \u00b7 Shift+Enter for a new line \u00b7 Ctrl+I to focus',
  /** EXPERIENCE.md:297 */
  navRailItemTooltip: '<Area> \u00b7 Ctrl+B toggles the side bar',
  /** EXPERIENCE.md:298 */
  agentComposerLabel: 'Message to the agent',
  /** EXPERIENCE.md:298 */
  agentShareContextLabel: 'Share screen context',
  /** EXPERIENCE.md:299 */
  tableRowCapNotice: 'Showing the first 1,000 rows. Narrow the filter or raise the max rows.',
  /** EXPERIENCE.md:300 */
  tableWriteCapableEmptyState: 'Or ask the agent: <a write it could propose here>.',
  /** EXPERIENCE.md:301 */
  homeStarterPromptExplainScreen: 'What\'s on this screen, and what should I look at first?',
  /** EXPERIENCE.md:301 */
  homeStarterPromptExplainLog: 'Explain the most recent entries in messages.log.',
  /** EXPERIENCE.md:301 */
  homeStarterPromptChangeOneThing: 'If you could change one thing on this instance, what would it be, and why?',
  /** EXPERIENCE.md:302 */
  proposalExpectedImpactExample: 'users holding %Development can reach the application',
  /** EXPERIENCE.md:303 */
  auditMarkerDescription: 'marked as coming through the OcuPilot agent co-pilot',

  // Not from the Fixed strings table, but required verbatim by this story's task
  // list: the audit-marker-failure fallback text (AD-15 / EXPERIENCE.md:207), the
  // reduced-motion word that replaces a running spinner (EXPERIENCE.md:591), and
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

  // The eight area names, in the rail's own daily-use order. They are not in the Fixed
  // strings table, which carries no row naming an area -- but they are not new copy either:
  // the table's `navRailItemTooltip` is "<Area> · Ctrl+B toggles the side bar", and these
  // eight are the domain of that `<Area>`, enumerated verbatim in EXPERIENCE.md's
  // Information Architecture. `ui/tools/strings.test.mjs` authorizes them by extracting that
  // line, the same shape it extracts the table with, in a category of its own -- never by
  // being added to REQUIRED_ALONGSIDE_TABLE, whose own comment calls that the bypass it must
  // not become. They resolve the tooltip's placeholder, name the rail items, the side bar's
  // landmark and eyebrow, and Home's own title.
  navAreaHome: 'Home',
  navAreaLogs: 'Logs',
  navAreaOsManagement: 'OS management',
  navAreaTasks: 'Tasks',
  navAreaPermissions: 'Permissions',
  navAreaWebApplications: 'Web applications and REST API explorer',
  navAreaSecurity: 'Security and secrets',
  navAreaAgent: 'Agent co-pilot',

  // The two navigation landmarks' accessible names, transcribed from EXPERIENCE.md's
  // Accessibility Floor -- "rail and side-bar = navigation (named "Areas" and "<Area>
  // screens")". Like the eight names above they are authorized by extraction rather than by
  // being named in `REQUIRED_ALONGSIDE_TABLE`, and the side bar's `<Area>` is resolved in
  // TypeScript from the same area name the rail renders.
  navRailLandmark: 'Areas',
  navSideBarLandmark: '<Area> screens',

  // Story 1.10's seven, every one re-derived from a UX document by its own targeted
  // extractor in `ui/tools/strings.test.mjs` -- the mechanism Story 1.9 established for the
  // eight area names, never by being added to REQUIRED_ALONGSIDE_TABLE, whose own comment
  // calls that the bypass it must not become.
  //
  // The locator bar's landmark name, from the same Landmarks line the two above come from:
  // "locator-bar = navigation "Breadcrumb"".
  navLocatorLandmark: 'Breadcrumb',

  // The namespace switch's accessible name (EXPERIENCE.md:315, "accessible name
  // "Namespace""). This story renders it as the slot's eyebrow; Story 1.11 turns the slot
  // into the select the same name labels.
  headerNamespaceLabel: 'Namespace',

  // The header lockup's accessible name (EXPERIENCE.md:316). The separator is an em dash,
  // authored as its escape (Rule 14); `epics.md:1350` renders the same name with a hyphen,
  // and EXPERIENCE.md is the authority for every word here. DESIGN.md:287 spells the alt
  // text "OcuPilot" instead -- filed, not reconciled in a component.
  headerHomeLink: 'OcuPilot \u2014 Home',

  // The four server-flag words (EXPERIENCE.md:319, DESIGN.md:1025). The word is always
  // present, never colour alone; an instance with no mode set gets no badge rather than a
  // fifth word (DW-10).
  serverFlagLive: 'Live',
  serverFlagTest: 'Test',
  serverFlagFailover: 'Failover',
  serverFlagDevelopment: 'Development',

  // Story 1.13's four, all published in EXPERIENCE.md but outside the Fixed strings table, so
  // each is authorized by its own targeted extractor in `ui/tools/strings.test.mjs` -- the
  // mechanism Story 1.9 established for the eight area names, never by being added to
  // REQUIRED_ALONGSIDE_TABLE, whose own comment calls that the bypass it must not become.
  //
  // The unreachable banner's body, published twice and identically: the Voice and Tone table's
  // *Do* column (:233) and the Instance-unreachable State Patterns row (:436). The extractor
  // reads :436 and asserts :233 carries the same sentence, so the two cannot drift apart
  // unnoticed. Every character is ASCII, so no escape is needed (Rule 14 still applies to any
  // later edit).
  connectivityBannerUnreachable: 'The instance is unreachable. Check that IRIS is running, then retry.',

  // The generic server-fault body, from the Generic-internal-error State Patterns row (:438).
  // The browser is told this and nothing more; the detail is on the instance (AD-12, AD-39).
  connectivityServerFault: 'Something failed on the instance. Retry; if it keeps failing, check messages.log.',

  // The two controls those rows name. They are absent from the Fixed strings table's action-names
  // row (:263), so they are taken verbatim from the rows that publish them (:436 and :438)
  // rather than invented -- filed as a DW-126 occurrence, not added to the table here.
  actionRetry: 'Retry',
  actionOpenMessagesLog: 'Open messages.log',

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
