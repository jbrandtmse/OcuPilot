/// <p>Pins Story 24.17 Batch 5's containment (AD-9, AD-39, AD-62): the vendor's call adds <code>%All</code> for itself, and the process's roles, user and namespace read the same after it on every
/// exit -- a seam that adds a role and succeeds, one that raises, an error status, and a raise after switching to <code>%SYS</code>, where the namespace is restored before anything is logged
/// and no line carries a vendor text. The real call leaves the roles, user and namespace as found, starts no process, writes no audit row, and writes no journal record but the vendor's own
/// <code>^SYS.EnsMetrics</code> bookkeeping (orchestrator ruling U-177); and the read answers 200 in a background job with the production running, which has no web request, as the agent's turn
/// has none, leaving no session behind.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropSystemMonitorCase</class> needs, auditing on, and journaling on.</p>
Class OcuPilot.Test.InteropSystemMonitorFrame Extends OcuPilot.Test.InteropSystemMonitorCase
{

Parameter CHILD = "OcuPilot.Test.InteropSystemMonitorChild";

/// <p>The journal's end now, as <code>file|address</code>.</p>
ClassMethod Mark() As %String
{
    Set tNs = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tName = ##class(%SYS.Journal.System).GetCurrentFileName()
    Set tFile = ##class(%SYS.Journal.File).%OpenId(tName)
    Set tAddress = tFile.LastRecord.Address
    Set $NAMESPACE = tNs
    Quit tName _ "|" _ tAddress
}

/// <p>The journal records process <var>pPid</var> wrote since <var>pMark</var>, as the global each one names, comma-separated and bracketed, and <code>-1</code> when the file rolled over.</p>
ClassMethod JournalBy(pMark As %String, pPid As %Integer) As %String
{
    Set tNs = $NAMESPACE
    Set tText = ","
    Try {
        Set $NAMESPACE = "%SYS"
        Set tName = ##class(%SYS.Journal.System).GetCurrentFileName()
        If tName '= $Piece(pMark, "|", 1) {
            Set tText = -1
            Quit
        }
        ; The file object stays open while its records are read: a record asks the open file for its process.
        Set tFile = ##class(%SYS.Journal.File).%OpenId(tName)
        Set tRec = tFile.LastRecord
        Set tStop = $Piece(pMark, "|", 2)
        While $IsObject(tRec) && (tRec.Address > tStop) {
            If tRec.ProcessID = pPid {
                Set tGlobal = $Select(tRec.%IsA("%SYS.Journal.SetKillRecord"): $Piece(tRec.GlobalNode, "(", 1), 1: "(" _ tRec.TypeName _ ")")
                Set tText = tText _ tGlobal _ ","
            }
            Set tRec = tRec.Prev
        }
    } Catch ex {
        Set tText = ",(journal read failed: " _ ex.DisplayString() _ "),"
    }
    Set $NAMESPACE = tNs
    Quit tText
}

/// <p>How many audit rows process <var>pPid</var> wrote, read again for up to five seconds until <var>pExpect</var> are found.</p>
ClassMethod AuditBy(pPid As %Integer, pExpect As %Integer = 0) As %Integer
{
    Set tNs = $NAMESPACE
    Set tRows = 0
    ; The audit table's process index does not answer an equality on the id here, so the read is bounded by the last hour's time and the id is tested without the index.
    Set tNow = $ZTimeStamp
    Set tDays = $Piece(tNow, ",", 1)
    Set tSeconds = $Piece(tNow, ",", 2) - 3600
    If tSeconds < 0 {
        Set tSeconds = tSeconds + 86400
        Set tDays = tDays - 1
    }
    Set tSince = $ZDateTime(tDays _ "," _ tSeconds, 3, 1, 3)
    For tTry = 1:1:20 {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX PID = ?", tSince, pPid)
        Set tRows = $Select(tResult.%Next(): +tResult.%GetData(1), 1: -1)
        Set $NAMESPACE = tNs
        If tRows '< pExpect Quit
        Hang 0.25
    }
    Quit tRows
}

/// <p>The process ids of every process now, comma-separated and bracketed.</p>
ClassMethod Pids() As %String
{
    Set tText = ","
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT Pid FROM %SYS.ProcessQuery")
    While tResult.%Next() {
        Set tText = tText _ tResult.%GetData(1) _ ","
    }
    Quit tText
}

/// <p>One System monitor call through the class <var>pClass</var>, with the roles, user and namespace before and after: the verdict and <code>sameRoles|sameUser|sameNamespace</code>.</p>
ClassMethod Framed(pClass As %String, Output pSame As %String) As %String
{
    Set tRoles = $ROLES
    Set tUser = $USERNAME
    Set tNamespace = $NAMESPACE
    Kill tQuery
    Set tVerdict = ..Verdict("SystemMonitor", .tRows, .tFault, .tQuery, tNamespace, pClass)
    Set pSame = (tRoles = $ROLES) _ "|" _ (tUser = $USERNAME) _ "|" _ (tNamespace = $NAMESPACE)
    Quit tVerdict
}

