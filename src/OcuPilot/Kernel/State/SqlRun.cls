/// <p>One background SQL run (Story 19.15, AD-7, AD-9, AD-36, AD-41): who started it, in which
/// namespace, where it stands and, once it has ended, the answer its owner's poll reads. Held in
/// OcuPilot's protected database and reached only through
/// <class>OcuPilot.Kernel.State.Base</class>'s guarded methods. The statement and its values are
/// never stored here.</p>
/// <p><b>Writers.</b> <method>GuardedReserve</method> inserts the row <code>queued</code>. After
/// <method>GuardedBegin</method> the job that began it writes its terminal state through
/// <method>GuardedFinish</method>; meanwhile <method>GuardedCancel</method> may set the cancel flag,
/// and a reconcile may end a row <code>failed</code>, but only while the row's run lock is free.</p>
/// <p><b>Concurrency is a process lock.</b> <code>^OcuPilotSqlRun(key)</code> is held by the run's job
/// from begin to finish, so a job that dies frees it by exiting, and a <code>running</code> row whose
/// lock is free, or a <code>queued</code> row past the queued limit whose lock is free, is lost.
/// <code>^OcuPilotSqlRun("reserve")</code> is the reserve section: the per-user and per-instance caps
/// are counted and the row inserted while it is held.</p>
/// <p><b>A <code>failed</code> row with no answer is a lost run.</b> The caller names its code: this
/// package does not name the API's vocabulary (AD-9's re-entry rule). The limits are read from the
/// class name the caller passes, <class>OcuPilot.Kernel.Agent.Limits</class> in production.</p>
Class OcuPilot.Kernel.State.SqlRun Extends OcuPilot.Kernel.State.Base
{

Parameter STATEQUEUED = "queued";

Parameter STATERUNNING = "running";

Parameter STATEENDED = "ended";

Parameter STATECANCELED = "canceled";

Parameter STATEFAILED = "failed";

/// <p>The run lock's key for the reserve section; a run key is 32 hex characters and never this.</p>
Parameter RESERVEKEY = "reserve";

/// <p>How many times a conditional write that lost to another writer re-reads the row and tries
/// again.</p>
Parameter WRITETRIES As %Integer = 3;

/// <p>The opaque, server-minted run id: 32 lower-case hex characters. Unique; matched exactly.</p>
Property RunKey As %String(MAXLEN = 64);

/// <p>The user who started the run, as <code>$USERNAME</code> read it. A weak reference
/// (AD-37).</p>
Property UserName As %String(MAXLEN = 160);

/// <p>The namespace the statement runs in.</p>
Property Namespace As %String(MAXLEN = 64);

/// <p>One of the five <code>STATE*</code> parameter values.</p>
Property State As %String(MAXLEN = 16);

/// <p>The process id of the job that began the run.</p>
Property JobId As %String(MAXLEN = 32);

/// <p>Whether the owner asked the run to stop. A row that ends with it set ends
/// <code>canceled</code>, with no answer.</p>
Property CancelRequested As %Boolean [ InitialExpression = 0 ];

/// <p>ISO-8601 UTC timestamps (Consistency Conventions: Dates).</p>
Property QueuedAt As %String(MAXLEN = 32);

Property StartedAt As %String(MAXLEN = 32);

Property EndedAt As %String(MAXLEN = 32);

/// <p>Stored as JSON text in a stream deliberately: the run's answer -- the port's run answer for an
/// <code>ended</code> run, or the refusal envelope for a <code>failed</code> one -- written once when
/// the run ends and read back whole by its owner's poll, never queried by member. A stream because a
/// run answer holds up to 1,000,000 characters of rows.</p>
Property Answer As %Stream.GlobalCharacter;

Index RunKeyIdx On RunKey [ Unique ];

Index RunUserIdx On UserName;

/// <p>Whether <var>pState</var> is one a run does not leave.</p>
ClassMethod IsTerminal(pState As %String) As %Boolean
{
    Quit $ListFind($ListBuild(..#STATEENDED, ..#STATECANCELED, ..#STATEFAILED), pState) > 0
}

/// <p>Reserve a run of <var>pUser</var> in <var>pNamespace</var> and insert its <code>queued</code>
/// row; <var>pKey</var> is the new run's id. In the reserve section, and in this order: every
/// <code>queued</code> or <code>running</code> row is reconciled (<method>Reconcile</method>);
/// <var>pBusyKey</var> is set to the user's live run's id when one remains; <var>pFull</var> is 1
/// when the live rows number <var>pMaxRunning</var> or more; otherwise the user's ended rows are
/// deleted and the row inserted. Neither refusal inserts anything. The section is released before the
/// expired rows are swept (<method>GuardedSweep</method>), whether or not a row was inserted; the
/// sweep's status is <var>pSweepStatus</var>, and it never fails the reserve.</p>
/// <p>A reserve section another process holds past <parameter>CAPLOCKTIMEOUT</parameter> seconds is
/// an error status, with nothing inserted.</p>
ClassMethod GuardedReserve(pUser As %String, pNamespace As %String, pMaxRunning As %Integer, pLimitsClass As %String, Output pKey As %String, Output pBusyKey As %String, Output pFull As %Boolean, Output pSweepStatus As %Status) As %Status
{
    Set pKey = ""
    Set pBusyKey = ""
    Set pFull = 0
    Set pSweepStatus = $$$OK
    Set tSC = ..GuardedSqlRunLock(..#RESERVEKEY, ..#CAPLOCKTIMEOUT, .tHeld)
    If $$$ISERR(tSC) Quit tSC
    If 'tHeld Quit $$$ERROR($$$GeneralError, "the background run reserve section stayed held")
    Try {
        Set tSC = ..GuardedIdsWhereNoParam("SELECT ID FROM OcuPilot_Kernel_State.SqlRun WHERE State IN ('queued', 'running') ORDER BY ID", .tIds)
        If $$$ISERR(tSC) Quit
        Set tLive = 0
        For tI = 1:1:+$Get(tIds) {
            Set tSC = ..Reconcile(tIds(tI), pLimitsClass, .tState, .tOwner, .tRunKey)
            If $$$ISERR(tSC) Quit
            If '..IsTerminal(tState) && (tState '= "") {
                Set tLive = tLive + 1
                If (tOwner = pUser) && (pBusyKey = "") Set pBusyKey = tRunKey
            }
        }
        If $$$ISERR(tSC) Quit
        If pBusyKey '= "" Quit
        If tLive >= +pMaxRunning {
            Set pFull = 1
            Quit
        }
        Set tSC = ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ? AND State IN ('ended', 'canceled', 'failed')", pUser)
        If $$$ISERR(tSC) Quit
        Set tRow = ..%New()
        Set tRow.RunKey = ..NewKey()
        Set tRow.UserName = pUser
        Set tRow.Namespace = pNamespace
        Set tRow.State = ..#STATEQUEUED
        Set tRow.QueuedAt = ##class(OcuPilot.Kernel.State.Turn).Timestamp()
        Set tSC = ..GuardedSaveIfCurrent(tRow, 0)
        If $$$ISOK(tSC) Set pKey = tRow.RunKey
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Do ..GuardedSqlRunUnlock(..#RESERVEKEY)
    Set pSweepStatus = ..GuardedSweep(pLimitsClass)
    Quit tSC
}

/// <p>Begin run <var>pKey</var> in the calling job: take its run lock without waiting, then move the
/// row from <code>queued</code> to <code>running</code>, stamping the start and <code>$JOB</code>.
/// <var>pBegun</var> is 1 only when the row still read <code>queued</code> and belonged to
/// <var>pUser</var>; the lock is then held until <method>GuardedFinish</method>, and released here
/// otherwise. <var>pCancel</var> is 1 when the owner asked the run to stop before it began.</p>
ClassMethod GuardedBegin(pKey As %String, pUser As %String, Output pBegun As %Boolean, Output pCancel As %Boolean) As %Status
{
    Set pBegun = 0
    Set pCancel = 0
    Set tSC = ..GuardedSqlRunLock(pKey, 0, .tHeld)
    If $$$ISERR(tSC) || 'tHeld Quit tSC
    Try {
        For tTry = 1:1:..#WRITETRIES {
            Set tRow = ""
            Set tSC = ..OpenByKey(pKey, .tRow)
            If $$$ISERR(tSC) || '$IsObject(tRow) Quit
            If (tRow.State '= ..#STATEQUEUED) || (tRow.UserName '= pUser) Quit
            Set tRow.State = ..#STATERUNNING
            Set tRow.StartedAt = ##class(OcuPilot.Kernel.State.Turn).Timestamp()
            Set tRow.JobId = $Job
            Set tCancel = ''tRow.CancelRequested
            Set tSC = ..GuardedSaveIfCurrent(tRow, +tRow.RowVersion)
            If ..IsStaleSave(tSC) {
                Set tSC = $$$OK
                Continue
            }
            If $$$ISERR(tSC) Quit
            Set pBegun = 1
            Set pCancel = tCancel
            Quit
        }
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If 'pBegun Do ..GuardedSqlRunUnlock(pKey)
    Quit tSC
}

/// <p>End run <var>pKey</var> in <var>pState</var> (<parameter>STATEENDED</parameter> or
/// <parameter>STATEFAILED</parameter>) with <var>pAnswerJson</var> as its answer: the port's run
/// answer for an ended run, the refusal envelope <code>{code, reason, detail?}</code> for a failed one,
/// or <code>""</code> for a lost one. A row whose cancel flag is set ends
/// <parameter>STATECANCELED</parameter> with no answer, and a row already terminal is left as it is.
/// The answer, the state and the end are written in one save, then the run lock is released, on every
/// path.</p>
ClassMethod GuardedFinish(pKey As %String, pState As %String, pAnswerJson As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        For tTry = 1:1:..#WRITETRIES {
            Set tRow = ""
            Set tSC = ..OpenByKey(pKey, .tRow)
            If $$$ISERR(tSC) || '$IsObject(tRow) Quit
            If ..IsTerminal(tRow.State) Quit
            If tRow.CancelRequested {
                Set tRow.State = ..#STATECANCELED
            } Else {
                Set tRow.State = pState
                If pAnswerJson '= "" Do tRow.Answer.Write(pAnswerJson)
            }
            Set tRow.EndedAt = ##class(OcuPilot.Kernel.State.Turn).Timestamp()
            Set tSC = ..GuardedSaveIfCurrent(tRow, +tRow.RowVersion)
            If ..IsStaleSave(tSC) {
                Set tSC = $$$OK
                Continue
            }
            Quit
        }
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Do ..GuardedSqlRunUnlock(pKey)
    Quit tSC
}

/// <p>Ask run <var>pKey</var> to stop, when <var>pUser</var> owns it; both are matched exactly.
/// <var>pFound</var> is 0 for an unknown key and for another user's run alike, and nothing is set. A
/// <code>queued</code> or <code>running</code> row gains its cancel flag; a terminal row is left as it
/// is. <var>pLive</var> is 1 only while the row reads <code>running</code> and its job holds the run
/// lock, and <var>pJobId</var> is then that job's process id: the one moment a cancel may be sent to
/// it, since a process id is reused once its process has ended.</p>
ClassMethod GuardedCancel(pKey As %String, pUser As %String, Output pFound As %Boolean, Output pJobId As %String, Output pLive As %Boolean) As %Status
{
    Set pFound = 0
    Set pJobId = ""
    Set pLive = 0
    Set tState = ""
    Set tSC = $$$OK
    Try {
        For tTry = 1:1:..#WRITETRIES {
            Set tSC = ..IdForOwner(pKey, pUser, .tId)
            If $$$ISERR(tSC) || (tId = "") Quit
            Set pFound = 1
            Set tRow = ""
            Set tSC = ..GuardedOpenId(tId, .tRow)
            If $$$ISERR(tSC) Quit
            Set tState = tRow.State
            Set pJobId = ..Text(tRow.JobId)
            If ..IsTerminal(tState) || tRow.CancelRequested Quit
            Set tRow.CancelRequested = 1
            Set tSC = ..GuardedSaveIfCurrent(tRow, +tRow.RowVersion)
            If ..IsStaleSave(tSC) {
                Set tSC = $$$OK
                Continue
            }
            Quit
        }
        Set tRow = ""
        If $$$ISOK(tSC) && pFound && (tState = ..#STATERUNNING) && (pJobId '= "") {
            Set tSC = ..LockHeld(pKey, .pLive)
        }
    } Catch ex {
        Set pLive = 0
        Set tSC = ex.AsStatus()
    }
    If 'pLive Set pJobId = ""
    Quit tSC
}

/// <p>Run <var>pKey</var> as its owner <var>pUser</var> reads it, both matched exactly in the
/// statement's literal SQL, after a lost run is ended (<method>Reconcile</method>).
/// <var>pFound</var> is 0 for an unknown key and for another user's run alike. <var>pView</var> is
/// <code>{id, status, startedAt, endedAt, cancelRequested, result?, refusal?}</code>:
/// <code>status</code> is <code>running</code> for a queued or running row, else the row's state;
/// <code>result</code> is an ended run's stored answer, and <code>refusal</code> a failed run's stored
/// envelope, each present only when one is stored.</p>
ClassMethod GuardedViewForOwner(pKey As %String, pUser As %String, pLimitsClass As %String, Output pFound As %Boolean, Output pView As %DynamicObject) As %Status
{
    Set pFound = 0
    Set pView = ""
    Set tSC = ..IdForOwner(pKey, pUser, .tId)
    If $$$ISERR(tSC) || (tId = "") Quit tSC
    Set tSC = ..Reconcile(tId, pLimitsClass, .tState, .tOwner, .tRunKey)
    If $$$ISERR(tSC) Quit tSC
    If tState = "" Quit $$$OK
    Set tSC = ..GuardedOpenId(tId, .tRow)
    If $$$ISERR(tSC) Quit tSC
    Set tView = {}
    Do tView.%Set("id", tRow.RunKey, "string")
    Set tState = tRow.State
    Do tView.%Set("status", $Select(..IsTerminal(tState): tState, 1: ..#STATERUNNING), "string")
    Do ..SetNullable(tView, "startedAt", ..Text(tRow.StartedAt))
    Do ..SetNullable(tView, "endedAt", ..Text(tRow.EndedAt))
    Do tView.%Set("cancelRequested", ''tRow.CancelRequested, "boolean")
    If (tState = ..#STATEENDED) || (tState = ..#STATEFAILED) {
        Set tStreamSC = ..GuardedStreamText(tRow, "Answer", .tText)
        If $$$ISERR(tStreamSC) {
            Set tRow = ""
            Quit tStreamSC
        }
        Set tAnswer = ..Parsed(tText)
        If $IsObject(tAnswer) Do tView.%Set($Select(tState = ..#STATEENDED: "result", 1: "refusal"), tAnswer)
    }
    Set tRow = ""
    Set pView = tView
    Set pFound = 1
    Quit $$$OK
}

/// <p>Delete every terminal run that ended more than the retention seconds of <var>pLimitsClass</var>
/// before <var>pNowSeconds</var> (<method>OcuPilot.Kernel.State.Turn.NowSeconds</method> units, now
/// when empty), after ending every lost run (<method>Reconcile</method>, against the real clock).</p>
ClassMethod GuardedSweep(pLimitsClass As %String, pNowSeconds As %String = "") As %Status
{
    Set tSC = ..GuardedIdsWhereNoParam("SELECT ID FROM OcuPilot_Kernel_State.SqlRun WHERE State IN ('queued', 'running') ORDER BY ID", .tLive)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:+$Get(tLive) {
        Set tSC = ..Reconcile(tLive(tI), pLimitsClass, .tState, .tOwner, .tRunKey)
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..GuardedIdsWhereNoParam("SELECT ID FROM OcuPilot_Kernel_State.SqlRun WHERE State IN ('ended', 'canceled', 'failed') ORDER BY ID", .tIds)
    If $$$ISERR(tSC) Quit tSC
    Set tNow = $Select(pNowSeconds = "": ##class(OcuPilot.Kernel.State.Turn).NowSeconds(), 1: +pNowSeconds)
    Set tCutoff = tNow - $Parameter(pLimitsClass, "RETENTIONSECONDS")
    For tI = 1:1:+$Get(tIds) {
        Set tOpenSC = ..GuardedOpenId(tIds(tI), .tRow)
        If $$$ISERR(tOpenSC) Continue
        Set tEnded = ##class(OcuPilot.Kernel.State.Turn).SecondsOf(..Text(tRow.EndedAt))
        Set tRow = ""
        If (tEnded = "") || (tEnded >= tCutoff) Continue
        Set tSC = ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.SqlRun WHERE ID = ?", tIds(tI))
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Delete every terminal run of <var>pUser</var>, matched exactly; a live run is left. For tests
/// and fixtures, which leave no run row behind them.</p>
ClassMethod GuardedForgetUser(pUser As %String) As %Status
{
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ? AND State IN ('ended', 'canceled', 'failed')", pUser)
}

/// <p>End row <var>pId</var> <parameter>STATEFAILED</parameter>, with no answer, when it is lost: a
/// <code>running</code> row whose run lock is free, or a <code>queued</code> row older than the
/// queued seconds of <var>pLimitsClass</var> whose run lock is free. A row another writer changed
/// meanwhile is left as that writer left it. <var>pState</var>, <var>pOwner</var> and
/// <var>pRunKey</var> are the row's state, owner and key as this call leaves them; <var>pState</var> is
/// <code>""</code> when the row is gone.</p>
ClassMethod Reconcile(pId As %String, pLimitsClass As %String, Output pState As %String, Output pOwner As %String, Output pRunKey As %String) As %Status [ Private ]
{
    Set (pState, pOwner, pRunKey) = ""
    Set tRow = ""
    Set tSC = ..GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit $$$OK
    Set pState = tRow.State
    Set pOwner = tRow.UserName
    Set pRunKey = tRow.RunKey
    Set tSuspect = (pState = ..#STATERUNNING)
    If pState = ..#STATEQUEUED {
        Set tQueued = ##class(OcuPilot.Kernel.State.Turn).SecondsOf(..Text(tRow.QueuedAt))
        Set tSuspect = (tQueued = "") || ((##class(OcuPilot.Kernel.State.Turn).NowSeconds() - tQueued) > +$Parameter(pLimitsClass, "QUEUEDSECONDS"))
    }
    If 'tSuspect {
        Set tRow = ""
        Quit $$$OK
    }
    Set tSC = ..LockHeld(pRunKey, .tHeld)
    If $$$ISERR(tSC) || tHeld {
        Set tRow = ""
        Quit tSC
    }
    Set tRow.State = ..#STATEFAILED
    Set tRow.EndedAt = ##class(OcuPilot.Kernel.State.Turn).Timestamp()
    Set tSC = ..GuardedSaveIfCurrent(tRow, +tRow.RowVersion)
    Set tRow = ""
    If ..IsStaleSave(tSC) {
        Set tSC = ..GuardedOpenId(pId, .tRow)
        If $$$ISOK(tSC) && $IsObject(tRow) Set pState = tRow.State
        Set tRow = ""
        Quit $$$OK
    }
    If $$$ISOK(tSC) Set pState = ..#STATEFAILED
    Quit tSC
}

/// <p>Whether a process holds run <var>pKey</var>'s lock, asked by taking it without waiting and
/// releasing it at once. <b>Caller contract:</b> the calling process does not hold that lock itself,
/// since a process re-enters a lock it holds.</p>
ClassMethod LockHeld(pKey As %String, Output pHeld As %Boolean) As %Status [ Private ]
{
    Set pHeld = 1
    Set tSC = ..GuardedSqlRunLock(pKey, 0, .tTaken)
    If $$$ISERR(tSC) Quit tSC
    If tTaken {
        Set pHeld = 0
        Set tSC = ..GuardedSqlRunUnlock(pKey)
    }
    Quit tSC
}

/// <p>The id of run <var>pKey</var> when <var>pUser</var> owns it, both matched exactly, or
/// <code>""</code>.</p>
ClassMethod IdForOwner(pKey As %String, pUser As %String, Output pId As %String) As %Status [ Private ]
{
    Set pId = ""
    Set tSC = ..GuardedIdsWhereTwoParam("SELECT ID FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = ? AND %EXACT(UserName) = ?", pKey, pUser, .tIds)
    If $$$ISOK(tSC) Set pId = $Get(tIds(1))
    Quit tSC
}

/// <p>The row for <var>pKey</var>, matched exactly, or <code>$$$NULLOREF</code>.</p>
ClassMethod OpenByKey(pKey As %String, Output pRow) As %Status [ Private ]
{
    Quit ..GuardedOpenOneWhere("SELECT ID FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = ?", pKey, .pRow)
}

/// <p>A fresh opaque run id: 32 lower-case hex characters from the instance's random source.</p>
ClassMethod NewKey() As %String [ Private ]
{
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.GenCryptRand(16)), "L")
}

/// <p><var>pText</var> parsed as a JSON object, or <code>""</code> when it is empty or is not one.</p>
ClassMethod Parsed(pText As %String) As %DynamicObject [ Private ]
{
    Set tObject = ""
    Try {
        If (pText = "") || (pText = $Char(0)) Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pText)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicObject") Set tObject = tParsed
    } Catch ex {
        Set tObject = ""
    }
    Quit tObject
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
