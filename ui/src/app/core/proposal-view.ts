/**
 * The proposal card's framework-free half (Story 5.2, AD-19): the map from what the wire sends
 * onto what the card draws, the countdown's formatter and its phase boundaries, and the phase
 * vocabulary the footer's status line is chosen from.
 *
 * It imports no `@angular/core`, so `ui/tools/proposal-view.test.mjs` executes every function
 * below under `node --test`; `shell/proposal-card.ts` mirrors them into getters over its inputs
 * the way `tool-call-card.ts` already mirrors `stepLabel`.
 *
 * **The clock is injected, never read here.** Every countdown function takes the moment as a
 * number, so a test drives 1:00 and 0:00 by hand and no assertion waits on a wall clock.
 *
 * **The instance owns the diff.** `toCardView` maps field by field and writes no value of its
 * own: `ui/tools/proposal.test.mjs`'s literal scan fails the gate on any proposal field assigned
 * a literal in a shipped module, which is the mechanical form of "the client authors no proposal"
 * (AD-6).
 *
 * **The screen's two facts arrive as parameters, not as a module-level lookup.** The singular
 * entity noun and the declared secret argument names both come from the screen mirror, and
 * reading `screens.generated.ts` here would tie the masked field's tests to whichever descriptor
 * declares a secret, so a test supplies a screen record as data.
 */

import type { Impact } from './impact.ts';
import { STRINGS } from './strings.ts';
import type { TurnProposal, TurnProposalPrivilege, TurnProposalUnchangedRow } from './turn.ts';

/**
 * One changed field, as the card draws it: the label, the before value and the after value.
 *
 * `removed` marks a **removal row** -- a delete proposal has no after-state, so the row shows the
 * target's identifying field and its value and the card draws the removed marker in place of the
 * after value (AD-48). It is the instance's own flag, like every other value here.
 */
export interface ProposalDiffRow {
  readonly field: string;
  readonly before: string;
  readonly after: string;
  readonly removed?: boolean;
  /** The `STRINGS` key an empty value of this field reads as, the tool's own declaration (DW-1016). */
  readonly emptyKey?: string;
}

/**
 * One unchanged field, as the card draws it: the label and the one value. No direction, because
 * the payload sends this field exactly as the instance holds it (FR-17).
 */
export interface ProposalUnchangedRow {
  readonly field: string;
  readonly value: string;
  /** As on a changed row (DW-1016). */
  readonly emptyKey?: string;
}

/**
 * Everything a proposal card renders. The six fields the static example fills are required; the
 * five a live card adds are optional, so `shell/example-proposal.ts`'s own fixture -- whose key
 * set `ui/tools/example-proposal.test.mjs` pins -- carries none of them and the example has no
 * countdown, no footer and no masked field by construction rather than by a flag.
 */
export interface ProposalCardView {
  /** The kind of thing the write is about, as the instance names it ("Web application"). */
  readonly entityType: string;
  /**
   * The write's own entity type as the wire spells it (`application-error`), which is what the
   * residue sentence is gated on (DW-1480). `entityType` above is the published noun the title
   * reads and is a different fact: two screens can spell one type's noun two ways, and the card
   * routes on the type rather than on the word.
   */
  readonly targetType?: string;
  /** The target's own name, as the instance stores it ("/csp/myapp"). */
  readonly name: string;
  /**
   * The name the title reads where `name` is an id rather than a name (a task's numeric id), or
   * `''`; `cardTitleName` answers the one the title shows.
   */
  readonly targetName?: string;
  /** The changed fields, first in the card and one `diff-row` each. */
  readonly changed: readonly ProposalDiffRow[];
  /** How many fields the payload also sends unchanged (AD-4), for the collapsed caption. */
  readonly unchangedCount: number;
  /** The agent's own words, rendered under their published headings and on the agent tint. */
  readonly rationale: string;
  readonly expectedImpact: string;
  /** How to undo the write, or `''` where no reversal exists (a delete has none). */
  readonly reverse: string;
  /** The proposal's own id, absent for the static example, which is not a proposal. */
  readonly proposalId?: string;
  /** When it stops being confirmable, in epoch milliseconds, or `0` for an unreadable timestamp. */
  readonly expiresAt?: number;
  /**
   * The fields the payload also sends unchanged, one value each and no arrow, listed when the
   * disclosure is open (DW-1223). The instance projects them from the payload it stored and masks
   * every value its tool's own classification does not admit, so nothing here renders or unmasks
   * one; the disclosure is a button exactly when there is something behind it, which is why the
   * static example -- which is not a proposal and carries no rows -- has none.
   */
  readonly unchanged?: readonly ProposalUnchangedRow[];
  /** The secret argument names the user fills before Confirm (AD-3, AD-6). */
  readonly maskedFields?: readonly string[];
  /**
   * The names among `maskedFields` the tool declares optional, which Confirm does not wait for: the
   * instance's own per-row declaration (`optional` on the diff row), never a guess from the name.
   */
  readonly optionalFields?: readonly string[];
  /** Whether this write would stop the instance marking agent writes (AD-15). */
  readonly auditWarning?: boolean;
  /**
   * Whether the tool declared its write destructive, which the card reads for its left-edge bar
   * and its Confirm (DESIGN.md's `button-destructive`). It is the wire's own value, projected the
   * way `auditWarning` is: the declaration is the tool's and no list of tool names exists here.
   */
  readonly destructive?: boolean;
  /**
   * The written `reason` of the refusal this proposal's last decision met, or `''` (DW-1348).
   *
   * It is the server's own sentence, carried through unchanged (AD-39): a prohibited or restrained
   * confirm leaves the row **live**, so nothing about the row says the press was refused and the
   * card would otherwise return to offering Confirm with no trace. The client authors none of this
   * copy and invents no phase -- the row is still live, and a phase is a terminal state.
   */
  readonly refusalReason?: string;
  /**
   * The kernel's code for what the write does beyond its diff, or `''`; the wire's own value,
   * projected the way `auditWarning` is. The card reads it through `consequenceSentence`.
   */
  readonly consequence?: string;
  /**
   * The privilege line (AD-8), filled from the wire's own `privilege`, or `null` when the proposal
   * recorded no pairs. The card shows it only while Confirm does; it gates nothing.
   */
  readonly privilege?: ProposalPrivilegeLine | null;
  /**
   * The removal's impact (AD-8), the wire's own value read at the mint, or `null` when the write
   * removes nothing covered. The card shows its line only while Confirm does; it gates nothing.
   */
  readonly impact?: Impact | null;
}

