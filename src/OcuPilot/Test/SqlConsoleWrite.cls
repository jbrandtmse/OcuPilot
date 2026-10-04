/// <p>Pins SQL query's confirmed run, the screen action <code>run</code> of
/// <code>explorer.sqlquery.run</code> (Story 19.6, AD-10, AD-11, AD-22, AD-39, AD-53): a DML and a DDL
/// statement run and answered with their target, verb and output; the write classifying the statement
/// again and refusing a query, a value count that does not match and a refused kind; an SQL error
/// answered as output with nothing changed; a transaction left open rolled back; OcuPilot's own tables
/// refused; SQLCODE -99 for a principal's statement on a table it holds no SQL privilege on
/// (DW-1964); the tool absent from every roster the agent sees, its key shipping disabled; and no
/// ledger row, agent marker or log line carrying the run.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and a <code>USER</code> namespace. It creates and
/// removes <class>OcuPilot.Test.SqlConsoleProbe</class>'s objects, data included, and its principals,
/// so it runs on a throwaway only (<parameter>OcuPilot.Test.SqlConsoleProbe.ARMINGVARIABLE</parameter>),
/// reads the tail of <code>messages.log</code>, and snapshots the stored governance policy before each
/// test and puts it back after it.</p>
Class OcuPilot.Test.SqlConsoleWrite Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlConsoleProbe";

Parameter TOOLNAME = "explorer.sqlquery.run";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.ExplorerSqlRun";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.ExplorerSqlQuery";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If '$ClassMethod(..#PROBE, "Armed") {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlConsoleWrite creates IRIS users and roles and runs on a throwaway container only. " _ $Parameter(..#PROBE, "ARMINGVARIABLE") _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe196" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Make")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..PreparedPassword)
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipals"))
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>One confirmed run of <var>pText</var> with <var>pValues</var> (JSON array text) in
/// <var>pNamespace</var> as <var>pUser</var> (the suite's own account when <code>""</code>): the HTTP
/// status and the parsed answer.</p>
Method Run(pText As %String, pValues As %String, Output pStatus As %Integer, Output pAnswer, pNamespace As %String = "USER", pUser As %String = "")
{
    Set tRequest = {"action": "run", "id": "sql"}
    Set tValues = {}
    Do tValues.%Set("statement", pText, "string")
    Do tValues.%Set("parameters", pValues, "string")
    Do tValues.%Set("maxRows", "10", "string")
    Do tRequest.%Set("values", tValues)
    Set tUser = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestUsername(), 1: pUser)
    Set tPassword = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestPassword(), 1: ..PreparedPassword)
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/screens/explorer.sqlquery/action?ns=" _ pNamespace, tUser, tPassword, .pStatus, .tBody, .tHeaders, tRequest.%ToJSON(), "application/json")
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set pAnswer = $Get(tBody)
    }
}

/// <p>An answer's status and output, or its status and code when refused.</p>
ClassMethod Said(pStatus As %Integer, pAnswer) As %String
{
    If '$IsObject($Get(pAnswer)) Quit $Get(pStatus) _ " " _ $Get(pAnswer)
    If pAnswer.%GetTypeOf("output") = "object" Quit pStatus _ " " _ pAnswer.output.%ToJSON()
    Quit pStatus _ " " _ pAnswer.%Get("code")
}

