/// <p>Pins Story 21.29's three writes on both permitted callers (AC1, AC2, AC3, AC4; AD-4, AD-6, AD-7, AD-21, AD-51, AD-53, AD-58): a query saved for a support
/// case by the list's Save query and by the agent's confirmed proposal, each read back through the vendor's own table and the list; a saved query removed by
/// either, with every other row left; a case's report generated to a server file by both and to the screen, read back through <code>%XML.Reader</code> into
/// the vendor's class with every saved statement present; the refusals before any call (a case with no saved query, a refused root or name, a missing
/// directory); a save that ends in an error status leaves no row and the error reaches the caller; a proposal whose target is gone closed target-changed; the
/// instance's refusal answered 409; the null device and the caller's namespace restored after a raised call; and no action that mails anyone.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, which holds
/// <code>%Development:USE</code>, SELECT on the probe table and <code>%SQL_Manager_QButtons.Base</code>, and WRITE on <code>USER</code>'s routines database,
/// and a <code>USER</code> namespace. It makes <class>OcuPilot.Test.SqlTuningProbe</class>'s report objects and
/// <class>OcuPilot.Test.ExplorerTransferProbe</class>'s directory, and removes every saved query, cached query, table, report file and directory it made when
/// each test ends. It writes nothing beyond those, so it is not armed.</p>
Class OcuPilot.Test.SqlReportWrite Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter DIRECTORY = "OcuPilot.Test.ExplorerTransferProbe";

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter FIXTURE = "OcuPilot.Test.SqlTuningPortFixture";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter NAMESPACE = "USER";

Parameter SCREEN = "explorer.sqlreports";

Parameter LIST = "OcuPilot.Screen.Descriptor.ExplorerSqlReports";

Parameter SAVE = "OcuPilot.Screen.Tool.ExplorerSqlReportSave";

Parameter DELETE = "OcuPilot.Screen.Tool.ExplorerSqlReportDelete";

Parameter GENERATE = "OcuPilot.Screen.Tool.ExplorerSqlReportGenerate";