/** The privilege line as the card draws it: the filled sentence, and whether it is the warning. */
export interface ProposalPrivilegeLine {
  readonly text: string;
  readonly missing: boolean;
}

/** The consequence the kernel marks a web-application create that admits unauthenticated access with. */
export const CONSEQUENCE_UNAUTHENTICATED = 'WEBAPP.UNAUTHENTICATED';

/** The consequence the kernel marks a write that grants %All or an administrative privilege with (AD-10). */
export const CONSEQUENCE_PRIVILEGED = 'GRANT.PRIVILEGED';

/** The one consequence a web-application create carries when it is both unauthenticated and privileged. */
export const CONSEQUENCE_UNAUTHENTICATED_PRIVILEGED = 'WEBAPP.UNAUTHENTICATEDPRIVILEGED';

/** The consequence the kernel marks a change clearing a web application's resource with (AD-10). */
export const CONSEQUENCE_NORESOURCE = 'WEBAPP.NORESOURCE';

/** The consequence the kernel marks a change repointing a web application's code with (AD-10). */
export const CONSEQUENCE_REPOINTED = 'WEBAPP.REPOINTED';

/** The consequence the kernel marks a change turning an SSL/TLS configuration's peer verification off with (AD-10). */
export const CONSEQUENCE_NOPEERCHECK = 'SSL.NOPEERCHECK';

/** The consequence the kernel marks a task create that runs as another account with (AD-10, Story 9.7). */
export const CONSEQUENCE_RUNSASOTHER = 'TASK.RUNSASOTHER';

/** The consequence the kernel marks a change to the addresses or methods of the service OcuPilot is served through with (AD-10, Story 9.9). */
export const CONSEQUENCE_SERVESOCUPILOT = 'SERVICE.SERVESOCUPILOT';

/** The consequence the kernel marks a change letting any other service admit unauthenticated connections with (AD-10, Story 9.9). */
export const CONSEQUENCE_SERVICEUNAUTHENTICATED = 'SERVICE.UNAUTHENTICATED';

/** The consequence the kernel marks an added service mapping another resource server holds with: the add moves it (Story 12.6). */
export const CONSEQUENCE_MAPPINGMOVE = 'OAUTH.MAPPINGMOVE';

/** The consequence the kernel marks a resource server edit naming another authenticator namespace or class with: the settings it does not send take the new class's defaults (Story 12.6). */
export const CONSEQUENCE_AUTHENTICATORRESET = 'OAUTH.AUTHENTICATORRESET';

/** The consequences the kernel marks a write to the authorization server configuration with (Story 12.7): it reaches every registered client, or deletes them, each also for an account that cannot list them; its customization roles add %All or an %Admin_ role; and the two combined. */
export const CONSEQUENCE_SERVERCLIENTS = 'OAUTH.SERVERCLIENTS';

export const CONSEQUENCE_SERVERCLIENTSHIDDEN = 'OAUTH.SERVERCLIENTSHIDDEN';

export const CONSEQUENCE_SERVERCLIENTSDELETED = 'OAUTH.SERVERCLIENTSDELETED';

export const CONSEQUENCE_SERVERCLIENTSDELETEDHIDDEN = 'OAUTH.SERVERCLIENTSDELETEDHIDDEN';

export const CONSEQUENCE_CUSTOMIZATIONPRIVILEGED = 'OAUTH.CUSTOMIZATIONPRIVILEGED';

export const CONSEQUENCE_SERVERCLIENTSPRIVILEGED = 'OAUTH.SERVERCLIENTSPRIVILEGED';

export const CONSEQUENCE_SERVERCLIENTSHIDDENPRIVILEGED = 'OAUTH.SERVERCLIENTSHIDDENPRIVILEGED';

/** Story 12.8: a server client's new secret, which its application must use from then on. */
export const CONSEQUENCE_SERVERCLIENTSECRETCHANGE = 'OAUTH.SERVERCLIENTSECRETCHANGE';

/** Story 14.2: the agent's audit purge, which removes the markers of the agent's own writes too. */
export const CONSEQUENCE_PURGEMARKERS = 'AUDIT.PURGEMARKERS';

/** Story 18.14: a global mapping whose name begins with `%`, which shadows a system global (AD-10). */
export const CONSEQUENCE_SYSTEMGLOBAL = 'MAPPING.SYSTEMGLOBAL';

/** Story 20.18: an agent change to a screen's permissions that drops a pair the screen required (AD-64). */
export const CONSEQUENCE_SCREENACCESSLOWERED = 'SCREENACCESS.LOWERED';

/** Story 18.14: a copy of mappings, which replaces the destination's same-named mappings. */
export const CONSEQUENCE_COPYMAPPINGS = 'NAMESPACE.COPYMAPPINGS';

/** Story 16.4: a task export, which replaces a file already at its name. */
export const CONSEQUENCE_TASKEXPORTREPLACES = 'TASK.EXPORT.REPLACES';

