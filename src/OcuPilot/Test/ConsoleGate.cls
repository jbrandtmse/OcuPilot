/// <p>Pins Story 24.6's two consoles behind a person's screen action (AD-10, AD-22, AD-23, AD-53): each governance key shipped off,
/// the port's checks in their fixed order, and the one body call the port makes. <b>No test runs a command or calls a class
/// method here</b>: <class>OcuPilot.Test.ConsoleActionFixture</class> sends the route's own action to
/// <class>OcuPilot.Test.DevToolPortFixture</class>, whose harvest port is <class>OcuPilot.Test.DevToolHarvestRecorder</class>,
/// which records a body call and answers a canned result.</p>
/// <p>Needs the namespace <code>USER</code> and a process holding the screen's pairs. Each test saves the probe class
/// <code>OcuProbe246.Echo</code> in <code>USER</code> and the stored governance policy before it, and puts both back after it. A
/// refusal row is read as no body call and no <code>SecurityChange</code> row that names either console since the test began.</p>
Class OcuPilot.Test.ConsoleGate Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.DevToolProbe";

Parameter FIXTURE = "OcuPilot.Test.DevToolPortFixture";

Parameter RECORDER = "OcuPilot.Test.DevToolHarvestRecorder";

Parameter ACTION = "OcuPilot.Test.ConsoleActionFixture";

Parameter GOVERNANCE = "OcuPilot.Test.GovernanceFixture";

Parameter NAMESPACE = "USER";

Parameter ECHO = "OcuProbe246.Echo";

/// <p>The governance policy found before each test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

