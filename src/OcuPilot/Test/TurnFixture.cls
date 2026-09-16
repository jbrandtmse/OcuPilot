/// <p>Shared instance-state helper for the turn suite: find, age and remove the turns a test created,
/// read a turn's stored fields, and report who holds a user's turn slot.</p>
/// <p><b>Every user name a turn test uses starts with <parameter>PROBEPREFIX</parameter></b>, so
/// teardown finds every turn, step and signal a class left without remembering keys. The suite runs
/// as an account holding <code>%All</code>, so the reads and the ageing writes here go straight to
/// SQL and the globals rather than through the stores they are checking.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.TurnFixture Extends %RegisteredObject
{

/// <p>The prefix every probe turn's user name starts with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeTurn";

/// <p>The keys of every turn whose user name starts with <var>pPrefix</var>, as
/// <code>pKeys(n)</code> with the count in <code>pKeys</code>.</p>
ClassMethod Keys(Output pKeys, pPrefix As %String = {..#PROBEPREFIX}) As %Status
{
    Kill pKeys
    Set pKeys = 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TurnKey FROM OcuPilot_Kernel_State.Turn WHERE UserName %STARTSWITH ? ORDER BY ID", pPrefix)
    If tRS.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "turn keys could not be read: SQLCODE=" _ tRS.%SQLCODE)
    While tRS.%Next() {
        Set pKeys($Increment(pKeys)) = tRS.%GetData(1)
    }
    Quit $$$OK
}

/// <p>Remove every probe turn with its steps and signals, and report in <var>pRemaining</var> how
/// many probe turns survive; <code>-1</code> when that could not be read. A removed turn that left
/// a step or a signal behind is an error status.</p>
ClassMethod RemoveTurns(Output pRemaining As %Integer, pPrefix As %String = {..#PROBEPREFIX}) As %Status
{
    Set pRemaining = -1
    Set tSC = ..Keys(.tKeys, pPrefix)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:tKeys {
        Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tKeys(tI))
        If $$$ISERR(tSC) Quit
        If ..StepCount(tKeys(tI)) || $Data(^OcuPilotTurnSignal(tKeys(tI))) Set tSC = $$$ERROR($$$GeneralError, "turn " _ tKeys(tI) _ " left steps or signals")
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Keys(.tLeft, pPrefix)
    If $$$ISERR(tSC) Quit tSC
    Set pRemaining = tLeft
    Quit $$$OK
}

/// <p>A stored field of turn <var>pKey</var>, read by SQL; <code>""</code> for a turn no row
/// holds.</p>
ClassMethod Field(pKey As %String, pField As %String) As %String
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT * FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = ?", pKey)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit ""
    Set tValue = tRS.%Get(pField)
    Quit $Select(tValue = $Char(0): "", 1: tValue)
}

/// <p>Move a timestamp field of turn <var>pKey</var> -- <code>QueuedAt</code>,
/// <code>StartedAt</code> or <code>EndedAt</code> -- <var>pSeconds</var> into the past.</p>
ClassMethod Age(pKey As %String, pField As %String, pSeconds As %Integer) As %Status
{
    Set tSql = $Case(pField, "QueuedAt": "UPDATE OcuPilot_Kernel_State.Turn SET QueuedAt = ? WHERE %EXACT(TurnKey) = ?", "StartedAt": "UPDATE OcuPilot_Kernel_State.Turn SET StartedAt = ? WHERE %EXACT(TurnKey) = ?", "EndedAt": "UPDATE OcuPilot_Kernel_State.Turn SET EndedAt = ? WHERE %EXACT(TurnKey) = ?", : "")
    If tSql = "" Quit $$$ERROR($$$GeneralError, "not a timestamp field: " _ pField)
    Set tSeconds = ##class(OcuPilot.Kernel.State.Turn).NowSeconds() - pSeconds
    Set tAged = ##class(OcuPilot.Kernel.State.Turn).Timestamp((tSeconds \ 86400) _ "," _ (tSeconds # 86400))
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSql, tAged, pKey)
    If tRS.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "could not age " _ pField _ ": SQLCODE=" _ tRS.%SQLCODE)
    Quit $$$OK
}

/// <p>Force turn <var>pKey</var>'s state, as a job that died mid-turn would have left it.</p>
ClassMethod ForceState(pKey As %String, pState As %String) As %Status
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Turn SET State = ? WHERE %EXACT(TurnKey) = ?", pState, pKey)
    If tRS.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "could not force the state: SQLCODE=" _ tRS.%SQLCODE)
    Quit $$$OK
}

/// <p>How many step rows turn <var>pKey</var> holds.</p>
ClassMethod StepCount(pKey As %String) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ?", pKey)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>How many turn rows name <var>pUser</var> exactly.</p>
ClassMethod TurnCount(pUser As %String) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(UserName) = ?", pUser)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>The process id holding <var>pUser</var>'s turn slot, or <code>""</code> when no process
/// does.</p>
ClassMethod SlotOwner(pUser As %String) As %String
{
    Set tName = $Name(^OcuPilotTurnSlot(pUser))
    If '$Data(^$LOCK(tName)) Quit ""
    Quit $Get(^$LOCK(tName, "OWNER"))
}

/// <p>Whether any probe user's turn slot is held by any process.</p>
ClassMethod AnyProbeSlotHeld() As %Boolean
{
    Set tName = ""
    Set tHeld = 0
    For {
        Set tName = $Order(^$LOCK(tName))
        If tName = "" Quit
        If tName [ ("OcuPilotTurnSlot(""" _ ..#PROBEPREFIX) Set tHeld = 1
    }
    Quit tHeld
}

/// <p>Wait up to <var>pSeconds</var> for turn <var>pKey</var> to reach a terminal state, and answer
/// the state it was last read in.</p>
ClassMethod AwaitTerminal(pKey As %String, pSeconds As %Integer) As %String
{
    Set tDeadline = $ZHorolog + pSeconds
    For {
        Set tState = ..Field(pKey, "State")
        If ##class(OcuPilot.Kernel.State.Turn).IsTerminal(tState) Quit
        If $ZHorolog > tDeadline Quit
        Hang 0.5
    }
    Quit tState
}

/// <p>Terminate the job of every probe turn that has not ended and whose process is still alive;
/// a terminated job releases its slot as it exits. <var>pKilled</var> counts the processes
/// terminated.</p>
ClassMethod StopProbeJobs(Output pKilled As %Integer) As %Status
{
    Set pKilled = 0
    Set tSC = ..Keys(.tKeys)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:tKeys {
        If ##class(OcuPilot.Kernel.State.Turn).IsTerminal(..Field(tKeys(tI), "State")) Continue
        Set tPid = ..Field(tKeys(tI), "JobId")
        If (tPid '= "") && $Data(^$JOB(tPid)) {
            Do $SYSTEM.Process.Terminate(tPid)
            Set pKilled = pKilled + 1
        }
    }
    Quit $$$OK
}

}