/** Story 19.13: a System Explorer export to a server file, which replaces a file already at its name. */
export const CONSEQUENCE_EXPLOREREXPORTREPLACES = 'EXPLORER.EXPORT.REPLACES';

/** Story 19.13: a System Explorer import, which replaces each document of the same name. */
export const CONSEQUENCE_EXPLORERIMPORTREPLACES = 'EXPLORER.IMPORT.REPLACES';

/**
 * Story 19.11: an agent-proposed SQL statement, by the kind the instance classified it, each stated as the
 * SQL query console's own confirmation states it. `consequenceSentence` answers `''` for the DML code,
 * whose sentence names the statement's tables; the card states it through `sqlConsequenceSentence`.
 */
export const CONSEQUENCE_SQLCHANGESROWS = 'EXPLORER.SQL.CHANGESROWS';
export const CONSEQUENCE_SQLCHANGESSCHEMA = 'EXPLORER.SQL.CHANGESSCHEMA';
export const CONSEQUENCE_SQLRUNSPROCEDURE = 'EXPLORER.SQL.RUNSPROCEDURE';
export const CONSEQUENCE_SQLUNDECLARED = 'EXPLORER.SQL.UNDECLARED';

/** The field an agent-proposed SQL statement's diff names the statement's tables in. */
const SQL_TABLES_FIELD = 'Tables';

/**
 * The card's sentence for a DML statement the agent proposed, or `''` for any other consequence: the
 * console's own sentence with `<tables>` filled from the proposal's `Tables` row, the tables the instance
 * recorded for the statement. The value is inserted through a replacer, so a name holding a placeholder is
 * shown as written.
 */
export function sqlConsequenceSentence(view: Pick<ProposalCardView, 'consequence' | 'changed'>): string {
  if (view.consequence !== CONSEQUENCE_SQLCHANGESROWS) return '';
  const tables = view.changed.find((row) => row.field === SQL_TABLES_FIELD)?.after ?? '';
  return STRINGS.explorerSqlConfirmDml.replace('<tables>', () => tables);
}

/** Story 16.25, AD-4: a change to a Python language server's own settings, which resets two the read never shows. */
export const CONSEQUENCE_PYTHONCUSTOM = 'LANGUAGESERVER.PYTHONCUSTOM';

/** Story 16.11: suspending the Task Manager, after which no scheduled task runs until it is resumed. */
export const CONSEQUENCE_TASKMANAGERSUSPEND = 'TASK.MANAGER.SUSPEND';

/** Story 16.12: removing a lock whose owner is in an open transaction, which it leaves running without it. */
export const CONSEQUENCE_LOCKINTRANSACTION = 'LOCK.INTRANSACTION';

/** Story 18.15: an enable of interoperability, which on IRIS for Health changes the whole instance. */
export const CONSEQUENCE_NAMESPACEINTEROP = 'NAMESPACE.INTEROP';

/**
 * Story 18.16: a remote database create or re-point, whose confirm lists the data server's databases
 * before it writes. `consequenceSentence` answers `''` for it; the card states it through
 * `remoteListSentence`, which names the data server the proposal sends.
 */
export const CONSEQUENCE_REMOTELIST = 'DATABASE.REMOTELIST';

/** The bound the confirm's listing waits for, in seconds: `RemoteDatabasePort`'s `LISTSECONDS`. */
export const REMOTE_DATABASE_LIST_SECONDS = 20;

/** The field a remote database proposal names its data server in. */
const REMOTE_SERVER_FIELD = 'Server';

/**
 * The card's bound sentence for a remote database proposal (AD-21's seventh case), or `''` for any
 * other consequence: the data server is the proposal's own `Server` value -- a changed row's after
 * value, else an unchanged row's -- and the bound is `REMOTE_DATABASE_LIST_SECONDS`. Each value is
 * inserted through a replacer, so a name holding a placeholder is shown as written.
 */
export function remoteListSentence(view: Pick<ProposalCardView, 'consequence' | 'changed' | 'unchanged'>): string {
  if (view.consequence !== CONSEQUENCE_REMOTELIST) return '';
  const changed = view.changed.find((row) => row.field === REMOTE_SERVER_FIELD);
  const unchanged = (view.unchanged ?? []).find((row) => row.field === REMOTE_SERVER_FIELD);
  const server = changed !== undefined ? changed.after : (unchanged?.value ?? '');
  return STRINGS.remoteDatabaseListConsequence
    .replace('<server>', () => server)
    .replace('<n>', () => String(REMOTE_DATABASE_LIST_SECONDS));
}

/**
 * Story 18.5: Journals' three writes, each stating its warning dialog's own sentence on the card.
 * `consequenceSentence` answers `''` for them; the card states each through `journalSentence`, which
 * names the file.
 */
export const CONSEQUENCE_JOURNALSWITCHFILE = 'JOURNAL.SWITCHFILE';
export const CONSEQUENCE_JOURNALSWITCHDIRECTORY = 'JOURNAL.SWITCHDIRECTORY';
export const CONSEQUENCE_JOURNALINTEGRITY = 'JOURNAL.INTEGRITY';

/** Story 18.18: a journal settings write that leaves Freeze on error on, stated as the form states it. */
export const CONSEQUENCE_JOURNALSETTINGSFREEZE = 'JOURNAL.SETTINGS.FREEZE';

/** Story 18.6: a license server delete while the instance's license key is a multi-server key. */
export const CONSEQUENCE_LICENSEMULTIKEY = 'LICENSE.SERVER.MULTIKEY';

/**
 * Story 18.20: an ECP data server status change -- Not connected or Disabled, which disconnects it,
 * and Normal, which connects this instance to it -- stated as the Change status dialog states it.
 */
export const CONSEQUENCE_ECPSTATUSDISCONNECT = 'ECP.STATUS.DISCONNECT';
export const CONSEQUENCE_ECPSTATUSCONNECT = 'ECP.STATUS.CONNECT';