/// <p>AC2, AC7, AC9: a confirmed UPDATE runs and answers the change event's triple, its verb and its
/// row count as output; a confirmed CREATE TABLE creates the table and a DROP TABLE removes it.</p>
Method TestAConfirmedRunChangesAndAnswersItsTarget()
{
    Do ..Run("UPDATE OcuProbe196.Granted SET Num = Num + 1 WHERE Num <= ?", "[""2""]", .tStatus, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("target")): tStatus _ " " _ tAnswer.action _ " " _ tAnswer.target.%ToJSON() _ " " _ tAnswer.output.%ToJSON(), 1: ..Said(tStatus, .tAnswer)), "200 updated {""type"":""class"",""scope"":""USER"",""id"":""sql""} {""kind"":""dml"",""outcome"":""done"",""rowCount"":2}", "the run answers its target, its verb and its row count")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 822", "and changed two rows")
    Do ..Run("UPDATE OcuProbe196.Granted SET Num = Num - 1 WHERE Num IN (2, 3) AND Name IN ('n1', 'n2')", "[]", .tStatus, .tAnswer)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 820", "which a second run puts back")
    Do ..Run("CREATE TABLE OcuProbe196.Made (X INTEGER)", "[]", .tStatus, .tAnswer)
    Do $$$AssertEquals(..Said(tStatus, .tAnswer), "200 {""kind"":""ddl"",""outcome"":""done"",""rowCount"":0}", "a CREATE TABLE runs")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "HoldsTable", "OcuProbe196.Made"), "and the table exists")
    Do ..Run("DROP TABLE OcuProbe196.Made", "[]", .tStatus, .tAnswer)
    Do $$$AssertEquals(..Said(tStatus, .tAnswer), "200 {""kind"":""ddl"",""outcome"":""done"",""rowCount"":0}", "a DROP TABLE runs")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "HoldsTable", "OcuProbe196.Made"), "and the table is gone")
}

