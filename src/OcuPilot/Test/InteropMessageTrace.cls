/// <p>Pins Story 20.30's session trace read (AD-21, AD-29, AD-36, AD-37, AD-62) on synthetic message headers it stores in the install
/// namespace: any header of a session answers the session's whole trace, in <code>ID</code> order, as <code>Step</code> 1 to n, and a
/// header of another session is absent; each row carries the header's type and status words, error flag, local creation time,
/// source, target, body class, session and the id the trace was asked for; a cap truncates through the read route; an id no header
/// holds, and a header saved with no session, read as no rows; a malformed id is refused by name; and the read route and the read tool
/// answer the same rows.</p>
/// <p><b>What it needs from the environment:</b> the install namespace running interoperability, and the account running it holding
/// the pairs the gate asks. It needs no production: the headers are stored directly, found by a marker in their source, and removed
/// after each test. <method>Plant</method> and <method>Clear</method> are the browser spec's fixture too.</p>
Class OcuPilot.Test.InteropMessageTrace Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter FIXTURE = "OcuPilot.Test.InteropMessageRead";

/// <p>What every marker begins with; a run's marker is this and a token of letters and digits.</p>
Parameter PREFIX = "OcuPilotProbe2030";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.InteropMessageTraceTab";

/// <p>The fields the trace screen declares, in order: what the route, the tool and the port are compared in.</p>
Parameter FIELDS = "Message,Step,ID,TimeCreated,Type,Status,Source,Target,BodyClass,Error,SessionId";

/// <p>This test's marker. The prefix must not begin with "Test" (<file>.claude/rules/objectscript-testing.md</file>).</p>
Property PreparedMarker As %String;

/// <p>The ids of the fixture's five headers (<method>Plant</method>), in order.</p>
Property PreparedIds As %List;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedMarker = ""
    Set ..PreparedIds = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedMarker = ..#PREFIX _ $Extract($Translate($System.Util.CreateGUID(), "-", ""), 1, 8)
    Set tSC = ..Plant(..PreparedMarker, .tIds)
    Set ..PreparedIds = tIds
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals(..Clear(..PreparedMarker), 0, "no header of this test's marker is left")
    Quit $$$OK
}