/**
 * Story 18.21: an ECP settings write that changes the maximum number of application servers, which
 * takes effect only after a restart, and an SSL/TLS authorize or reject, each stated as its screen
 * states it.
 */
export const CONSEQUENCE_ECPSETTINGSRESTART = 'ECP.SETTINGS.RESTART';
export const CONSEQUENCE_ECPSSLAUTHORIZE = 'ECP.SSL.AUTHORIZE';
export const CONSEQUENCE_ECPSSLREJECT = 'ECP.SSL.REJECT';

/**
 * Story 18.7: a new encryption key, unique and lost with every key file holding it, and the removal of
 * a key from a key file, each stated as its screen states it.
 */
export const CONSEQUENCE_ENCRYPTIONNEWKEY = 'ENCRYPTION.KEYFILE.NEWKEY';
export const CONSEQUENCE_ENCRYPTIONREMOVEKEY = 'ENCRYPTION.KEYFILE.REMOVEKEY';

/**
 * Story 18.24: replacing an RSA key pair, and a symmetric key, each stated as the Secret form's
 * typed-name dialog states it.
 */
export const CONSEQUENCE_WALLETKEYREPLACERSA = 'WALLETKEY.REPLACE.RSA';
export const CONSEQUENCE_WALLETKEYREPLACESYMMETRIC = 'WALLETKEY.REPLACE.SYMMETRIC';

/**
 * Story 18.22: activating a key file's keys and deactivating one key, for database keys and for
 * data-element keys, each stated as its screen states it.
 */
export const CONSEQUENCE_ENCRYPTIONKEYACTIVATE = 'ENCRYPTION.KEY.ACTIVATE';
export const CONSEQUENCE_ENCRYPTIONKEYDEACTIVATE = 'ENCRYPTION.KEY.DEACTIVATE';
export const CONSEQUENCE_ENCRYPTIONKEYACTIVATEDATAELEMENT = 'ENCRYPTION.KEY.ACTIVATEDATAELEMENT';
export const CONSEQUENCE_ENCRYPTIONKEYDEACTIVATEDATAELEMENT = 'ENCRYPTION.KEY.DEACTIVATEDATAELEMENT';

/**
 * Story 18.23: the start mode an encryption startup settings write chooses, an IRISSECURITY or IRISTEMP
 * change, a journal encryption change and a change to the audit log's encryption, each stated as the form
 * states it.
 */
export const CONSEQUENCE_ENCRYPTIONSTARTUPNONE = 'ENCRYPTION.STARTUP.NONE';
export const CONSEQUENCE_ENCRYPTIONSTARTUPINTERACTIVE = 'ENCRYPTION.STARTUP.INTERACTIVE';
export const CONSEQUENCE_ENCRYPTIONSTARTUPUNATTENDED = 'ENCRYPTION.STARTUP.UNATTENDED';
export const CONSEQUENCE_ENCRYPTIONSTARTUPKMIP = 'ENCRYPTION.STARTUP.KMIP';
export const CONSEQUENCE_ENCRYPTIONSTARTUPRESTART = 'ENCRYPTION.STARTUP.RESTART';
export const CONSEQUENCE_ENCRYPTIONSTARTUPJOURNAL = 'ENCRYPTION.STARTUP.JOURNAL';
export const CONSEQUENCE_AUDITENCRYPTIONCHANGE = 'AUDIT.ENCRYPTIONCHANGE';

/** Story 18.8: a change to the JWT issuer or signature algorithm, which ends every token session. */
export const CONSEQUENCE_WEBAUTHSIGNOUT = 'WEBAUTH.SIGNOUT';

/** The consequence of an SSL/TLS change to the superserver the web gateway connects through (Story 18.25). */
export const CONSEQUENCE_SUPERSERVERSERVES = 'SUPERSERVER.SERVESOCUPILOT';
/** Story 20.2: the production actions that wait or recover (AD-62); each is one published sentence. */
export const CONSEQUENCE_INTEROPSTOP = 'INTEROP.STOP';
export const CONSEQUENCE_INTEROPRESTART = 'INTEROP.RESTART';
export const CONSEQUENCE_INTEROPUPDATE = 'INTEROP.UPDATE';
export const CONSEQUENCE_INTEROPRECOVER = 'INTEROP.RECOVER';

/** The consequences of a managed file transfer connection's delete and token revoke (Story 18.26). */
export const CONSEQUENCE_MFTDELETE = 'MFT.DELETE';
export const CONSEQUENCE_MFTREVOKE = 'MFT.REVOKE';

/** The field a switch file proposal's diff names the file the instance writes now in. */
const JOURNAL_CURRENT_FIELD = 'CurrentFile';

/**
 * The card's sentence for a journal proposal, or `''` for any other consequence: a switch file names
 * the file it closes, its `CurrentFile` row's before value; an integrity check names the file it
 * reads, the proposal's own target; a directory switch's sentence names no file, and its diff row
 * names the directory it moves to. Each value is inserted through a replacer, so a name holding a
 * placeholder is shown as written.
 */
export function journalSentence(view: Pick<ProposalCardView, 'consequence' | 'changed' | 'name'>): string {
  if (view.consequence === CONSEQUENCE_JOURNALSWITCHFILE) {
    const current = view.changed.find((row) => row.field === JOURNAL_CURRENT_FIELD)?.before ?? '';
    return STRINGS.journalSwitchFileConsequence.replace('<file>', () => current);
  }
  if (view.consequence === CONSEQUENCE_JOURNALSWITCHDIRECTORY) return STRINGS.journalSwitchDirectoryConsequence;
  if (view.consequence === CONSEQUENCE_JOURNALINTEGRITY) return STRINGS.journalIntegrityConsequence.replace('<file>', () => view.name);
  return '';
}

