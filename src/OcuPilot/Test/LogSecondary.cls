/// <p>Pins <method>OcuPilot.Port.LogSourcePort.Recent</method> and its per-source readers
/// (Story 16.8) in process: the gate before any read, the
/// readable set and each source's predicate, each source's mapping, the merge, cap and
/// <code>truncated</code>, <method>Page</method>'s refusal of the six keys, <method>Rows</method>'
/// projection, and a fault failing the whole read.</p>
/// <p>Driven through <class>OcuPilot.Test.LogSourceFixture</class> (the gate is
/// <class>OcuPilot.Test.ScreenGate</class>, the readable set <class>OcuPilot.Test.NamespaceFixture</class>
/// over HSCUSTOM and USER) and <class>OcuPilot.Test.LogRecordsFixture</class>, whose rows the tests
/// arm, so no vendor store is read or written. The two file sources read scratch files under
/// <code>&lt;ManagerDirectory&gt;ocupilotsecondaryprobe/</code>, removed afterwards; needs a writable
/// manager directory.</p>
Class OcuPilot.Test.LogSecondary Extends %UnitTest.TestCase
{

/// <p>The port under test, through its fixture.</p>
Parameter PORT = "OcuPilot.Test.LogSourceFixture";

/// <p>The records fixture the port is pointed at.</p>
Parameter RECORDS = "OcuPilot.Test.LogRecordsFixture";

/// <p>The scratch root, removed whole in <method>OnAfterAllTests</method>.</p>
Parameter PROBEROOT = "ocupilotsecondaryprobe";

/// <p>The six keys and the pair each source's gate names first, <code>key=resource:permission</code>.</p>
Parameter KEYPAIRS = "systemmonitor=%Admin_Operate:USE,taskerrors=%Admin_Operate:USE,xdbc=%Admin_Operate:USE,sqldiagnostics=%Admin_Operate:USE,eventlog=%Ens_EventLog:USE,analytics=%DeepSee_Portal:USE";

/// <p>The scratch directory the fixture's manager directory answers.</p>
ClassMethod Root() As %String
{
    Quit ##class(%File).NormalizeDirectory(..#PROBEROOT, $System.Util.ManagerDirectory())
}

Method OnBeforeAllTests() As %Status
{
    Do ##class(%File).RemoveDirectoryTree(..Root())
    If '##class(%File).CreateDirectoryChain(..Root(), .tMade) Quit $$$ERROR($$$GeneralError, "the scratch directory could not be created")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Do ##class(%File).RemoveDirectoryTree(..Root())
    If ##class(%File).DirectoryExists(..Root()) Quit $$$ERROR($$$GeneralError, "the scratch directory survived its removal")
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ..Reset()
    Do ##class(OcuPilot.Test.LogSourceFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.LogSourceFixture).SetRecordsClass(..#RECORDS)
    Do ##class(OcuPilot.Test.LogSourceFixture).SetNamespaceResolver("OcuPilot.Test.NamespaceFixture")
    Do ##class(OcuPilot.Test.LogSourceFixture).QueueManagerDirectory(..Root())
    Do ##class(OcuPilot.Test.NamespaceFixture).Arm("HSCUSTOM,USER")
    Do ##class(%File).Delete(..Root() _ "SystemMonitor.log")
    Do ##class(%File).Delete(..Root() _ "DeepSeeTasks_HSCUSTOM.log")
    Do ##class(%File).Delete(..Root() _ "DeepSeeTasks_USER.log")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Reset()
    Quit $$$OK
}

/// <p>Forget every fixture's arming.</p>
Method Reset()
{
    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.LogRecordsFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.NamespaceFixture).Reset()
}

/// <p>Hold every pair the six sources need, and READ on both namespaces' globals databases.</p>
Method HoldAll()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_EventLog", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_HSCUSTOM", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
}

/// <p>One call to <method>Recent</method> through the fixture.</p>
Method Recent(pSource As %String, pMax As %Integer, Output pResult, Output pHttp, Output pFault) As %Status
{
    Quit $ClassMethod(..#PORT, "Recent", pSource, pMax, .pResult, .pHttp, .pFault)
}

/// <p>The texts of <var>pResult</var>'s entries, <code>|</code>-separated, or <code>""</code>.</p>
ClassMethod Texts(pResult) As %String
{
    If '$IsObject(pResult) Quit ""
    Set tTexts = ""
    Set tIterator = pResult.entries.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tTexts = tTexts _ $Select(tTexts = "": "", 1: "|") _ tEntry.text
    }
    Quit tTexts
}

