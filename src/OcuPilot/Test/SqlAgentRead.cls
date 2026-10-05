/// <p>Pins the agent's SQL query, <code>explorer.sqlquery.read</code> (Story 19.11, AD-3, AD-7, AD-11,
/// AD-21, AD-24, AD-36, AD-60, AD-61): a query answered as columns and rows with its values bound and
/// its rows bounded; a credential-named column masked; a statement the instance did not prepare, or
/// that a principal's SQL privileges refuse (SQLCODE -99, DW-1964), answered as an <code>error</code>
/// outcome; every kind that changes something, every refused group and OcuPilot's own tables refused
/// before anything runs; the input and value-count refusals; neither tool class naming the Atelier
/// port or its query route; and a real turn whose provider request carries the rows as a framed
/// <code>tool_result</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP, a
/// <code>USER</code> namespace, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PROVIDERVARIABLE</parameter> reading <code>1</code>: it creates and removes
/// <class>OcuPilot.Test.SqlConsoleProbe</class>'s objects and principals, one table of its own, a
/// turn principal and the <code>turnprobe</code> definition, and runs one turn job. Everything is
/// removed in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.SqlAgentRead Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter PROBE = "OcuPilot.Test.SqlConsoleProbe";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TOOL = "OcuPilot.Screen.Tool.ExplorerSqlRead";

Parameter TAG = "sqlagentread-probe";

Parameter NAMESPACE = "USER";

/// <p>The probe table whose column is named like a credential.</p>
Parameter TOKENS = "OcuProbe196.Tokens";

/// <p>What the turn principal's second role grants beyond the fixture's own resources.</p>
Parameter DEVELOPMENTGRANT = "%Development:U";

Property PreparedPassword As %String;

Property PreparedTurnPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedTurnPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlAgentRead creates IRIS users and roles and runs a turn job against the turnprobe row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was created.")
    }
    Set ..PreparedPassword = "OcuProbe196" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set ..PreparedTurnPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = $ClassMethod(..#PROBE, "Make")
    If $$$ISOK(tSC) Set tSC = ..MakeTokens()
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..PreparedPassword)
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#NAMESPACE, .tCode, .tGlobals, .tMapped, .tResolved)
    If 'tResolved || (tCode = "") Quit $$$ERROR($$$GeneralError, "the " _ ..#NAMESPACE _ " namespace's code database could not be resolved")
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", tUser, ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "Resources", 0), ..#DEVELOPMENTGRANT _ "," _ tCode _ ":RW")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Grant", tUser)
    If $$$ISOK(tSC) Set tSC = ..GrantTokens(tUser)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISOK(tSC) Set ..PreparedDefinitionId = tId
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    Do ..DropTokens()
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove"))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipals"))
    If tLeft '= "" Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlAgentRead teardown left:" _ tLeft))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Quit $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Quit $$$OK
}