/**
 * The published sentence for a proposal's `consequence` code, or `''` for no code or one this
 * client publishes nothing for. The sentence is `STRINGS`'; the code is the kernel's (AD-39).
 */
export function consequenceSentence(code: string | undefined): string {
  if (code === CONSEQUENCE_UNAUTHENTICATED) return STRINGS.webAppUnauthenticatedEffect;
  if (code === CONSEQUENCE_PRIVILEGED) return STRINGS.privilegedGrantEffect;
  if (code === CONSEQUENCE_UNAUTHENTICATED_PRIVILEGED) return STRINGS.privilegedGrantEffectUnauthenticated;
  if (code === CONSEQUENCE_NORESOURCE) return STRINGS.webAppNoResourceEffect;
  if (code === CONSEQUENCE_REPOINTED) return STRINGS.webAppRepointedEffect;
  if (code === CONSEQUENCE_NOPEERCHECK) return STRINGS.sslEffectNoPeerCheck;
  if (code === CONSEQUENCE_RUNSASOTHER) return STRINGS.taskRunAsOtherEffect;
  if (code === CONSEQUENCE_SERVESOCUPILOT) return STRINGS.serviceEffectServesOcuPilot;
  if (code === CONSEQUENCE_SERVICEUNAUTHENTICATED) return STRINGS.serviceEffectUnauthenticated;
  if (code === CONSEQUENCE_MAPPINGMOVE) return STRINGS.oauthResourceServerMoveEffect;
  if (code === CONSEQUENCE_AUTHENTICATORRESET) return STRINGS.oauthResourceServerAuthenticatorResetEffect;
  if (code === CONSEQUENCE_SERVERCLIENTS) return STRINGS.oauthAuthServerClientsEffect;
  if (code === CONSEQUENCE_SERVERCLIENTSHIDDEN) return STRINGS.oauthAuthServerClientsHiddenEffect;
  if (code === CONSEQUENCE_SERVERCLIENTSDELETED) return STRINGS.oauthAuthServerClientsDeletedEffect;
  if (code === CONSEQUENCE_SERVERCLIENTSDELETEDHIDDEN) return STRINGS.oauthAuthServerClientsDeletedHiddenEffect;
  if (code === CONSEQUENCE_CUSTOMIZATIONPRIVILEGED) return STRINGS.oauthAuthServerCustomizationEffect;
  if (code === CONSEQUENCE_SERVERCLIENTSPRIVILEGED) return STRINGS.oauthAuthServerClientsPrivilegedEffect;
  if (code === CONSEQUENCE_SERVERCLIENTSHIDDENPRIVILEGED) return STRINGS.oauthAuthServerClientsHiddenPrivilegedEffect;
  if (code === CONSEQUENCE_SERVERCLIENTSECRETCHANGE) return STRINGS.oauthRegisteredClientSecretEffect;
  if (code === CONSEQUENCE_PURGEMARKERS) return STRINGS.auditPurgeMarkersEffect;
  if (code === CONSEQUENCE_SYSTEMGLOBAL) return STRINGS.mappingSystemGlobalConsequence;
  if (code === CONSEQUENCE_SCREENACCESSLOWERED) return STRINGS.screenPermissionsLowerConsequence;
  // The copy dialog's own consequence sentence, published once.
  if (code === CONSEQUENCE_COPYMAPPINGS) return STRINGS.namespaceCopyMappingsConsequence;
  // The export dialog's own replace line, published once.
  if (code === CONSEQUENCE_TASKEXPORTREPLACES) return STRINGS.taskExportReplaces;
  // An export to a server file replaces one at its name, as a task export does.
  if (code === CONSEQUENCE_EXPLOREREXPORTREPLACES) return STRINGS.taskExportReplaces;
  // The import dialog's own consequence line, published once.
  if (code === CONSEQUENCE_EXPLORERIMPORTREPLACES) return STRINGS.explorerImportReplaces;
  // Story 19.11: an agent-proposed SQL statement's own confirmation sentences, published once; the DML
  // sentence names the statement's tables, so the card states it through `sqlConsequenceSentence`.
  if (code === CONSEQUENCE_SQLCHANGESSCHEMA) return STRINGS.explorerSqlConfirmDdl;
  if (code === CONSEQUENCE_SQLRUNSPROCEDURE) return STRINGS.explorerSqlConfirmCall;
  if (code === CONSEQUENCE_SQLUNDECLARED) return STRINGS.explorerSqlConfirmOther;
  // The editor's own consequence line, published once.
  if (code === CONSEQUENCE_PYTHONCUSTOM) return STRINGS.languageServerPythonConsequence;
  // The warning dialog's own consequence sentence, published once.
  if (code === CONSEQUENCE_TASKMANAGERSUSPEND) return STRINGS.taskManagerSuspendConsequence;
  // The Remove locks dialog's own warning, published once (DW-1073).
  if (code === CONSEQUENCE_LOCKINTRANSACTION) return STRINGS.lockRemoveInTransaction;
  // The enable dialog's own consequence sentence, published once.
  if (code === CONSEQUENCE_NAMESPACEINTEROP) return STRINGS.namespaceEnableInteropConsequence;
  // The form's own Freeze on error line, published once.
  if (code === CONSEQUENCE_JOURNALSETTINGSFREEZE) return STRINGS.journalSettingsFreezeConsequence;
  // Story 18.6: removing a license server a multi-server key may use.
  if (code === CONSEQUENCE_LICENSEMULTIKEY) return STRINGS.licenseServerMultiKeyConsequence;
  // Story 18.20: the Change status dialog's own consequence sentences, published once.
  if (code === CONSEQUENCE_ECPSTATUSDISCONNECT) return STRINGS.ecpDataServerDisconnectConsequence;
  if (code === CONSEQUENCE_ECPSTATUSCONNECT) return STRINGS.ecpDataServerConnectConsequence;
  // Story 18.21: the settings' restart sentence and the two warnings, each published once.
  if (code === CONSEQUENCE_ECPSETTINGSRESTART) return STRINGS.ecpSettingsRestart;
  if (code === CONSEQUENCE_ECPSSLAUTHORIZE) return STRINGS.ecpSslAuthorizeConsequence;
  if (code === CONSEQUENCE_ECPSSLREJECT) return STRINGS.ecpSslRejectConsequence;
  // Story 18.7: the new key's and the key removal's sentences, each published once.
  if (code === CONSEQUENCE_ENCRYPTIONNEWKEY) return STRINGS.encryptionKeyFileNewKeyConsequence;
  if (code === CONSEQUENCE_ENCRYPTIONREMOVEKEY) return STRINGS.encryptionKeyFileRemoveKeyLoss;
  // Story 18.24: the two key replaces' sentences, each published once.
  if (code === CONSEQUENCE_WALLETKEYREPLACERSA) return STRINGS.walletKeyReplaceRsaConsequence;
  if (code === CONSEQUENCE_WALLETKEYREPLACESYMMETRIC) return STRINGS.walletKeyReplaceSymmetricConsequence;
  // Story 18.22: the two activations' and the two deactivations' sentences, each published once.
  if (code === CONSEQUENCE_ENCRYPTIONKEYACTIVATE) return STRINGS.encryptionKeyActivateConsequence;
  if (code === CONSEQUENCE_ENCRYPTIONKEYDEACTIVATE) return STRINGS.encryptionKeyDeactivateConsequence;
  if (code === CONSEQUENCE_ENCRYPTIONKEYACTIVATEDATAELEMENT) return STRINGS.encryptionKeyActivateDataElementConsequence;
  if (code === CONSEQUENCE_ENCRYPTIONKEYDEACTIVATEDATAELEMENT) return STRINGS.encryptionKeyDeactivateDataElementConsequence;
  // Story 18.23: the form's own option sentences, each published once.
  if (code === CONSEQUENCE_ENCRYPTIONSTARTUPNONE) return STRINGS.encryptionStartupNoneConsequence;
  if (code === CONSEQUENCE_ENCRYPTIONSTARTUPINTERACTIVE) return STRINGS.encryptionStartupInteractiveConsequence;
  if (code === CONSEQUENCE_ENCRYPTIONSTARTUPUNATTENDED) return STRINGS.encryptionStartupUnattendedConsequence;
  if (code === CONSEQUENCE_ENCRYPTIONSTARTUPKMIP) return STRINGS.encryptionStartupKmipConsequence;
  if (code === CONSEQUENCE_ENCRYPTIONSTARTUPRESTART) return STRINGS.encryptionStartupRestart;
  if (code === CONSEQUENCE_ENCRYPTIONSTARTUPJOURNAL) return STRINGS.encryptionStartupJournalConsequence;
  if (code === CONSEQUENCE_AUDITENCRYPTIONCHANGE) return STRINGS.encryptionStartupAuditConsequence;
  // Story 18.8: the sign-out sentence, published once.
  if (code === CONSEQUENCE_WEBAUTHSIGNOUT) return STRINGS.authOptionsSignOutConsequence;
  // Story 18.25: the serving superserver's SSL/TLS sentence, published once.
  if (code === CONSEQUENCE_SUPERSERVERSERVES) return STRINGS.superserverServesConsequence;
  // Story 18.26: the connection delete's and token revoke's sentences, each published once.
  if (code === CONSEQUENCE_MFTDELETE) return STRINGS.mftDeleteConsequence;
  if (code === CONSEQUENCE_MFTREVOKE) return STRINGS.mftRevokeConsequence;
  // Story 20.2: the four production consequences, each published once.
  if (code === CONSEQUENCE_INTEROPSTOP) return STRINGS.interopStopConsequence;
  if (code === CONSEQUENCE_INTEROPRESTART) return STRINGS.interopRestartConsequence;
  if (code === CONSEQUENCE_INTEROPUPDATE) return STRINGS.interopUpdateConsequence;
  if (code === CONSEQUENCE_INTEROPRECOVER) return STRINGS.interopRecoverConsequence;
  return '';
}

