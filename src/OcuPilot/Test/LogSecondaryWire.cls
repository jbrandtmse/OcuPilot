/// <p>The six secondary log routes over the wire (Story 16.8): each
/// <code>GET /api/ocupilot/logs/&lt;key&gt;</code> answers one envelope carrying the entry
/// <class>OcuPilot.Test.LogSecondarySeed</class> put in its store, at that store's severity; a
/// <code>file</code> parameter is refused <code>LOG.FILE</code>; and each screen's declared read
/// answers the route's newest entries. It also pins the columns of
/// <code>%SQL.Manager.Catalog:XdbcErrors</code> and <code>%CSP.UI.System.BackgroundTask</code>'s
/// <code>EnumerateTasks</code> and <code>ErrorLog</code>, which are vendor-internal.</p>
/// <p><b>It writes the instance's own log stores</b>, removing exactly what it seeded in
/// <method>OnAfterAllTests</method>, so it runs on a throwaway container only and refuses anywhere
/// <parameter>ARMINGVARIABLE</parameter> does not arm it. Needs the API application installed and
/// the test principal (<class>OcuPilot.Test.Http</class>) holding every pair the six screens
/// declare.</p>
Class OcuPilot.Test.LogSecondaryWire Extends %UnitTest.TestCase
{

/// <p>The variable that arms this class, <class>OcuPilot.Test.LogSecondarySeed</class>'s own.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_LOG_ROTATION";

/// <p>The text every seeded entry carries.</p>
Parameter MARKER = "OcuPilotSecondaryWire";

/// <p>Each key and the severity its seeded entry carries, <code>key=severity</code>, with
/// <code>*</code> after the severity where the entry is led by its namespace.</p>
Parameter SEEDED = "systemmonitor=0,taskerrors=2*,xdbc=2*,sqldiagnostics=2*,eventlog=2*,analytics=0*";

/// <p>The six routes, spelled literally, in <parameter>SEEDED</parameter>'s order.</p>
Parameter ROUTES = "/api/ocupilot/logs/systemmonitor,/api/ocupilot/logs/taskerrors,/api/ocupilot/logs/xdbc,/api/ocupilot/logs/sqldiagnostics,/api/ocupilot/logs/eventlog,/api/ocupilot/logs/analytics";

/// <p>The columns of <code>XdbcErrors</code> the reader reads or deliberately does not, each as
/// <code>position:name</code>; the query answers nine.</p>
Parameter XDBCCOLUMNS = "1:DATE_TIME,3:SQLCODE,6:MESSAGE,7:DisplayPID,8:CONNECTION_INFO";

/// <p>The columns <code>EnumerateTasks</code> answers, in order: <class>OcuPilot.Port.LogSourcePort</class>
/// reads the first six, and <class>OcuPilot.Port.BackgroundTaskPort</class> every one (Story 16.5).</p>
Parameter TASKCOLUMNS = "ID,StartTime,Namespace,Task,Status,Details,ErrorCount,SysBGTaskId";

/// <p>The columns <code>ErrorLog</code> answers, in order.</p>
Parameter TASKERRORCOLUMNS = "Type,ErrorNo,ErrorText,Row";

/// <p>Refuse unless armed; otherwise seed the six stores.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogSecondaryWire writes this instance's own log stores and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ##class(OcuPilot.Test.LogSecondarySeed).Seed(..#MARKER)
}

/// <p>Remove the seeded entries, and fail if any store still holds the marker.</p>
Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Quit ##class(OcuPilot.Test.LogSecondarySeed).Remove()
}

/// <p>Request <var>pPath</var> as the configured test principal.</p>
Method Fetch(pPath As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBody, .pHeaders)
}

/// <p>The pid source <var>pKey</var>'s seeded entry carries: none for the System Monitor log, the
/// seeded task's and xDBC error's own ids, and otherwise this process, which seeded the store in
/// <method>OnBeforeAllTests</method>.</p>
Method SeededPid(pKey As %String) As %String
{
    If pKey = "systemmonitor" Quit ""
    If pKey = "taskerrors" Quit ##class(OcuPilot.Test.LogSecondarySeed).#TASKID
    If pKey = "xdbc" Quit ##class(OcuPilot.Test.LogSecondarySeed).#XDBCPID
    Quit $Job
}