/// <p>AC4: the process's roles, user and namespace read as before after a seam that adds a role and succeeds, after one that adds a role and raises, and after one that switches to
/// <code>%SYS</code> and raises; the vendor's call sees the process's own roles, and the answer is 200 for the first and 500 <code>INTERNAL</code> for the others, never 200.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ReadMetrics</method> call <method>VendorMetrics</method> outside <method>PurgeFrame</method> -- the role legs go red.</p>
Method TestTheRolesUserAndNamespaceAreTheSameAfterEveryExit()
{
    Set tRoles = $ROLES
    For tMode = "roles", "rolesfault", "fault", "status" {
        Set ^IRIS.Temp.OcuProbe2417SmMode = tMode
        Set tVerdict = ..Framed(..#SEAM, .tSame)
        Do $$$AssertEquals(tSame, "1|1|1", tMode _ ": the roles, user and namespace are as before")
        Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417SmMode("before")), tRoles, tMode _ ": the vendor's call saw the process's own roles")
        Do $$$AssertEquals(tVerdict, $Select(tMode = "roles": "200 ", 1: "500 INTERNAL"), tMode _ ": answered " _ tVerdict _ ", and a failure is never a 200")
    }
    ; The same two role changes as a real administrator, whose roles the process may change: inside the call the process held other roles, and after it the roles are as before.
    For tMode = "roles", "rolesfault" {
        Set ^IRIS.Temp.OcuProbe2417SmMode = tMode
        Set tOut = $ClassMethod(..#CHILD, "ProbeAs", "_SYSTEM", "roles", ..#SEAM)
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tMode _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertEquals(tOut.http, $Select(tMode = "roles": 200, 1: 500), tMode _ ": answered as declared")
        Do $$$AssertEquals(tOut.after, tOut.before, tMode _ ": the administrator's roles are as before")
        Do $$$AssertTrue($Get(^IRIS.Temp.OcuProbe2417SmMode("inside")) '= tOut.before, tMode _ ": and inside the call the process held other roles: " _ $Get(^IRIS.Temp.OcuProbe2417SmMode("inside")))
    }
}

/// <p>AC5: a vendor error status and a raise while switched to <code>%SYS</code> are 500 <code>INTERNAL</code>; the namespace is restored before anything is logged, so every line is written in the
/// namespace the call was made in; and no line carries the vendor's text, only its codes.</p>
/// <p>Mutation (Rule 19): move the namespace restore in <method>OcuPilot.Port.InteropPort.ReadMetrics</method> after the log -- the raise leg logs in <code>%SYS</code> and this goes red.</p>
Method TestAFaultIsLoggedAfterTheRestoreWithNoVendorText()
{
    Set tHome = $NAMESPACE
    For tMode = "status", "fault" {
        Set ^IRIS.Temp.OcuProbe2417SmMode = tMode
        Do $ClassMethod(..#SEAM, "ClearLog")
        Kill tQuery
        Do $$$AssertEquals(..Verdict("SystemMonitor", .tRows, .tFault, .tQuery, tHome, ..#SEAM), "500 INTERNAL", tMode _ ": 500 INTERNAL")
        Do $$$AssertEquals($NAMESPACE, tHome, tMode _ ": the namespace is as it was")
        Do $$$AssertTrue(($ClassMethod(..#SEAM, "LoggedText") '= "") && ($ClassMethod(..#SEAM, "LoggedIn") = tHome), tMode _ ": one line was logged, in the namespace of the call: " _ $ClassMethod(..#SEAM, "LoggedIn"))
        Do $$$AssertTrue($ClassMethod(..#SEAM, "LoggedText") '[ $Parameter(..#SEAM, "MARKER"), tMode _ ": no line carries the vendor's text")
        If tMode = "fault" Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417SmMode("hereIn")), "%SYS", "fault: the seam raised while switched to %SYS")
        Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.%ToJSON() '[ $Parameter(..#SEAM, "MARKER")), tMode _ ": nor does the answer")
    }
}

/// <p>AC4: the real call, made in this process, leaves the roles, user and namespace as found; starts no process; writes no audit row (with a positive control, which the same query must see); and
/// writes no journal record but the vendor's own <code>^SYS.EnsMetrics</code> maintenance records. Idle and with the probe production running.</p>
Method TestTheRealCallWritesOnlyTheVendorsOwnBookkeeping()
{
    For tLeg = "idle", "running" {
        If tLeg = "running" Do $$$AssertStatusOK(..StartProbe(), "the probe production runs in USER")
        If tLeg = "idle" Do ..AgeSnapshot()
        Set tPids = ..Pids()
        ; The audit count is taken first and the journal marked after it: a query this process prepares for the first time writes the instance's statement index, which is not the call's.
        Set tAuditBefore = ..AuditBy($Job)
        Set tMark = ..Mark()
        Set tVerdict = ..Framed(..#PORT, .tSame)
        Set tJournal = ..JournalBy(tMark, $Job)
        Do $$$AssertEquals(tVerdict, "200 ", tLeg _ ": the real call answers 200")
        Do $$$AssertEquals(tSame, "1|1|1", tLeg _ ": the roles, user and namespace are as before")
        Set tAfterPids = ..Pids()
        Set tNew = ""
        For tI = 2:1:$Length(tAfterPids, ",") - 1 {
            If tPids '[ ("," _ $Piece(tAfterPids, ",", tI) _ ",") Set tNew = tNew _ $Piece(tAfterPids, ",", tI) _ ","
        }
        Do $$$AssertEquals(tNew, "", tLeg _ ": the call started no process")
        Do $$$AssertEquals(..AuditBy($Job), tAuditBefore, tLeg _ ": the call wrote no audit row")
        Do $$$AssertTrue(tJournal '= -1, tLeg _ ": the journal did not roll over during the call")
        Set tOther = ""
        For tI = 2:1:$Length(tJournal, ",") - 1 {
            Set tGlobal = $Piece(tJournal, ",", tI)
            If tGlobal '= "^SYS.EnsMetrics" Set tOther = tOther _ tGlobal _ ","
        }
        Do $$$AssertEquals(tOther, "", tLeg _ ": no journal record names a global but the vendor's ^SYS.EnsMetrics bookkeeping: " _ tOther)
        If tLeg = "running" Do $$$AssertTrue(tJournal [ ",^SYS.EnsMetrics,", "running: the journal read sees the vendor's own records, so it would see any other: " _ tJournal)
    }
    ; The positive control: the same audit query sees a security change this process makes.
    Set tNs = $NAMESPACE
    Set tBeforeControl = ..AuditBy($Job)
    Try {
        Set $NAMESPACE = "%SYS"
        Do ##class(Security.Resources).Create("OcuP2417SmControl", "positive control", "")
        Do ##class(Security.Resources).Delete("OcuP2417SmControl")
        Set $NAMESPACE = tNs
    } Catch {
        Set $NAMESPACE = tNs
    }
    Do $$$AssertTrue(..AuditBy($Job, tBeforeControl + 1) > tBeforeControl, "the audit query sees a row a process does write")
}

/// <p>Condition 3 of the orchestrator's ruling: a background job, which has no web request (the agent's turn is one, AD-7), reads the System monitor and Most active queues with the probe production
/// running -- 200, one production, the probe queue listed -- and leaves its roles and namespace as found, no web request defined and no session behind.</p>
Method TestABackgroundJobReadsWithAProductionRunning()
{
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs in USER")
    Set tOut = $ClassMethod(..#CHILD, "ProbeAs", "", "job")
    Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), "the job ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
    If '$IsObject(tOut) || (tOut.%Get("error") '= "") Quit
    Do $$$AssertEquals(tOut.hasRequest, 0, "the job holds no web request")
    Do $$$AssertEquals(tOut.row.http _ "|" _ tOut.row.running, "200|1", "the System monitor answers 200 and counts the production")
    Do $$$AssertEquals(tOut.queues.http, 200, "Most active queues answers 200")
    Do $$$AssertTrue(tOut.queues.queues [ ("," _ $Parameter(..#PROBE, "OPNAME") _ ","), "and lists the probe operation's queue: " _ tOut.queues.queues)
    Do $$$AssertEquals(tOut.sameRoles _ "|" _ tOut.sameNamespace _ "|" _ tOut.sessionLeft _ "|" _ tOut.requestAfter, "1|1|0|0", "the roles and namespace are as before, no session is stored, and no request context is left")
}

/// <p>The vendor's call leaves an exclusive and a shared lock on <code>^SYS.EnsMetrics</code> behind, and while a process holds them every other process reads the instance as idle. A process that has
/// made the read and stays alive (as a turn's job does for the whole turn) therefore leaves another process reading the running production.</p>
/// <p>Mutation (Rule 19): drop the two <code>Lock -</code> lines of <method>OcuPilot.Port.InteropPort.VendorMetrics</method> -- the second process reads no production and this goes red.</p>
Method TestAnotherProcessStillReadsTheProductionWhileTheFirstReaderLives()
{
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs in USER")
    Set tOut = $ClassMethod(..#CHILD, "ProbeAs", "", "hold")
    Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), "the first reader ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
    If '$IsObject(tOut) || (tOut.%Get("error") '= "") Quit
    Do $$$AssertEquals(tOut.row.http _ "|" _ tOut.row.running, "200|1", "the first reader counted the production")
    Do $$$AssertTrue($Data(^$JOB(tOut.child)) > 0, "and it is still alive")
    Do ..AgeSnapshot()
    Kill tQuery
    Do $$$AssertEquals(..Verdict("SystemMonitor", .tRows, .tFault, .tQuery), "200 ", "a second process reads while the first lives")
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Get(0).EnsProductionsRunning, 1: "no row"), "1", "and it counts the production, so the first reader gave the vendor's locks back")
    Do $System.Event.Signal(tOut.child, "release")
}

}