/**
 * Where one card is in the proposal lifecycle: live, the in-flight Confirm, and the eight terminal
 * states EXPERIENCE.md's status-line row publishes a sentence for.
 */
export type ProposalPhase =
  | 'live'
  | 'confirming'
  | 'confirmed'
  | 'canceled-by-you'
  | 'canceled-by-message'
  | 'canceled-sibling'
  | 'canceled-by-draft'
  | 'target-changed'
  | 'expired'
  | 'switched-off';

/** Which phases are terminal: the buttons are gone and a status line stands in their place. */
const TERMINAL_PHASES: ReadonlySet<ProposalPhase> = new Set<ProposalPhase>([
  'confirmed',
  'canceled-by-you',
  'canceled-by-message',
  'canceled-sibling',
  'canceled-by-draft',
  'target-changed',
  'expired',
  'switched-off',
]);

export function isTerminalPhase(phase: ProposalPhase): boolean {
  return TERMINAL_PHASES.has(phase);
}

/**
 * Which terminal phases offer Re-propose: the expiry limit's WCAG 2.2.1 accommodation, and the
 * fingerprint mismatch, whose own refusal is terminal and whose accommodation is the same fresh
 * read and fresh diff (EXPERIENCE.md's target-changed step).
 */
const REPROPOSABLE_PHASES: ReadonlySet<ProposalPhase> = new Set<ProposalPhase>([
  'expired',
  'target-changed',
]);