/// <p>AC1, AC2 -- each route answers one envelope with its seeded entry: its time in the local
/// <code>YYYY-MM-DDTHH:MM:SS.mmm</code> form, its store's severity and pid, a namespace-scoped
/// entry led by <code>[HSCUSTOM] </code>, and <code>raw</code> as one line. The seeded task's
/// details differ from its error row, so the task entry is found only through
/// <code>ErrorLog</code>.</p>
Method TestEachRouteAnswersItsSeededEntry()
{
    For tI = 1:1:$Length(..#SEEDED, ",") {
        Set tRow = $Piece(..#SEEDED, ",", tI)
        Set tKey = $Piece(tRow, "=", 1)
        Set tSeverity = $Translate($Piece(tRow, "=", 2), "*")
        Set tScoped = ($Piece(tRow, "=", 2) [ "*")
        Set tSC = ..Fetch($Piece(..#ROUTES, ",", tI), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tKey _ ": the request completes")
        Do $$$AssertEquals(tStatus, 200, tKey _ ": answers 200")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tKey _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tKey _ ": in exactly one envelope")
        If tStatus '= 200 Continue
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tAnswer.source, tKey, tKey _ ": naming the source the route bound")
        Do $$$AssertEquals(tAnswer.%GetTypeOf("truncated"), "boolean", tKey _ ": reporting whether it cut")
        Set tFound = ""
        Set tIterator = tAnswer.entries.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If tEntry.text [ ##class(OcuPilot.Test.LogSecondarySeed).Text(..#MARKER, tKey) {
                Set tFound = tEntry
                Quit
            }
        }
        Do $$$AssertTrue($IsObject(tFound), tKey _ ": carries the seeded entry")
        If '$IsObject(tFound) Continue
        Do $$$AssertTrue($Match(tFound.time, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}$"), tKey _ ": its time is local YYYY-MM-DDTHH:MM:SS.mmm: " _ tFound.time)
        Do $$$AssertEquals(tFound.severity, tSeverity, tKey _ ": at its store's severity")
        Do $$$AssertEquals(tFound.pid, ..SeededPid(tKey), tKey _ ": under the pid its store filed it with")
        If tScoped Do $$$AssertEquals($Extract(tFound.text, 1, 11), "[HSCUSTOM] ", tKey _ ": led by its namespace")
        Do $$$AssertEquals(tFound.raw, tFound.time _ " (" _ tFound.pid _ ") " _ tFound.severity _ " " _ tFound.text, tKey _ ": raw is the entry as one line")
    }
}

/// <p>AC2 (AD-21) -- a route names its source and takes no file: a <code>file</code> parameter is
/// refused 400 <code>LOG.FILE</code> in one envelope that does not repeat the value.</p>
Method TestAFileParameterIsRefused()
{
    For tKey = "systemmonitor", "xdbc", "analytics" {
        Set tSC = ..Fetch("/api/ocupilot/logs/" _ tKey _ "?file=ocupilotnamedfile", .tStatus, .tBody, .tHeaders)
        Do $$$AssertEquals(tStatus, 400, tKey _ ": a file parameter is refused")
        Do $$$AssertEquals((tBody [ "}{"), 0, tKey _ ": in exactly one envelope")
        If tStatus '= 400 Continue
        Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tFault.code, "LOG.FILE", tKey _ ": on LOG.FILE")
        Do $$$AssertEquals((tBody [ "ocupilotnamedfile"), 0, tKey _ ": without repeating the value")
    }
}

/// <p>AC7 -- a screen's declared read, which its tool derives from, answers the route's newest
/// entries as <code>{time, severity, text}</code>. The System Monitor writes on its own, so a pair
/// of reads that straddles one of its lines is read again once.</p>
Method TestEachToolReadsTheRoutesNewestEntries()
{
    For tI = 1:1:$Length(..#SEEDED, ",") {
        Set tKey = $Piece($Piece(..#SEEDED, ",", tI), "=", 1)
        Set tSame = 0
        For tTry = 1:1:2 {
            Set tSC = ..Fetch("/api/ocupilot/logs/" _ tKey, .tStatus, .tBody, .tHeaders)
            Set tSC2 = ..Fetch("/api/ocupilot/screens/logs." _ tKey _ "/read?maxRows=5", .tStatus2, .tBody2, .tHeaders2)
            If (tStatus '= 200) || (tStatus2 '= 200) Quit
            Set tRoute = ##class(%DynamicObject).%FromJSON(tBody)
            Set tRead = ##class(%DynamicObject).%FromJSON(tBody2)
            Set tWant = []
            For tAt = 0:1:(tRoute.entries.%Size() - 1) {
                If tAt >= 5 Quit
                Set tEntry = tRoute.entries.%Get(tAt)
                Do tWant.%Push({"time": (tEntry.time), "severity": (tEntry.severity), "text": (tEntry.text)})
            }
            Set tSame = (tWant.%ToJSON() = tRead.rows.%ToJSON())
            If tSame Quit
        }
        Do $$$AssertEquals(tStatus _ "|" _ tStatus2, "200|200", tKey _ ": both the route and the declared read answer")
        Do $$$AssertTrue(tSame, tKey _ ": the declared read holds the route's newest entries")
    }
}

/// <p>AD-36 -- an SQL diagnostics result whose messages outnumber
/// <parameter>OcuPilot.Port.LogSourcePort.DIAGMESSAGEMAX</parameter> is read with that many and a
/// U+2026 line, never all of them. The result is added and removed here, in HSCUSTOM.</p>
Method TestADiagnosticsResultCarriesAtMostItsMessageCap()
{
    Set tCap = ##class(OcuPilot.Port.LogSourcePort).#DIAGMESSAGEMAX
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "HSCUSTOM"
    Set tDiag = ##class(%SQL.Diag.Result).addDiagResult(0)
    For tI = 1:1:(tCap + 2) Do ##class(%SQL.Diag.Result).addDiagMessage(tDiag, "OcuPilot", -400, ..#MARKER _ " capped " _ tI, 3)
    Set $NAMESPACE = tOrigNS
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).FetchDiagnostics("HSCUSTOM", 5, .tRows)
    Set $NAMESPACE = "HSCUSTOM"
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM %SQL_Diag.Message WHERE diagResult = ?", tDiag)
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM %SQL_Diag.Result WHERE ID = ?", tDiag)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertStatusOK(tSC, "the diagnostics fetcher answers")
    Set tAt = 0
    For tI = 1:1:+$Get(tRows) {
        If $ListGet(tRows(tI), 1) = tDiag Set tAt = tI
    }
    Do $$$AssertTrue(tAt > 0, "the added result is among the newest")
    If tAt = 0 Quit
    Set tLines = 0
    Set tLine = ""
    For {
        Set tLine = $Order(tRows(tAt, tLine))
        If tLine = "" Quit
        Set tLines = tLines + 1
    }
    Do $$$AssertEquals(tLines, tCap + 1, "the cap's messages and one more line")
    Do $$$AssertEquals($Get(tRows(tAt, tCap)), ..#MARKER _ " capped " _ tCap, "the first messages, in order")
    Do $$$AssertEquals($Get(tRows(tAt, tCap + 1)), $Char(8230), "then U+2026 alone")
}

/// <p>The vendor readers this story depends on are internal, so their columns are pinned: a
/// release that renames or moves one fails here rather than on a screen.</p>
Method TestTheVendorReadersColumnsArePinned()
{
    Set tRS = ##class(%ResultSet).%New("%SQL.Manager.Catalog:XdbcErrors")
    Do $$$AssertTrue($IsObject(tRS), "XdbcErrors opens")
    If $IsObject(tRS) {
        Do $$$AssertStatusOK(tRS.Execute("HSCUSTOM"), "XdbcErrors executes")
        Do $$$AssertEquals(tRS.GetColumnCount(), 9, "XdbcErrors answers nine columns")
        For tI = 1:1:$Length(..#XDBCCOLUMNS, ",") {
            Set tColumn = $Piece(..#XDBCCOLUMNS, ",", tI)
            Do $$$AssertEquals(tRS.GetColumnName(+tColumn), $Piece(tColumn, ":", 2), "XdbcErrors column " _ tColumn)
        }
        Do tRS.Close()
    }
    For tRow = $ListBuild("%CSP.UI.System.BackgroundTask:EnumerateTasks", ..#TASKCOLUMNS, ""), $ListBuild("%CSP.UI.System.BackgroundTask:ErrorLog", ..#TASKERRORCOLUMNS, ##class(OcuPilot.Test.LogSecondarySeed).#TASKID) {
        Set tQuery = $List(tRow, 1)
        Set tRS = ##class(%ResultSet).%New(tQuery)
        Do $$$AssertTrue($IsObject(tRS), tQuery _ ": opens")
        If '$IsObject(tRS) Continue
        Set tArgument = $List(tRow, 3)
        Set tSC = $Select(tArgument = "": tRS.Execute(), 1: tRS.Execute(tArgument))
        Do $$$AssertStatusOK(tSC, tQuery _ ": executes")
        Set tColumns = ""
        For tAt = 1:1:tRS.GetColumnCount() {
            Set tColumns = tColumns _ $Select(tColumns = "": "", 1: ",") _ tRS.GetColumnName(tAt)
        }
        Do $$$AssertEquals(tColumns, $List(tRow, 2), tQuery _ ": answers the columns OcuPilot.Port.LogSourcePort and OcuPilot.Port.BackgroundTaskPort read")
        Do tRS.Close()
    }
}

}