/// <p>The probe table with a credential-named column, in <parameter>NAMESPACE</parameter>.</p>
ClassMethod MakeTokens() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Do ##class(%SQL.Statement).%ExecDirect(, "DROP TABLE " _ ..#TOKENS _ " CASCADE")
        For tText = "CREATE TABLE " _ ..#TOKENS _ " (Name VARCHAR(50), ApiToken VARCHAR(50))", "INSERT INTO " _ ..#TOKENS _ " (Name, ApiToken) VALUES ('t1', 'tok-probe-1')", "INSERT INTO " _ ..#TOKENS _ " (Name, ApiToken) VALUES ('t2', 'tok-probe-2')" {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, tText)
            If tResult.%SQLCODE < 0 {
                Set tSC = $$$ERROR($$$GeneralError, "probe statement failed: SQLCODE " _ tResult.%SQLCODE _ " " _ tResult.%Message)
                Quit
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Drop <parameter>TOKENS</parameter> from <parameter>NAMESPACE</parameter>, data included.</p>
ClassMethod DropTokens()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Do ##class(%SQL.Statement).%ExecDirect(, "DROP TABLE " _ ..#TOKENS _ " CASCADE")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Grant <var>pUser</var> SELECT on <parameter>TOKENS</parameter>.</p>
ClassMethod GrantTokens(pUser As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT ON " _ ..#TOKENS _ " TO " _ pUser)
        If tResult.%SQLCODE < 0 Set tSC = $$$ERROR($$$GeneralError, "the grant failed: SQLCODE " _ tResult.%SQLCODE)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The agent's query of <var>pText</var> with <var>pValues</var> (a <class>%DynamicArray</class>)
/// and <var>pMax</var> rows in <var>pNamespace</var> as the running account.</p>
ClassMethod Read(pText As %String, pValues As %DynamicArray, pMax As %Integer, Output pResult, Output pHttp As %Integer, Output pFault, pNamespace As %String = {..#NAMESPACE}) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Set tArgs = {"statement": (pText), "parameters": (pValues)}
    If pMax '= "" Do tArgs.%Set("maxRows", pMax, "number")
    Quit $ClassMethod(..#TOOL, "View", "", tArgs, 200, .pResult, .pHttp, .pFault)
}

/// <p>How a call ended: <code>http code</code> for a refusal, <code>200 outcome</code> otherwise.</p>
ClassMethod Said(pSC As %Status, pResult, pHttp As %Integer, pFault) As %String
{
    If $$$ISERR(pSC) Quit +pHttp _ " " _ $Select($IsObject(pFault): pFault.%Get("code"), 1: "")
    Quit pHttp _ " " _ $Select($IsObject(pResult): pResult.%Get("outcome"), 1: "")
}

/// <p>AC7: the query runs with its values bound and answers its kind, statement type, tables, columns
/// and rows, cut at <code>maxRows</code> with truncation reported; a value that would change the
/// statement's meaning if it were spliced is a value; a cell is cut at 1,000 characters.</p>
/// <p>Mutation (Rule 19): splice the first value into the statement text before it reaches the port --
/// the bound leg answers rows and goes red.</p>
Method TestAQueryAnswersRowsWithItsValuesBound()
{
    Set tSC = ..Read("SELECT Name, Num FROM OcuProbe196.Granted WHERE Num > ?", ["0"], 2, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault), "200 rows", "a SELECT with a value runs")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.kind _ " " _ tResult.statementType _ " " _ tResult.namespace, "query 1 " _ ..#NAMESPACE, "typed a query in the scope's namespace")
    Do $$$AssertEquals(tResult.tables.%ToJSON(), "[""OCUPROBE196.GRANTED""]", "naming its table")
    Do $$$AssertEquals(tResult.columns.%ToJSON(), "[""Name"",""Num""]", "its columns")
    Do $$$AssertEquals(tResult.rows.%Size() _ " " _ tResult.truncated _ " " _ tResult.redactedColumns.%Size(), "2 1 0", "cut at two rows, truncation reported, nothing masked")
    Do $$$AssertEquals(tResult.rows.%Get(0).%ToJSON(), "[""n1"",""1""]", "its first row, as text cells")

    Set tSC = ..Read("SELECT Name FROM OcuProbe196.Granted WHERE Name = ?", [" OR '='"], "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault) _ " " _ $Select($IsObject(tResult): tResult.rows.%Size(), 1: -1), "200 rows 0", "a value is bound, never spliced: it matches nothing")
    Set tSC = ..Read("SELECT Name FROM OcuProbe196.Granted WHERE Name = ?", ["' OR ''='"], "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tResult): tResult.rows.%Size(), 1: -1), 0, "even a value that closes a literal matches nothing")

    Set tSC = ..Read("SELECT LPAD('x', 1500, 'y') AS Wide", [], "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault), "200 rows", "a wide cell is read")
    If $IsObject(tResult) {
        Set tCell = tResult.rows.%Get(0).%Get(0)
        Do $$$AssertEquals($Length(tCell) _ " " _ $Extract(tCell, *) _ " " _ tResult.truncated, "1000 " _ $Char(8230) _ " 1", "cut at 1,000 characters, ending in U+2026, truncation reported")
    }
}

/// <p>AC7, AD-36: every cell of a column whose name the credential pattern matches reads
/// <code>[redacted]</code> and <code>redactedColumns</code> names it; a column that does not match is
/// read as it is.</p>
/// <p>Mutation (Rule 19): drop the <code>IsCredentialName</code> test from
/// <method>OcuPilot.Screen.Tool.ExplorerSqlRead.Projected</method> -- the cells read their values and
/// this goes red.</p>
Method TestACredentialNamedColumnIsMasked()
{
    Set tSC = ..Read("SELECT Name, ApiToken FROM " _ ..#TOKENS _ " ORDER BY Name", [], "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault), "200 rows", "the table is read")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%ToJSON() _ " " _ tResult.redactedColumns.%ToJSON(), "[[""t1"",""[redacted]""],[""t2"",""[redacted]""]] [""ApiToken""]", "the token cells read [redacted] and the column is named")
    Do $$$AssertTrue(tResult.%ToJSON() '[ "tok-probe", "no value of the column is anywhere in the answer")
}

/// <p>AD-7, AD-21: a statement that changes something -- DML, DDL, a CALL, one the instance types
/// otherwise -- is refused 422 <code>EXPLORER.SQL.CHANGES</code> before it runs, and nothing changes.</p>
/// <p>Mutation (Rule 19): drop the <code>Mutating</code> refusal from
/// <method>OcuPilot.Screen.Tool.ExplorerSqlRead.View</method> -- the port refuses the kind instead,
/// answering 500, and this goes red.</p>
Method TestAStatementThatChangesIsRefusedBeforeItRuns()
{
    Set tCode = ##class(OcuPilot.Api.AtelierError).#SQLCHANGES
    For tText = "UPDATE OcuProbe196.Granted SET Num = 3", "DELETE FROM OcuProbe196.Granted", "CREATE TABLE OcuProbe196.Made (X INTEGER)", "CALL OcuProbe196.LeaveOpen()", "TUNE TABLE OcuProbe196.Granted" {
        Set tSC = ..Read(tText, [], "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault), "422 " _ tCode, tText)
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 820", "the table is unchanged")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "HoldsTable", "OcuProbe196.Made"), "and nothing was created")
}

/// <p>The console's refused groups and OcuPilot's own tables are refused on the read as they are on the
/// console, with 19.6's codes, the password statement before any prepare; and bad input and a wrong
/// value count are refused by name.</p>
Method TestRefusedGroupsOwnTablesAndBadInputAreRefused()
{
    For tCase = $ListBuild("START TRANSACTION", "422 EXPLORER.SQL.SESSION"), $ListBuild("GRANT SELECT ON OcuProbe196.Granted TO _PUBLIC", "422 EXPLORER.SQL.ADMINISTRATION"), $ListBuild("LOAD DATA FROM FILE '/tmp/x.csv' INTO OcuProbe196.Granted", "422 EXPLORER.SQL.SERVERFILES"), $ListBuild("CREATE USER OcuProbe196Nobody IDENTIFY BY 'OcuProbe196NotACredential'", "422 EXPLORER.SQL.PASSWORD"), $ListBuild("SELECT Name FROM OcuProbe196.Granted WHERE Num = ?", "422 EXPLORER.SQL.PARAMETERS") {
        Set tSC = ..Read($List(tCase, 1), [], "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault), $List(tCase, 2), $List(tCase, 1))
    }
    Set tView = $Parameter(..#PROBE, "OWNVIEW")
    For tText = "SELECT ID FROM OcuPilot_Kernel_State.Proposal", "SELECT ID FROM " _ tView {
        Set tSC = ..Read(tText, [], "", .tResult, .tHttp, .tFault, $NAMESPACE)
        Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault), "403 PROHIBITED.OCUPILOTSQL", tText)
    }
    Set tSC = ..Read($Justify("", 100001), [], "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault), "400 " _ ##class(OcuPilot.Api.AtelierError).#SQLINPUT, "an over-long blank statement is refused")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = $ClassMethod(..#TOOL, "View", "", {"statement": " "}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault), "400 " _ ##class(OcuPilot.Api.AtelierError).#SQLINPUT, "a blank statement is refused by the console's own bounds")
    Set tSC = $ClassMethod(..#TOOL, "View", "", {"statement": "SELECT 1", "maxRows": 1001}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault), "400 TOOL.ARGUMENTS", "Max rows above 1,000 is refused")
    Set tSC = $ClassMethod(..#TOOL, "View", "", {"statement": "SELECT 1", "parameters": [1]}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault), "400 TOOL.ARGUMENTS", "a value that is not a string is refused")
}

/// <p>AC7, DW-1964: a statement the instance does not prepare is an <code>error</code> outcome carrying
/// its SQLCODE and no row, and a principal granted SELECT on one table reading another is answered -99,
/// the instance's own verdict at prepare.</p>
/// <p>Mutation (Rule 19): prepare with privilege checks off in
/// <method>OcuPilot.Port.SqlPort.Prepared</method> -- the principal's read answers its rows and goes
/// red.</p>
Method TestAnUnpreparedStatementIsAnErrorOutcome()
{
    Set tSC = ..Read("SELEKT Name FROM OcuProbe196.Granted", [], "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault), "200 error", "a syntax error is an outcome, not a fault")
    Do $$$AssertTrue($IsObject(tResult) && (tResult.sqlcode < 0) && (tResult.%GetTypeOf("rows") = "unassigned"), "with its SQLCODE and no row")
    Set tUser = $Parameter(..#PROBE, "USER")
    Set tLegs = [{"op": "read", "namespace": (..#NAMESPACE), "statement": "SELECT Name FROM OcuProbe196.Granted ORDER BY Num"}, {"op": "read", "namespace": (..#NAMESPACE), "statement": "SELECT Name FROM OcuProbe196.Hidden"}]
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", tUser, tLegs.%ToJSON())
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegText", tProbe, 0), "200   rows ", "the principal reads the table it holds SELECT on")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegText", tProbe, 1), "200   error -99", "and is answered -99 on the one it does not")
}

/// <p>DW-1964: neither agent SQL tool class names the Atelier port or its query route, so a caller's
/// statement cannot reach a prepare with privilege checks off.</p>
Method TestNeitherToolReachesTheAtelierQueryRoute()
{
    For tClass = "OcuPilot.Screen.Tool.ExplorerSqlRead", "OcuPilot.Screen.Tool.ExplorerSqlRun", "OcuPilot.Screen.Tool.ExplorerSqlRunMint" {
        Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString(, tClass, .tText)
        Do $$$AssertStatusOK(tSC, tClass _ "'s source is read")
        Do $$$AssertTrue((tText '[ "AtelierPort") && (tText '[ "action/query"), tClass _ " names neither the Atelier port nor its query route")
    }
}

/// <p>AC7, AD-24, AD-60: a real turn as a principal granted SELECT on the probe table calls the tool; the
/// provider's next request carries the columns and rows as a <code>tool_result</code> framed as data,
/// at most <code>maxRows</code> rows with truncation reported, and the credential-named column masked;
/// the turn completes.</p>
/// <p>Mutation (Rule 19): empty the tool's registration -- delete <code>ExplorerSqlRead</code>'s
/// <code>KIND</code> -- the call is refused as unknown and this goes red.</p>
Method TestATurnReadsRowsFramedAsData()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tCalls = [{"id": "toolu_sql_a", "input": {"statement": "SELECT Name, Num FROM OcuProbe196.Granted WHERE Num > ? ORDER BY Num", "parameters": ["0"], "maxRows": 2}}, {"id": "toolu_sql_b", "input": {"statement": "SELECT Name, ApiToken FROM OcuProbe196.Tokens ORDER BY Name"}}]
    Do tCalls.%Get(0).%Set("name", "explorer_sqlquery_read", "string")
    Do tCalls.%Get(1).%Set("name", "explorer_sqlquery_read", "string")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tCalls))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedTurnPassword, .tStatus, .tText)
    Do $$$AssertNotEquals(tConvId, "", "the principal starts a conversation: " _ tStatus)
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ ..#NAMESPACE, tUser, ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "StartBody", "read the probe rows", tConvId), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the turn starts: " _ $Extract(tText, 1, 200))
    If tStatus '= 202 Quit
    Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", ##class(%DynamicObject).%FromJSON(tText).turnId, tUser, ..PreparedTurnPassword, 60, .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 2, "after two provider calls")
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Kill tByUse
    Set tIterator = tMessages.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMessage) {
        If (tMessage.%Get("role") '= "user") || (tMessage.%GetTypeOf("content") '= "array") Continue
        Set tBlocks = tMessage.%Get("content").%GetIterator()
        While tBlocks.%GetNext(.tBlockIndex, .tBlock) {
            If tBlock.%Get("type") = "tool_result" Set tByUse(tBlock.%Get("tool_use_id")) = tBlock.%Get("content")
        }
    }
    Set tRows = $Get(tByUse("toolu_sql_a"))
    Set tBody = $ClassMethod(..#FIXTURE, "Unwrapped", tRows, .tWrapped)
    Do $$$AssertTrue(tWrapped, "the rows reach the model framed as data (AD-60)")
    Set tParsed = ""
    Try { Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertTrue($IsObject(tParsed), "and parse")
    If $IsObject(tParsed) {
        Do $$$AssertEquals(tParsed.outcome _ " " _ tParsed.rows.%Size() _ " " _ tParsed.truncated _ " " _ tParsed.rows.%Get(0).%ToJSON(), "rows 2 1 [""n1"",""1""]", "two bound rows, truncation reported")
    }
    Set tMasked = $ClassMethod(..#FIXTURE, "Unwrapped", $Get(tByUse("toolu_sql_b")), .tMaskedWrapped)
    Do $$$AssertTrue(tMaskedWrapped && (tMasked [ "[redacted]") && (tMasked '[ "tok-probe"), "the credential-named column reaches the model masked: " _ $Get(tByUse("toolu_sql_b")))
}

}