export function offersRepropose(phase: ProposalPhase): boolean {
  return REPROPOSABLE_PHASES.has(phase);
}

/**
 * The phase a wire `state` and its `closedReason` read as.
 *
 * `canceled` is five phases, told apart by the reason the instance recorded with it -- `draft` is
 * the user taking the script instead (AD-59) -- and a `canceled` row whose reason this client does
 * not recognise reads as the user's own decision, which is the one of the five that claims least
 * about why. Anything this client does not
 * recognise at all reads as `expired`: a card drawn restrained with no Confirm is the restrained
 * direction, and the alternative -- treating an unknown state as live -- would offer a decision on
 * a proposal whose fate the instance has already settled.
 */
export function phaseForState(state: string, closedReason = ''): ProposalPhase {
  if (state === 'live') return 'live';
  if (state === 'confirmed') return 'confirmed';
  if (state === 'canceled') {
    if (closedReason === 'message') return 'canceled-by-message';
    if (closedReason === 'sibling') return 'canceled-sibling';
    if (closedReason === 'draft') return 'canceled-by-draft';
    if (closedReason === 'target-changed') return 'target-changed';
    return 'canceled-by-you';
  }
  return 'expired';
}

/** The placeholder every proposal string leaves for the account a sentence is about. */
export const USER_NAME_PLACEHOLDER = '<user name>';

/** The placeholder the confirmed status line leaves for the moment of the write. */
export const CONFIRMED_TIME_PLACEHOLDER = 'hh:mm:ss';

/** The substitution point inside the published countdown caption. */
export const COUNTDOWN_PLACEHOLDER = 'm:ss';

/**
 * `<user name>` resolved, for the footer's runs-as caption and the confirmed status line.
 *
 * A function rather than a `replace` inside a template, for the reason `formatProposalTitle` is
 * one: renaming the placeholder on one side only would ship the placeholder to the reader, and a
 * source-text pin cannot see that.
 */
export function formatUserName(template: string, userName: string): string {
  return template.split(USER_NAME_PLACEHOLDER).join(userName);
}

/** The placeholder the published residue sentence leaves for the number of rows the card lists. */
export const RESIDUE_COUNT_PLACEHOLDER = '<n>';

/**
 * The published residue sentence with `count` in place of its `<n>`.
 *
 * The count is how many removal rows the card is drawing, so the sentence and the list it is about
 * cannot disagree; nothing here writes a value the instance did not send (AD-6).
 */
export function formatRemovalResidue(template: string, count: number): string {
  return template.split(RESIDUE_COUNT_PLACEHOLDER).join(String(count));
}

/**
 * The published countdown caption with the clock in place of its own `m:ss`, which is the
 * substitution point the caption ships with -- the same `split`/`join` idiom
 * `formatUnchangedCaption` uses for its `N`, so the published literal stays intact.
 */
export function formatCountdownCaption(template: string, clock: string): string {
  return template.split(COUNTDOWN_PLACEHOLDER).join(clock);
}

/**
 * How long proposal `expiresAt` (epoch milliseconds) has left at `nowMs`, or `null` when the
 * instance's own timestamp could not be read.
 *
 * `null` is "unknown", never "expired": `core/turn.ts` records `0` for a wire timestamp it could
 * not parse, and reading that as a deadline already past would show a live proposal as expired and
 * take its Confirm away. An unknown expiry leaves the card live until the poll closes it.
 */
export function countdownRemaining(expiresAt: number, nowMs: number): number | null {
  if (!Number.isFinite(expiresAt) || expiresAt <= 0) return null;
  return expiresAt - nowMs;
}

/** The boundary, in milliseconds, at which the caption turns to the warning token and announces. */
export const COUNTDOWN_WARNING_MS = 60 * 1000;

/** How the countdown reads: ordinary, inside the last minute, or done. */
export type CountdownPhase = 'normal' | 'warning' | 'expired';

/**
 * Which of the three `msRemaining` is in. The 1:00 boundary is inclusive, so the caption takes
 * the warning token *at* one minute and holds it to 0:00 rather than a second later.
 */
export function countdownPhase(msRemaining: number): CountdownPhase {
  if (!Number.isFinite(msRemaining) || msRemaining <= 0) return 'expired';
  return msRemaining <= COUNTDOWN_WARNING_MS ? 'warning' : 'normal';
}

/**
 * `msRemaining` as `m:ss`, floored to the second and never negative -- so a deadline already past
 * reads `0:00` rather than a negative clock.
 */
export function formatCountdown(msRemaining: number): string {
  const total = Number.isFinite(msRemaining) && msRemaining > 0 ? Math.floor(msRemaining / 1000) : 0;
  const seconds = total % 60;
  return `${Math.floor(total / 60)}:${seconds < 10 ? '0' : ''}${seconds}`;
}

/**
 * The status line one terminal phase reads, resolved from `core/strings.ts`, or `''` for a phase
 * that has no line (`live` and `confirming` still have their buttons).
 */
export function statusLineFor(phase: ProposalPhase, userName: string, at: string): string {
  if (phase === 'confirmed') {
    return formatUserName(STRINGS.proposalStatusConfirmedBy, userName)
      .split(CONFIRMED_TIME_PLACEHOLDER)
      .join(at);
  }
  if (phase === 'canceled-by-you') return STRINGS.proposalStatusCanceledByYou;
  if (phase === 'canceled-by-message') return STRINGS.proposalStatusCanceledByMessage;
  if (phase === 'canceled-sibling') return STRINGS.proposalStatusCanceledSibling;
  if (phase === 'canceled-by-draft') return STRINGS.proposalStatusCanceledByDraft;
  // EXPERIENCE.md publishes one fixed string for this transition, and DESIGN.md says the warning
  // banner's fixed string is EXPERIENCE.md's -- so the status line IS the banner's text, rendered
  // inside it, rather than a second piece of copy invented here.
  if (phase === 'target-changed') return STRINGS.proposalTargetChanged;
  if (phase === 'expired') return STRINGS.proposalStatusExpired;
  if (phase === 'switched-off') return STRINGS.proposalStatusAgentSwitchedOff;
  return '';
}