/// <p>One analytics log line as <code>%DeepSee.Utils.%WriteToLog</code> writes it: the stamp,
/// the job and the source each right-justified in ten, then the message.</p>
ClassMethod AnalyticsLine(pStamp As %String, pJob As %String, pSource As %String, pMessage As %String) As %String
{
    Quit pStamp _ " " _ $Justify(pJob, 10) _ " " _ $Justify($Extract(pSource, 1, 10), 10) _ " " _ pMessage _ $Char(10)
}

/// <p>A UTC <code>YYYY-MM-DD HH:MM:SS</code> moved by the instance's own local offset, measured
/// from <code>$Horolog</code> against <code>$ZTimeStamp</code>, as <code>YYYY-MM-DDTHH:MM:SS</code>.</p>
ClassMethod ExpectedLocal(pUtc As %String) As %String
{
    Set tLocalNow = $Horolog
    Set tUtcNow = $ZTimeStamp
    Set tOffset = (($Piece(tLocalNow, ",", 1) - $Piece(tUtcNow, ",", 1)) * 86400) + ($Piece(tLocalNow, ",", 2) - ($Piece(tUtcNow, ",", 2) \ 1))
    Set tOffset = ((tOffset + 30) \ 60) * 60
    Set tH = $ZDateTimeH(pUtc, 3)
    Set tSeconds = ($Piece(tH, ",", 1) * 86400) + $Piece(tH, ",", 2) + tOffset
    Quit $Translate($ZDateTime((tSeconds \ 86400) _ "," _ (tSeconds # 86400), 3, 1), " ", "T")
}

/// <p>AD-29 -- with no pair held, each of the six sources is refused 403 naming its own pair, and
/// no reader, predicate or file is reached.</p>
/// <p>Mutation (Rule 19): move <method>OcuPilot.Port.LogSourcePort.Recent</method>'s reads above
/// its gate -&gt; the call counts go non-zero and this goes red.</p>
Method TestNothingIsReadBeforeTheGate()
{
    Do ##class(OcuPilot.Test.LogRecordsFixture).AddRow("FetchXdbc", "HSCUSTOM", $ListBuild("2026-09-20 10:00:00", "1", "<-1>", "armed"))
    Do ##class(OcuPilot.Test.LogRecordsFixture).AddTask($ListBuild(1, "2026-09-20 10:00:00", "HSCUSTOM", "Task", "ERROR", "armed"))
    Do ##class(OcuPilot.Test.LogSource).WriteFile(..Root() _ "SystemMonitor.log", "09/20/26-10:00:00 armed" _ $Char(10))
    For tI = 1:1:$Length(..#KEYPAIRS, ",") {
        Set tRow = $Piece(..#KEYPAIRS, ",", tI)
        Set tKey = $Piece(tRow, "=", 1)
        Set tSC = ..Recent(tKey, 10, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tKey _ ": refused")
        Do $$$AssertEquals(tHttp, 403, tKey _ ": with 403")
        Do $$$AssertEquals(##class(OcuPilot.Test.LogSource).FailedPair(tFault), $Piece(tRow, "=", 2), tKey _ ": naming its own pair")
        Do $$$AssertEquals($IsObject($Get(tResult)), 0, tKey _ ": and no entries")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.LogRecordsFixture).Calls(), 0, "no reader or predicate ran")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "and no file was touched")
}

/// <p>A namespace in the readable set whose own pairs fail is left out unread, and that is not a
/// fault: the other namespace's entries still come back.</p>
Method TestARefusedNamespaceIsLeftOutUnread()
{
    Do ..HoldAll()
    Do ##class(OcuPilot.Test.LogSourceFixture).SetNamespacePairs("xdbc", "USER", "%Admin_Operate:USE,OcuPilotNeverHeld:USE")
    Do ##class(OcuPilot.Test.LogRecordsFixture).AddRow("FetchXdbc", "HSCUSTOM", $ListBuild("2026-09-20 10:00:00", "1", "<-1>", "in HSCUSTOM"))
    Do ##class(OcuPilot.Test.LogRecordsFixture).AddRow("FetchXdbc", "USER", $ListBuild("2026-09-20 11:00:00", "2", "<-1>", "in USER"))
    Set tSC = ..Recent("xdbc", 10, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read answers")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Do $$$AssertEquals(..Texts(tResult), "[HSCUSTOM] <-1> in HSCUSTOM", "with the admitted namespace's entry alone")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogRecordsFixture).CallsFor("FetchXdbc", "USER"), 0, "the refused namespace was never read")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogRecordsFixture).CallsFor("FetchXdbc", "HSCUSTOM"), 1, "the admitted one once")
}

/// <p>AD-48 -- only the namespaces the caller can read are read: holding READ on HSCUSTOM's
/// globals database and not USER's, the USER entries neither come back nor are read.</p>
Method TestOnlyTheReadableSetIsRead()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_HSCUSTOM", "READ")
    For tMethod = "FetchXdbc", "FetchDiagnostics" {
        Do ##class(OcuPilot.Test.LogRecordsFixture).AddRow(tMethod, "USER", $ListBuild("2026-09-20 11:00:00", "2", "<-1>", "in USER", 0, "in USER"))
    }
    For tKey = "xdbc", "sqldiagnostics" {
        Set tSC = ..Recent(tKey, 10, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, tKey _ ": answers 200")
        Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.entries.%Size(), 1: -1), 0, tKey _ ": with no USER entry")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.LogRecordsFixture).CallsFor("FetchXdbc", "USER") + ##class(OcuPilot.Test.LogRecordsFixture).CallsFor("FetchDiagnostics", "USER"), 0, "USER was never read")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogRecordsFixture).CallsFor("FetchXdbc", "HSCUSTOM"), 1, "HSCUSTOM was")
}

/// <p>Each per-namespace source's predicate: the event log reads only interoperability-enabled
/// namespaces, and the analytics log only namespaces with a log file.</p>
/// <p>Mutation (Rule 19): drop the <code>Interoperable</code> check from
/// <method>OcuPilot.Port.LogSourcePort.NamespaceEntries</method> -&gt; USER's event log is read and
/// this goes red.</p>
Method TestEachSourcesPredicateFiltersTheReadableSet()
{
    Do ..HoldAll()
    Do ##class(OcuPilot.Test.LogRecordsFixture).SetInteroperable("USER", 0)
    Do ##class(OcuPilot.Test.LogRecordsFixture).AddRow("FetchEvents", "HSCUSTOM", $ListBuild(1, "2026-09-20 10:00:00.000", "4", "7", "", "in HSCUSTOM"))
    Do ##class(OcuPilot.Test.LogRecordsFixture).AddRow("FetchEvents", "USER", $ListBuild(1, "2026-09-20 11:00:00.000", "4", "7", "", "in USER"))
    Set tSC = ..Recent("eventlog", 10, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the event log answers")
    Do $$$AssertEquals(..Texts(tResult), "[HSCUSTOM] in HSCUSTOM", "with the interoperability-enabled namespace alone")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogRecordsFixture).CallsFor("FetchEvents", "USER"), 0, "USER, which is not, was never read")

    Do ##class(OcuPilot.Test.LogSource).WriteFile(..Root() _ "DeepSeeTasks_HSCUSTOM.log", ..AnalyticsLine("2026-09-20 15:00:00.250", 4242, "Builder", "built cube"))
    Set tSC = ..Recent("analytics", 10, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the analytics log answers with no file for USER")
    Do $$$AssertEquals(..Texts(tResult), "[HSCUSTOM] Builder built cube", "and reads HSCUSTOM's")
}

/// <p>Each source's mapping: time (a UTC store converted to local), pid, severity on the console
/// scale, the <code>[NS]</code> prefix and <code>raw</code>.</p>
Method TestEachSourceMapsItsEntries()
{
    Do ..HoldAll()
    Set tFixture = "OcuPilot.Test.LogRecordsFixture"
    Do $ClassMethod(tFixture, "AddTask", $ListBuild(4242, "2026-09-20 10:00:00", "HSCUSTOM", "Import", "ERROR", "details"))
    Do $ClassMethod(tFixture, "AddTaskError", 4242, $ListBuild("ERROR", -400, "bad row"))
    Do $ClassMethod(tFixture, "AddTaskError", 4242, $ListBuild("Msg", 0, "a note"))
    Do $ClassMethod(tFixture, "AddTask", $ListBuild(4343, "2026-09-20 09:00:00", "USER", "Link", "ERROR", "link failed"))
    Do $ClassMethod(tFixture, "AddTask", $ListBuild(4444, "2026-09-20 08:00:00", "USER", "Quiet", "Done", ""))
    Set tSC = ..Recent("taskerrors", 10, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Texts(tResult), "[HSCUSTOM] Import: a note|[HSCUSTOM] Import: bad row|[USER] Link: link failed", "task rows newest first, a failed task with no rows by its details, a finished one not at all")
    If $IsObject($Get(tResult)) && (tResult.entries.%Size() = 3) {
        Do $$$AssertEquals(tResult.entries.%Get(0).severity _ tResult.entries.%Get(1).severity _ tResult.entries.%Get(2).severity, "022", "Msg is 0 and ERROR 2")
        Do $$$AssertEquals(tResult.entries.%Get(0).time, "2026-09-20T10:00:00.000", "the task's start time")
        Do $$$AssertEquals(tResult.entries.%Get(0).pid, "4242", "and its id as the pid")
    }

    Do $ClassMethod(tFixture, "AddRow", "FetchXdbc", "HSCUSTOM", $ListBuild("2026-09-20 11:00:00", "777", "<-30>:<Table or view not found>", " Table 'X' not found"))
    Set tSC = ..Recent("xdbc", 10, .tResult, .tHttp, .tFault)
    Set tEntry = $Select($IsObject($Get(tResult)): tResult.entries.%Get(0), 1: "")
    Do $$$AssertTrue($IsObject(tEntry), "an xDBC entry")
    If $IsObject(tEntry) {
        Do $$$AssertEquals(tEntry.text, "[HSCUSTOM] <-30>:<Table or view not found> Table 'X' not found", "SQLCODE then MESSAGE, led by the namespace")
        Do $$$AssertEquals(tEntry.severity _ "|" _ tEntry.pid _ "|" _ tEntry.time, "2|777|2026-09-20T11:00:00.000", "severity 2, the display pid, the local time")
        Do $$$AssertEquals(tEntry.raw, "2026-09-20T11:00:00.000 (777) 2 [HSCUSTOM] <-30>:<Table or view not found> Table 'X' not found", "and raw is time, pid, severity and text on one line")
    }

    Do $ClassMethod(tFixture, "AddRow", "FetchDiagnostics", "HSCUSTOM", $ListBuild(6, "2026-09-20 12:30:00.500", "889", 0, 0, "LOAD DATA clean"))
    Do $ClassMethod(tFixture, "AddRow", "FetchDiagnostics", "HSCUSTOM", $ListBuild(5, "2026-09-20 12:00:00.123456", "888", -400, 1, "LOAD DATA failed"), $ListBuild("row 3 failed"))
    Set tSC = ..Recent("sqldiagnostics", 10, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Texts(tResult), "[HSCUSTOM] LOAD DATA clean|[HSCUSTOM] LOAD DATA failed" _ $Char(10) _ "row 3 failed", "each result's statement, then its messages")
    If $IsObject($Get(tResult)) && (tResult.entries.%Size() = 2) {
        Do $$$AssertEquals(tResult.entries.%Get(0).severity _ tResult.entries.%Get(1).severity, "02", "2 only for a failed result")
        Do $$$AssertEquals(tResult.entries.%Get(1).time, ..ExpectedLocal("2026-09-20 12:00:00") _ ".123", "a UTC creation time in local time, to the millisecond")
    }

    Do $ClassMethod(tFixture, "AddRow", "FetchEvents", "HSCUSTOM", $ListBuild(9, "2026-09-20 13:00:00.500", "3", "999", "MyService", "warned"))
    Do $ClassMethod(tFixture, "AddRow", "FetchEvents", "HSCUSTOM", $ListBuild(8, "2026-09-20 12:59:00.000", "5", "998", "", "traced"))
    Set tSC = ..Recent("eventlog", 10, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Texts(tResult), "[HSCUSTOM] MyService: warned|[HSCUSTOM] traced", "the host leads the text where there is one")
    If $IsObject($Get(tResult)) && (tResult.entries.%Size() = 2) {
        Do $$$AssertEquals(tResult.entries.%Get(0).severity _ "," _ tResult.entries.%Get(1).severity, "1,-1", "Warning 1, Trace -1")
        Do $$$AssertEquals(tResult.entries.%Get(0).time, ..ExpectedLocal("2026-09-20 13:00:00") _ ".500", "TimeLogged converted from UTC")
        Do $$$AssertEquals(tResult.entries.%Get(0).pid, "999", "the job as the pid")
    }

    Do ##class(OcuPilot.Test.LogSource).WriteFile(..Root() _ "SystemMonitor.log", "09/20/26-14:00:00 [SYSTEM MONITOR] started" _ $Char(10) _ "  and continued" _ $Char(10) _ "09/20/26-14:05:00 1 alerts posted" _ $Char(10))
    Set tSC = ..Recent("systemmonitor", 10, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Texts(tResult), "1 alerts posted|[SYSTEM MONITOR] started" _ $Char(10) _ "  and continued", "System Monitor lines newest first, a continuation kept with its entry")
    If $IsObject($Get(tResult)) && (tResult.entries.%Size() = 2) {
        Do $$$AssertEquals(tResult.entries.%Get(0).time _ "|" _ tResult.entries.%Get(0).pid _ "|" _ tResult.entries.%Get(0).severity, "2026-09-20T14:05:00.000||0", "the file's local stamp, no pid, severity 0")
    }

    Do ##class(OcuPilot.Test.LogSource).WriteFile(..Root() _ "DeepSeeTasks_HSCUSTOM.log", ..AnalyticsLine("2026-09-20 15:00:00.250", 4242, "Builder", "built cube"))
    Set tSC = ..Recent("analytics", 10, .tResult, .tHttp, .tFault)
    Set tEntry = $Select($IsObject($Get(tResult)): tResult.entries.%Get(0), 1: "")
    Do $$$AssertTrue($IsObject(tEntry), "an analytics entry")
    If $IsObject(tEntry) Do $$$AssertEquals(tEntry.time _ "|" _ tEntry.pid _ "|" _ tEntry.severity _ "|" _ tEntry.text, "2026-09-20T15:00:00.250|4242|0|[HSCUSTOM] Builder built cube", "the stamp, the job, severity 0 and source then message")
}

/// <p>AD-36 -- entries merge across namespaces newest first and cut at the cap, reporting
/// <code>truncated</code> only when something was cut; <method>OcuPilot.Port.LogSourcePort.Rows</method>
/// reports the same cut to a declared read (Story 16.9).</p>
/// <p>Mutation (Rule 19): walk <method>OcuPilot.Port.LogSourcePort.Recent</method>'s merge in
/// ascending time -&gt; the order assertions go red. Drop <method>OcuPilot.Port.LogSourcePort.Rows</method>'
/// report of <method>OcuPilot.Port.LogSourcePort.Recent</method>'s cut -&gt; the port-cut assertion
/// goes red.</p>
Method TestTheMergeIsNewestFirstAndCutAtTheCap()
{
    Do ..HoldAll()
    For tRow = "HSCUSTOM|10", "USER|11", "HSCUSTOM|12", "USER|13", "HSCUSTOM|14" {
        Set tNamespace = $Piece(tRow, "|", 1)
        Set tHour = $Piece(tRow, "|", 2)
        Do ##class(OcuPilot.Test.LogRecordsFixture).AddRow("FetchXdbc", tNamespace, $ListBuild("2026-09-20 " _ tHour _ ":00:00", "1", "<-1>", "at " _ tHour))
    }
    Set tSC = ..Recent("xdbc", 3, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Texts(tResult), "[HSCUSTOM] <-1> at 14|[USER] <-1> at 13|[HSCUSTOM] <-1> at 12", "the newest three across both namespaces")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.truncated, 1: ""), 1, "reporting the cut")

    Set tSC = ..Recent("xdbc", 10, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Texts(tResult), "[HSCUSTOM] <-1> at 14|[USER] <-1> at 13|[HSCUSTOM] <-1> at 12|[USER] <-1> at 11|[HSCUSTOM] <-1> at 10", "all five, newest first")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.truncated, 1: ""), 0, "and nothing cut")

    Set tCut = ""
    Set tSC = $ClassMethod(..#PORT, "Rows", "xdbc", 3, .tRows, .tHttp, .tFault, .tCut)
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size(), 1: 0) _ "|" _ tCut, "3|1", "Rows reports the port's own cut beside its rows")
    Set tSC = $ClassMethod(..#PORT, "Rows", "xdbc", 10, .tRows, .tHttp, .tFault, .tCut)
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size(), 1: 0) _ "|" _ tCut, "5|0", "and none when nothing was cut")
}