/// <p>AD-11: the write classifies the statement again and refuses a query, a value count that does
/// not match, a refused kind and a password statement by name, and bad values by the route; an SQL
/// error is answered as output and changes nothing; a transaction left open is rolled back.</p>
Method TestTheWriteClassifiesTheStatementAgain()
{
    For tCase = $ListBuild("SELECT Name FROM OcuProbe196.Granted", "[]", "422 EXPLORER.SQL.READS"), $ListBuild("UPDATE OcuProbe196.Granted SET Num = Num WHERE Num = ?", "[]", "422 EXPLORER.SQL.PARAMETERS"), $ListBuild("START TRANSACTION", "[]", "422 EXPLORER.SQL.SESSION"), $ListBuild("GRANT SELECT ON OcuProbe196.Granted TO _PUBLIC", "[]", "422 EXPLORER.SQL.ADMINISTRATION"), $ListBuild("CREATE USER OcuProbe196Nobody IDENTIFY BY 'OcuProbe196NotACredential'", "[]", "422 EXPLORER.SQL.PASSWORD"), $ListBuild("UPDATE OcuProbe196.Granted SET Num = Num + 1", "not json", "400 TOOL.ARGUMENTS"), $ListBuild("DELETE FROM OcuProbe196.Nope", "[]", "200 {""outcome"":""error"",""kind"":"""",""sqlcode"":-30,""message"":"" Table 'OCUPROBE196.NOPE' not found""}"), $ListBuild("CALL OcuProbe196.LeaveOpen()", "[]", "200 {""outcome"":""error"",""kind"":""call"",""sqlcode"":null,""message"":"""",""rolledBack"":true}") {
        Do ..Run($List(tCase, 1), $List(tCase, 2), .tStatus, .tAnswer)
        Do $$$AssertEquals(..Said(tStatus, .tAnswer), $List(tCase, 3), $List(tCase, 1))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 820", "and nothing changed")
}

/// <p>AC4: as the suite's <code>%All</code> account in the install namespace, a confirmed run over
/// OcuPilot's own tables -- directly, reading or changing them through a view, or as DDL naming one --
/// is refused 403 <code>PROHIBITED.OCUPILOTSQL</code> inside the target's hold. The changes match no
/// row, so a refusal that failed would change nothing.</p>
Method TestOcuPilotsOwnTablesAreRefusedOnTheWritePath()
{
    Set tView = $Parameter(..#PROBE, "OWNVIEW")
    For tText = "SELECT ID FROM OcuPilot_Kernel_State.Proposal", "SELECT ID FROM " _ tView, "DELETE FROM " _ tView _ " WHERE ID < 0", "DROP TABLE OcuPilot_Kernel_State.OcuProbe196NoSuchTable" {
        Do ..Run(tText, "[]", .tStatus, .tAnswer, $NAMESPACE)
        Do $$$AssertEquals(..Said(tStatus, .tAnswer), "403 PROHIBITED.OCUPILOTSQL", tText)
    }
}

/// <p>DW-1964: a principal granted SELECT on one table is answered SQLCODE -99 as output for UPDATE,
/// TRUNCATE, CREATE TABLE, CALL and SELECT on the other through the write path, and nothing
/// changes.</p>
/// <p>Mutation (Rule 19): prepare with privilege checks off in both
/// <method>OcuPilot.Port.SqlPort.Prepared</method> and <method>OcuPilot.Port.SqlPort.Executed</method> --
/// the UPDATE leg changes the table and goes red.</p>
Method TestAnUngrantedTableIsRefusedOnTheWritePath()
{
    Set tMade = "OcuProbe196.Made" _ $Translate($ZTimeStamp, ",.", "")
    Set tUser = $Parameter(..#PROBE, "USER")
    For tText = "UPDATE OcuProbe196.Hidden SET Num = Num + 10", "TRUNCATE TABLE OcuProbe196.Hidden", "CREATE TABLE " _ tMade _ " (X INTEGER)", "CALL OcuProbe196.HiddenCount()", "SELECT Name FROM OcuProbe196.Hidden" {
        Do ..Run(tText, "[]", .tStatus, .tAnswer, "USER", tUser)
        Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")): tStatus _ " " _ tAnswer.output.outcome _ " " _ tAnswer.output.sqlcode, 1: ..Said(tStatus, .tAnswer)), "200 error -99", tText)
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted", $Parameter(..#PROBE, "HIDDEN")), "2 3", "the ungranted table is unchanged")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "HoldsTable", tMade), "and nothing was created")
}

/// <p>AC7, AD-53: the run is in no roster the agent sees -- the provider tool list, the dispatch
/// lookup, a proposal-path resolve, the screen context's <code>tools</code> -- while the registry still
/// lists it, and a model's call of it is refused as an unknown tool with no proposal written.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.ExplorerSqlRun.ADVERTISED</parameter> 1 -- this
/// goes red.</p>
Method TestTheRunIsAbsentFromEveryRosterTheAgentSees()
{
    Set tRegistry = "OcuPilot.Screen.Tool.Registry"
    Do $$$AssertEquals($ClassMethod(..#TOOLCLASS, "Advertised"), 0, "declared unadvertised")
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ProviderTools", .tProvider), "the provider tool list builds")
    Set tWire = $ClassMethod(tRegistry, "WireName", ..#TOOLNAME)
    Set tProviderNames = ""
    For tI = 1:1:+$Get(tProvider) Set tProviderNames = tProviderNames _ $ListBuild(tProvider(tI, "name"))
    Do $$$AssertTrue('$ListFind(tProviderNames, tWire), "the provider tool list leaves it out")
    Kill tByWire, tByName, tForRoute
    Do $ClassMethod(tRegistry, "ResolveWire", tWire, .tByWire)
    Do $$$AssertTrue('$IsObject($Get(tByWire)), "the dispatch lookup does not find it")
    Do $ClassMethod(tRegistry, "Resolve", ..#TOOLNAME, .tByName)
    Do $$$AssertTrue('$IsObject($Get(tByName)), "nor does a proposal-path resolve")
    Do $ClassMethod(tRegistry, "Resolve", ..#TOOLNAME, .tForRoute, 1)
    Do $$$AssertTrue($IsObject($Get(tForRoute)), "while the screen's route reaches it")
    Kill tTools
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(..#DESCRIPTOR, .tTools), "the screen's context tools build")
    Set tJson = $Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: "")
    Do $$$AssertTrue((tJson '[ tWire) && (tJson '[ ..#TOOLNAME), "and carry no run: " _ tJson)

    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#TOOLNAME)
    Do $$$AssertTrue(tBefore >= 0, "the stored proposals are counted: " _ tBefore)
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded")
    Set tUse = {"type": "tool_use", "id": "toolu_sqlrun", "input": {"statement": "DELETE FROM OcuProbe196.Granted", "rationale": "probe", "expectedImpact": "probe"}}
    Do tUse.%Set("name", tWire, "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurn, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertStatusOK(tSC, "the dispatch answers")
    Set tCode = ""
    If $IsObject($Get(tResults)) && (tResults.%Size() = 1) Set tCode = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content")).%Get("code")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Api.Error).#TOOLUNKNOWN, "a model's run is refused as an unknown tool")
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#TOOLNAME), tBefore, "and no proposal is written")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 820", "and nothing ran")
}

/// <p>AC7, AD-22, AD-39: the key ships disabled and reads disabled while a person's run writes; the
/// screen declares no read and no context field; and a run's statement and SQL error reach no ledger
/// row, no agent marker and no log line, on the write path or on the run route.</p>
Method TestTheKeyShipsDisabledAndARunLeavesNoTrace()
{
    Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed(..#TOOLNAME, .tListed)
    Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve(..#TOOLNAME, "write", .tEnabled, .tSource)
    Do $$$AssertEquals(tListed _ " " _ tValue _ " " _ ''$Get(tEnabled), "1 0 0", "listed, disabled, and read disabled")
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclared)
    If '$IsObject($Get(tDeclared)) Set tDeclared = {"context": {"fields": [""]}}
    Do $$$AssertEquals(tDeclared.%GetTypeOf("read") _ " " _ tDeclared.context.fields.%Size(), "unassigned 0", "the screen declares no read and no context field")

    Set tSince = $ZDateTime($ZTimeStamp, 3, 1, 3)
    Set tLog = ##class(%File).NormalizeFilename(##class(OcuPilot.Port.LogSourcePort).FileFor("messages"), ##class(OcuPilot.Port.LogSourcePort).ManagerDirectory())
    Set tFrom = ##class(%File).GetFileSize(tLog)
    Set tMark = "OcuProbe196Trace" _ $Translate($ZTimeStamp, ",.", "")
    Do ..Run("DELETE FROM OcuProbe196." _ tMark, "[]", .tStatus, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")): tStatus _ " " _ tAnswer.output.sqlcode, 1: ..Said(tStatus, .tAnswer)), "200 -30", "a person's run writes, answering its SQL error")
    Do ..Run("UPDATE OcuProbe196.Granted SET Num = Num WHERE Name = ?", "[""" _ tMark _ """]", .tStatus, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")): tStatus _ " " _ tAnswer.output.outcome, 1: ..Said(tStatus, .tAnswer)), "200 done", "and a run that changes nothing")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/explorer/sql/run?ns=USER", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tRouteStatus, .tRouteBody, .tHeaders, "{""statement"":""SELECT * FROM OcuProbe196." _ tMark _ """}", "application/json")
    Do $$$AssertTrue((tRouteStatus = 200) && (tRouteBody [ "-30"), "the run route answers the same error: " _ tRouteBody)

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(Name) = ?", ..#TOOLNAME)
    Do $$$AssertEquals($Select((tRS.%SQLCODE = 0) && tRS.%Next(): tRS.%Get("N"), 1: -1), 0, "no ledger row names the run")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, ##class(OcuPilot.Test.AuditMarker).MarkerName(), ..#TOOLNAME, .tData), 0, "no agent marker carries it")
    Set tFound = ""
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If tStream.LinkToFile(tLog) && (tStream.Size > tFrom) && tStream.MoveTo(tFrom + 1) {
        While 'tStream.AtEnd {
            Set tLine = tStream.ReadLine()
            If $ZConvert(tLine, "U") [ $ZConvert(tMark, "U") Set tFound = tLine
        }
    }
    Set tStream = ""
    Do $$$AssertEquals(tFound, "", "and no log line carries its statement, value or error")
}

}