/// <p>The audit clock when the test began, so a row it counts is one this test could have caused.</p>
Property Since As %String;

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = $ClassMethod(..#GOVERNANCE, "Snapshot", .tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Kill tNone
    Do $ClassMethod(..#GOVERNANCE, "Restore", .tNone)
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#FIXTURE, "Clear")
    ; The audit stamps a row a little after the call that wrote it, so the clock is read once the last test's rows are behind it.
    Hang 0.25
    Set ..Since = ##class(OcuPilot.Test.AuditEvent).Now()
    Quit $ClassMethod(..#PROBE, "MakeConsoleProbe", ..#NAMESPACE)
}

Method OnAfterOneTest() As %Status
{
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK($ClassMethod(..#GOVERNANCE, "Restore", .tRows), "the governance policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveConsoleProbe", ..#NAMESPACE), "the console probe class is removed")
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>The console <var>pConsole</var>'s screen, governance key and the literal its target is named by.</p>
ClassMethod ScreenOf(pConsole As %String) As %String
{
    Quit "explorer." _ pConsole
}

ClassMethod KeyOf(pConsole As %String) As %String
{
    Quit "explorer." _ pConsole _ ".run"
}

/// <p>Store the key of <var>pConsole</var> on, the one setting that lets the route past its governance ask.</p>
ClassMethod EnableKey(pConsole As %String)
{
    Kill tSettings
    Set tSettings(..KeyOf(pConsole)) = "enabled"
    Do $ClassMethod(..#GOVERNANCE, "Apply", "", .tSettings)
}

/// <p>Send a person's Run of <var>pConsole</var> with <var>pValues</var> through the route: the status and the parsed envelope.</p>
Method Act(pConsole As %String, pValues As %DynamicObject, Output pStatus As %Integer, Output pAnswer) As %Status
{
    Set tBody = {"action": "run", "id": (pConsole)}
    Do tBody.%Set("values", pValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", ..ScreenOf(pConsole), tBody, .tRaw, .pStatus)
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicAbstractObject).%FromJSON(tRaw)
    } Catch {
        Set pAnswer = ""
    }
    Quit tSC
}

/// <p>Run the command <var>pText</var> through the route.</p>
Method ActCommand(pText As %String, Output pStatus As %Integer, Output pAnswer) As %Status
{
    Quit ..Act("command", {"command": (pText)}, .pStatus, .pAnswer)
}

/// <p>Call <var>pClass</var>.<var>pMethod</var> with the argument list text <var>pArgs</var> through the route.</p>
Method ActMethod(pClass As %String, pMethod As %String, pArgs As %String, Output pStatus As %Integer, Output pAnswer) As %Status
{
    Quit ..Act("classmethod", {"class": (pClass), "method": (pMethod), "args": (pArgs)}, .pStatus, .pAnswer)
}

/// <p>The code of the envelope <var>pAnswer</var>, or <code>""</code>.</p>
ClassMethod CodeOf(pAnswer) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>How many <code>SecurityChange</code> rows since the test began name a run of <var>pConsole</var> (<code>command</code> or
/// <code>classmethod</code>), or of either when none is named.</p>
Method Rows(pConsole As %String = "") As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(..Since, "SecurityChange", """verb"":""run""", .tData, """console"":""" _ pConsole)
}

/// <p>Matrix, Switched off: with the key at its shipped <code>false</code> a Run of either console is 403 with the console's own
/// code and published sentence, before the hold and the fresh read: the port is never asked, no body is recorded and no row is
/// written. The key stored on lets the same Run through.</p>
/// <p>Mutation (Rule 19): remove the <code>PERSONGATE</code> ask from <method>OcuPilot.Api.ScreenAction.Run</method> -- the
/// recorder records a call and this goes red.</p>
Method TestSwitchedOffRefusesBeforeTheHoldTheReadAndTheRun()
{
    For tRow = "command|EXPLORER.COMMAND.OFF|" _ ##class(OcuPilot.Api.AtelierError).#REASONCOMMANDOFF, "classmethod|EXPLORER.CLASSMETHOD.OFF|" _ ##class(OcuPilot.Api.AtelierError).#REASONCLASSMETHODOFF {
        Set tConsole = $Piece(tRow, "|", 1)
        Do $ClassMethod(..#FIXTURE, "Clear")
        Do $ClassMethod(..#RECORDER, "SetAnswer", {"output": "x", "truncated": false, "error": ""}.%ToJSON())
        If tConsole = "command" {
            Do $$$AssertStatusOK(..ActCommand("W ""ok""", .tStatus, .tAnswer), tConsole _ ": the route answers")
        } Else {
            Do $$$AssertStatusOK(..ActMethod(..#ECHO, "Echo", "[""hi""]", .tStatus, .tAnswer), tConsole _ ": the route answers")
        }
        Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tAnswer), "403|" _ $Piece(tRow, "|", 2), tConsole _ ": refused as switched off")
        Do $$$AssertTrue($IsObject(tAnswer), tConsole _ ": the refusal is an envelope")
        If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.reason, $Piece(tRow, "|", 3), tConsole _ ": with the published sentence")
        Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls") _ "|" _ $ClassMethod(..#FIXTURE, "Invokes") _ "|" _ ..Rows(tConsole), "0|0|0", tConsole _ ": no read, no body call and no row")
        Do ..EnableKey(tConsole)
        If tConsole = "command" {
            Do $$$AssertStatusOK(..ActCommand("W ""ok""", .tOnStatus, .tOnAnswer), tConsole _ ": the route answers with the key on")
        } Else {
            Do $$$AssertStatusOK(..ActMethod(..#ECHO, "Echo", "[""hi""]", .tOnStatus, .tOnAnswer), tConsole _ ": the route answers with the key on")
        }
        Do $$$AssertEquals(tOnStatus _ "|" _ ..Rows(tConsole), "200|1", tConsole _ ": and the same Run goes through, writing its one row")
    }
}

/// <p>Matrix, Command and Class method, with the key on: one Run is one body call to <code>ConsoleRun.Command</code> or
/// <code>ConsoleRun.ClassMethod</code> carrying the port's keys alone, in the namespace the screen is scoped to, under the pairs
/// of the gate and the namespace including WRITE; the answer is what the body gave, on the screen only.</p>
/// <p>Mutation (Rule 19): send the screen's values nowhere in <method>OcuPilot.Screen.Tool.ExplorerCommandRun.PortQuery</method>
/// -- the recorded query goes red.</p>
Method TestARunWithTheKeyOnIsOneBodyCallWithThePortsKeysOnly()
{
    Do ..EnableKey("command")
    Do ..EnableKey("classmethod")
    Do $ClassMethod(..#RECORDER, "SetAnswer", {"output": "ok", "truncated": false, "error": ""}.%ToJSON())
    Do $$$AssertStatusOK(..ActCommand("W ""ok""", .tStatus, .tAnswer), "the command route answers")
    Do $$$AssertEquals(tStatus, 200, "the command Run is applied")
    Do $$$AssertTrue($IsObject(tAnswer), "the command answer is JSON")
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.output.%ToJSON(), "{""output"":""ok"",""truncated"":false,""error"":""""}", "and answers the output the body gave")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls"), 1, "one body call")
    Set tCall = $ClassMethod(..#RECORDER, "CallAt", 1)
    Do $$$AssertEquals(tCall.handler _ "." _ tCall.method, "OcuPilot.Port.Harvest.ConsoleRun.Command", "it is the command body")
    Do $$$AssertEquals(tCall.query.%ToJSON(), "{""command"":""W \""ok\"""",""namespace"":""USER""}", "carrying the port's two keys alone")
    Do $$$AssertTrue(tCall.pairs [ "%Development:USE", "under the screen's pair")
    Do $$$AssertTrue(tCall.pairs [ "WRITE", "and WRITE on the routines database")
    Do $ClassMethod(..#RECORDER, "Clear")
    Do $ClassMethod(..#RECORDER, "SetAnswer", {"returnValue": "2", "argCount": 1, "byRefValues": {}, "output": "hi", "truncated": true, "byRefTruncated": true, "returnValueTruncated": true, "error": ""}.%ToJSON())
    Do $$$AssertStatusOK(..ActMethod(..#ECHO, "Echo", "[""hi""]", .tMethodStatus, .tMethodAnswer), "the class method route answers")
    Do $$$AssertEquals(tMethodStatus, 200, "the class method Run is applied")
    Do $$$AssertTrue($IsObject(tMethodAnswer), "the class method answer is JSON")
    If $IsObject(tMethodAnswer) Do $$$AssertEquals(tMethodAnswer.output.returnValue _ "|" _ tMethodAnswer.output.output _ "|" _ tMethodAnswer.output.argCount, "2|hi|1", "and answers the return value, the output and the count the body gave")
    If $IsObject(tMethodAnswer) Do $$$AssertEquals(tMethodAnswer.output.truncated _ "|" _ tMethodAnswer.output.byRefTruncated _ "|" _ tMethodAnswer.output.returnValueTruncated, "1|1|1", "and each cut flag the body gave")
    Set tMethodCall = $ClassMethod(..#RECORDER, "CallAt", 1)
    Do $$$AssertEquals(tMethodCall.handler _ "." _ tMethodCall.method, "OcuPilot.Port.Harvest.ConsoleRun.ClassMethod", "it is the class method body")
    Do $$$AssertEquals(tMethodCall.query.%ToJSON(), "{""args"":""[\""hi\""]"",""class"":""OcuProbe246.Echo"",""method"":""Echo"",""namespace"":""USER""}", "carrying the port's four keys alone")
    Do $$$AssertEquals(..Rows("command") _ "|" _ ..Rows("classmethod"), "1|1", "and each Run wrote its one row, the port's own, whatever the body is")
}

/// <p>A run whose harvest call faults is answered 500 and still writes its row, for either console: the row is written before the
/// body is entered, so code that ends its own process or breaks the port's answer is recorded all the same.</p>
/// <p>Mutation (Rule 19): move the <code>AuditRun</code> calls below the harvest status check in
/// <method>OcuPilot.Port.DevToolPort.RunConsole</method> -- the row count goes red.</p>
Method TestARunWhoseBodyFaultedStillWritesItsRow()
{
    Do ..EnableKey("command")
    Do ..EnableKey("classmethod")
    Do $ClassMethod(..#RECORDER, "SetFault")
    Do $$$AssertStatusOK(..ActCommand("W ""ok""", .tStatus, .tAnswer), "the command route answers")
    Do $$$AssertEquals(tStatus, 500, "a command whose body faulted is 500")
    Do $$$AssertStatusOK(..ActMethod(..#ECHO, "Echo", "[""hi""]", .tMethodStatus, .tMethodAnswer), "the class method route answers")
    Do $$$AssertEquals(tMethodStatus, 500, "a class method whose body faulted is 500")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls") _ "|" _ ..Rows("command") _ "|" _ ..Rows("classmethod"), "2|1|1", "both bodies were asked for, and each run wrote its row")
}

/// <p>The matrix's refusals through the route, each with both keys on: its status and code, no body call and no row. Every
/// refusal is unlogged. A blank command is three spaces, since the route admits only a non-empty value.</p>
/// <p>Mutation (Rule 19): make the <code>ocupilot</code> screen unreachable in <method>OcuPilot.Port.DevToolPort.Console</method>
/// -- the own-code rows go red.</p>
Method TestEveryRefusalRowAnswersItsStatusAndCodeAndRecordsNoCall()
{
    Do ..EnableKey("command")
    Do ..EnableKey("classmethod")
    Do $ClassMethod(..#RECORDER, "SetAnswer", {"output": "x", "truncated": false, "error": ""}.%ToJSON())
    Set tLong = $Translate($Justify("", 30001), " ", "x")
    For tCommand = "   ", tLong, "W 1" _ $Char(9) _ "W 2", "W ""OCUPILOT""", "Do ##class(ocupilot.Kernel.Utils).X()", "Set x = ""Ocupilot""" {
        Do $$$AssertStatusOK(..ActCommand(tCommand, .tStatus, .tAnswer), $Extract(tCommand, 1, 20) _ ": the route answers")
        Set tOwn = $ZConvert(tCommand, "L") [ "ocupilot"
        Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tAnswer), $Select(tOwn: "400|EXPLORER.COMMAND.OWNCODE", 1: "400|PORT.VALIDATION"), "command " _ $Extract(tCommand, 1, 20) _ ": its status and code")
    }
    For tRow = "a..b|Echo|[]|400|PORT.VALIDATION", "OcuProbe246.Echo|1x|[]|400|PORT.VALIDATION", "OcuProbe246.Echo|Echo|{}|400|PORT.VALIDATION", "OcuProbe246.Echo|Echo|not json|400|PORT.VALIDATION", "OcuProbe246.Echo|Echo|[null]|400|PORT.VALIDATION", "OcuProbe246.Echo|Echo|[[1]]|400|PORT.VALIDATION", "OcuProbe246.Echo|Echo|[{""byRef"":false}]|400|PORT.VALIDATION", "OcuProbe246.Echo|Echo|[{""byRef"":""yes"",""value"":1}]|400|PORT.VALIDATION", "OcuProbe246.Echo|Echo|[{""byRef"":true,""value"":null}]|400|PORT.VALIDATION", "OcuProbe246.Echo|Echo|[{""byRef"":true,""value"":{""a"":1}}]|400|PORT.VALIDATION", "OcuProbe246.Echo|Echo|[{""byRef"":true,""value"":[1]}]|400|PORT.VALIDATION", "OcuProbe246.Echo|Echo|[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21]|400|PORT.VALIDATION", "OcuPilot.Test.Prohibited|Run|[]|400|EXPLORER.CLASSMETHOD.OWNCODE", "OCUPILOT.Kernel.Utils|Run|[]|400|EXPLORER.CLASSMETHOD.OWNCODE", "OcuProbe246.Nope|Echo|[]|404|EXPLORER.CLASSMETHOD.NOTFOUND", "OcuProbe246.Echo|Nope|[]|404|EXPLORER.CLASSMETHOD.NOTFOUND", "OcuProbe246.Echo|Instance|[]|404|EXPLORER.CLASSMETHOD.NOTFOUND", "OcuProbe246.Echo|Hidden|[]|404|EXPLORER.CLASSMETHOD.NOTFOUND" {
        Do $$$AssertStatusOK(..ActMethod($Piece(tRow, "|", 1), $Piece(tRow, "|", 2), $Piece(tRow, "|", 3), .tMethodStatus, .tMethodAnswer), $Piece(tRow, "|", 1) _ "." _ $Piece(tRow, "|", 2) _ ": the route answers")
        Do $$$AssertEquals(tMethodStatus _ "|" _ ..CodeOf(tMethodAnswer), $Piece(tRow, "|", 4) _ "|" _ $Piece(tRow, "|", 5), $Piece(tRow, "|", 1) _ "." _ $Piece(tRow, "|", 2) _ " " _ $Piece(tRow, "|", 3) _ ": its status and code")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls") _ "|" _ ..Rows() _ "|" _ $ClassMethod(..#FIXTURE, "LogCount"), "0|0|0", "no body call, no row, and none of the refusals logged")
    Do $$$AssertStatusOK(..ActCommand($Translate($Justify("", 30000), " ", "x"), .tLongStatus, .tLongAnswer), "a command of exactly 30,000 characters is sent")
    Do $$$AssertEquals(tLongStatus _ "|" _ $ClassMethod(..#RECORDER, "Calls"), "200|1", "and passes the shape check to its body")
}

/// <p>Matrix, Gate: a caller without <code>%Development:USE</code>, or with it but without WRITE on the routines database, is
/// 403 <code>AUTH.NOPRIVILEGE</code> naming the failed pair, before any body, for each console endpoint.</p>
/// <p>Mutation (Rule 19): ask <method>OcuPilot.Port.AtelierPort.NamespacePairs</method> instead of <code>WritePairs</code> in
/// <method>OcuPilot.Port.DevToolPort.Console</method> -- the WRITE leg goes red.</p>
Method TestACallerShortOfAPairIsRefusedByName()
{
    Do $ClassMethod(..#FIXTURE, "SetGateClass", "OcuPilot.Test.ScreenGate")
    For tEndpoint = "Command", "ClassMethod" {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        If tEndpoint = "Command" {
            Set tQuery("command") = "W 1"
        } Else {
            Set tQuery("class") = ..#ECHO
            Set tQuery("method") = "Echo"
            Set tQuery("args") = "[]"
        }
        Do $$$AssertStatusNotOK($ClassMethod(..#FIXTURE, "Invoke", tEndpoint, "RUN", .tQuery, "", .tResult, .tHttp, .tFault), tEndpoint _ ": a caller holding nothing is refused")
        Do $$$AssertEquals(tHttp _ "|" _ tFault.code _ "|" _ tFault.detail.failedPair, "403|AUTH.NOPRIVILEGE|%Development:USE", tEndpoint _ ": naming %Development:USE")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
        Set tPairs = ##class(OcuPilot.Port.AtelierPort).NamespacePairs(..#NAMESPACE)
        For tI = 1:1:$ListLength(tPairs) Do ##class(OcuPilot.Test.ScreenGate).Hold($List($List(tPairs, tI), 1), $List($List(tPairs, tI), 2))
        Set tWritePairs = ##class(OcuPilot.Port.AtelierPort).WritePairs(..#NAMESPACE)
        Set tWritePair = $List(tWritePairs, $ListLength(tWritePairs))
        Do $$$AssertStatusNotOK($ClassMethod(..#FIXTURE, "Invoke", tEndpoint, "RUN", .tQuery, "", .tResult2, .tHttp2, .tFault2), tEndpoint _ ": a caller short of WRITE is refused")
        Do $$$AssertEquals(tHttp2 _ "|" _ tFault2.code _ "|" _ tFault2.detail.failedPair, "403|AUTH.NOPRIVILEGE|" _ $List(tWritePair, 1) _ ":" _ $List(tWritePair, 2), tEndpoint _ ": naming WRITE on the routines database")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls") _ "|" _ ..Rows(), "0|0", "no body call and no row")
}

/// <p>The read the route makes before a write answers the console's own fields: the command echoed for the command console, and
/// the class, the method, the list as sent and its length for the class method console; a request type other than the two is 501.</p>
Method TestTheReadEchoesWhatTheRunWouldRun()
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("command") = "W 1"
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Invoke", "Command", "STATE", .tQuery, "", .tState, .tHttp, .tFault), "the command read answers")
    Do $$$AssertEquals($Select($IsObject($Get(tState)): tState.%ToJSON(), 1: ""), "{""Namespace"":""USER"",""Command"":""W 1""}", "the namespace and the command")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("class") = ..#ECHO
    Set tQuery("method") = "Echo"
    Set tQuery("args") = "[""a"",{""byRef"":true}]"
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Invoke", "ClassMethod", "STATE", .tQuery, "", .tMethodState, .tHttp2, .tFault2), "the class method read answers")
    Do $$$AssertEquals($Select($IsObject($Get(tMethodState)): tMethodState.%ToJSON(), 1: ""), "{""Namespace"":""USER"",""Class"":""OcuProbe246.Echo"",""Method"":""Echo"",""Arguments"":""[\""a\"",{\""byRef\"":true}]"",""ArgumentCount"":2}", "the namespace, the class, the method, the list and its length")
    Do $$$AssertStatusNotOK($ClassMethod(..#FIXTURE, "Invoke", "Command", "LIST", .tQuery, "", .tOther, .tHttp3, .tFault3), "another request type is refused")
    Do $$$AssertEquals(tHttp3, 501, "501")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls"), 0, "and no read asks a body")
}

}
