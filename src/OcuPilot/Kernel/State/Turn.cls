/// <p>One agent turn (AD-7, AD-33, AD-41): who started it, where it stands, what it spent and how it
/// ended. Held in OcuPilot's protected database and reached only through
/// <class>OcuPilot.Kernel.State.Base</class>'s guarded methods (AD-9).</p>
/// <p><b>Writers.</b> <method>GuardedReserve</method> inserts the row <code>queued</code>. After
/// <method>GuardedBegin</method> the job that began it is the row's only writer, until
/// <method>GuardedFinish</method>. A reserve or a poll may also write a lost turn's terminal state,
/// but only while holding the owner's slot lock, which a live job holds for its whole life.</p>
/// <p><b>Concurrency is a process lock.</b> <code>^OcuPilotTurnSlot(user)</code> is held by the job
/// from begin to finish, so a crashed job frees the slot by exiting; a reserve takes it without
/// waiting, and the <code>queued</code> window closes the gap between a reserve and the job's
/// begin.</p>
/// <p><b>Signals are scalar nodes</b>, <code>^OcuPilotTurnSignal(key, "renewed"|"stop"|"abandon")</code>:
/// polls, stop and sign-out set them while the job writes the row, so they never contend with the
/// row's version. The job only reads them.</p>
/// <p>Terminal and signal codes are passed in by the caller: this package does not name the API's
/// vocabulary class (AD-9's re-entry rule). The limits are read from the class name the caller
/// passes, which is <class>OcuPilot.Kernel.Agent.Limits</class> in production.</p>
Class OcuPilot.Kernel.State.Turn Extends OcuPilot.Kernel.State.Base
{

Parameter STATEQUEUED = "queued";

Parameter STATERUNNING = "running";

Parameter STATECOMPLETED = "completed";

Parameter STATESTOPPED = "stopped";

Parameter STATEABANDONED = "abandoned";

Parameter STATEFAILED = "failed";

/// <p>The value a turn that stopped at its iteration cap records in <property>LimitHit</property>.</p>
Parameter LIMITITERATIONS = "iterations";

/// <p>The opaque, server-minted turn id. Unique; matched exactly.</p>
Property TurnKey As %String(MAXLEN = 64);

/// <p>The user who started the turn, as <code>$USERNAME</code> read it. A weak reference
/// (AD-37).</p>
Property UserName As %String(MAXLEN = 160);

/// <p>The agent definition the turn was started under.</p>
Property DefinitionId As %String(MAXLEN = 32);

/// <p>One of the six <code>STATE*</code> parameter values.</p>
Property State As %String(MAXLEN = 16);

/// <p>The terminal code, or <code>""</code> for a turn that completed or has not ended.</p>
Property Code As %String(MAXLEN = 64);

/// <p>ISO-8601 UTC timestamps (Consistency Conventions: Dates).</p>
Property QueuedAt As %String(MAXLEN = 32);

Property StartedAt As %String(MAXLEN = 32);

Property EndedAt As %String(MAXLEN = 32);

/// <p>Provider calls made so far.</p>
Property Iterations As %Integer [ InitialExpression = 0 ];

Property InputTokens As %Integer [ InitialExpression = 0 ];

Property OutputTokens As %Integer [ InitialExpression = 0 ];

/// <p><parameter>LIMITITERATIONS</parameter> when the turn completed at its iteration cap, else
/// <code>""</code>.</p>
Property LimitHit As %String(MAXLEN = 16);

/// <p>Progress steps counted past the step cap and not stored.</p>
Property StepsDropped As %Integer [ InitialExpression = 0 ];

/// <p>The process id of the job that began the turn.</p>
Property JobId As %String(MAXLEN = 32);

/// <p>The sequence number of the step the turn ended on, when it ended with a code; 0 when no step
/// was written.</p>
Property ErrorSeq As %Integer [ InitialExpression = 0 ];

/// <p>The reply a completed turn produced, cut at the text cap. Model output: untrusted content
/// (AD-11, AD-33).</p>
Property Reply As %String(MAXLEN = "");

/// <p>The screen-context route the turn was started from, or <code>""</code> for a turn that
/// carried no context -- the same <code>context.route</code> the job already holds, recorded once at
/// <method>GuardedBegin</method> so the turn's own row says which screen it ran from after its
/// progress has been swept.</p>
/// <p><b>Added with no <code>SCHEMAVERSION</code> move</b> (Consistency Conventions): a row stored
/// before this property existed reads it back as <code>""</code>, which is the same value a turn
/// with no context holds, so no older row is reinterpreted (the precedent is
/// <property>OcuPilot.Kernel.State.Step.Target</property>).</p>
Property ContextRoute As %String(MAXLEN = 512);

/// <p>The reply's citations as JSON text (<method>OcuPilot.Kernel.Agent.Citations.Cite</method>'s
/// array): <code>[]</code> when the reply cites nothing, <code>""</code> when the turn ended without
/// a reply. Stored as data, never as a reference the instance resolves
/// (AD-37), and never replayed to the model.</p>
/// <p><b>Added with no <code>SCHEMAVERSION</code> move</b> (Consistency Conventions): a row stored
/// before this property existed reads it back as <code>""</code>, which reads as no citations, so no
/// older row is reinterpreted.</p>
Property Citations As %String(MAXLEN = "");

Index TurnKeyIdx On TurnKey [ Unique ];

Index TurnUserIdx On UserName;

/// <p>ISO-8601 UTC for the <code>$ZTimeStamp</code> value <var>pStamp</var>, now by default.</p>
ClassMethod Timestamp(pStamp As %String = {$ZTimeStamp}) As %String
{
    Quit $Translate($ZDateTime(pStamp, 3, 1), " ", "T") _ "Z"
}

/// <p>Whole UTC seconds for the <code>$ZTimeStamp</code> value <var>pStamp</var>, now by default --
/// the unit every duration here is compared in.</p>
ClassMethod NowSeconds(pStamp As %String = {$ZTimeStamp}) As %Integer
{
    Quit ($Piece(pStamp, ",", 1) * 86400) + ($Piece(pStamp, ",", 2) \ 1)
}

/// <p>Whole UTC seconds for an ISO timestamp this class wrote, or <code>""</code> when
/// <var>pIso</var> is empty or not one.</p>
ClassMethod SecondsOf(pIso As %String) As %String
{
    Set tSeconds = ""
    Try {
        If pIso = "" Quit
        Set tHorolog = $ZDateTimeH($Translate($Extract(pIso, 1, 19), "T", " "), 3, 1)
        Set tSeconds = ($Piece(tHorolog, ",", 1) * 86400) + ($Piece(tHorolog, ",", 2) \ 1)
    } Catch ex {
        Set tSeconds = ""
    }
    Quit tSeconds
}

/// <p>Whether <var>pState</var> is one a turn does not leave.</p>
ClassMethod IsTerminal(pState As %String) As %Boolean
{
    Quit $ListFind($ListBuild(..#STATECOMPLETED, ..#STATESTOPPED, ..#STATEABANDONED, ..#STATEFAILED), pState) > 0
}

/// <p><var>pValue</var> cut at <var>pMax</var> characters, never between the halves of a surrogate
/// pair; <var>pTruncated</var> is set to 1 when a cut was made and left alone otherwise.</p>
ClassMethod Cap(pValue As %String, pMax As %Integer, ByRef pTruncated As %Boolean) As %String
{
    If $Length(pValue) <= pMax Quit pValue
    Set pTruncated = 1
    Quit $Extract(pValue, 1, ##class(OcuPilot.Kernel.Utils).SurrogateSafeCutLength(pValue, pMax))
}

/// <p>Reserve <var>pUser</var>'s one turn slot and insert a <code>queued</code> row for definition
/// <var>pDefinitionId</var>. <var>pKey</var> is the new turn's id; <var>pBusy</var> is 1, with
/// nothing inserted, when the user already has a queued or running turn or another request holds
/// the slot this instant.</p>
/// <p>Under the slot lock, and in this order: turns of this user whose job is gone are finished
/// <code>abandoned</code> with <var>pLostCode</var>; busy is refused; the row is inserted and its
/// lease set to now; terminal turns past retention are deleted with their steps and signals. The
/// lock is released before this returns. <var>pSweepStatus</var> reports the retention sweep alone,
/// which never fails the reserve.</p>
ClassMethod GuardedReserve(pUser As %String, pDefinitionId As %String, pLostCode As %String, pLimitsClass As %String, Output pKey As %String, Output pBusy As %Boolean, Output pSweepStatus As %Status) As %Status
{
    Set pKey = ""
    Set pBusy = 0
    Set pSweepStatus = $$$OK
    Set tSC = ..GuardedTurnSlotLock(pUser, 0, .tHeld)
    If $$$ISERR(tSC) Quit tSC
    If 'tHeld {
        Set pBusy = 1
        Quit $$$OK
    }
    Try {
        Set tSC = ..ReconcileHeld(pUser, pLostCode, pLimitsClass, .tLive)
        If $$$ISERR(tSC) Quit
        If tLive {
            Set pBusy = 1
            Quit
        }
        Set tStamp = $ZTimeStamp
        Set tRow = ..%New()
        Set tRow.TurnKey = ..NewKey()
        Set tRow.UserName = pUser
        Set tRow.DefinitionId = pDefinitionId
        Set tRow.State = ..#STATEQUEUED
        Set tRow.QueuedAt = ..Timestamp(tStamp)
        Set tSC = ..GuardedSaveIfCurrent(tRow, 0)
        If $$$ISERR(tSC) Quit
        Set tKey = tRow.TurnKey
        Set tRow = ""
        Set tSC = ..GuardedTurnSignalSet(tKey, "renewed", ..NowSeconds(tStamp))
        If $$$ISERR(tSC) Quit
        Set pKey = tKey
        Set pSweepStatus = ..GuardedSweep(pLimitsClass)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Do ..GuardedTurnSlotUnlock(pUser)
    Quit tSC
}

/// <p>Finish every turn of <var>pUser</var> whose job is gone, when the slot is free this instant:
/// what a poll does before it reads. A slot another process holds means a live job or a reserve in
/// progress, and nothing is written.</p>
ClassMethod GuardedReconcile(pUser As %String, pLostCode As %String, pLimitsClass As %String) As %Status
{
    Set tSC = ..GuardedTurnSlotLock(pUser, 0, .tHeld)
    If $$$ISERR(tSC) || 'tHeld Quit tSC
    Try {
        Set tSC = ..ReconcileHeld(pUser, pLostCode, pLimitsClass, .tLive)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Do ..GuardedTurnSlotUnlock(pUser)
    Quit tSC
}

/// <p><b>Caller contract:</b> the caller holds <var>pUser</var>'s slot. A running turn is then one
/// no job holds, and a turn queued longer than the queued limit is one whose job never began; both
/// are finished <code>abandoned</code> with <var>pLostCode</var>. <var>pLive</var> is 1 when a
/// younger queued turn remains.</p>
ClassMethod ReconcileHeld(pUser As %String, pLostCode As %String, pLimitsClass As %String, Output pLive As %Boolean) As %Status [ Private ]
{
    Set pLive = 0
    Set tSC = ..GuardedIdsWhere("SELECT ID FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(UserName) = ? AND State IN ('queued', 'running') ORDER BY ID", pUser, .tIds)
    If $$$ISERR(tSC) Quit tSC
    Set tNow = ..NowSeconds()
    Set tQueuedLimit = +$Parameter(pLimitsClass, "QUEUEDSECONDS")
    For tI = 1:1:+$Get(tIds) {
        Set tSC = ..GuardedOpenId(tIds(tI), .tRow)
        If $$$ISERR(tSC) Quit
        Set tLost = (tRow.State = ..#STATERUNNING)
        If tRow.State = ..#STATEQUEUED {
            Set tQueued = ..SecondsOf(tRow.QueuedAt)
            If (tQueued = "") || ((tNow - tQueued) > tQueuedLimit) {
                Set tLost = 1
            } Else {
                Set pLive = 1
            }
        }
        If tLost {
            Set tRow.State = ..#STATEABANDONED
            Set tRow.Code = pLostCode
            Set tRow.EndedAt = ..Timestamp()
            Set tSC = ..GuardedSaveIfCurrent(tRow, +tRow.RowVersion)
        }
        Set tRow = ""
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Begin turn <var>pKey</var> in the calling job: wait for <var>pUser</var>'s slot up to the
/// queued limit, then move the row from <code>queued</code> to <code>running</code>, stamping the
/// start and <code>$JOB</code>. <var>pBegun</var> is 1 only when the row still read
/// <code>queued</code> and belonged to <var>pUser</var>; the slot is then held until
/// <method>GuardedFinish</method>, and released here otherwise. <var>pStartedSeconds</var> is the
/// start in <method>NowSeconds</method> units.</p>
/// <p><var>pContextRoute</var> is written onto <property>ContextRoute</property> in the same write,
/// which is the one place it is ever set; trailing and optional so a caller with no context calls
/// this unchanged.</p>
ClassMethod GuardedBegin(pKey As %String, pUser As %String, pLimitsClass As %String, Output pBegun As %Boolean, Output pStartedSeconds As %Integer, pContextRoute As %String = "") As %Status
{
    Set pBegun = 0
    Set pStartedSeconds = ""
    Set tSC = ..GuardedTurnSlotLock(pUser, +$Parameter(pLimitsClass, "QUEUEDSECONDS"), .tHeld)
    If $$$ISERR(tSC) || 'tHeld Quit tSC
    Try {
        Set tSC = ..OpenByKey(pKey, .tRow)
        If $$$ISERR(tSC) || '$IsObject(tRow) Quit
        If (tRow.State '= ..#STATEQUEUED) || (tRow.UserName '= pUser) {
            Set tRow = ""
            Quit
        }
        Set tStamp = $ZTimeStamp
        Set tRow.State = ..#STATERUNNING
        Set tRow.StartedAt = ..Timestamp(tStamp)
        Set tRow.JobId = $Job
        ; No truncation byref: the route is a closed enum from Loop.ContextRoute() and there is no
        ; contextRouteTruncated column, so a flag nothing reads would only look like one.
        Set tRow.ContextRoute = ..Cap(pContextRoute, ..#ROUTEMAXLENGTH)
        Set tSC = ..GuardedSaveIfCurrent(tRow, +tRow.RowVersion)
        Set tRow = ""
        If $$$ISERR(tSC) Quit
        Set pBegun = 1
        Set pStartedSeconds = ..NowSeconds(tStamp)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If 'pBegun Do ..GuardedTurnSlotUnlock(pUser)
    Quit tSC
}

/// <p>Record a running turn's call count and token spend so far.</p>
ClassMethod GuardedProgress(pKey As %String, pIterations As %Integer, pInputTokens As %Integer, pOutputTokens As %Integer) As %Status
{
    Set tSC = ..OpenByKey(pKey, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit tSC
    If ..IsTerminal(tRow.State) Quit $$$OK
    Set tRow.Iterations = +pIterations
    Set tRow.InputTokens = +pInputTokens
    Set tRow.OutputTokens = +pOutputTokens
    Set tSC = ..GuardedSaveIfCurrent(tRow, +tRow.RowVersion)
    Set tRow = ""
    Quit tSC
}

/// <p>Count one progress step past the cap on turn <var>pKey</var>, and answer the new count in
/// <var>pDropped</var>. <class>OcuPilot.Kernel.State.Step</class> is the caller.</p>
ClassMethod GuardedAddDropped(pKey As %String, Output pDropped As %Integer) As %Status
{
    Set pDropped = 0
    Set tSC = ..OpenByKey(pKey, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit tSC
    Set tRow.StepsDropped = tRow.StepsDropped + 1
    Set pDropped = tRow.StepsDropped
    Set tSC = ..GuardedSaveIfCurrent(tRow, +tRow.RowVersion)
    Set tRow = ""
    Quit tSC
}

/// <p>The steps counted past the cap on turn <var>pKey</var> so far.</p>
ClassMethod GuardedDropped(pKey As %String, Output pDropped As %Integer) As %Status
{
    Set pDropped = 0
    Set tSC = ..OpenByKey(pKey, .tRow)
    If $$$ISOK(tSC) && $IsObject(tRow) Set pDropped = +tRow.StepsDropped
    Set tRow = ""
    Quit tSC
}

/// <p>End turn <var>pKey</var> in <var>pState</var> with <var>pCode</var>, the iteration-limit
/// marker <var>pLimitHit</var>, the reply <var>pReply</var> cut at the text cap, and the step
/// <var>pErrorSeq</var> it ended on, and the reply's citations <var>pCitations</var> (JSON text);
/// then release <var>pUser</var>'s slot. A row already terminal is left as it is. The slot is
/// released on every path.</p>
ClassMethod GuardedFinish(pKey As %String, pUser As %String, pState As %String, pCode As %String, pLimitHit As %String, pReply As %String, pErrorSeq As %Integer, pLimitsClass As %String, pCitations As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..OpenByKey(pKey, .tRow)
        If $$$ISERR(tSC) || '$IsObject(tRow) Quit
        If ..IsTerminal(tRow.State) {
            Set tRow = ""
            Quit
        }
        Set tRow.State = pState
        Set tRow.Code = pCode
        Set tRow.LimitHit = pLimitHit
        Set tRow.Reply = ..Cap(pReply, +$Parameter(pLimitsClass, "TEXTMAXLENGTH"))
        Set tRow.ErrorSeq = +pErrorSeq
        Set tRow.Citations = pCitations
        Set tRow.EndedAt = ..Timestamp()
        Set tSC = ..GuardedSaveIfCurrent(tRow, +tRow.RowVersion)
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Do ..GuardedTurnSlotUnlock(pUser)
    Quit tSC
}

/// <p>Renew turn <var>pKey</var>'s lease to now. <b>Caller contract:</b> the caller has already
/// established that the authenticated caller owns the turn and that it has not ended.</p>
ClassMethod GuardedRenew(pKey As %String) As %Status
{
    Quit ..GuardedTurnSignalSet(pKey, "renewed", ..NowSeconds())
}

/// <p>Ask turn <var>pKey</var> to stop at its next step boundary, when <var>pUser</var> owns it and
/// it has not ended. <var>pFound</var> is 0, and nothing is set, otherwise.</p>
ClassMethod GuardedRequestStop(pKey As %String, pUser As %String, Output pFound As %Boolean) As %Status
{
    Set pFound = 0
    Set tSC = ..GuardedForOwner(pKey, pUser, .tFound, .tValues)
    If $$$ISERR(tSC) || 'tFound Quit tSC
    If ..IsTerminal(tValues("state")) Quit $$$OK
    Set pFound = 1
    Quit ..GuardedTurnSignalSet(pKey, "stop", 1)
}

/// <p>Ask every queued or running turn of <var>pUser</var>, matched exactly, to abandon at its next
/// step boundary; <var>pCount</var> is how many were asked.</p>
ClassMethod GuardedAbandonForUser(pUser As %String, Output pCount As %Integer) As %Status
{
    Set pCount = 0
    Set tSC = ..GuardedIdsWhere("SELECT ID FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(UserName) = ? AND State IN ('queued', 'running') ORDER BY ID", pUser, .tIds)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:+$Get(tIds) {
        Set tSC = ..GuardedOpenId(tIds(tI), .tRow)
        If $$$ISERR(tSC) Quit
        Set tKey = tRow.TurnKey
        Set tRow = ""
        Set tSC = ..GuardedTurnSignalSet(tKey, "abandon", 1)
        If $$$ISERR(tSC) Quit
        Set pCount = pCount + 1
    }
    Quit tSC
}

/// <p>Whether job <var>pJobId</var> is running a turn: <var>pIsTurnJob</var> is 1 when a
/// <code>running</code> row carries that <property>JobId</property>, which
/// <method>GuardedBegin</method> stamps from the job's own <code>$JOB</code>.</p>
/// <p><b>Only a running turn counts.</b> A pid is reusable once its process has ended, so a
/// terminal row's <property>JobId</property> would answer for whatever process the instance next
/// gave that pid to. The cost of the narrowing is named rather than hidden: a job that died
/// without finishing its turn leaves the row <code>running</code> until a reserve or a poll
/// reconciles it, so that pid answers 1 until then. The converse window is a <code>queued</code>
/// row, whose <property>JobId</property> <method>GuardedBegin</method> has not stamped yet: that
/// job answers 0 until its turn begins, and no record identifies it before then.</p>
/// <p><b>Caller contract:</b> <class>OcuPilot.Kernel.Proposal.Prohibited</class> asks it inside
/// the confirm transition to refuse a write against a turn job (AD-7, AD-10). It reads and never
/// writes.</p>
ClassMethod GuardedIsTurnJob(pJobId As %String, Output pIsTurnJob As %Boolean) As %Status
{
    Set pIsTurnJob = 0
    If pJobId = "" Quit $$$OK
    Set tSC = ..GuardedIdsWhere("SELECT ID FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(JobId) = ? AND State = 'running' ORDER BY ID", pJobId, .tIds)
    If $$$ISERR(tSC) Quit tSC
    Set pIsTurnJob = ($Get(tIds(1)) '= "")
    Quit $$$OK
}

/// <p>Turn <var>pKey</var>'s signals: the stop and abandon flags, and the lease's last renewal in
/// <method>NowSeconds</method> units (<code>""</code> when never set).</p>
ClassMethod GuardedSignals(pKey As %String, Output pStop As %Boolean, Output pAbandon As %Boolean, Output pRenewedAt As %String) As %Status
{
    Set pStop = 0
    Set pAbandon = 0
    Set pRenewedAt = ""
    Set tSC = ..GuardedTurnSignalGet(pKey, "stop", .tStop)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..GuardedTurnSignalGet(pKey, "abandon", .tAbandon)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..GuardedTurnSignalGet(pKey, "renewed", .pRenewedAt)
    If $$$ISERR(tSC) Quit tSC
    Set pStop = ''tStop
    Set pAbandon = ''tAbandon
    Quit $$$OK
}

/// <p>Turn <var>pKey</var> when <var>pUser</var> owns it, both matched exactly. <var>pFound</var>
/// is 0 for an unknown key and for another user's turn alike. <var>pValues</var> carries
/// <code>state</code>, <code>code</code> and <code>user</code>.</p>
ClassMethod GuardedForOwner(pKey As %String, pUser As %String, Output pFound As %Boolean, Output pValues) As %Status
{
    Set pFound = 0
    Kill pValues
    Set tSC = ..GuardedIdsWhereTwoParam("SELECT ID FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = ? AND %EXACT(UserName) = ?", pKey, pUser, .tIds)
    If $$$ISERR(tSC) Quit tSC
    If $Get(tIds(1)) = "" Quit $$$OK
    Set tSC = ..GuardedOpenId(tIds(1), .tRow)
    If $$$ISERR(tSC) Quit tSC
    Set pValues("state") = tRow.State
    Set pValues("code") = ..Text(tRow.Code)
    Set pValues("user") = tRow.UserName
    Set tRow = ""
    Set pFound = 1
    Quit $$$OK
}

/// <p>The progress projection of turn <var>pKey</var> when <var>pUser</var> owns it:
/// <code>{turnId, state, startedAt, endedAt, iterations, tokens{input,output}, limit, steps,
/// stepsDropped, reply, citations, error, navigation?}</code>. <code>citations</code> is always an
/// array (<method>CitationsArray</method>). <code>error</code> is <code>{seq, code}</code>
/// when the turn ended with a code, else <code>null</code>; the caller adds its <code>reason</code>.
/// Ownership is <method>GuardedForOwner</method>'s answer, so there is one predicate that decides
/// it.</p>
/// <p><code>navigation</code> (Story 4.7, AD-11 rule 3) is
/// <code>{seq, route, entityId, criterion}</code>
/// carried only while <class>OcuPilot.Kernel.State.Nav</class> holds an unsettled directive for
/// this turn <b>and</b> the announce step it names is present in this same <var>pView</var>'s own
/// <code>steps</code> -- the pairing that makes it impossible for a reader to observe a directive
/// whose announcement it cannot also see. The key is omitted otherwise, never emitted
/// <code>null</code>.</p>
ClassMethod GuardedView(pKey As %String, pUser As %String, Output pFound As %Boolean, Output pView As %DynamicObject) As %Status
{
    Set pFound = 0
    Set pView = ""
    Set tSC = ..GuardedForOwner(pKey, pUser, .tOwned, .tValues)
    If $$$ISERR(tSC) || 'tOwned Quit tSC
    Set tSC = ..OpenByKey(pKey, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit tSC
    Set tView = {}
    Do tView.%Set("turnId", tRow.TurnKey, "string")
    Do tView.%Set("state", tRow.State, "string")
    Do ..SetNullable(tView, "startedAt", ..Text(tRow.StartedAt))
    Do ..SetNullable(tView, "endedAt", ..Text(tRow.EndedAt))
    Do tView.%Set("iterations", +tRow.Iterations, "number")
    Set tTokens = {}
    Do tTokens.%Set("input", +tRow.InputTokens, "number")
    Do tTokens.%Set("output", +tRow.OutputTokens, "number")
    Do tView.%Set("tokens", tTokens)
    Do ..SetNullable(tView, "limit", ..Text(tRow.LimitHit))
    Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedRows(pKey, .tSteps)
    If $$$ISERR(tSC) {
        Set tRow = ""
        Quit tSC
    }
    Do tView.%Set("steps", tSteps)
    Do tView.%Set("stepsDropped", +tRow.StepsDropped, "number")
    Do ..SetNullable(tView, "reply", $Select(tRow.State = ..#STATECOMPLETED: ..Text(tRow.Reply), 1: ""))
    Do tView.%Set("citations", ..CitationsArray($Select(tRow.State = ..#STATECOMPLETED: ..Text(tRow.Citations), 1: "")))
    If ..Text(tRow.Code) = "" {
        Do tView.%Set("error", "", "null")
    } Else {
        Set tError = {}
        Do tError.%Set("seq", +tRow.ErrorSeq, "number")
        Do tError.%Set("code", tRow.Code, "string")
        Do tView.%Set("error", tError)
    }
    Set tRow = ""

    Set tNavSC = ##class(OcuPilot.Kernel.State.Nav).GuardedPending(pKey, .tNavSeq, .tNavRoute, .tNavEntity, .tNavSettled, .tNavOutcome, .tNavCode, .tNavCriterion)
    If $$$ISOK(tNavSC) && (+tNavSeq > 0) && 'tNavSettled {
        Set tHasAnnounce = 0
        Set tStepIterator = tSteps.%GetIterator()
        While tStepIterator.%GetNext(.tStepIndex, .tStepEntry) {
            If (tStepEntry.%Get("seq") = +tNavSeq) && (tStepEntry.%Get("kind") = "announce") {
                Set tHasAnnounce = 1
                Quit
            }
        }
        If tHasAnnounce {
            Set tNav = {}
            Do tNav.%Set("seq", +tNavSeq, "number")
            Do tNav.%Set("route", tNavRoute, "string")
            If tNavEntity = "" {
                Do tNav.%Set("entityId", "", "null")
            } Else {
                Do tNav.%Set("entityId", tNavEntity, "string")
            }
            Do tNav.%Set("criterion", $Get(tNavCriterion), "string")
            Do tView.%Set("navigation", tNav)
        }
    }

    Set pView = tView
    Set pFound = 1
    Quit $$$OK
}

/// <p>Delete every terminal turn that ended retention seconds ago or more, with its steps and
/// signals.</p>
ClassMethod GuardedSweep(pLimitsClass As %String) As %Status
{
    Set tSC = ..GuardedIdsWhereNoParam("SELECT ID FROM OcuPilot_Kernel_State.Turn WHERE State IN ('completed', 'stopped', 'abandoned', 'failed') ORDER BY ID", .tIds)
    If $$$ISERR(tSC) Quit tSC
    Set tCutoff = ..NowSeconds() - $Parameter(pLimitsClass, "RETENTIONSECONDS")
    For tI = 1:1:+$Get(tIds) {
        Set tOpenSC = ..GuardedOpenId(tIds(tI), .tRow)
        If $$$ISERR(tOpenSC) Continue
        Set tKey = tRow.TurnKey
        Set tEnded = ..SecondsOf(..Text(tRow.EndedAt))
        Set tRow = ""
        If (tEnded = "") || (tEnded > tCutoff) Continue
        Set tSC = ..GuardedDelete(tKey)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Delete turn <var>pKey</var>, its steps, its navigation directive and its signals.</p>
ClassMethod GuardedDelete(pKey As %String) As %Status
{
    Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedDeleteForTurn(pKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.State.Nav).GuardedDeleteForTurn(pKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..GuardedTurnSignalKill(pKey)
    If $$$ISERR(tSC) Quit tSC
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = ?", pKey)
}

/// <p>The row for <var>pKey</var>, matched exactly, or <code>$$$NULLOREF</code>.</p>
ClassMethod OpenByKey(pKey As %String, Output pRow) As %Status [ Private ]
{
    Quit ..GuardedOpenOneWhere("SELECT ID FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = ?", pKey, .pRow)
}

/// <p>A fresh opaque turn id: 32 lower-case hex characters from the instance's random source.</p>
ClassMethod NewKey() As %String [ Private ]
{
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.GenCryptRand(16)), "L")
}

/// <p>The stored citations text <var>pJson</var> as an array: <code>[]</code> when it is empty, does
/// not parse or is not an array.</p>
ClassMethod CitationsArray(pJson As %String) As %DynamicArray
{
    Set tArray = []
    Try {
        If (pJson = "") || (pJson = $Char(0)) Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pJson)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicArray") Set tArray = tParsed
    } Catch ex {
        Set tArray = []
    }
    Quit tArray
}

/// <p>Set <var>pKey</var> on <var>pObject</var> to <var>pValue</var>, or to JSON null when it is
/// empty.</p>
ClassMethod SetNullable(pObject As %DynamicObject, pKey As %String, pValue As %String) [ Private ]
{
    If pValue = "" {
        Do pObject.%Set(pKey, "", "null")
    } Else {
        Do pObject.%Set(pKey, pValue, "string")
    }
}

/// <p><var>pValue</var> with the <code>$Char(0)</code> a SQL <code>UPDATE</code> leaves normalized
/// to <code>""</code>.</p>
ClassMethod Text(pValue As %String) As %String [ Private ]
{
    If pValue = $Char(0) Quit ""
    Quit pValue
}

}
