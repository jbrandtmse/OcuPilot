/// <p>Test helper for Story 24.14's cancel suites: reads what a PMML test run leaves (its processes, its lock, its event resource, its record and its result rows) and holds a web process busy so
/// that a later request is served by another one. It extends no test class and changes nothing a run owns. <method>Hold</method> is a job's entry point.</p>
Class OcuPilot.Test.PmmlRunWatch Extends %RegisteredObject
{

Parameter PMML = "OcuPilot.Test.PmmlProbe";

/// <p>The seconds <method>Hold</method> tries to reach a web process for.</p>
Parameter HOLDTRYSECONDS = 0.5;

/// <p>What <method>Residue</method> reads when a run has left nothing.</p>
Parameter CLEAN = "child:0 sup:0 rows:0 records:0 lock:0 event:0";

/// <p>The process id the store records for run <var>pKey</var>, which is the run's supervisor, <code>""</code> for none.</p>
ClassMethod JobOf(pKey As %String) As %String
{
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT JobId FROM OcuPilot_Kernel_State.SqlRun WHERE RunKey = ?", pKey)
    Quit $Select(tResult.%Next(): tResult.%GetData(1), 1: "")
}

/// <p>The process id the run's record names, which is the run's child once the child has recorded its test id, <code>""</code> for none.</p>
ClassMethod ChildOf(pKey As %String) As %String
{
    Set tRecord = $Get(^IRIS.Temp.OcuPilotPmmlRun(pKey))
    Quit $Select($ListValid(tRecord): $ListGet(tRecord, 1), 1: "")
}

/// <p>The test id the run's record names, <code>""</code> for none.</p>
ClassMethod TestIdOf(pKey As %String) As %String
{
    Set tRecord = $Get(^IRIS.Temp.OcuPilotPmmlRun(pKey))
    Quit $Select($ListValid(tRecord): $ListGet(tRecord, 2), 1: "")
}

/// <p>Whether process <var>pPid</var> is in the process table.</p>
ClassMethod Alive(pPid As %String) As %Boolean
{
    Quit (pPid '= "") && ($Data(^$JOB(pPid)) > 0)
}

/// <p>Wait up to <var>pSeconds</var> for process <var>pPid</var> to leave the process table; 1 when it has.</p>
ClassMethod WaitGone(pPid As %String, pSeconds As %Numeric) As %Boolean
{
    Set tDeadline = $ZHorolog + pSeconds
    While ..Alive(pPid) && ($ZHorolog < tDeadline) {
        Hang 0.05
    }
    Quit '..Alive(pPid)
}

/// <p>Whether any process holds a lock whose name holds run key <var>pKey</var>, the run's lock among them.</p>
ClassMethod LockHeld(pKey As %String) As %Boolean
{
    Set tName = ""
    For {
        Set tName = $Order(^$LOCK(tName))
        If (tName = "") || (tName [ pKey) Quit
    }
    Quit tName '= ""
}

/// <p>Whether run <var>pKey</var>'s event resource exists.</p>
ClassMethod EventDefined(pKey As %String) As %Boolean
{
    Quit ''$System.Event.Defined(##class(OcuPilot.Area.Analytics.PmmlTest).EventName(pKey))
}

/// <p>What run <var>pKey</var> leaves once its supervisor <var>pSup</var> and its child <var>pChild</var> have had up to five seconds each to leave the process table, as
/// <code>child:&lt;alive&gt; sup:&lt;alive&gt; rows:&lt;rows of test id pTestId&gt; records:&lt;run records&gt; lock:&lt;held&gt; event:&lt;defined&gt;</code>; <parameter>CLEAN</parameter> is nothing.</p>
ClassMethod Residue(pKey As %String, pTestId As %Integer, pChild As %String, pSup As %String) As %String
{
    Do ..WaitGone(pSup, 5)
    Do ..WaitGone(pChild, 5)
    Quit "child:" _ ..Alive(pChild) _ " sup:" _ ..Alive(pSup) _ " rows:" _ $Select(pTestId = "": 0, 1: $ClassMethod(..#PMML, "RowsOf", pTestId)) _ " records:" _ $ClassMethod(..#PMML, "Records") _ " lock:" _ ..LockHeld(pKey) _ " event:" _ ..EventDefined(pKey)
}

/// <p>Wait up to 30 seconds for the run that holds test id <var>pId</var> to have written a result row: 1 when it has, so that a canceled run has a row to drop.</p>
ClassMethod AwaitRows(pId As %Integer) As %Boolean
{
    Set tDeadline = $ZHorolog + 30
    While ($ClassMethod(..#PMML, "RowsOf", pId) = 0) && ($ZHorolog < tDeadline) {
        Hang 0.1
    }
    Quit ($ClassMethod(..#PMML, "RowsOf", pId) > 0)
}

/// <p>A job's entry point: send <var>pPath</var><code>?pid=&lt;pPid&gt;&amp;s=&lt;pSeconds&gt;</code> as <var>pUser</var> until <class>OcuPilot.Test.PmmlHoldRouter</class>'s hold route answers that the web
/// process <var>pPid</var> served it, for up to <parameter>HOLDTRYSECONDS</parameter> or until <method>ReleaseProcess</method> is called, and record the answer in
/// <code>^IRIS.Temp.OcuPilotPmmlHoldDone(pPid)</code> once the hold has ended. While the hold lasts, <code>^IRIS.Temp.OcuPilotPmmlHold(pPid)</code> is set, and a request sent meanwhile is served by another
/// web process. The web server does not send a request to a process chosen by the caller: a request reaches <var>pPid</var> only when that process is the one the server picks, so the answer may be that it
/// was not held, and then the requests meanwhile were served by the process the server did pick.</p>
ClassMethod Hold(pPid As %String, pSeconds As %Numeric, pPath As %String, pUser As %String, pPassword As %String)
{
    Set tHeld = 0
    Set tDeadline = $ZHorolog + ..#HOLDTRYSECONDS
    While 'tHeld && ($ZHorolog < tDeadline) && '$Data(^IRIS.Temp.OcuPilotPmmlHoldRelease(pPid)) {
        Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", pPath _ "?pid=" _ pPid _ "&s=" _ pSeconds _ "&ns=USER", pUser, pPassword, .tStatus, .tBody)
        Try {
            Set tHeld = ''##class(%DynamicObject).%FromJSON(tBody).held
        } Catch {
            Set tHeld = 0
        }
        If 'tHeld Hang 0.02
    }
    Set ^IRIS.Temp.OcuPilotPmmlHoldDone(pPid) = tHeld
}

/// <p>Start <method>Hold</method> in a job and wait up to <parameter>HOLDTRYSECONDS</parameter> and a half second for web process <var>pPid</var> to be held: 1 when it is. A caller that gets 0 calls
/// <method>ReleaseProcess</method>, which stops the job.</p>
ClassMethod HoldProcess(pPid As %String, pSeconds As %Numeric, pPath As %String, pUser As %String, pPassword As %String) As %Boolean
{
    Kill ^IRIS.Temp.OcuPilotPmmlHold(pPid), ^IRIS.Temp.OcuPilotPmmlHoldDone(pPid), ^IRIS.Temp.OcuPilotPmmlHoldRelease(pPid)
    Job ##class(OcuPilot.Test.PmmlRunWatch).Hold(pPid, pSeconds, pPath, pUser, pPassword)::5
    If '$Test Quit 0
    Set tDeadline = $ZHorolog + ..#HOLDTRYSECONDS + 0.5
    While ('$Data(^IRIS.Temp.OcuPilotPmmlHold(pPid))) && ($ZHorolog < tDeadline) && ('$Data(^IRIS.Temp.OcuPilotPmmlHoldDone(pPid))) {
        Hang 0.01
    }
    Quit ''$Data(^IRIS.Temp.OcuPilotPmmlHold(pPid))
}

/// <p>End the hold of web process <var>pPid</var>, wait up to <var>pSeconds</var> for it to end, then remove its nodes.</p>
ClassMethod ReleaseProcess(pPid As %String, pSeconds As %Numeric)
{
    Set ^IRIS.Temp.OcuPilotPmmlHoldRelease(pPid) = 1
    Set tDeadline = $ZHorolog + pSeconds
    While ('$Data(^IRIS.Temp.OcuPilotPmmlHoldDone(pPid))) && ($ZHorolog < tDeadline) {
        Hang 0.05
    }
    Kill ^IRIS.Temp.OcuPilotPmmlHold(pPid), ^IRIS.Temp.OcuPilotPmmlHoldDone(pPid), ^IRIS.Temp.OcuPilotPmmlHoldRelease(pPid)
}

}
