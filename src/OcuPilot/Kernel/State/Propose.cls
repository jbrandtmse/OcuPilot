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

/// <p>Mint one row and answer its id, token and expiry.</p>
/// <p><b>Caller contract:</b> <var>pValues</var> carries <code>user</code>, <code>convKey</code>,
/// <code>turnKey</code>, <code>toolName</code>, <code>targetRef</code>, <code>fingerprint</code>,
/// <code>arguments</code>, <code>payload</code>, <code>diff</code>, <code>unchangedCount</code>,
/// <code>rationale</code>, <code>expectedImpact</code> and <code>reverse</code>, every one already
/// built and already stripped of secret-declared keys by
/// <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>; nothing here strips anything.
/// <var>pLimitsClass</var> is the class <code>PROPOSALEXPIRYSECONDS</code> is read from, so a test
/// narrows the window rather than waiting it out.</p>
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
        Do tRow.Arguments.Write($Get(pValues("arguments")))
        Do tRow.Payload.Write($Get(pValues("payload")))
        Do tRow.Diff.Write($Get(pValues("diff")))
        Set tRow.UnchangedCount = +$Get(pValues("unchangedCount"))
        Set tSummaryMax = +$Parameter(pLimitsClass, "SUMMARYMAXLENGTH")
        Set tRow.Rationale = ..Cut($Get(pValues("rationale")), tSummaryMax)
        Set tRow.ExpectedImpact = ..Cut($Get(pValues("expectedImpact")), tSummaryMax)
        Set tRow.Reverse = ..Cut($Get(pValues("reverse")), tSummaryMax)
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

/// <p>Turn <var>pTurnKey</var>'s proposals owned by <var>pUser</var>, oldest first, as the wire
/// array the turn's progress payload carries:
/// <code>{proposalId, target: {type, scope, id}, expiresAt, tool, changed, unchangedCount,
/// rationale, expectedImpact, reverse, state}</code>.</p>
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
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Parse(tValues("targetRef"), .tType, .tScope, .tId)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Wire(tType, tScope, tId, .tTarget)
        If $$$ISERR(tSC) Quit
        Set tOut = {}
        Do tOut.%Set("proposalId", tValues("proposalId"), "string")
        Do tOut.%Set("target", tTarget)
        Do tOut.%Set("expiresAt", tValues("expiresAt"), "string")
        Do tOut.%Set("tool", tValues("toolName"), "string")
        Do tOut.%Set("changed", ..ParsedArray(tValues("diff")))
        Do tOut.%Set("unchangedCount", +tValues("unchangedCount"), "number")
        Do tOut.%Set("rationale", tValues("rationale"), "string")
        Do tOut.%Set("expectedImpact", tValues("expectedImpact"), "string")
        Do tOut.%Set("reverse", tValues("reverse"), "string")
        Do tOut.%Set("state", tValues("state"), "string")
        Do pRows.%Push(tOut)
    }
    If $$$ISERR(tSC) Set pRows = []
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
    Set pValues("state") = ..Text(pRow.State)
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