Parameter ERROR = "OcuPilot.Api.AtelierError";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter CASE = "2291";

Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPolicyTaken = 0
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Kill ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Kill tSettings
    For tTool = ..#SAVE, ..#DELETE, ..#GENERATE Set tSettings($Parameter(tTool, "TOOLNAME")) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeReport", ..#NAMESPACE), "the probe's table is created in " _ ..#NAMESPACE)
    Do $$$AssertStatusOK($ClassMethod(..#DIRECTORY, "MakeDirectory"), "the probe directory is made")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotSqlTuningLeaveRow, ^||OcuPilotDatabaseWritePort
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveReport", ..#NAMESPACE), "the probe's saved queries, cached queries and table are removed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ReportLeft", ..#NAMESPACE), 0, "and no saved query of the probe is left")
    Do $ClassMethod(..#DIRECTORY, "RemoveDirectory")
    Do $$$AssertEquals(##class(%File).DirectoryExists($ClassMethod(..#DIRECTORY, "Directory")), 0, "the probe directory and its report files are removed")
    If '..PreparedPolicyTaken Quit $$$OK
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>The screen action <var>pAction</var> on <var>pId</var> with the values <var>pValues</var>, through the shipped route in <code>USER</code>: the
/// answer's parsed envelope in <var>pAnswer</var>, answering the HTTP status.</p>
ClassMethod Act(pAction As %String, pValues As %DynamicObject = "", pId As %String = "*", Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": (pAction), "id": (pId)}
    If $IsObject(pValues) Do tBody.%Set("values", ..Typed(pValues))
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/" _ ..#SCREEN _ "/action?ns=" _ ..#NAMESPACE, .tStatus, .pAnswer, tBody.%ToJSON())
    Quit $Select($$$ISOK(tSC): tStatus, 1: 0)
}

/// <p>The agent's proposal of tool <var>pTool</var> on <var>pId</var> with the arguments <var>pArgs</var> and, when <var>pConfirm</var> is 1, its confirmation:
/// <code>mint &lt;http&gt; &lt;problem&gt;</code> when the mint refused, <code>minted</code> when it stopped there, else the confirm's <code>http code</code>.</p>
ClassMethod Agent(pTool As %String, pArgs As %DynamicObject, pId As %String = "*", pConfirm As %Boolean = 1, Output pProposal As %DynamicObject, Output pResult As %DynamicObject) As %String
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set ^||OcuPilotDatabaseWritePort = $Parameter(pTool, "PORTCLASS")
    Set pArgs = ..Typed(pArgs)
    Do pArgs.%Set($ClassMethod(pTool, "IdArgument"), pId, "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", pTool, pId, pArgs, .pProposal, .tHttp, .tProblem)
    If $$$ISERR(tSC) Quit "mint " _ tHttp _ " " _ tProblem
    If 'pConfirm Quit "minted"
    Quit $ClassMethod(..#AGENT, "Confirm", pProposal, .pResult)
}

/// <p>A copy of <var>pValues</var> whose every member is a string, as the screen sends them: a literal that reads as a number would otherwise be stored as one.</p>
ClassMethod Typed(pValues As %DynamicObject) As %DynamicObject
{
    Set tTyped = {}
    Set tIterator = pValues.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do tTyped.%Set(tKey, tValue, "string")
    }
    Quit tTyped
}

/// <p>The saved queries the vendor's table holds for the probe's case, as ids joined by <code>,</code>.</p>
ClassMethod Ids() As %String
{
    Quit $ListToString($ClassMethod(..#PROBE, "ReportIds", ..#NAMESPACE))
}

/// <p>One query saved for the probe's case through the vendor, as the calling process; the new row's id.</p>
ClassMethod Seed(pText As %String = {$Parameter("OcuPilot.Test.SqlTuningProbe", "REPORTQUERY")}) As %String
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tSC = ##class(%SQL.Manager.QButtons.Base).InsertQuery(pText, ..#CASE, 0, 0)
    Set $NAMESPACE = tOrigNS
    Set tIds = $ClassMethod(..#PROBE, "ReportIds", ..#NAMESPACE)
    Quit $Select($$$ISOK(tSC): $ListGet(tIds, $ListLength(tIds)), 1: "")
}

/// <p>The statements of the report in the file or text <var>pStream</var> holds, read back through <code>%XML.Reader</code> into the vendor's class
/// without saving, as the texts joined by <code>|</code> in order, and the row count as <var>pCount</var>.</p>
ClassMethod Statements(pStream As %Stream.Object, Output pCount As %Integer) As %String
{
    Set pCount = 0
    Set tText = ""
    Set tReader = ##class(%XML.Reader).%New()
    Set tSC = tReader.OpenStream(pStream)
    If $$$ISERR(tSC) Quit "(unreadable)"
    Do tReader.Correlate("QButton", "%SQL.Manager.QButtons.Base")
    While tReader.Next(.tObject, .tSC) {
        Set pCount = pCount + 1
        Set tText = tText _ $Select(tText = "": "", 1: "|") _ tObject.QueryStatement
    }
    Quit tText
}

/// <p>The report file <var>pName</var> under the probe directory as text.</p>
ClassMethod FileText(pName As %String) As %String
{
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Set tStream.TranslateTable = "UTF8"
    Set tSC = tStream.LinkToFile($ClassMethod(..#DIRECTORY, "Directory") _ pName)
    If $$$ISERR(tSC) Quit ""
    Quit tStream.Read(3000000)
}

/// <p>AC1. The list's Save query stores the statement under the case: the vendor's table holds one new row for it, the port's case read counts it, the list
/// answers it as <code>Planned</code>, and the agent's <code>explorer.sqlreports.read</code> answers the same row.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.ReportCall</code> saves a query with the case and the statement swapped -> the case assertion goes red.</p>
Method TestTheScreenSavesAQueryAndTheListAndTheAgentsReadAgree()
{
    Set tText = $Parameter(..#PROBE, "REPORTQUERY")
    Set tStatus = ..Act("save", {"Statement": (tText), "WRCNumber": (..#CASE)}, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type, 1: ""), "200|updated|sql-saved-query", "the screen's save answers: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tIds = ..Ids()
    Do $$$AssertEquals($Length(tIds, ",") _ "|" _ $ClassMethod(..#PROBE, "ReportStatement", ..#NAMESPACE, tIds), "1|" _ tText, "the instance holds one saved query for the case, with the statement as sent")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 1000, .tScreen, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals($Select($$$ISOK(tSC): tHttp, 1: 0), 200, "the screen's read answers")
    If $$$ISERR(tSC) || '$IsObject(tScreen) Quit
    Set tListed = ""
    Set tIterator = tScreen.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.ID = tIds Set tListed = tRow.WRCNumber _ "|" _ tRow.Status
    }
    Do $$$AssertEquals(tListed, ..#CASE _ "|Planned", "the list answers the new row, planned")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed turn is seeded")
    Set tUse = {"type": "tool_use", "id": "toolu_sqlreports"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.sqlreports.read"), "string")
    Do tUse.%Set("input", {"filter": "OcuProbe229", "maxRows": 1000})
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tSC, "the agent's read is dispatched")
    If $$$ISERR(tSC) Quit
    Set tAgent = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content"))
    Set tSame = 0
    Set tIterator = tAgent.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.ID = tIds Set tSame = (tRow.WRCNumber = ..#CASE) && (tRow.Status = "Planned")
    }
    Do $$$AssertEquals(tSame, 1, "the agent's read answers the same row")
}

/// <p>AC1. The agent's confirmed save stores the statement under the case, and its proposal carries the ruled consequence and the case's count moving by
/// one; the mint itself calls nothing.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.ExplorerSqlReportSave.StateDiff</code> moves the count by two -> the state assertion goes red.</p>
Method TestTheAgentSavesAQueryAndItsMintCallsNothing()
{
    Set tText = $Parameter(..#PROBE, "REPORTQUERY")
    Set tOutcome = ..Agent(..#SAVE, {"Statement": (tText), "WRCNumber": "2291"}, , 0, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ ..Ids(), "minted|", "the mint saves nothing")
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "EXPLORER.SQLREPORT.SAVE", "its consequence is the save's")
    Set tCard = tProposal.%ToJSON()
    Do $$$AssertTrue((tCard [ """Saved""") && (tCard [ """after"":""1"""), "its card moves the case's saved count from 0 to 1: " _ tCard)
    Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(+tConfirm, 200, "the confirm answers: " _ tConfirm)
    Set tIds = ..Ids()
    Do $$$AssertEquals($Length(tIds, ",") _ "|" _ $ClassMethod(..#PROBE, "ReportStatement", ..#NAMESPACE, tIds), "1|" _ tText, "the instance holds the saved query")
}

/// <p>AC1. A statement that is not a query, one over OcuPilot's own tables and a malformed case number are each refused before any vendor call on both
/// callers, with no row saved.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.ExplorerSqlReportSave.Holds</code> admits every kind -> the UPDATE legs go red.</p>
Method TestTheRefusalsCallNothingOnBothCallers()
{
    Set tUpdate = "UPDATE " _ $Parameter(..#PROBE, "REPORTTABLE") _ " SET B = 'x'"
    Set tOwn = "SELECT COUNT(*) AS Probe229 FROM OcuPilot_Kernel_State.Version"
    Set tStatus = ..Act("save", {"Statement": (tUpdate), "WRCNumber": "2291"}, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.detail): tAnswer.detail.problem, 1: ""), "400|" _ $Parameter(..#ERROR, "REASONSQLREPORTQUERYONLY"), "the screen refuses an UPDATE with the published sentence")
    Set tStatus = ..Act("save", {"Statement": (tOwn), "WRCNumber": "2291"}, , .tAnswer)
    Do $$$AssertEquals(tStatus, 403, "the screen refuses a query over OcuPilot's own tables")
    For tWrc = "", "abc", "0", "1234567890", "-5" {
        Set tStatus = ..Act("save", {"Statement": ($Parameter(..#PROBE, "REPORTQUERY")), "WRCNumber": (tWrc)})
        Do $$$AssertEquals(tStatus, 400, "the screen refuses the case number '" _ tWrc _ "'")
    }
    Set tOutcome = ..Agent(..#SAVE, {"Statement": (tUpdate), "WRCNumber": "2291"}, , 0)
    Do $$$AssertTrue(tOutcome [ $Parameter(..#ERROR, "REASONSQLREPORTQUERYONLY"), "the agent's mint refuses an UPDATE with the published sentence: " _ tOutcome)
    Set tOutcome = ..Agent(..#SAVE, {"Statement": (tOwn), "WRCNumber": "2291"}, , 0)
    Do $$$AssertTrue(tOutcome [ "mint 403", "the agent's mint refuses a query over OcuPilot's own tables: " _ tOutcome)
    Set tOutcome = ..Agent(..#SAVE, {"Statement": ($Parameter(..#PROBE, "REPORTQUERY")), "WRCNumber": "12ab"}, , 0)
    Do $$$AssertTrue(tOutcome [ $Parameter(..#ERROR, "SQLREPORTWRC"), "the agent's mint refuses a malformed case number: " _ tOutcome)
    Do $$$AssertEquals(..Ids() _ "|" _ $ClassMethod(..#PROBE, "ReportLeft", ..#NAMESPACE), "|0", "no row was saved")
}

/// <p>The 2026-11-27 ruling. A save the instance answers with an error status leaves no row, and the error reaches the caller: the vendor's own call is made,
/// leaves the row it saved before it failed (the seam stands in for the vendor's answer, a compile error after the row is written, and for a case number the
/// vendor stored and then raised on), and the port removes it by id before answering 409 <code>EXPLORER.SQLREPORT.VENDOR</code> with the message in
/// <code>detail</code> alone. A row of another case, and an earlier row of the same case, stay.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.ReportWrite</code> skips its clean-up of new rows -> both legs go red.</p>
Method TestASaveThatEndsInAnErrorStatusLeavesNoRowAndTheErrorReachesTheCaller()
{
    Set tKept = ..Seed()
    Do $$$AssertTrue(tKept '= "", "an earlier row of the case is saved: " _ tKept)
    For tCase = $ListBuild("compile", "Error compiling routine %sqlcq.USER.QButtons.WRC22911 : <UNDEFINED>probe"), $ListBuild("negative", "<INVALID OREF>QueryIntCodeCreate+5^%SYS.PTools") {
        Set ^||OcuPilotSqlTuningLeaveRow = $List(tCase, 2)
        Kill tQuery
        Set tQuery("WRCNumber") = ..#CASE
        Set tQuery("Statement") = $Parameter(..#PROBE, "REPORTQUERY") _ " ORDER BY A"
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = "*"
        Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "Reports", "SAVEQUERY", .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.reason, 1: ""), "409 " _ $Parameter(..#ERROR, "SQLREPORTVENDOR") _ "|" _ $Parameter(..#ERROR, "REASONSQLREPORTVENDOR"), $List(tCase, 1) _ ": 409 with the ruled sentence")
        Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.detail.message [ $List(tCase, 2)) && (tFault.reason '[ "UNDEFINED"), $List(tCase, 1) _ ": the instance's message is in detail alone")
        Do $$$AssertEquals(..Ids(), tKept, $List(tCase, 1) _ ": the row the failed call left is gone and the earlier row stays")
    }
    Kill ^||OcuPilotSqlTuningLeaveRow
}

/// <p>AC2. The list's Delete removes the one row it names, through the vendor's removal by id, and the agent's confirmed delete does the same: each read back
/// absent in the vendor's table, with the case's other rows untouched.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.ReportCall</code> clears another id -> the other-rows leg goes red.</p>
Method TestTheScreenAndTheAgentEachDeleteOneRowAndNoOther()
{
    Set tA = ..Seed()
    Set tB = ..Seed($Parameter(..#PROBE, "REPORTQUERY") _ " ORDER BY A")
    Set tC = ..Seed($Parameter(..#PROBE, "REPORTQUERY") _ " ORDER BY B")
    Do $$$AssertEquals(..Ids(), tA _ "," _ tB _ "," _ tC, "three rows are saved for the case")
    Set tStatus = ..Act("delete", , tA, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.action, 1: "") _ "|" _ ..Ids(), "200|deleted|" _ tB _ "," _ tC, "the screen's delete removes the one row: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tOutcome = ..Agent(..#DELETE, {}, tB, 0, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ ..Ids(), "minted|" _ tB _ "," _ tC, "the agent's mint removes nothing")
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "EXPLORER.SQLREPORT.DELETE", "its consequence is the delete's")
    Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(+tConfirm _ "|" _ ..Ids(), "200|" _ tC, "the confirm removes that row alone: " _ tConfirm)
    Set tStatus = ..Act("delete", , tA)
    Do $$$AssertEquals(tStatus, 404, "a row that is gone is refused at the read")
    Do $$$AssertEquals(..Ids(), tC, "and the remaining row is still there")
}

/// <p>AC2. A saved query gone after the proposal was minted closes the confirm target-changed, and the mint called nothing.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.ExplorerSqlReportDelete</code> drops <code>ID</code> from its fingerprint subject -> the confirm is
/// not refused and the assertion goes red.</p>
Method TestARowGoneAfterTheMintRefusesTheConfirm()
{
    Set tId = ..Seed()
    Set tOutcome = ..Agent(..#DELETE, {}, tId, 0, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ ..Ids(), "minted|" _ tId, "the mint removes nothing")
    Do $$$AssertEquals($ClassMethod(..#PORT, "ReportCall", "DELETEQUERY", tId, ..#NAMESPACE, ""), 1, "the row is removed out of band")
    Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
    Do $$$AssertTrue(tConfirm [ "PROPOSAL.TARGETCHANGED", "the confirm is refused target-changed: " _ tConfirm)
}

/// <p>AC3. A case's report is written to a server file by the list's Generate report and by the agent's confirmed proposal, and answered to the screen as
/// lines by Generate report to this browser: each holds every statement saved for the case, in order, and parses back into the vendor's class without saving;
/// a file already at the name is replaced; the temporary file the vendor writes is not left behind.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.ReportGenerate</code> answers the lines of the first row alone -> the statement-count legs go red;
/// the store drops the browser branch -> <code>sql-reports.page.spec.ts</code> goes red.</p>
Method TestTheReportHoldsEveryStatementOfTheCaseOnEachRoute()
{
    Set tOne = $Parameter(..#PROBE, "REPORTQUERY")
    Set tTwo = tOne _ " ORDER BY A"
    Do ..Seed(tOne)
    Do ..Seed(tTwo)
    Set tFile = $ClassMethod(..#DIRECTORY, "RelativeName", "screen.xml")
    Set tStatus = ..Act("generate", {"WRCNumber": (..#CASE), "root": ($ClassMethod(..#DIRECTORY, "Root")), "path": (tFile)}, , .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the screen's generate to a server file answers: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tStream = ##class(%Stream.TmpCharacter).%New()
    Do tStream.Write(..FileText("screen.xml"))
    Do tStream.Rewind()
    Do $$$AssertEquals(..Statements(tStream, .tCount) _ "|" _ tCount, tOne _ "|" _ tTwo _ "|2", "the file holds both statements and parses into the vendor's class")
    Set tStatus = ..Act("generate-browser", {"WRCNumber": (..#CASE)}, , .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the screen's generate to this browser answers: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 400), 1: ""))
    Set tText = ""
    If $IsObject(tAnswer) && $IsObject(tAnswer.output) && (tAnswer.output.%GetTypeOf("lines") = "array") {
        Set tIterator = tAnswer.output.lines.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLine) {
            Set tText = tText _ tLine _ $Char(10)
        }
    }
    Set tStream = ##class(%Stream.TmpCharacter).%New()
    Do tStream.Write(tText)
    Do tStream.Rewind()
    Do $$$AssertEquals(..Statements(tStream, .tCount) _ "|" _ tCount, tOne _ "|" _ tTwo _ "|2", "the lines answered to the screen hold both statements and parse the same")
    Set tArgs = {"WRCNumber": "2291", "root": ($ClassMethod(..#DIRECTORY, "Root")), "path": ($ClassMethod(..#DIRECTORY, "RelativeName", "agent.xml"))}
    Set tOutcome = ..Agent(..#GENERATE, tArgs, , 0, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ ##class(%File).Exists($ClassMethod(..#DIRECTORY, "Directory") _ "agent.xml"), "minted|0", "the agent's mint writes no file")
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "EXPLORER.SQLREPORT.GENERATE", "its consequence names the replaced file")
    Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(+tConfirm, 200, "the confirm answers: " _ tConfirm)
    Do $$$AssertEquals(..FileText("agent.xml"), ..FileText("screen.xml"), "the agent's file holds what the screen's file holds")
    Set tStatus = ..Act("generate", {"WRCNumber": (..#CASE), "root": ($ClassMethod(..#DIRECTORY, "Root")), "path": (tFile)})
    Do $$$AssertEquals(tStatus, 200, "a file already at the name is replaced")
}

/// <p>AC3. A case with no saved query, a root that is not an allowed directory, a name the port refuses and a name under a directory that does not exist
/// are each refused before the instance is asked to write: the seam counts no call and no file appears.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.ReportGenerate</code> skips its no-row precondition -> the no-row leg goes red (the seam counts a
/// call).</p>
Method TestTheGenerateRefusalsCallNothing()
{
    Set tRoot = $ClassMethod(..#DIRECTORY, "Root")
    Set tName = $ClassMethod(..#DIRECTORY, "RelativeName", "none.xml")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tQuery("WRCNumber") = ..#CASE
    Set tQuery("root") = tRoot
    Set tQuery("path") = tName
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "Reports", "GENERATE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 " _ $Parameter(..#ERROR, "SQLREPORTNOROWS"), "a case with no saved query is refused")
    Do ..Seed()
    For tCase = $ListBuild("/nonexistent/root", tName, "PATH.ROOT"), $ListBuild(tRoot, "../escape.xml", "PATH.NAME"), $ListBuild(tRoot, "OcuProbe1913NoSuchDirectory/x.xml", "TASK.EXPORT.DIRECTORY") {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = "*"
        Set tQuery("WRCNumber") = ..#CASE
        Set tQuery("root") = $List(tCase, 1)
        Set tQuery("path") = $List(tCase, 2)
        Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "Reports", "GENERATE", .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 " _ $List(tCase, 3), "'" _ $List(tCase, 2) _ "' under '" _ $List(tCase, 1) _ "' is refused with " _ $List(tCase, 3))
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ ##class(%File).Exists($ClassMethod(..#DIRECTORY, "Directory") _ "none.xml"), "0|0", "the instance was asked for no call and no file was written")
    Set tOutcome = ..Agent(..#GENERATE, {"WRCNumber": "2291", "root": ($ClassMethod(..#DIRECTORY, "Root")), "path": "OcuProbe1913NoSuchDirectory/x.xml"}, , 1)
    Do $$$AssertTrue(tOutcome [ "TASK.EXPORT.DIRECTORY", "the agent's confirm refuses a missing directory before any write: " _ tOutcome)
    Do $$$AssertEquals(##class(%File).DirectoryExists($ClassMethod(..#DIRECTORY, "Directory") _ "OcuProbe1913NoSuchDirectory"), 0, "and no directory was made")
}

/// <p>AC1, AC3. The instance's own refusal of a report write is 409 with the ruled sentence and the message in <code>detail</code> alone, one call made, no
/// file left and no row saved; a call that raises is the internal fault; a delete the instance answers an error for is the internal fault.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.ReportGenerate</code> puts the message in the reason -> the reason assertion goes red.</p>
Method TestTheInstancesRefusalIsAnsweredAndNothingIsLeft()
{
    Set tId = ..Seed()
    Do $ClassMethod(..#SEAM, "Refuse", "the report could not be written")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tQuery("WRCNumber") = ..#CASE
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "Reports", "GENERATE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.reason, 1: ""), "409 " _ $Parameter(..#ERROR, "SQLREPORTGENERATEVENDOR") _ "|" _ $Parameter(..#ERROR, "REASONSQLREPORTGENERATEVENDOR"), "generate: 409 with the ruled sentence")
    Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.detail.message [ "could not be written") && (tFault.reason '[ "written."), "generate: the instance's message is in detail alone")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tQuery("WRCNumber") = ..#CASE
    Set tQuery("Statement") = $Parameter(..#PROBE, "REPORTQUERY") _ " ORDER BY A"
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "Reports", "SAVEQUERY", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 " _ $Parameter(..#ERROR, "SQLREPORTVENDOR"), "save: 409")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tId
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "Reports", "DELETEQUERY", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "delete: an error status is the internal fault")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ ..Ids(), "3|" _ tId, "one call was made for each and only the earlier row is saved")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Raise")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tQuery("WRCNumber") = ..#CASE
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "Reports", "GENERATE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "a call that raises is the internal fault")
}

/// <p>The null device and the caller's namespace are as they were after a vendor call that raises and after one that answers, so the response's own device is
/// never left redirected.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Kernel.Utils.CallWithNullDevice</code> skips the namespace restore -> the namespace assertion goes red.</p>
Method TestTheDeviceAndTheNamespaceAreRestoredAfterARaisedCall()
{
    Set tDevice = $IO
    Set tNamespace = $NAMESPACE
    Set tSC = ##class(OcuPilot.Kernel.Utils).CallWithNullDevice(..#NAMESPACE, "%SQL.Manager.QButtons.Base", "NoSuchMethod", 1, .tResult)
    Do $$$AssertStatusNotOK(tSC, "a vendor call that raises answers an error status")
    Do $$$AssertEquals($IO _ "|" _ $NAMESPACE, tDevice _ "|" _ tNamespace, "the device and the namespace are the caller's")
    Set tSC = $ClassMethod(..#PORT, "ReportCall", "SAVEQUERY", "*", ..#NAMESPACE, {"Statement": ($Parameter(..#PROBE, "REPORTQUERY")), "WRCNumber": "2291"}.%ToJSON())
    Do $$$AssertStatusOK(tSC, "a save through the vendor answers OK")
    Do $$$AssertEquals($IO _ "|" _ $NAMESPACE, tDevice _ "|" _ tNamespace, "the device and the namespace are the caller's after it too")
    Do $$$AssertEquals($ListLength($ClassMethod(..#PROBE, "ReportIds", ..#NAMESPACE)), 1, "and it saved its row")
}

/// <p>AC4. The page offers no mail action and the server sends nothing: the list's actions and each tool's screen actions name none, and no tool, descriptor or
/// port text of the troubleshooting reports carries a mail address or a mail link.</p>
/// <p>Mutation (Rule 19): the descriptor gains a <code>mail</code> row action -> the actions assertion goes red.</p>
Method TestThePageOffersNoMailAction()
{
    Do $ClassMethod(..#LIST, "DeclarationJson", .tDeclaration)
    Set tText = tDeclaration.%ToJSON()
    Set tActions = ""
    Set tIterator = tDeclaration.rowActions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAction) {
        Set tActions = tActions _ "," _ tAction.id
    }
    Do $$$AssertEquals(tActions, ",save,generate,generate-browser,delete", "the list's actions are Save query, Generate report (two destinations) and Delete")
    For tTool = ..#SAVE, ..#DELETE, ..#GENERATE {
        Set tScreens = $Parameter(tTool, "SCREENACTIONS") _ "|" _ $Parameter(tTool, "DESCRIPTION")
        Do $$$AssertTrue(($ZConvert(tScreens, "L") '[ "mail") && (tScreens '[ "@"), $Parameter(tTool, "TOOLNAME") _ ": no mail action or address")
    }
    Do $$$AssertTrue(($ZConvert(tText, "L") '[ "mailto") && (tText '[ "@"), "the descriptor names no mail link or address")
}

}