/// <p><method>Page</method> serves messages and alerts only: each of the six keys is refused
/// <code>LOG.SOURCE</code> before its gate or any read, so a caller holding no pair is told the
/// source is not paged rather than refused a privilege. <method>Recent</method> likewise refuses
/// any other key, messages included, before its gate. <method>Rows</method> answers the same
/// entries as <code>{time, severity, text}</code> alone.</p>
/// <p>Mutation (Rule 19): delete <method>OcuPilot.Port.LogSourcePort.Page</method>'s
/// <parameter>RECENTSOURCES</parameter> refusal, or <method>OcuPilot.Port.LogSourcePort.Recent</method>'s
/// enum check -&gt; the gate answers 403 first and this goes red.</p>
Method TestPageRefusesTheSixAndRowsProjectsThreeFields()
{
    For tI = 1:1:$Length(..#KEYPAIRS, ",") {
        Set tKey = $Piece($Piece(..#KEYPAIRS, ",", tI), "=", 1)
        Set tSC = $ClassMethod(..#PORT, "Page", tKey, "", "", "", .tPage, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 404, tKey _ ": Page refuses it, holding no pair")
        Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), "LOG.SOURCE", tKey _ ": as a source it does not page")
    }
    For tKey = "messages", "ocupilotnosuchsource" {
        Set tSC = ..Recent(tKey, 10, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "404|LOG.SOURCE", tKey _ ": Recent refuses a key outside the six before its gate")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.LogRecordsFixture).Calls() + ##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "reading nothing")
    Do ..HoldAll()

    Do ##class(OcuPilot.Test.LogRecordsFixture).AddRow("FetchXdbc", "HSCUSTOM", $ListBuild("2026-09-20 10:00:00", "5", "<-1>", "projected"))
    Set tSC = $ClassMethod(..#PORT, "Rows", "xdbc", 5, .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "Rows answers the same source")
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size(), 1: 0), 1, "one row")
    If '$IsObject($Get(tRows)) || (tRows.%Size() '= 1) Quit
    Set tKeys = ""
    Set tIterator = tRows.%Get(0).%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tName
    }
    Do $$$AssertEquals(tKeys, "time,severity,text", "carrying time, severity and text, never pid or raw")
    Do $$$AssertEquals(tRows.%Get(0).text, "[HSCUSTOM] <-1> projected", "the entry's own text")
}

