/// <p>Pins Story 21.20's Transactions screen (AC3; AD-5, AD-29, AD-36): its declaration; its read over transaction rows a
/// fixture supplies (<class>OcuPilot.Test.MonitorPortFixture</class>), local then remote and in the monitor's order, each
/// with the status the classic page maps; the 409 <code>MONITOR.NOTRUNNING</code> answer with its sentence while the System
/// Monitor is not running; a caller missing a pair refused naming it before any node is read; and the live read, which
/// equals the monitor's own global at that read, for the screen's read and the read tool alike; and the port's real node
/// reader over rows written under node names of its own; and a transaction a job of its own holds open, read through the
/// shipped node names once the System Monitor records it.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries and a <code>USER</code> namespace. Live-safe: it writes
/// process-private globals, two <code>^IRIS.Temp.SysMetrics</code> nodes named for it, which it kills after each test, and one
/// node in <code>USER</code> inside a transaction its job rolls back.</p>
Class OcuPilot.Test.TransactionsRead Extends %UnitTest.TestCase
{

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.TransactionList";

Parameter FIXTURE = "OcuPilot.Test.Read.ReadFixture";

Parameter PORT = "OcuPilot.Port.MonitorPort";

Parameter PORTFIXTURE = "OcuPilot.Test.MonitorPortFixture";

Parameter NODEPROBE = "OcuPilot.Test.TransactionsNodeProbe";

Parameter TOOLFIXTURE = "OcuPilot.Test.Read.ToolFixture";

/// <p>The namespace the held transaction's journaled set is made in, and the seconds the job holds it at most.</p>
Parameter HOLDNAMESPACE = "USER";

Parameter HOLDSECONDS As INTEGER = 300;

/// <p>The seconds the open-transaction leg waits for the System Monitor to record the transaction (about 43 measured).</p>
Parameter WAITSECONDS As INTEGER = 150;

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORTFIXTURE, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORTFIXTURE, "Clear")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Kill ^IRIS.Temp.SysMetrics($Parameter(..#NODEPROBE, "TRANSACTIONSNODE")), ^IRIS.Temp.SysMetrics($Parameter(..#NODEPROBE, "REMOTETRANSACTIONSNODE"))
    ; Release every holding job this class started; each rolls its transaction back and ends.
    Set tPid = ""
    For {
        Set tPid = $Order(^IRIS.Temp.OcuPilotTransactionsHold(tPid))
        If tPid = "" Quit
        Set ^IRIS.Temp.OcuPilotTransactionsHold(tPid) = "release"
        Set tEnd = $ZHorolog + 10
        While $Data(^$JOB(tPid)) && ($ZHorolog < tEnd) {
            Hang 0.5
        }
        Do $$$AssertTrue('$Data(^$JOB(tPid)), "the holding job " _ tPid _ " has ended")
        Kill ^IRIS.Temp.OcuPilotTransactionsHold(tPid)
    }
    Quit $$$OK
}

/// <p>The rows <var>pRows</var> as one text, <code>Kind|ProcessID|Seconds|Status|Remote</code> a line each.</p>
ClassMethod RowsText(pRows As %DynamicArray) As %String
{
    Set tText = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: $Char(10)) _ tRow.%Get("Kind") _ "|" _ tRow.%Get("ProcessID") _ "|" _ tRow.%Get("Seconds") _ "|" _ tRow.%Get("Status") _ "|" _ tRow.%Get("Remote")
    }
    Quit tText
}

