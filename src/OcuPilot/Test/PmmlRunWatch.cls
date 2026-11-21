/// <p>Test helper for Story 24.14's cancel suites: reads what a PMML test run leaves (its processes, its lock, its event resource, its record and its result rows) and sends a run's cancel from a process
/// of its own. It extends no test class and changes nothing a run owns. <method>CancelAs</method> is a job's entry point.</p>
Class OcuPilot.Test.PmmlRunWatch Extends %RegisteredObject
{

Parameter PMML = "OcuPilot.Test.PmmlProbe";

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

/// <p>A job's entry point: the cancel of run <var>pKey</var> as its owner <var>pUser</var> through <var>pClass</var>'s <code>Cancel</code>, the entry the cancel route calls, then the run as <var>pClass</var>'s
/// <code>View</code> reads it, recorded in <code>^IRIS.Temp.OcuPilotPmmlCancelAs(pKey)</code> as <code>$ListBuild(process id, accepted, status, cancelRequested, seconds)</code>. The job's process id
/// differs from every live process's by construction. The job runs as the process that started it, and the run's owner is named to the store.</p>
ClassMethod CancelAs(pKey As %String, pUser As %String, pClass As %String)
{
    Set tAccepted = 0
    Set tStatus = ""
    Set tRequested = ""
    Set tStart = $ZHorolog
    Try {
        Set tSC = $ClassMethod(pClass, "Cancel", pKey, pUser, .tFound)
        Set tAccepted = $$$ISOK(tSC) && tFound
        Set tSeconds = $ZHorolog - tStart
        Set tView = ""
        Do $ClassMethod(pClass, "View", pKey, pUser, .tViewFound, .tView)
        If $IsObject(tView) {
            Set tStatus = tView.%Get("status")
            Set tRequested = tView.%Get("cancelRequested")
        }
    } Catch ex {
        Set tStatus = "threw " _ ex.Name
    }
    Set ^IRIS.Temp.OcuPilotPmmlCancelAs(pKey) = $ListBuild($Job, tAccepted, tStatus, tRequested, $ZHorolog - tStart)
}

/// <p>Run <method>CancelAs</method> in a job and wait up to 15 seconds for its record: the record, <code>$ListBuild(process id, accepted, status, cancelRequested, seconds)</code>, which it removes; <code>""</code>
/// when the job was not accepted or did not answer.</p>
ClassMethod CancelFromJob(pKey As %String, pUser As %String, pClass As %String) As %List
{
    Kill ^IRIS.Temp.OcuPilotPmmlCancelAs(pKey)
    Job ##class(OcuPilot.Test.PmmlRunWatch).CancelAs(pKey, pUser, pClass)::5
    If '$Test Quit ""
    Set tDeadline = $ZHorolog + 15
    While '$Data(^IRIS.Temp.OcuPilotPmmlCancelAs(pKey)) && ($ZHorolog < tDeadline) {
        Hang 0.01
    }
    Set tRecord = $Get(^IRIS.Temp.OcuPilotPmmlCancelAs(pKey))
    Kill ^IRIS.Temp.OcuPilotPmmlCancelAs(pKey)
    Quit tRecord
}

}