/// <p>AD-36 -- a read that faults after its gate fails the whole answer 500
/// <code>LOG.UNREADABLE</code>, never a partial list, whether the fault is one namespace's or the
/// instance's.</p>
Method TestAFaultFailsTheWholeRead()
{
    Do ..HoldAll()
    Do ##class(OcuPilot.Test.LogRecordsFixture).AddRow("FetchXdbc", "HSCUSTOM", $ListBuild("2026-09-20 10:00:00", "1", "<-1>", "readable"))
    Do ##class(OcuPilot.Test.LogRecordsFixture).SetFault("FetchXdbc", "USER")
    Set tSC = ..Recent("xdbc", 10, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "one namespace's fault fails the read")
    Do $$$AssertEquals(tHttp, 500, "with 500")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), "LOG.UNREADABLE", "on LOG.UNREADABLE")
    Do $$$AssertEquals($IsObject($Get(tResult)), 0, "and HSCUSTOM's entry is not answered alone")

    Do ##class(OcuPilot.Test.LogRecordsFixture).SetFault("FetchTasks")
    Set tSC = ..Recent("taskerrors", 10, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "500|LOG.UNREADABLE", "and so does the instance store's")
}

/// <p>Each half of the severity rules: an SQL diagnostics result is 2 when its <code>sqlcode</code>
/// is negative or it counted errors, either alone, and 0 otherwise; an event of type Assert, Error or
/// Alert is 2, Warning 1, Info 0 and Trace -1.</p>
/// <p>Mutation (Rule 19): drop the <code>errorCount</code> half from
/// <method>OcuPilot.Port.LogSourcePort.SqlDiagnostics</method>, or <code>ALERT</code> from
/// <method>OcuPilot.Port.LogSourcePort.EventSeverity</method> -&gt; this goes red.</p>
Method TestTheSeverityRulesCoverEachCondition()
{
    Do ..HoldAll()
    Set tFixture = "OcuPilot.Test.LogRecordsFixture"
    Do $ClassMethod(tFixture, "AddRow", "FetchDiagnostics", "HSCUSTOM", $ListBuild(3, "2026-09-20 12:03:00", "1", 0, 0, "clean"))
    Do $ClassMethod(tFixture, "AddRow", "FetchDiagnostics", "HSCUSTOM", $ListBuild(2, "2026-09-20 12:02:00", "1", -400, 0, "code alone"))
    Do $ClassMethod(tFixture, "AddRow", "FetchDiagnostics", "HSCUSTOM", $ListBuild(1, "2026-09-20 12:01:00", "1", 0, 2, "count alone"))
    Set tSC = ..Recent("sqldiagnostics", 10, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Severities(tResult), "[HSCUSTOM] clean=0|[HSCUSTOM] code alone=2|[HSCUSTOM] count alone=2", "a negative sqlcode or a counted error, either alone, is 2")

    For tRow = "6|6|Alert", "5|1|Assert", "4|2|Error", "3|3|Warning", "2|4|Info", "1|5|Trace" {
        Do $ClassMethod(tFixture, "AddRow", "FetchEvents", "HSCUSTOM", $ListBuild(+$Piece(tRow, "|", 1), "2026-09-20 13:0" _ $Piece(tRow, "|", 1) _ ":00", $Piece(tRow, "|", 2), "1", "", $Piece(tRow, "|", 3)))
    }
    Set tSC = ..Recent("eventlog", 10, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Severities(tResult), "[HSCUSTOM] Alert=2|[HSCUSTOM] Assert=2|[HSCUSTOM] Error=2|[HSCUSTOM] Warning=1|[HSCUSTOM] Info=0|[HSCUSTOM] Trace=-1", "each event type on the console scale")
    Do $$$AssertEquals(##class(OcuPilot.Port.LogSourcePort).EventSeverity("Alert") _ ##class(OcuPilot.Port.LogSourcePort).EventSeverity("warning"), "21", "and the display values map the same way")
}

/// <p>The texts and severities of <var>pResult</var>'s entries, as <code>text=severity</code>,
/// <code>|</code>-separated.</p>
ClassMethod Severities(pResult) As %String
{
    If '$IsObject(pResult) Quit ""
    Set tOut = ""
    Set tIterator = pResult.entries.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: "|") _ tEntry.text _ "=" _ tEntry.severity
    }
    Quit tOut
}