/// <p>The screen's declaration: OS management's Transactions list, instance-scoped with no id, read through the monitor
/// port's own pairs, never refreshing, with no action, the classic page named, and a Process ID that opens Process details
/// unless the row is remote.</p>
/// <p>Mutation (Rule 19): drop <code>"unless": "Remote"</code> from the descriptor -- the row-target leg goes red.</p>
Method TestTheDescriptorShape()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration reads")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.toolIdentifier, "os-management/transactions|os-management|list|instance||osmgmt.transactions", "an instance-scoped list with no entity type")
    Do $$$AssertEquals(tDeclaration.id.%ToJSON(), "{""kind"":""none"",""parts"":[]}", "its id is none")
    Do $$$AssertEquals(##class(OcuPilot.Test.SqlActivityDescriptor).Spelled($ClassMethod(..#DESCRIPTOR, "PrivilegePairs")), $Parameter(..#PORT, "PAIRS"), "its pairs are the port's, in order")
    Do $$$AssertEquals(tDeclaration.refreshes _ "|" _ tDeclaration.primaryAction.id _ "|" _ tDeclaration.rowActions.%Size(), "0||0", "it never refreshes and declares no action")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""monitor"",""endpoint"":""Transactions"",""type"":""LIST""}", "its read names the monitor port's Transactions list")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Kind"",""ProcessID"",""Seconds"",""Status"",""Remote""]", "and the row's fields")
    Do $$$AssertEquals(tDeclaration.classicPage, "%CSP.UI.Portal.Transactions", "the classic page is named")
    Do $$$AssertEquals(tDeclaration.rowTarget.%ToJSON(), "{""route"":""os-management/processes/details"",""field"":""ProcessID"",""unless"":""Remote""}", "a Process ID opens Process details unless the row is remote")
    Do $$$AssertEquals(tDeclaration.table.columns.%Get(0).field _ ":" _ tDeclaration.table.columns.%Get(0).kind, "ProcessID:name", "and the Process ID is the name cell")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "three suggested prompts")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read passes the registry")
}