/// <p>Store one fixture header and answer its id (0 when it could not be stored): <var>pSource</var> to <var>pTarget</var>, a request
/// or a response (<var>pType</var> 1 or 2), Completed or Error (<var>pStatus</var> 9 or 8), made <var>pAgo</var> seconds ago, naming
/// the body class <var>pBodyClass</var> and no body. <var>pSession</var>, when given, is its session; <var>pErrorText</var>, when given,
/// marks it as an error; <var>pOwnSession</var> makes its own id its session.</p>
ClassMethod Store(pSource As %String, pTarget As %String, pBodyClass As %String, pType As %Integer, pStatus As %Integer, pAgo As %Integer, pSession As %String = "", pErrorText As %String = "", pOwnSession As %Boolean = 0) As %Integer
{
    Quit $ClassMethod(..#FIXTURE, "StoreHeader", "", pBodyClass, "", pType, pStatus, pAgo, pSession, pErrorText, pOwnSession, "", pSource, pTarget)
}

/// <p>Store the session fixture for <var>pMarker</var> (the prefix and a token of letters and digits) and answer its ids, in order, in
/// <var>pIds</var>, every header made within the last hour. H1: a Request from <code>&lt;m&gt;Svc</code> to <code>&lt;m&gt; Proc;1</code> with an
/// <code>Ens.StringRequest</code> body class, Completed, its session its own id. H2: a Request from <code>&lt;m&gt; Proc;1</code> to
/// <code>&lt;m&gt;Op</code>, no body class, Completed, in H1's session. H3: a Response from <code>&lt;m&gt;Op</code> to <code>&lt;m&gt; Proc;1</code>,
/// no body class, Error and marked as an error, in H1's session. H4: a Response from <code>&lt;m&gt; Proc;1</code> to <code>&lt;m&gt;Svc</code> with
/// an <code>Ens.StringResponse</code> body class, Completed, in H1's session. H5: a Request from <code>&lt;m&gt;Svc</code> to <code>&lt;m&gt;Op</code>,
/// in its own session. <code>&lt;m&gt;</code> is <var>pMarker</var>.</p>
ClassMethod Plant(pMarker As %String, Output pIds As %List) As %Status
{
    Set pIds = ""
    Set tSC = $$$OK
    Try {
        If '$Match(pMarker, "^" _ ..#PREFIX _ "[A-Za-z0-9]{1,24}$") {
            Set tSC = $$$ERROR($$$GeneralError, "the marker is " _ ..#PREFIX _ " and a token of letters and digits")
            Quit
        }
        Set tSvc = pMarker _ "Svc"
        Set tProc = pMarker _ " Proc;1"
        Set tOp = pMarker _ "Op"
        Set tH1 = ..Store(tSvc, tProc, "Ens.StringRequest", 1, 9, 300, "", "", 1)
        Set tH2 = ..Store(tProc, tOp, "", 1, 9, 240, tH1)
        Set tH3 = ..Store(tOp, tProc, "", 2, 8, 180, tH1, "OcuPilot probe error " _ pMarker)
        Set tH4 = ..Store(tProc, tSvc, "Ens.StringResponse", 2, 9, 120, tH1)
        Set tH5 = ..Store(tSvc, tOp, "", 1, 9, 60, "", "", 1)
        If '(tH1 && tH2 && tH3 && tH4 && tH5) Set tSC = $$$ERROR($$$GeneralError, "a fixture header could not be stored")
        Set pIds = $ListBuild(tH1, tH2, tH3, tH4, tH5)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many headers whose source begins with <var>pMarker</var> are stored.</p>
ClassMethod Left(pMarker As %String) As %Integer
{
    Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT COUNT(*) FROM Ens.MessageHeader WHERE SourceConfigName %STARTSWITH ?", pMarker)
    If tResult.%Next() Quit tResult.%GetData(1)
    Quit -1
}

/// <p>Remove every header whose source begins with <var>pMarker</var>, and answer how many are left.</p>
ClassMethod Clear(pMarker As %String) As %Integer
{
    If $Extract(pMarker, 1, $Length(..#PREFIX)) '= ..#PREFIX Quit -1
    Try {
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT ID FROM Ens.MessageHeader WHERE SourceConfigName %STARTSWITH ?", pMarker)
        Kill tFound
        While tResult.%Next() {
            Set tFound($Increment(tFound)) = tResult.%GetData(1)
        }
        For tI = 1:1:+$Get(tFound) {
            Do ##class(Ens.MessageHeader).%DeleteId(tFound(tI))
        }
    } Catch {
    }
    Quit ..Left(pMarker)
}

/// <p>The rows the port's MessageTrace answers for the header <var>pId</var> (or for the query already in <var>pQuery</var>), or
/// <code>""</code> when it refuses; the HTTP status in <var>pHttp</var> and the fault in <var>pFault</var>.</p>
ClassMethod Trace(pId As %String, ByRef pQuery, Output pHttp As %Integer, Output pFault) As %DynamicArray
{
    Set pQuery("message") = pId
    Quit $ClassMethod(..#FIXTURE, "Rows", "MessageTrace", .pQuery, .pHttp, .pFault)
}

/// <p>The step and id of each of <var>pRows</var>, <code>step:id</code>, comma-separated, in order.</p>
ClassMethod Steps(pRows As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pRows) Quit "none"
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.%Get("Step") _ ":" _ tRow.%Get("ID")
    }
    Quit tText
}

/// <p>The session's whole trace opens from any of its headers: the first, a middle one and the last each answer H1 to H4 as steps 1 to
/// 4, and the header of another session is in none of them and opens a trace of its own.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Port.InteropPort.TRACESQL</parameter> reads <code>WHERE ID = ?</code> in place of the
/// session -- this goes red.</p>
Method TestAnyHeaderOpensItsWholeSession()
{
    Set tH1 = $List(..PreparedIds, 1), tH2 = $List(..PreparedIds, 2), tH3 = $List(..PreparedIds, 3), tH4 = $List(..PreparedIds, 4), tH5 = $List(..PreparedIds, 5)
    Set tWhole = "1:" _ tH1 _ ",2:" _ tH2 _ ",3:" _ tH3 _ ",4:" _ tH4
    For tFrom = tH1, tH3, tH4 {
        Kill tQ
        Set tRows = ..Trace(tFrom, .tQ, .tHttp)
        Do $$$AssertEquals(tHttp, 200, "the trace of " _ tFrom _ " answers 200")
        Do $$$AssertEquals(..Steps(tRows), tWhole, "the trace opened from " _ tFrom _ " is the whole session as steps 1 to 4, in ID order, and holds no header of another session")
    }
    Kill tQ
    Do $$$AssertEquals(..Steps(..Trace(tH5, .tQ)), "1:" _ tH5, "the other session's header opens a trace of its own")
}

/// <p>Each row carries the header it stands for: the type and status as display words, the error flag, the creation time in the
/// instance's local time, source, target and body class, the session and the id the trace was asked for. <code>Step</code> is a JSON
/// number, <code>Error</code> a boolean, and every other value a string.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ListMessageTrace</method> sets <code>Step</code> as a string -- the type
/// leg goes red; <method>OcuPilot.Port.InteropPort.MessageRow</method> reads <code>TimeCreated</code> without
/// <method>OcuPilot.Port.InteropPort.LocalStamp</method> -- the time leg goes red.</p>
Method TestTheRowsCarryTheHeaders()
{
    Set tM = ..PreparedMarker
    Set tSvc = tM _ "Svc", tProc = tM _ " Proc;1", tOp = tM _ "Op"
    Set tH1 = $List(..PreparedIds, 1)
    Set tSpec = $ListBuild($ListBuild("Request", "Completed", tSvc, tProc, "Ens.StringRequest", 0), $ListBuild("Request", "Completed", tProc, tOp, "", 0), $ListBuild("Response", "Error", tOp, tProc, "", 1), $ListBuild("Response", "Completed", tProc, tSvc, "Ens.StringResponse", 0))
    Kill tQ
    Set tRows = ..Trace(tH1, .tQ, .tHttp)
    Do $$$AssertEquals(tHttp, 200, "the trace answers")
    Do $$$AssertTrue($IsObject(tRows), "with rows")
    If '$IsObject(tRows) Quit
    Do $$$AssertEquals(tRows.%Size(), 4, "four rows")
    For tI = 1:1:tRows.%Size() {
        Set tRow = tRows.%Get(tI - 1)
        Set tId = $List(..PreparedIds, tI)
        Set tWant = $List(tSpec, tI)
        Do $$$AssertEquals(tRow.%GetTypeOf("Step") _ "|" _ tRow.Step, "number|" _ tI, "row " _ tI _ ": Step is a JSON number, " _ tI)
        Do $$$AssertEquals(tRow.%GetTypeOf("Error") _ "|" _ tRow.Error, "boolean|" _ $List(tWant, 6), "row " _ tI _ ": Error is the header's flag, a boolean")
        Do $$$AssertEquals(tRow.%GetTypeOf("ID") _ "|" _ tRow.%GetTypeOf("Message") _ "|" _ tRow.%GetTypeOf("SessionId") _ "|" _ tRow.%GetTypeOf("TimeCreated"), "string|string|string|string", "row " _ tI _ ": the other values are strings")
        Do $$$AssertEquals(tRow.ID _ "|" _ tRow.Message _ "|" _ tRow.SessionId, tId _ "|" _ tH1 _ "|" _ tH1, "row " _ tI _ ": its id, the id the trace was asked for and the session")
        Do $$$AssertEquals(tRow.Type _ "|" _ tRow.Status, $List(tWant, 1) _ "|" _ $List(tWant, 2), "row " _ tI _ ": the type and status words")
        Do $$$AssertEquals(tRow.Source _ "|" _ tRow.Target _ "|" _ tRow.BodyClass, $List(tWant, 3) _ "|" _ $List(tWant, 4) _ "|" _ $List(tWant, 5), "row " _ tI _ ": source, target and body class")
        Set tStored = $ClassMethod(..#FIXTURE, "StoredCreated", tId)
        Do $$$AssertEquals(tRow.TimeCreated, ##class(OcuPilot.Test.InteropHostRead).LocalForm(tStored), "row " _ tI _ ": the creation time is the instance's local time, from " _ tStored)
    }
}

/// <p>A cap of 2 answers the first two steps through the port and, through the read route, says it truncated.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ListMessageTrace</method> binds
/// <parameter>OcuPilot.Port.InteropPort.SQLMAX</parameter> in place of the cap -- this goes red.</p>
Method TestTheCapTruncates()
{
    Set tH1 = $List(..PreparedIds, 1), tH2 = $List(..PreparedIds, 2)
    Kill tQ
    Set tQ("maxRows") = 2
    Do $$$AssertEquals(..Steps(..Trace(tH1, .tQ)), "1:" _ tH1 _ ",2:" _ tH2, "the port answers the first two steps")
    Kill tCriteria
    Set tCriteria("message") = tH1
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 2, .tAnswer, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(tHttp, 200, "the read route answers")
    Do $$$AssertTrue($IsObject($Get(tAnswer)), "with an answer")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(tAnswer.rows.%Size() _ "|" _ tAnswer.truncated, "2|1", "two rows and the truncated flag")
    Do $$$AssertEquals(..Steps(tAnswer.rows), "1:" _ tH1 _ ",2:" _ tH2, "steps 1 and 2")
}

/// <p>An id no header holds, and a header saved with no session, each read as no rows; <code>abc</code>, <code>0</code> and twenty
/// digits are each refused 400 <code>PORT.VALIDATION</code> naming <code>message</code>; and no id at all is refused 400
/// <code>READ.CRITERION</code> by the read route.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Port.InteropPort.TRACESQL</parameter> also reads the header's own row
/// (<code>OR ID = ?</code>) and <method>OcuPilot.Port.InteropPort.ListMessageTrace</method> drops its empty-session check -- the no-session
/// leg goes red; <method>OcuPilot.Port.InteropPort.InvokeRuntime</method> routes MessageTrace around the id-shape check -- the malformed
/// legs go red.</p>
Method TestAbsentAndMalformedIds()
{
    Kill tQ
    Set tRows = ..Trace("9223372036854775", .tQ, .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tRows): tRows.%Size(), 1: "none"), "200|0", "an id no header holds reads as no rows")
    Set tBare = ..Store(..PreparedMarker _ "Bare", ..PreparedMarker _ "Op", "", 1, 9, 30)
    Do $$$AssertTrue(tBare > 0, "a header with no session is stored")
    Kill tQ
    Set tRows = ..Trace(tBare, .tQ, .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tRows): tRows.%Size(), 1: "none"), "200|0", "and reads as no rows")
    For tBad = "abc", "0", "12345678901234567890" {
        Kill tQ
        Set tRows = ..Trace(tBad, .tQ, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "400|PORT.VALIDATION", "'" _ tBad _ "' is refused 400 PORT.VALIDATION")
        Do $$$AssertTrue($IsObject(tFault) && ($Extract(tFault.reason, 1, 7) = "message"), "'" _ tBad _ "': the reason names message")
        Do $$$AssertEquals($IsObject(tRows), 0, "'" _ tBad _ "': no row is returned")
    }
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 1000, .tAnswer, .tReadHttp, .tReadFault)
    Do $$$AssertEquals(tReadHttp _ "|" _ $Select($IsObject($Get(tReadFault)): tReadFault.code, 1: ""), "400|READ.CRITERION", "a read with no id is refused READ.CRITERION by the route")
}

/// <p>AD-36: the read route, the read tool and the port answer the same rows, in the fields the screen declares.</p>
/// <p>Mutation (Rule 19): rename the <code>message</code> criterion in <class>OcuPilot.Screen.Descriptor.InteropMessageTraceTab</class> --
/// the route and the tool answer a refusal while the port answers the session, and this goes red.</p>
Method TestTheToolAndTheRouteAgree()
{
    Set tH1 = $List(..PreparedIds, 1)
    Kill tQ, tCriteria
    Set tCriteria("message") = tH1
    Set tArgs = {}
    Do tArgs.%Set("message", tH1, "string")
    Set tPortRows = ..Trace(tH1, .tQ, .tPortHttp)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 1000, .tAnswer, .tRouteHttp, .tRouteFault, .tCriteria)
    Set tToolName = $ClassMethod(..#SCREEN, "ToolIdentifier") _ ".read"
    Do $$$AssertEquals(tToolName, "interop.messagetrace.read", "the screen's read tool")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tToolName, .tTool)
    Do $$$AssertTrue($IsObject($Get(tTool)), tToolName _ " is a registered read tool")
    Kill tResult
    Set tToolHttp = 0
    If $IsObject($Get(tTool)) Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, tArgs, 1000, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertEquals(tPortHttp _ "|" _ tRouteHttp _ "|" _ tToolHttp, "200|200|200", "the port, the route and the tool answer")
    If '$IsObject(tPortRows) || '$IsObject($Get(tAnswer)) || '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tPortRows.%Size(), 4, "the port answers the session's four steps")
    Set tPortCanon = $ClassMethod(..#FIXTURE, "Canon", tPortRows, ..#FIELDS)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Canon", tAnswer.rows, ..#FIELDS), tPortCanon, "the route's rows are the port's")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Canon", tResult.rows, ..#FIELDS), tPortCanon, "and so are the tool's")
}

}