/// <p>AD-36 -- the production fetchers turn a failed statement into an error status, never an
/// empty result, and leave the caller in its own namespace: <code>Ens_Util.Log</code> does not
/// exist in <code>%SYS</code> (SQLCODE -30), and a namespace that does not exist raises.</p>
/// <p>Mutation (Rule 19): delete <method>OcuPilot.Port.LogSourcePort.FetchEvents</method>'
/// <code>%SQLCODE &lt; 0</code> check -&gt; the statement error reads as no rows and this goes red.</p>
Method TestTheRealFetchersFailOnAnUnreadableStore()
{
    Set tHere = $NAMESPACE
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).FetchEvents("%SYS", 5, .tRows)
    Do $$$AssertStatusNotOK(tSC, "the event log fetcher fails where its table does not exist")
    Do $$$AssertEquals(+$Get(tRows) _ "|" _ $NAMESPACE, "0|" _ tHere, "with no rows, back in the caller's namespace")
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).FetchDiagnostics("OCUPILOTNOSUCHNAMESPACE", 5, .tRows2)
    Do $$$AssertStatusNotOK(tSC, "the diagnostics fetcher fails for a namespace it cannot enter")
    Do $$$AssertEquals(+$Get(tRows2) _ "|" _ $NAMESPACE, "0|" _ tHere, "with no rows, back in the caller's namespace")
}

/// <p>An instance with no System Monitor log answers no entries rather than a fault.</p>
Method TestAnAbsentSystemMonitorLogIsEmpty()
{
    Do ..HoldAll()
    Set tSC = ..Recent("systemmonitor", 10, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read answers")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.entries.%Size() _ "|" _ tResult.truncated, 1: ""), "0|0", "and no entries")
}

}