/**
 * The eight-bullet mask a secret value reads as, on both sides of its diff row. Authored as
 * escapes, never literal bytes (Rule 14).
 */
export const MASKED_VALUE = '\u2022'.repeat(8);

/** One diff row with both of its values masked, for a field the descriptor declared secret. */
function maskedRow(row: ProposalDiffRow): ProposalDiffRow {
  return { field: row.field, before: MASKED_VALUE, after: MASKED_VALUE, removed: row.removed };
}

/**
 * The card's privilege line for the wire's `privilege`, or `null` for none or an empty `requires`.
 * `<resources>` becomes every required pair, comma-separated; `<resource>` the first one missing,
 * which turns the line into the warning. Both are the instance's answers (AD-8); nothing here
 * derives a pair or decides whether one is held.
 */
export function privilegeLine(privilege: TurnProposalPrivilege | null | undefined): ProposalPrivilegeLine | null {
  if (privilege === null || privilege === undefined || privilege.requires.length === 0) return null;
  const resources = privilege.requires.join(', ');
  if (privilege.missing === '') {
    return { text: STRINGS.privilegeProposalHeld.replace('<resources>', () => resources), missing: false };
  }
  return {
    text: STRINGS.privilegeProposalMissing
      .replace('<resources>', () => resources)
      .replace('<resource>', () => privilege.missing),
    missing: true,
  };
}

/**
 * One live proposal as its card renders it: `entityLabel` is the singular noun the target's screen
 * declares, `secretArguments` the names that screen declares secret, and everything else is
 * `proposal`'s own -- the instance-computed diff with every declared secret masked on both sides,
 * the unchanged count and the instance's own already-masked unchanged rows, the agent's two
 * blocks, the reversal, the expiry, the audit warning, the tool's destructive declaration and the
 * kernel's consequence code.
 * `maskedFields` is `secretArguments` narrowed to the names this proposal's own payload carries
 * (`payloadSecrets`).
 * `refusalReason` is the envelope's own sentence for a decision the instance refused on a row it
 * left live (DW-1348), passed in for the same reason the screen's two facts are: it is the
 * caller's to hold, and nothing here writes it.
 *
 * Both of the screen's facts are parameters rather than a lookup of `screens.generated.ts` here,
 * for the reason the header gives.
 *
 * Nothing here writes a proposal value down (AD-6).
 */
export function toCardView(
  proposal: TurnProposal,
  entityLabel: string,
  secretArguments: readonly string[] = [],
  refusalReason = ''
): ProposalCardView {
  const secrets = new Set(secretArguments);
  return {
    proposalId: proposal.proposalId,
    entityType: entityLabel,
    targetType: proposal.target.type,
    name: proposal.target.id,
    targetName: proposal.targetName ?? '',
    changed: proposal.changed.map((row) => (secrets.has(row.field) ? maskedRow(row) : row)),
    unchangedCount: proposal.unchangedCount,
    unchanged: proposal.unchanged,
    rationale: proposal.rationale,
    expectedImpact: proposal.expectedImpact,
    reverse: proposal.reverse,
    expiresAt: proposal.expiresAt,
    maskedFields: payloadSecrets(proposal, secretArguments),
    optionalFields: optionalSecrets(proposal, secretArguments),
    auditWarning: proposal.auditWarning,
    destructive: proposal.destructive,
    consequence: proposal.consequence,
    privilege: privilegeLine(proposal.privilege),
    impact: proposal.impact ?? null,
    refusalReason,
  };
}

/** The name the card's title shows: the instance's `targetName`, else the target's id. */
export function cardTitleName(view: Pick<ProposalCardView, 'name' | 'targetName'>): string {
  const named = view.targetName ?? '';
  return named !== '' ? named : view.name;
}

/**
 * The declared secret names whose diff row the instance marked `optional`: the ones the card lets the
 * user leave empty. A secret whose row carries no mark is required.
 */
function optionalSecrets(
  proposal: TurnProposal,
  secretArguments: readonly string[]
): readonly string[] {
  const optional = new Set<string>();
  for (const row of proposal.changed) {
    if (row.optional === true) optional.add(row.field);
  }
  return secretArguments.filter((name) => optional.has(name));
}

/**
 * The declared secret names **this proposal's own payload carries** (DW-1227), which is what the
 * card asks the user to fill.
 *
 * A screen declares the secrets of every write its tool can make, and one proposal sends one
 * body: a field the payload does not carry is a field the confirm body must not carry either
 * (AD-6's channel is closed to the tool's declared names), so asking for it would leave Confirm
 * `aria-disabled` on a value this write has no field for. The narrowing is this function's own
 * restriction rather than a consequence of the merge: `Confirm.WithSecrets` calls `%Set` for every
 * declared name the body supplied, which **adds** one the payload does not carry.
 * The payload's own field names are its diff rows and its unchanged rows -- together the
 * projection of the stored body the instance published (AD-4). The mint refuses a secret argument
 * outright, so an update names a secret in its unchanged half; a create names one as the diff row
 * the kernel composes for it, masked on both sides.
 */
function payloadSecrets(
  proposal: TurnProposal,
  secretArguments: readonly string[]
): readonly string[] {
  if (secretArguments.length === 0) return secretArguments;
  const carried = new Set<string>();
  for (const row of proposal.changed) carried.add(row.field);
  for (const row of proposal.unchanged) carried.add(row.field);
  return secretArguments.filter((name) => carried.has(name));
}