/// <p>The screen's read answers the monitor's local rows then its remote rows, each <code>{Kind, ProcessID, Seconds, Status,
/// Remote}</code>, with the status each kind's node maps to (<code>OK</code> reads Normal, <code>Warning</code> Warning, any other
/// value Troubled); a cap of two keeps the first two rows and reports the cut.</p>
/// <p>Mutation (Rule 19): swap <code>Local</code> and <code>Remote</code> in the kind loop of
/// <method>OcuPilot.Port.MonitorPort.Transactions</method> -- the order leg goes red.</p>
Method TestTheReadAnswersLocalThenRemoteWithTheMappedStatus()
{
    Do $ClassMethod(..#PORTFIXTURE, "SetRunning", 1)
    Do $ClassMethod(..#PORTFIXTURE, "SetNodes", "Local", "OK", "[{""ProcessID"":""4101"",""Seconds"":42},{""ProcessID"":""4102"",""Seconds"":7}]")
    Do $ClassMethod(..#PORTFIXTURE, "SetNodes", "Remote", "Warning", "[{""ProcessID"":""node-b:77"",""Seconds"":9}]")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(..RowsText(tAnswer.rows), $ListToString($ListBuild("Local|4101|42|Normal|0", "Local|4102|7|Normal|0", "Remote|node-b:77|9|Warning|1"), $Char(10)), "the rows are the monitor's, local then remote, each with its kind's status")
    Do $ClassMethod(..#PORTFIXTURE, "SetNodes", "Local", "Failing", "[{""ProcessID"":""4101"",""Seconds"":42}]")
    Do $ClassMethod(..#PORTFIXTURE, "SetNodes", "Remote", "OK", "[]")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tTroubled, .tHttp, .tFault)
    Do $$$AssertEquals(..RowsText(tTroubled.rows), "Local|4101|42|Troubled|0", "any other node value reads Troubled, and a kind with no row adds none")
    Do $ClassMethod(..#PORTFIXTURE, "SetNodes", "Local", "OK", "[{""ProcessID"":""4101"",""Seconds"":42},{""ProcessID"":""4102"",""Seconds"":7}]")
    Do $ClassMethod(..#PORTFIXTURE, "SetNodes", "Remote", "OK", "[{""ProcessID"":""node-b:77"",""Seconds"":9}]")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, 2, .tCut, .tHttp, .tFault)
    Do $$$AssertEquals(tCut.rows.%Size() _ "|" _ tCut.truncated, "2|1", "a cap of two keeps two rows and reports the cut")
}

/// <p>While the System Monitor is not running the read answers 409 <code>MONITOR.NOTRUNNING</code> with its sentence and no
/// node is read.</p>
/// <p>Mutation (Rule 19): drop the <code>MonitorRunning</code> check in <method>OcuPilot.Port.MonitorPort.Transactions</method> -- this
/// goes red.</p>
Method TestTheMonitorOffAnswers409WithItsSentence()
{
    Do $ClassMethod(..#PORTFIXTURE, "SetRunning", 0)
    Do $ClassMethod(..#PORTFIXTURE, "SetNodes", "Local", "OK", "[{""ProcessID"":""4101"",""Seconds"":42}]")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the read fails")
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409|MONITOR.NOTRUNNING", "409 MONITOR.NOTRUNNING")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), $Parameter("OcuPilot.Api.MonitorError", "REASONNOTRUNNING"), "with its sentence")
}

/// <p>A caller missing a pair is refused 403 naming it, before any node is read.</p>
/// <p>Mutation (Rule 19): skip the gate in <method>OcuPilot.Port.MonitorPort.Invoke</method> for the Transactions endpoint -- this goes
/// red.</p>
Method TestAMissingPairIsRefusedByName()
{
    Do $ClassMethod(..#PORTFIXTURE, "SetRunning", 1)
    Do $ClassMethod(..#PORTFIXTURE, "SetNodes", "Local", "OK", "[{""ProcessID"":""4101"",""Seconds"":42}]")
    Do $ClassMethod(..#PORTFIXTURE, "SetGateClass", "OcuPilot.Test.ScreenGate")
    For tCase = $ListBuild("%DB_IRISSYS", "READ", "%Admin_Operate:USE"), $ListBuild("%Admin_Operate", "USE", "%DB_IRISSYS:READ") {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tCase, 1), $List(tCase, 2))
        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tDenied, .tHttp, .tFault)
        Set tPair = ""
        If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set tPair = tFault.detail.failedPair
        Do $$$AssertEquals(tHttp _ " " _ tPair, "403 " _ $List(tCase, 3), "holding only " _ $List(tCase, 1) _ ": 403 naming the pair that failed")
    }
}

/// <p>The live read equals the monitor's global at that read, for the screen's read and the read tool alike: while the System
/// Monitor runs, both answer the rows the nodes hold, local then remote; otherwise both answer 409.</p>
/// <p>Mutation (Rule 19): answer the screen's rows from the wrong node in
/// <method>OcuPilot.Port.MonitorPort.Transactions</method> -- a held transaction's row goes red. With no transaction open the
/// leg compares nothing to nothing; the real node reader is pinned over rows of its own by
/// <method>TestTheRealNodeReaderReadsTheRowsTheGlobalHolds</method>.</p>
Method TestTheLiveReadEqualsTheMonitorsGlobal()
{
    Set tRunning = $ClassMethod(..#PORT, "MonitorRunning")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, "", .tScreen, .tHttp, .tFault)
    If 'tRunning {
        Do $$$AssertEquals($Get(tHttp), 409, "with the System Monitor off the screen's read is 409")
        Quit
    }
    Do $$$AssertEquals($Get(tHttp), 200, "the screen's read answers")
    Set tExpected = ""
    For tPair = $ListBuild("Local", "Transactions"), $ListBuild("Remote", "ECPTransactions") {
        Set tRow = ""
        For {
            Set tRow = $Order(^IRIS.Temp.SysMetrics($List(tPair, 2), tRow))
            If tRow = "" Quit
            Set tNodeStatus = $Case($Get(^IRIS.Temp.SysMetrics($List(tPair, 2))), "OK": "Normal", "Warning": "Warning", : "Troubled")
            Set tExpected = tExpected _ $Select(tExpected = "": "", 1: $Char(10)) _ $List(tPair, 1) _ "|" _ $Get(^IRIS.Temp.SysMetrics($List(tPair, 2), tRow, "pid")) _ "|" _ +$Get(^IRIS.Temp.SysMetrics($List(tPair, 2), tRow, "secs")) _ "|" _ tNodeStatus _ "|" _ ($List(tPair, 1) = "Remote")
        }
    }
    If '$IsObject($Get(tScreen)) Quit
    Do $$$AssertEquals(..RowsText(tScreen.rows), tExpected, "the screen's rows are the global's")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.transactions.read", .tTool, 1)
    Do $$$AssertStatusOK(tSC, "the read tool resolves")
    If '$IsObject($Get(tTool)) Quit
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 200, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertEquals($Get(tToolHttp), 200, "the read tool answers")
    If $IsObject($Get(tResult)) Do $$$AssertEquals(tResult.rows.%Size(), tScreen.rows.%Size(), "with as many rows as the screen")
}

/// <p>The port's real node reader and monitor check, over the rows a test writes under node names of its own
/// (<class>OcuPilot.Test.TransactionsNodeProbe</class>): each kind answers its node's value and its rows' <code>pid</code>
/// and <code>secs</code> in subscript order, and the whole read maps them to the classic page's statuses.</p>
/// <p>Mutation (Rule 19): read <code>secs</code> in place of <code>pid</code> for the process id in
/// <method>OcuPilot.Port.MonitorPort.TransactionNodes</method> -- the node leg goes red.</p>
Method TestTheRealNodeReaderReadsTheRowsTheGlobalHolds()
{
    Set tLocal = $Parameter(..#NODEPROBE, "TRANSACTIONSNODE")
    Set tRemote = $Parameter(..#NODEPROBE, "REMOTETRANSACTIONSNODE")
    Kill ^IRIS.Temp.SysMetrics(tLocal), ^IRIS.Temp.SysMetrics(tRemote)
    Set ^IRIS.Temp.SysMetrics(tLocal) = "OK"
    Set ^IRIS.Temp.SysMetrics(tLocal, 1, "pid") = 4101
    Set ^IRIS.Temp.SysMetrics(tLocal, 1, "secs") = 42
    Set ^IRIS.Temp.SysMetrics(tLocal, 2, "pid") = 4102
    Set ^IRIS.Temp.SysMetrics(tLocal, 2, "secs") = 7
    Set ^IRIS.Temp.SysMetrics(tRemote) = "Warning"
    Set ^IRIS.Temp.SysMetrics(tRemote, 1, "pid") = "node-b:77"
    Set ^IRIS.Temp.SysMetrics(tRemote, 1, "secs") = 9
    Set tSC = $ClassMethod(..#NODEPROBE, "TransactionNodes", "Local", .tStatus, .tNodes)
    Do $$$AssertStatusOK(tSC, "the local node reads")
    Do $$$AssertEquals(tStatus _ "|" _ tNodes.%ToJSON(), "OK|[{""ProcessID"":""4101"",""Seconds"":42},{""ProcessID"":""4102"",""Seconds"":7}]", "its value and its rows, in subscript order")
    Set tSC = $ClassMethod(..#NODEPROBE, "TransactionNodes", "Remote", .tRemoteStatus, .tRemoteNodes)
    Do $$$AssertEquals(tRemoteStatus _ "|" _ tRemoteNodes.%ToJSON(), "Warning|[{""ProcessID"":""node-b:77"",""Seconds"":9}]", "the remote node reads its own value and rows")
    Set tSC = $ClassMethod(..#NODEPROBE, "TransactionNodes", "Other", .tOtherStatus, .tOtherNodes)
    Do $$$AssertStatusNotOK(tSC, "a kind that is neither is refused")
    Kill tQuery
    Set tSC = $ClassMethod(..#NODEPROBE, "Invoke", "Transactions", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $ClassMethod(..#PORT, "MonitorRunning") {
        Do $$$AssertEquals(tHttp, 200, "while the System Monitor runs the whole read answers")
        If $IsObject($Get(tRows)) Do $$$AssertEquals(..RowsText(tRows), $ListToString($ListBuild("Local|4101|42|Normal|0", "Local|4102|7|Normal|0", "Remote|node-b:77|9|Warning|1"), $Char(10)), "the rows the nodes hold, local then remote, each with its node's status")
    } Else {
        Do $$$AssertEquals(tHttp, 409, "while the System Monitor is off the whole read is 409")
    }
}

/// <p>The real monitor check is the vendor's own status read in <code>%SYS</code>, and the caller's namespace is
/// restored.</p>
/// <p>Mutation (Rule 19): invert the comparison with <code>OK</code> in <method>OcuPilot.Port.MonitorPort.MonitorRunning</method> --
/// this goes red.</p>
Method TestTheRealMonitorCheckIsTheVendorsStatus()
{
    Set tOrigNS = $NAMESPACE
    Set tGot = $ClassMethod(..#PORT, "MonitorRunning")
    Do $$$AssertEquals($NAMESPACE, tOrigNS, "the caller's namespace is restored")
    Set $NAMESPACE = "%SYS"
    Set tStatus = $ClassMethod("SYS.Metrics", "SystemMonitorStatus")
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(tGot, ''(tStatus = "OK"), "it is whether the vendor's status reads OK: " _ tStatus)
}

/// <p>The codes this screen's port answers carry their sentences through the tool-result resolver, and the read tool with the
/// System Monitor off answers 409 <code>MONITOR.NOTRUNNING</code> with that sentence.</p>
/// <p>Mutation (Rule 19): drop the <code>MONITOR.</code> branch from <method>OcuPilot.Api.Error.ReasonForToolCode</method> -- both
/// legs go red.</p>
Method TestTheMonitorOffReadToolAnswersItsSentence()
{
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(##class(OcuPilot.Api.MonitorError).#NOTRUNNING), ##class(OcuPilot.Api.MonitorError).#REASONNOTRUNNING, "the code's sentence reaches the tool-result resolver")
    Do $ClassMethod(..#PORTFIXTURE, "SetRunning", 0)
    Set tSC = $ClassMethod(..#TOOLFIXTURE, "View", ..#DESCRIPTOR, {}, 200, .tView, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409|MONITOR.NOTRUNNING", "the read tool answers 409 MONITOR.NOTRUNNING while the monitor is off")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): ##class(OcuPilot.Api.Error).ReasonForToolCode(tFault.code), 1: ""), ##class(OcuPilot.Api.MonitorError).#REASONNOTRUNNING, "and its code resolves to the published sentence")
}

/// <p>The port's request types: a read has no script form.</p>
Method TestTheScriptForms()
{
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Transactions", "LIST"), "", "no script form for the Transactions read")
}

/// <p>A transaction a job of the test holds open, with one journaled set, reaches the shipped port through the monitor's own
/// nodes: the screen's read lists it as a Local row of that job's process id once the System Monitor records it. While the
/// System Monitor is not running the read answers 409 instead.</p>
/// <p>Mutation (Rule 19): <code>TRANSACTIONSNODE</code> <code>"Transaction"</code> in <class>OcuPilot.Port.MonitorPort</class> -- the held
/// transaction's row never appears and this goes red.</p>
Method TestAnOpenTransactionIsReadThroughTheShippedNodes()
{
    If '$ClassMethod(..#PORT, "MonitorRunning") {
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, "", .tScreen, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp), 409, "with the System Monitor off the screen's read is 409")
        Quit
    }
    Job ##class(OcuPilot.Test.TransactionsRead).HoldTransaction(..#HOLDNAMESPACE, ..#HOLDSECONDS)::10
    Set tStarted = $Test
    Do $$$AssertTrue(tStarted, "a job holding an open transaction started")
    If 'tStarted Quit
    Set tPid = $ZChild
    Set ^IRIS.Temp.OcuPilotTransactionsHold(tPid) = ""
    Set tRow = ""
    Set tDeadline = $ZHorolog + ..#WAITSECONDS
    While (tRow = "") && ($ZHorolog < tDeadline) {
        Hang 2
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, "", .tScreen, .tHttp, .tFault)
        If '$IsObject($Get(tScreen)) Continue
        Set tIterator = tScreen.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tCandidate) {
            If (tCandidate.%Get("Kind") = "Local") && (tCandidate.%Get("ProcessID") = tPid) Set tRow = tCandidate
        }
    }
    Do $$$AssertTrue($IsObject(tRow), "the held transaction's process " _ tPid _ " is listed as a Local row within " _ ..#WAITSECONDS _ " seconds")
    If $IsObject(tRow) Do $$$AssertTrue((tRow.%Get("Seconds") > 0) && (tRow.%Get("Remote") = 0) && (tRow.%Get("Status") '= ""), "with its seconds open, its status and no remote flag: " _ tRow.%ToJSON())
}

/// <p>The job <method>TestAnOpenTransactionIsReadThroughTheShippedNodes</method> starts: in <var>pNamespace</var>, open a transaction
/// and set one journaled node in it, hold it until <code>^IRIS.Temp.OcuPilotTransactionsHold</code> reads <code>release</code> for
/// this process or <var>pBound</var> seconds pass, then roll it back, so nothing it set is kept.</p>
ClassMethod HoldTransaction(pNamespace As %String, pBound As %Integer)
{
    Try {
        Set $NAMESPACE = pNamespace
        TSTART
        Set ^OcuP2120TransactionsHold($Job) = $ZTimeStamp
        Set tEnd = $ZHorolog + pBound
        While ($ZHorolog < tEnd) && ($Get(^IRIS.Temp.OcuPilotTransactionsHold($Job)) '= "release") {
            Hang 1
        }
    } Catch {
    }
    If $TLevel > 0 TROLLBACK
}

}
