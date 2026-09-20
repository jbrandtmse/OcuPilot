/// <p>One minted proposal (AD-6, AD-9, AD-37): who minted it, against which scoped target, what the
/// write will send, what changed, and the single-use token a confirm claims it with. Held in
/// OcuPilot's protected database and reached only through
/// <class>OcuPilot.Kernel.State.Base</class>'s guarded methods.</p>
/// <p><b>The class is <code>Propose</code> and the table is <code>Proposal</code>.</b>
/// <code>OcuPilot.Kernel.State.</code> spends 22 of the 29 characters a class with a data global
/// may carry (Consistency Conventions: ObjectScript naming), so the store's own name may be seven;
/// <code>Proposal</code> is eight. <code>SqlTableName</code> carries the name the reader expects,
/// the same split <class>OcuPilot.Kernel.State.Switch</class> already uses.</p>
/// <p><b>Every reference to an IRIS object is weak</b> (AD-37): <property>TargetRef</property> is
/// the AD-13 triple as data -- <method>OcuPilot.Kernel.EntityRef.Key</method>'s value -- never a
/// foreign key, and a target deleted since the mint is refused at confirm by the fresh read rather
/// than by anything here.</p>
/// <p><b>This class mints and reads; it never decides.</b> Whether a claim may proceed is
/// <method>OcuPilot.Kernel.Proposal.Write.Claim</method>'s, outside every escalated frame (AD-9's
/// re-entry rule), and burning the token is Story 5.3's.</p>
/// <p><b>Added with no <code>SCHEMAVERSION</code> move</b> (Consistency Conventions): a new table
/// has no pre-existing rows for an older OcuPilot to reinterpret.</p>
Class OcuPilot.Kernel.State.Propose Extends OcuPilot.Kernel.State.Base [ SqlTableName = Proposal ]
{

/// <p>A proposal awaiting the user's decision: the only state a claim admits.</p>
Parameter STATELIVE = "live";

/// <p>Confirmed, and so spent (Story 5.3).</p>
Parameter STATECONFIRMED = "confirmed";

/// <p>Cancelled by the user's next message, by a sibling's confirm (AD-34), or by New
/// conversation.</p>
Parameter STATECANCELED = "canceled";

/// <p>Past <property>ExpiresAt</property> and swept.</p>
Parameter STATEEXPIRED = "expired";

/// <p><property>ClosedReason</property>: the minting user pressed Cancel.</p>
Parameter REASONYOU = "you";

/// <p><property>ClosedReason</property>: the user's next message closed it.</p>
Parameter REASONMESSAGE = "message";

/// <p><property>ClosedReason</property>: a proposal on the same scoped target was confirmed
/// (AD-34).</p>
Parameter REASONSIBLING = "sibling";

/// <p><property>ClosedReason</property>: the target moved under the diff, so the fingerprint no
/// longer matched (AD-6, FR-17).</p>
Parameter REASONTARGETCHANGED = "target-changed";

/// <p>The opaque, server-minted proposal id: 32 lower-case hex characters. Unique; matched
/// exactly.</p>
Property ProposalKey As %String(MAXLEN = 64);

/// <p>The single-use token a confirm claims this proposal with (AD-6), minted the same way and
/// independently of <property>ProposalKey</property>, so holding one is not holding the other.</p>
Property Token As %String(MAXLEN = 64);

/// <p>Whether the token has been spent. Set inside Story 5.3's transition; read here and by
/// <method>OcuPilot.Kernel.Proposal.Write.Claim</method>.</p>
Property Burned As %Boolean [ InitialExpression = 0 ];

/// <p>The user who minted it, as <code>$USERNAME</code> read it. A weak reference (AD-37), matched
/// <code>%EXACT</code>.</p>
Property UserName As %String(MAXLEN = 160);

/// <p>The conversation the minting turn belonged to.</p>
Property ConvKey As %String(MAXLEN = 64);

/// <p>The turn that minted it. A proposal is confirmable only while that turn ended normally
/// (AD-40), which is why the turn's retention outlives the proposal's expiry
/// (<parameter>OcuPilot.Kernel.Agent.Limits.PROPOSALEXPIRYSECONDS</parameter>).</p>
Property TurnKey As %String(MAXLEN = 64);

/// <p>The canonical dotted name of the write tool that minted it.</p>
Property ToolName As %String(MAXLEN = 128);

/// <p>The scoped target as <method>OcuPilot.Kernel.EntityRef.Key</method> spells it: the entity
/// type, the scope and the id, joined by that class's separator (AD-13).</p>
Property TargetRef As %String(MAXLEN = 512);

/// <p>The digest of the payload the write will send, minus the descriptor's declared exclusions
/// (AD-6). Confirm re-reads the target, recomputes this and refuses on a mismatch.</p>
Property Fingerprint As %String(MAXLEN = 128);

/// <p>The tool call's resolved arguments as compact JSON, secret-declared keys never among them
/// (AD-3). A stream because a payload is unbounded by the row's own storage.</p>
Property Arguments As %Stream.GlobalCharacter;

/// <p>The complete merged body the write will send (AD-4): the fresh read's own object with the
/// arguments applied over it, every other property kept.</p>
Property Payload As %Stream.GlobalCharacter;

/// <p>The computed diff as a JSON array of <code>{field, before, after}</code> -- what the user
/// reviews, as the card draws it.</p>
Property Diff As %Stream.GlobalCharacter;

/// <p>How many properties the payload also sends unchanged, for the card's collapsed caption.</p>
Property UnchangedCount As %Integer [ InitialExpression = 0 ];

/// <p>The agent's own words, each cut at the summary cap. Untrusted content (AD-11).</p>
Property Rationale As %String(MAXLEN = 1000);

Property ExpectedImpact As %String(MAXLEN = 1000);

/// <p>How to undo the write, or <code>""</code> where no reversal exists.</p>
Property Reverse As %String(MAXLEN = 1000);

/// <p>ISO-8601 UTC timestamps (Consistency Conventions: Dates).</p>
Property CreatedAt As %String(MAXLEN = 32);

Property ExpiresAt As %String(MAXLEN = 32);

/// <p>One of the four <code>STATE*</code> parameter values.</p>
Property State As %String(MAXLEN = 16);

/// <p>Whether this write would stop the instance marking agent writes in the audit database
/// (AD-10, AD-15), as <method>OcuPilot.Kernel.Proposal.Mint.WarnsAuditingOff</method> answered it
/// at mint time. The card renders the warning above its footer; the kernel owns the predicate.</p>
/// <p><b>Added with no <code>SCHEMAVERSION</code> move</b> (Consistency Conventions: when
/// SCHEMAVERSION moves): every pre-existing row reads 0, which is the same answer the predicate
/// gives every tool that shipped before this property existed, so no older row means anything
/// different once a newer OcuPilot reads it.</p>
Property AuditWarning As %Boolean [ InitialExpression = 0 ];

/// <p>When the confirmed write was committed, ISO-8601 UTC; <code>""</code> while the row is not
/// <parameter>STATECONFIRMED</parameter>. Written inside the claim's own transition and read by the
/// card's confirmed status line.</p>
Property ConfirmedAt As %String(MAXLEN = 32);

/// <p>Why a <parameter>STATECANCELED</parameter> row closed: <code>you</code>, <code>message</code>,
/// <code>sibling</code> or <code>target-changed</code>. <code>""</code> while the row is live, and
/// on any state that is not <code>canceled</code>.</p>
Property ClosedReason As %String(MAXLEN = 16);

/// <p>The agent definition in force when this proposal was minted, and the version
/// <method>OcuPilot.Kernel.State.Agent.GuardedVersion</method> answered for it. Confirm refuses
/// when the definition has moved or gone (FR-17); <code>""</code> in
/// <property>DefinitionVersion</property> is "no row", never <code>0</code>.</p>
Property DefinitionId As %String(MAXLEN = 64);

Property DefinitionVersion As %String(MAXLEN = 32);

Index ProposalKeyIdx On ProposalKey [ Unique ];

Index ProposalTokenIdx On Token [ Unique ];

/// <p>A user's proposals by state, for the sweep and for the panel's own read.
/// <property>UserName</property> is indexed <code>Exact</code> because every predicate over it
/// matches <code>%EXACT</code> (a weak reference is compared as stored, AD-37).</p>
Index ProposalUserStateIdx On (UserName As Exact, State);

/// <p>A turn's own proposals, the predicate <method>GuardedRowsForTurn</method> runs once per
/// progress poll -- about once a second while a turn is live. Without it that read filters
/// <property>TurnKey</property> against the master map for every row the user has ever minted,
/// because nothing else indexes it and the retention sweep is Story 5.3's.</p>
Index ProposalTurnIdx On (TurnKey As Exact, UserName As Exact);

/// <p>A conversation's own proposals, the predicate <method>GuardedRowsForConvo</method> runs once
/// per restored conversation. Without it that read filters <property>ConvKey</property> against
/// the master map for every row the user has ever minted, exactly as
/// <code>ProposalTurnIdx</code> exists to stop the per-turn read doing.</p>
Index ProposalConvIdx On (ConvKey As Exact, UserName As Exact);

/// <p>A scoped target's own proposals by state, the predicate the sibling cancel inside
/// <method>GuardedClaimAndClose</method> runs while a claim's transaction is open (AD-34). Without
/// it that update filters <property>TargetRef</property> against the master map with the claimed
/// row's transaction still holding its locks.</p>
Index ProposalTargetIdx On (TargetRef As Exact, State);

/// <p>Mint one row and answer its id, token and expiry.</p>
/// <p><b>Caller contract:</b> <var>pValues</var> carries <code>user</code>, <code>convKey</code>,
/// <code>turnKey</code>, <code>toolName</code>, <code>targetRef</code>, <code>fingerprint</code>,
/// <code>arguments</code>, <code>payload</code>, <code>diff</code>, <code>unchangedCount</code>,
/// <code>rationale</code>, <code>expectedImpact</code>, <code>reverse</code>,
/// <code>auditWarning</code>, <code>definitionId</code> and <code>definitionVersion</code>, every
/// one already
/// built and already stripped of secret-declared keys by
/// <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>; nothing here strips anything.
/// <var>pLimitsClass</var> is the class <code>PROPOSALEXPIRYSECONDS</code> is read from, so a test
/// narrows the window rather than waiting it out.</p>
/// <p>Each of the three stream writes is checked and no row is saved on a failure: a row stored
/// with a payload its diff does not describe reads to every diff-scoped gate behind the mint as a
/// proposal that changes nothing (DW-1353).</p>
ClassMethod GuardedMint(ByRef pValues, pLimitsClass As %String, Output pKey As %String, Output pToken As %String, Output pExpiresAt As %String) As %Status
{
    Set pKey = ""
    Set pToken = ""
    Set pExpiresAt = ""
    Set tSC = $$$OK
    Try {
        Set tStamp = $ZTimeStamp
        Set tSeconds = ..NowSeconds(tStamp) + +$Parameter(pLimitsClass, "PROPOSALEXPIRYSECONDS")
        Set tRow = ..%New()
        Set tRow.ProposalKey = ..NewKey()
        Set tRow.Token = ..NewKey()
        Set tRow.UserName = ..Cut($Get(pValues("user")), 160)
        Set tRow.ConvKey = ..Cut($Get(pValues("convKey")), 64)
        Set tRow.TurnKey = ..Cut($Get(pValues("turnKey")), 64)
        Set tRow.ToolName = ..Cut($Get(pValues("toolName")), 128)
        Set tRow.TargetRef = ..Cut($Get(pValues("targetRef")), 512)
        Set tRow.Fingerprint = ..Cut($Get(pValues("fingerprint")), 128)
        Set tSC = tRow.Arguments.Write($Get(pValues("arguments")))
        If $$$ISERR(tSC) Quit
        Set tSC = tRow.Payload.Write($Get(pValues("payload")))
        If $$$ISERR(tSC) Quit
        Set tSC = tRow.Diff.Write($Get(pValues("diff")))
        If $$$ISERR(tSC) Quit
        Set tRow.UnchangedCount = +$Get(pValues("unchangedCount"))
        Set tSummaryMax = +$Parameter(pLimitsClass, "SUMMARYMAXLENGTH")
        Set tRow.Rationale = ..Cut($Get(pValues("rationale")), tSummaryMax)
        Set tRow.ExpectedImpact = ..Cut($Get(pValues("expectedImpact")), tSummaryMax)
        Set tRow.Reverse = ..Cut($Get(pValues("reverse")), tSummaryMax)
        Set tRow.AuditWarning = ''$Get(pValues("auditWarning"))
        Set tRow.DefinitionId = ..Cut($Get(pValues("definitionId")), 64)
        Set tRow.DefinitionVersion = ..Cut($Get(pValues("definitionVersion")), 32)
        Set tRow.CreatedAt = ..Stamp(tStamp)
        Set tRow.ExpiresAt = ..StampOfSeconds(tSeconds)
        Set tRow.State = ..#STATELIVE
        Set tSC = ..GuardedSaveIfCurrent(tRow, 0)
        If $$$ISERR(tSC) Quit
        Set pKey = tRow.ProposalKey
        Set pToken = tRow.Token
        Set pExpiresAt = tRow.ExpiresAt
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The proposal whose token is exactly <var>pToken</var>, as data in <var>pValues</var>:
/// <code>proposalId</code>, <code>user</code>, <code>convKey</code>, <code>turnKey</code>,
/// <code>toolName</code>, <code>targetRef</code>, <code>fingerprint</code>,
/// <code>unchangedCount</code>, <code>rationale</code>, <code>expectedImpact</code>,
/// <code>reverse</code>, <code>createdAt</code>, <code>expiresAt</code>, <code>state</code>,
/// <code>storedState</code>, <code>closedReason</code>, <code>confirmedAt</code>,
/// <code>definitionId</code>, <code>definitionVersion</code>, <code>auditWarning</code>,
/// <code>burned</code>, <code>arguments</code>, <code>payload</code> and <code>diff</code>.
/// <var>pFound</var> is 0 when no row carries that token.</p>
/// <p>Data, not a decision: this package names nothing outside it (AD-9), so the caller is what
/// reads the turn's own state and answers the refusals.</p>
ClassMethod GuardedByToken(pToken As %String, Output pFound As %Boolean, Output pValues) As %Status
{
    Set pFound = 0
    Kill pValues
    If pToken = "" Quit $$$OK
    Set tSC = ..GuardedOpenOneWhere("SELECT ID FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(Token) = ?", pToken, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit tSC
    Set tSC = ..RowValues(tRow, .pValues)
    Set tRow = ""
    If $$$ISERR(tSC) Quit tSC
    Set pFound = 1
    Quit $$$OK
}

/// <p>The same projection for the proposal whose id is exactly <var>pKey</var>.</p>
ClassMethod GuardedByKey(pKey As %String, Output pFound As %Boolean, Output pValues) As %Status
{
    Set pFound = 0
    Kill pValues
    If pKey = "" Quit $$$OK
    Set tSC = ..GuardedOpenOneWhere("SELECT ID FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", pKey, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit tSC
    Set tSC = ..RowValues(tRow, .pValues)
    Set tRow = ""
    If $$$ISERR(tSC) Quit tSC
    Set pFound = 1
    Quit $$$OK
}

/// <p>How long a claim waits for its scoped target's lock before giving up. The transition it
/// guards is two SQL statements, so a wait this long means a genuinely concurrent confirm.</p>
Parameter CLAIMLOCKSECONDS As %Integer = 10;

/// <p>The lock subscript a claim on <var>pTargetRef</var> serializes on -- a SHA-256 digest of the
/// reference rather than the reference itself, because <property>TargetRef</property> holds up to
/// 512 characters and a lock name does not. <code>""</code> for an unscoped claim, which has no
/// siblings to cancel and takes no lock.</p>
/// <p>Public so a test can name the same lock a claim takes rather than rebuilding it, which is
/// the only way an assertion about the serialization can fail for the right reason.</p>
ClassMethod TargetLockKey(pTargetRef As %String) As %String
{
    If pTargetRef = "" Quit ""
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.SHAHash(256, $ZConvert(pTargetRef, "O", "UTF8"))), "L")
}

/// <p>Claim proposal <var>pProposalKey</var> and close its siblings, in one transaction (AD-34).</p>
/// <p><b>Caller contract:</b> every gate that decides whether the write may happen has already been
/// evaluated by the caller (<class>OcuPilot.Kernel.Proposal.Confirm</class>) and none of them is
/// re-asked here; <var>pExpectedVersion</var> is the <property>RowVersion</property> the caller read
/// the row at, and <var>pTargetRef</var> its stored scoped target. Nothing outside this package is
/// named (AD-9), and the vendor write follows the commit rather than sitting inside it.</p>
/// <p><b>Exactly one caller wins.</b> The conditional <code>UPDATE</code> matches only while the row
/// is still unburned, still <parameter>STATELIVE</parameter> and still at that version, so the row
/// count is 1 for the winner and 0 for every other. A winner's own statement carries the burn, the
/// terminal state and the confirmation stamp together, and the sibling cancel runs inside the same
/// transaction -- so there is no window in which one row is burned and a sibling is still live.</p>
/// <p><b>One transition per scoped target at a time.</b> A scoped claim holds
/// <method>TargetLockKey</method>'s lock across its whole transaction, because the row locks alone
/// do not order two claims of two different rows on one target: at IRIS's READ UNCOMMITTED default
/// each sibling update reads the other's uncommitted claim as already confirmed, matches nothing
/// and never asks for its lock. A claim that cannot take the target lock within
/// <parameter>CLAIMLOCKSECONDS</parameter> answers an error and writes nothing.</p>
/// <p><b>Siblings are closed whatever user owns them.</b> The target moved for everyone, and a
/// sibling left live would offer a decision against a diff that is already stale.</p>
/// <p>A row count of 0 leaves <var>pWon</var> 0 and answers the row's current state in
/// <var>pTerminal</var> -- projected, so a row past its expiry reads <code>expired</code> -- which
/// is what the loser is refused with. It is never retried.</p>
ClassMethod GuardedClaimAndClose(pProposalKey As %String, pExpectedVersion As %Integer, pTargetRef As %String, Output pWon As %Boolean, Output pTerminal As %String) As %Status
{
    Set pWon = 0
    Set pTerminal = ""
    Set tSC = $$$OK
    Set tInTx = 0
    Set tLockKey = ""
    Try {
        If pProposalKey = "" {
            Set tSC = $$$ERROR($$$GeneralError, "a claim needs a proposal id")
            Quit
        }
        ; AD-34. Confirms of one scoped target are serialized here, and not by the rows' own locks.
        ; IRIS's default isolation is READ UNCOMMITTED, so the sibling update below reads a rival
        ; claim's uncommitted State = 'confirmed', matches nothing and asks for no lock -- without
        ; this both claims commit, neither cancels the other, and two writes go out against one
        ; target. Observed on this build, 2026-09-19.
        If pTargetRef '= "" {
            Set tLockKey = ..TargetLockKey(pTargetRef)
            Set tSC = ..GuardedTargetLock(tLockKey, ..#CLAIMLOCKSECONDS, .tHeld)
            If $$$ISERR(tSC) Quit
            If 'tHeld {
                Set tLockKey = ""
                Set tSC = $$$ERROR($$$GeneralError, "another confirm of this target is in flight")
                Quit
            }
        }
        Set tNow = ..Stamp()
        TSTART
        Set tInTx = 1
        Set tClaim = [].%Push(..#STATECONFIRMED).%Push(tNow).%Push(+pExpectedVersion + 1).%Push(pProposalKey).%Push(..#STATELIVE).%Push(+pExpectedVersion)
        Set tSC = ..GuardedExecuteRows("UPDATE OcuPilot_Kernel_State.Proposal SET Burned = 1, State = ?, ConfirmedAt = ?, RowVersion = ? WHERE %EXACT(ProposalKey) = ? AND Burned = 0 AND %EXACT(State) = ? AND COALESCE(RowVersion, 0) = ?", .tClaim, .tClaimed)
        If $$$ISERR(tSC) Quit
        If tClaimed = 0 Quit
        Set pWon = 1
        If pTargetRef '= "" {
            Set tSiblings = [].%Push(..#STATECANCELED).%Push(..#REASONSIBLING).%Push(pTargetRef).%Push(..#STATELIVE).%Push(pProposalKey)
            Set tSC = ..GuardedExecuteRows("UPDATE OcuPilot_Kernel_State.Proposal SET State = ?, ClosedReason = ? WHERE %EXACT(TargetRef) = ? AND %EXACT(State) = ? AND %EXACT(ProposalKey) <> ?", .tSiblings, .tCanceled)
            If $$$ISERR(tSC) Quit
        }
        TCOMMIT
        Set tInTx = 0
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If tInTx {
        TROLLBACK 1
        Set pWon = 0
    }
    If tLockKey '= "" {
        Set tUnlockSC = ..GuardedTargetUnlock(tLockKey)
        If $$$ISERR(tUnlockSC) && $$$ISOK(tSC) Set tSC = tUnlockSC
    }
    If $$$ISOK(tSC) && 'pWon {
        Set tReadSC = ..GuardedByKey(pProposalKey, .tFound, .tValues)
        If $$$ISERR(tReadSC) Quit tReadSC
        Set pTerminal = $Select(tFound: $Get(tValues("state")), 1: "")
    }
    Quit tSC
}

/// <p>Close proposal <var>pProposalKey</var>, owned by <var>pUser</var>, as
/// <parameter>STATECANCELED</parameter> with reason <var>pReason</var>. <var>pClosed</var> is 1
/// when a live row was closed and 0 when none matched -- an id nobody owns, a row already terminal,
/// and a row another user minted are the same 0.</p>
/// <p>A row past its expiry is flipped to <parameter>STATEEXPIRED</parameter> first, so a cancel
/// arriving after the window closes records the expiry rather than overwriting it (DW-1209).</p>
ClassMethod GuardedClose(pProposalKey As %String, pUser As %String, pReason As %String, Output pClosed As %Boolean) As %Status
{
    Set pClosed = 0
    If (pProposalKey = "") || (pUser = "") Quit $$$OK
    Set tExpireSC = ..GuardedExpireStale()
    If $$$ISERR(tExpireSC) Quit tExpireSC
    Set tParams = [].%Push(..#STATECANCELED).%Push(pReason).%Push(pProposalKey).%Push(pUser).%Push(..#STATELIVE)
    Set tSC = ..GuardedExecuteRows("UPDATE OcuPilot_Kernel_State.Proposal SET State = ?, ClosedReason = ? WHERE %EXACT(ProposalKey) = ? AND %EXACT(UserName) = ? AND %EXACT(State) = ? AND Burned = 0", .tParams, .tRows)
    If $$$ISERR(tSC) Quit tSC
    Set pClosed = (tRows > 0)
    Quit $$$OK
}

/// <p>Close every live proposal of conversation <var>pConvKey</var> owned by <var>pUser</var> with
/// reason <var>pReason</var>, and answer how many closed in <var>pCount</var>.</p>
/// <p>This is what makes "a typed message cancels every live proposal" and "New conversation cancels
/// them too" facts of the instance rather than optimistic client writes: the row is closed before
/// the turn job is spawned, so a confirm arriving afterwards meets a row that is no longer live.</p>
ClassMethod GuardedCloseLiveForConvo(pConvKey As %String, pUser As %String, pReason As %String, Output pCount As %Integer) As %Status
{
    Set pCount = 0
    If (pConvKey = "") || (pUser = "") Quit $$$OK
    Set tExpireSC = ..GuardedExpireStale()
    If $$$ISERR(tExpireSC) Quit tExpireSC
    Set tParams = [].%Push(..#STATECANCELED).%Push(pReason).%Push(pConvKey).%Push(pUser).%Push(..#STATELIVE)
    Set tSC = ..GuardedExecuteRows("UPDATE OcuPilot_Kernel_State.Proposal SET State = ?, ClosedReason = ? WHERE %EXACT(ConvKey) = ? AND %EXACT(UserName) = ? AND %EXACT(State) = ? AND Burned = 0", .tParams, .tRows)
    If $$$ISERR(tSC) Quit tSC
    Set pCount = +tRows
    Quit $$$OK
}

/// <p>Close every live proposal <var>pUser</var> owns, whatever conversation minted it, with reason
/// <var>pReason</var>, and answer how many closed in <var>pCount</var>.</p>
/// <p>What New conversation calls: the transcript it replaces is the caller's whole panel, and the
/// handler is given no earlier conversation id to narrow it by.</p>
ClassMethod GuardedCloseLiveForUser(pUser As %String, pReason As %String, Output pCount As %Integer) As %Status
{
    Set pCount = 0
    If pUser = "" Quit $$$OK
    Set tExpireSC = ..GuardedExpireStale(pUser)
    If $$$ISERR(tExpireSC) Quit tExpireSC
    Set tParams = [].%Push(..#STATECANCELED).%Push(pReason).%Push(pUser).%Push(..#STATELIVE)
    Set tSC = ..GuardedExecuteRows("UPDATE OcuPilot_Kernel_State.Proposal SET State = ?, ClosedReason = ? WHERE %EXACT(UserName) = ? AND %EXACT(State) = ? AND Burned = 0", .tParams, .tRows)
    If $$$ISERR(tSC) Quit tSC
    Set pCount = +tRows
    Quit $$$OK
}

/// <p>Close every live proposal of <var>pUser</var> whose window has passed, recording the state
/// <method>RowValues</method> already projects for it (DW-1209). Called by the three close paths
/// before they touch a row -- the confirm path does not need it, because
/// <method>OcuPilot.Kernel.Proposal.Write.Claim</method> refuses a row past its window before the
/// claim is reached. A scheduled retention sweep over these rows is not this story's.
/// <var>pUser</var> <code>""</code> flips every user's stale rows, which is what a path holding no
/// user calls it with.</p>
ClassMethod GuardedExpireStale(pUser As %String = "") As %Status
{
    Set tNow = ..Stamp()
    If pUser = "" {
        Set tParams = [].%Push(..#STATEEXPIRED).%Push(..#STATELIVE).%Push(tNow)
        Quit ..GuardedExecuteRows("UPDATE OcuPilot_Kernel_State.Proposal SET State = ? WHERE %EXACT(State) = ? AND Burned = 0 AND %EXACT(ExpiresAt) < ?", .tParams, .tRows)
    }
    Set tParams = [].%Push(..#STATEEXPIRED).%Push(pUser).%Push(..#STATELIVE).%Push(tNow)
    Quit ..GuardedExecuteRows("UPDATE OcuPilot_Kernel_State.Proposal SET State = ? WHERE %EXACT(UserName) = ? AND %EXACT(State) = ? AND Burned = 0 AND %EXACT(ExpiresAt) < ?", .tParams, .tRows)
}

/// <p>The version proposal <var>pProposalKey</var>'s row currently carries, or <code>0</code> when
/// no row holds that id. The snapshot a claim is made conditional on; never taken from a
/// request.</p>
ClassMethod GuardedRowVersion(pProposalKey As %String, Output pVersion As %Integer) As %Status
{
    Set pVersion = 0
    If pProposalKey = "" Quit $$$OK
    Set tSC = ..GuardedOpenOneWhere("SELECT ID FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", pProposalKey, .tRow)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject(tRow) Set pVersion = +tRow.RowVersion
    Set tRow = ""
    Quit $$$OK
}

/// <p>The state a reader is shown for a row stored <var>pStored</var> expiring at
/// <var>pExpiresAt</var>: <parameter>STATEEXPIRED</parameter> for a still-live row whose window has
/// passed, and the stored state otherwise (DW-1209).</p>
/// <p><b>Read-time projection, so no reader can see a live card the instance would refuse.</b> The
/// stored value is flipped to match the next time the confirm or cancel path touches the row; until
/// then the two agree everywhere it is read, because every read goes through here.</p>
ClassMethod ProjectedState(pStored As %String, pExpiresAt As %String) As %String
{
    If pStored '= ..#STATELIVE Quit pStored
    Set tExpires = ..SecondsOf(pExpiresAt)
    If tExpires = "" Quit pStored
    If ..NowSeconds() > tExpires Quit ..#STATEEXPIRED
    Quit pStored
}

/// <p>Turn <var>pTurnKey</var>'s proposals owned by <var>pUser</var>, oldest first, as the wire
/// array the turn's progress payload carries:
/// <code>{proposalId, target: {type, scope, id}, expiresAt, tool, changed, unchangedCount,
/// rationale, expectedImpact, reverse, state, auditWarning}</code>.</p>
/// <p><b>Every value is the row's own.</b> The target triple is
/// <method>OcuPilot.Kernel.EntityRef.Parse</method>'s reading of the stored key, so a reader
/// cannot be handed a triple this store never wrote; <code>changed</code> is the stored diff,
/// parsed, and the stored payload is not on the wire at all -- the card renders the diff and the
/// unchanged count, never the body.</p>
ClassMethod GuardedRowsForTurn(pTurnKey As %String, pUser As %String, Output pRows As %DynamicArray) As %Status
{
    Set pRows = []
    If (pTurnKey = "") || (pUser = "") Quit $$$OK
    Set tSC = ..GuardedIdsWhereTwoParam("SELECT ID FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(TurnKey) = ? AND %EXACT(UserName) = ? ORDER BY ID", pTurnKey, pUser, .tIds)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:+$Get(tIds) {
        Set tOpenSC = ..GuardedOpenId(tIds(tI), .tRow)
        If $$$ISERR(tOpenSC) Continue
        Set tValuesSC = ..RowValues(tRow, .tValues)
        Set tRow = ""
        If $$$ISERR(tValuesSC) Set tSC = tValuesSC Quit
        Set tSC = ..WireRow(.tValues, .tOut)
        If $$$ISERR(tSC) Quit
        Do pRows.%Push(tOut)
    }
    If $$$ISERR(tSC) Set pRows = []
    Quit tSC
}

/// <p>Conversation <var>pConvKey</var>'s proposals owned by <var>pUser</var>, grouped by the turn
/// that minted them: <var>pByTurn(turnKey)</var> is a <class>%DynamicArray</class> of the same wire
/// rows <method>GuardedRowsForTurn</method> answers, oldest first within each turn.</p>
/// <p><b>One query for the whole transcript</b>, never one per turn: a restored conversation may
/// hold many turns and the caller has one conversation id, so the predicate is over
/// <property>ConvKey</property> and <property>UserName</property> together
/// (<code>ProposalConvIdx</code>). A turn that minted nothing has no subscript, which is a
/// caller's "no proposals" rather than an empty array it has to distinguish.</p>
/// <p>Owner-gated exactly as the per-turn read is (AD-33): the predicate matches the user as well
/// as the conversation, so a conversation this caller does not own answers nothing whatever the
/// caller read the id from.</p>
ClassMethod GuardedRowsForConvo(pConvKey As %String, pUser As %String, Output pByTurn) As %Status
{
    Kill pByTurn
    If (pConvKey = "") || (pUser = "") Quit $$$OK
    Set tSC = ..GuardedIdsWhereTwoParam("SELECT ID FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ConvKey) = ? AND %EXACT(UserName) = ? ORDER BY ID", pConvKey, pUser, .tIds)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:+$Get(tIds) {
        Set tOpenSC = ..GuardedOpenId(tIds(tI), .tRow)
        If $$$ISERR(tOpenSC) Continue
        Set tValuesSC = ..RowValues(tRow, .tValues)
        Set tRow = ""
        If $$$ISERR(tValuesSC) Set tSC = tValuesSC Quit
        Set tWireSC = ..WireRow(.tValues, .tOut)
        If $$$ISERR(tWireSC) Set tSC = tWireSC Quit
        Set tTurn = tValues("turnKey")
        If tTurn = "" Continue
        If '$Data(pByTurn(tTurn)) Set pByTurn(tTurn) = []
        Do pByTurn(tTurn).%Push(tOut)
    }
    If $$$ISERR(tSC) Kill pByTurn
    Quit tSC
}

/// <p>How many rows turn <var>pTurnKey</var> holds.</p>
ClassMethod GuardedCountForTurn(pTurnKey As %String, Output pCount As %Integer) As %Status
{
    Set pCount = 0
    Set tSC = ..GuardedIdsWhere("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(TurnKey) = ?", pTurnKey, .tRows)
    If $$$ISERR(tSC) Quit tSC
    Set pCount = +$Get(tRows(1))
    Quit $$$OK
}

/// <p>Delete every proposal of turn <var>pTurnKey</var>. A test's cleanup, never a lifecycle rule:
/// a proposal outlives its turn's job by construction (AD-6), and the retention sweep over these
/// rows is Story 5.3's.</p>
ClassMethod GuardedDeleteForTurn(pTurnKey As %String) As %Status
{
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(TurnKey) = ?", pTurnKey)
}

/// <p>Delete every proposal of <var>pUser</var>, matched exactly. Same caveat as
/// <method>GuardedDeleteForTurn</method>.</p>
ClassMethod GuardedDeleteForUser(pUser As %String) As %Status
{
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(UserName) = ?", pUser)
}

/// <p>Row <var>pRow</var>'s columns and streams as data, subscripted by wire name.</p>
ClassMethod RowValues(pRow As OcuPilot.Kernel.State.Propose, Output pValues) As %Status [ Private ]
{
    Kill pValues
    Set pValues("proposalId") = ..Text(pRow.ProposalKey)
    Set pValues("token") = ..Text(pRow.Token)
    Set pValues("burned") = ''pRow.Burned
    Set pValues("user") = ..Text(pRow.UserName)
    Set pValues("convKey") = ..Text(pRow.ConvKey)
    Set pValues("turnKey") = ..Text(pRow.TurnKey)
    Set pValues("toolName") = ..Text(pRow.ToolName)
    Set pValues("targetRef") = ..Text(pRow.TargetRef)
    Set pValues("fingerprint") = ..Text(pRow.Fingerprint)
    Set pValues("unchangedCount") = +pRow.UnchangedCount
    Set pValues("rationale") = ..Text(pRow.Rationale)
    Set pValues("expectedImpact") = ..Text(pRow.ExpectedImpact)
    Set pValues("reverse") = ..Text(pRow.Reverse)
    Set pValues("createdAt") = ..Text(pRow.CreatedAt)
    Set pValues("expiresAt") = ..Text(pRow.ExpiresAt)
    Set pValues("storedState") = ..Text(pRow.State)
    Set pValues("state") = ..ProjectedState(pValues("storedState"), pValues("expiresAt"))
    Set pValues("closedReason") = ..Text(pRow.ClosedReason)
    Set pValues("confirmedAt") = ..Text(pRow.ConfirmedAt)
    Set pValues("definitionId") = ..Text(pRow.DefinitionId)
    Set pValues("definitionVersion") = ..Text(pRow.DefinitionVersion)
    Set pValues("auditWarning") = ''pRow.AuditWarning
    Set tSC = ..GuardedStreamText(pRow, "Arguments", .tArguments)
    If $$$ISERR(tSC) Quit tSC
    Set pValues("arguments") = tArguments
    Set tSC = ..GuardedStreamText(pRow, "Payload", .tPayload)
    If $$$ISERR(tSC) Quit tSC
    Set pValues("payload") = tPayload
    Set tSC = ..GuardedStreamText(pRow, "Diff", .tDiff)
    If $$$ISERR(tSC) Quit tSC
    Set pValues("diff") = tDiff
    Quit $$$OK
}

/// <p>One row's wire object from the values <method>RowValues</method> read: the whole
/// <code>proposals[]</code> entry, and the only place that shape is written.</p>
/// <p>The target triple is <method>OcuPilot.Kernel.EntityRef.Parse</method>'s reading of the
/// stored key, so a reader cannot be handed a triple this store never wrote, and the stored
/// payload, fingerprint and token are absent by construction rather than by omission.</p>
ClassMethod WireRow(ByRef pValues, Output pOut As %DynamicObject) As %Status [ Private ]
{
    Set pOut = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Parse($Get(pValues("targetRef")), .tType, .tScope, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Wire(tType, tScope, tId, .tTarget)
    If $$$ISERR(tSC) Quit tSC
    Set tOut = {}
    Do tOut.%Set("proposalId", $Get(pValues("proposalId")), "string")
    Do tOut.%Set("target", tTarget)
    Do tOut.%Set("expiresAt", $Get(pValues("expiresAt")), "string")
    Do tOut.%Set("tool", $Get(pValues("toolName")), "string")
    Do tOut.%Set("changed", ..ParsedArray($Get(pValues("diff"))))
    Do tOut.%Set("unchangedCount", +$Get(pValues("unchangedCount")), "number")
    Do tOut.%Set("rationale", $Get(pValues("rationale")), "string")
    Do tOut.%Set("expectedImpact", $Get(pValues("expectedImpact")), "string")
    Do tOut.%Set("reverse", $Get(pValues("reverse")), "string")
    Do tOut.%Set("state", $Get(pValues("state")), "string")
    Do tOut.%Set("closedReason", $Get(pValues("closedReason")), "string")
    Do tOut.%Set("confirmedAt", $Get(pValues("confirmedAt")), "string")
    Do tOut.%Set("auditWarning", ''$Get(pValues("auditWarning")), "boolean")
    Set pOut = tOut
    Quit $$$OK
}

/// <p><var>pText</var> parsed as a JSON array, or an empty array when it is empty or unreadable --
/// a stored diff that cannot be read leaves the card with no rows rather than failing the poll.</p>
ClassMethod ParsedArray(pText As %String) As %DynamicArray [ Private ]
{
    Set tArray = []
    Try {
        If pText = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pText)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicArray") Set tArray = tParsed
    } Catch {
        Set tArray = []
    }
    Quit tArray
}

/// <p>A fresh opaque id: 32 lower-case hex characters, the idiom
/// <method>OcuPilot.Kernel.State.Turn.NewKey</method> established. Called twice per mint, for the
/// proposal id and for the token, so that holding one is not holding the other.</p>
ClassMethod NewKey() As %String [ Private ]
{
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.GenCryptRand(16)), "L")
}

/// <p>Whole UTC seconds for <var>pStamp</var>, the unit an expiry is compared in.</p>
ClassMethod NowSeconds(pStamp As %String = {$ZTimeStamp}) As %Integer
{
    Quit ##class(OcuPilot.Kernel.State.Turn).NowSeconds(pStamp)
}

/// <p>Whole UTC seconds for an ISO timestamp this class wrote, or <code>""</code>.</p>
ClassMethod SecondsOf(pIso As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.State.Turn).SecondsOf(pIso)
}

/// <p>ISO-8601 UTC for the <code>$ZTimeStamp</code> value <var>pStamp</var>.</p>
ClassMethod Stamp(pStamp As %String = {$ZTimeStamp}) As %String [ Private ]
{
    Quit ##class(OcuPilot.Kernel.State.Turn).Timestamp(pStamp)
}

/// <p>ISO-8601 UTC for the whole-second value <var>pSeconds</var>.</p>
ClassMethod StampOfSeconds(pSeconds As %Integer) As %String [ Private ]
{
    Quit ##class(OcuPilot.Kernel.State.Turn).Timestamp((pSeconds \ 86400) _ "," _ (pSeconds # 86400))
}

/// <p><var>pValue</var> cut to <var>pMax</var> characters, never between the halves of a surrogate
/// pair. A column's declared length is a storage bound, not a caller contract.</p>
ClassMethod Cut(pValue As %String, pMax As %Integer) As %String [ Private ]
{
    Quit ##class(OcuPilot.Kernel.State.Turn).Cap(pValue, pMax, .tCut)
}

/// <p><var>pValue</var> with the <code>$Char(0)</code> a SQL <code>UPDATE</code> leaves normalized
/// to <code>""</code>.</p>
ClassMethod Text(pValue As %String) As %String [ Private ]
{
    If pValue = $Char(0) Quit ""
    Quit pValue
}

}
