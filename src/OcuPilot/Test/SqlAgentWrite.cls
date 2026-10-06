/// <p>Pins the agent's SQL proposal, <code>explorer.sqlquery.run</code> (Story 19.11, AD-6, AD-10, AD-13,
/// AD-15, AD-22, AD-34, AD-39, AD-51, AD-53): the mint refusing a query, a statement that carries code, a
/// statement the instance did not prepare, a wrong value count, OcuPilot's own tables, the refused groups
/// and bad input, each with nothing minted; the baseline key refusing the agent's call until it is enabled;
/// the proposal's card rows and consequence naming the statement's real kind, type and tables; its confirm
/// changing the table once, with a marker and a ledger row that carry no statement text and no outcome;
/// a table moved under the card closing the proposal as a moved target; a person's own Run reading the
/// same guard; and a principal granted SELECT on one table refused (DW-1964).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, a <code>USER</code> namespace, and
/// <parameter>OcuPilot.Test.SqlConsoleProbe.ARMINGVARIABLE</parameter> reading <code>1</code>: it creates
/// and removes that probe's objects, data included, and its principals. It snapshots the stored governance
/// policy before each test and puts it back after it, and removes the probe proposals and turns.</p>
Class OcuPilot.Test.SqlAgentWrite Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlConsoleProbe";

Parameter TOOLNAME = "explorer.sqlquery.run";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.ExplorerSqlRun";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.ExplorerSqlQuery";

Parameter NAMESPACE = "USER";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Property PreparedPassword As %String;

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlAgentWrite creates IRIS users and roles and runs on a throwaway container only. " _ $Parameter(..#PROBE, "ARMINGVARIABLE") _ " does not read 1 here, so nothing was created.")
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
    Do ..PutBack()
    Quit $$$OK
}

/// <p>The probe table's rows as the probe made them, and the probe objects a test may have made
/// removed.</p>
ClassMethod PutBack()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Do ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuProbe196.Granted SET Num = CAST(SUBSTRING(Name, 2) AS INTEGER)")
        Do ##class(%SQL.Statement).%ExecDirect(, "DROP TABLE OcuProbe196.Moved CASCADE")
        Do ##class(%SQL.Statement).%ExecDirect(, "DROP FUNCTION OcuProbe196.AgentFn")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Enable the run's governance key through its stored setting.</p>
ClassMethod EnableKey() As %Status
{
    Kill tSettings
    Set tSettings(..#TOOLNAME) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>The agent's call of the run for <var>pText</var> and <var>pValues</var> (a
/// <class>%DynamicArray</class>), through the dispatcher on a seeded turn scoped to
/// <parameter>NAMESPACE</parameter>: <var>pContent</var> is the answer's content parsed, and
/// <var>pIsError</var> its error flag.</p>
Method Dispatch(pText As %String, pValues As %DynamicArray, Output pContent, Output pIsError As %Boolean, Output pTurn As %String) As %Status
{
    Set pContent = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurn)
    If $$$ISERR(tSC) Quit tSC
    Set tUse = {"type": "tool_use", "id": "toolu_sqlrun", "input": {"Target": "sql", "rationale": "probe", "expectedImpact": "probe"}}
    Do tUse.input.%Set("statement", pText, "string")
    Do tUse.input.%Set("parameters", pValues)
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(..#TOOLNAME), "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pTurn)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(pTurn, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(pTurn)
    If $$$ISERR(tSC) Quit tSC
    Set pIsError = ''tResults.%Get(0).%Get("is_error")
    Try { Set pContent = ##class(%DynamicAbstractObject).%FromJSON(tResults.%Get(0).%Get("content")) } Catch { Set pContent = tResults.%Get(0).%Get("content") }
    Quit $$$OK
}

/// <p>The run's mint for <var>pText</var>, called directly: the proposal, the HTTP status and the fault.</p>
Method MintFor(pText As %String, pValues As %DynamicArray, Output pProposal, Output pHttp As %Integer, Output pFault, Output pTurn As %String) As %Status
{
    Set pProposal = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurn)
    If $$$ISERR(tSC) Quit tSC
    Set tTurn = pTurn
    Set tArgs = {"Target": "elsewhere", "rationale": "probe", "expectedImpact": "probe"}
    Do tArgs.%Set("statement", pText, "string")
    Do tArgs.%Set("parameters", pValues)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
    Set tSC = $ClassMethod(..#TOOLCLASS, "View", "", tArgs, 0, .pProposal, .pHttp, .pFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit tSC
}

/// <p>Confirm <var>pProposal</var> in process as the running account, scoped to
/// <parameter>NAMESPACE</parameter>.</p>
ClassMethod ConfirmIn(pProposal As %DynamicObject, Output pResult, Output pHttp As %Integer, Output pCode As %String) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Quit ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(pProposal)): pProposal.%Get("proposalId"), 1: ""), "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p>How a refused mint ended: <code>http code</code>.</p>
ClassMethod Said(pSC As %Status, pHttp As %Integer, pFault) As %String
{
    If $$$ISOK(pSC) Quit "minted"
    Quit +pHttp _ " " _ $Select($IsObject(pFault): pFault.%Get("code"), 1: "")
}

/// <p>AC9, AC10, DW-1964: the mint refuses a query, a statement that carries code, one the instance did
/// not prepare, a wrong value count, OcuPilot's own tables, the refused groups and bad input, each with
/// nothing minted; the console still asks its confirmation for the statement that carries code.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.SqlPort.CarriesCode</method> answer 0 -- the code
/// legs mint and this goes red; skip the <code>Check</code> in
/// <method>OcuPilot.Screen.Tool.ExplorerSqlRunMint.Mint</method> -- the own-table legs mint and this goes
/// red.</p>
Method TestTheMintRefusesWhatTheAgentMayNotPropose()
{
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#TOOLNAME)
    Set tCode = ##class(OcuPilot.Api.AtelierError).#SQLAGENTCODE
    For tCase = $ListBuild("SELECT Name FROM OcuProbe196.Granted", "[]", "422 " _ ##class(OcuPilot.Api.AtelierError).#SQLREADS), $ListBuild("CREATE FUNCTION OcuProbe196.AgentFn() RETURNS INT LANGUAGE OBJECTSCRIPT { Quit 7 }", "[]", "422 " _ tCode), $ListBuild("CREATE PROCEDURE OcuProbe196.AgentProc() LANGUAGE OBJECTSCRIPT { Quit }", "[]", "422 " _ tCode), $ListBuild("CREATE METHOD OcuProbe196.AgentMethod() RETURNS INT LANGUAGE OBJECTSCRIPT { Quit 7 }", "[]", "422 " _ tCode), $ListBuild("CREATE QUERY OcuProbe196.AgentQuery() SELECTMODE RUNTIME PROCEDURE BEGIN SELECT 1; END", "[]", "422 " _ tCode), $ListBuild("CREATE TRIGGER OcuProbe196.AgentTrig AFTER INSERT ON OcuProbe196.Granted LANGUAGE OBJECTSCRIPT { Quit }", "[]", "422 " _ tCode), $ListBuild("CREATE AGGREGATE OcuProbe196.AgentAgg(x INT) RETURNS INT ITERATE WITH OcuProbe196.IterFn", "[]", "422 " _ tCode), $ListBuild("CREATE TABLE OcuProbe196.AgentComputed (X INTEGER, Y INTEGER COMPUTECODE { Set {Y} = 1 })", "[]", "422 " _ tCode), $ListBuild("create table OcuProbe196.AgentComputed (X integer, Y integer computecode { Set {Y} = 1 })", "[]", "422 " _ tCode), $ListBuild("SELEKT 1", "[]", "422 " _ ##class(OcuPilot.Api.AtelierError).#SQLNOTPREPARED), $ListBuild("UPDATE OcuProbe196.Granted SET Num = Num WHERE Num = ?", "[]", "422 " _ ##class(OcuPilot.Api.AtelierError).#SQLPARAMETERS), $ListBuild("START TRANSACTION", "[]", "422 EXPLORER.SQL.SESSION"), $ListBuild("GRANT SELECT ON OcuProbe196.Granted TO _PUBLIC", "[]", "422 EXPLORER.SQL.ADMINISTRATION"), $ListBuild("CREATE USER OcuProbe196Nobody IDENTIFY BY 'OcuProbe196NotACredential'", "[]", "422 EXPLORER.SQL.PASSWORD") {
        Set tSC = ..MintFor($List(tCase, 1), [], .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals(..Said(tSC, tHttp, .tFault), $List(tCase, 3), $List(tCase, 1))
    }
    Set tView = $Parameter(..#PROBE, "OWNVIEW")
    Do ##class(OcuPilot.Kernel.Scope).Set($NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    For tText = "UPDATE OcuPilot_Kernel_State.Proposal SET RowVersion = RowVersion WHERE ID < 0", "DELETE FROM " _ tView _ " WHERE ID < 0" {
        Set tArgs = {"Target": "sql", "rationale": "probe", "expectedImpact": "probe", "parameters": []}
        Do tArgs.%Set("statement", tText, "string")
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
        Set tSC = $ClassMethod(..#TOOLCLASS, "View", "", tArgs, 0, .tProposal, .tHttp, .tFault)
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
        Do $$$AssertEquals(..Said(tSC, tHttp, .tFault), "403 PROHIBITED.OCUPILOTSQL", tText)
    }
    Set tSC = ..MintFor($Justify("", 100001), [], .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, tHttp, .tFault), "400 " _ ##class(OcuPilot.Api.AtelierError).#SQLINPUT, "an over-long statement is refused by the console's bounds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#TOOLNAME), tBefore, "no refusal wrote a proposal")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 820", "and nothing changed")

    Do ..Run("CREATE FUNCTION OcuProbe196.AgentFn() RETURNS INT LANGUAGE OBJECTSCRIPT { Quit 7 }", "[]", .tStatus, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("outcome") _ " " _ tAnswer.%Get("kind"), 1: tStatus), "confirm ddl", "the console still asks its confirmation for the statement that carries code")
    Do ..Confirmed("CREATE FUNCTION OcuProbe196.AgentFn() RETURNS INT LANGUAGE OBJECTSCRIPT { Quit 7 }", "[]", .tStatus, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")): tAnswer.output.outcome, 1: tStatus), "done", "and runs it once confirmed")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "HoldsRoutine", "OcuProbe196.AgentFn"), "so the function exists")
}

/// <p>One run of <var>pText</var> on the console's run route, in <parameter>NAMESPACE</parameter>: the
/// HTTP status and the parsed answer.</p>
ClassMethod Run(pText As %String, pValues As %String, Output pStatus As %Integer, Output pAnswer)
{
    Set tBody = {"parameters": ([])}
    Do tBody.%Set("statement", pText, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/explorer/sql/run?ns=" _ ..#NAMESPACE, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tBody2, .tHeaders, tBody.%ToJSON(), "application/json")
    Set pAnswer = ""
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tBody2) } Catch { Set pAnswer = $Get(tBody2) }
}

/// <p>One confirmed run of <var>pText</var> through the screen action, in <parameter>NAMESPACE</parameter>.</p>
ClassMethod Confirmed(pText As %String, pValues As %String, Output pStatus As %Integer, Output pAnswer)
{
    Set tRequest = {"action": "run", "id": "sql"}
    Set tValues = {}
    Do tValues.%Set("statement", pText, "string")
    Do tValues.%Set("parameters", pValues, "string")
    Do tValues.%Set("maxRows", "10", "string")
    Do tRequest.%Set("values", tValues)
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/screens/explorer.sqlquery/action?ns=" _ ..#NAMESPACE, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tBody, .tHeaders, tRequest.%ToJSON(), "application/json")
    Set pAnswer = ""
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch { Set pAnswer = $Get(tBody) }
}

/// <p>AC9: a plain schema change is minted with the console's schema sentence and the statement's own
/// kind, type and table; <method>OcuPilot.Screen.Tool.ExplorerSqlRun.Consequence</method> words a call and
/// an unclassified kind in their own sentences, not the data-change one.</p>
/// <p>Mutation (Rule 19): make <method>Consequence</method> answer <parameter>CONSEQUENCEROWS</parameter>
/// for every kind -- the DDL leg and the kind legs go red.</p>
Method TestTheConsequenceNamesTheKindOfStatement()
{
    Do $$$AssertStatusOK(..EnableKey(), "the key is enabled")
    Set tSC = ..MintFor("CREATE TABLE OcuProbe196.Moved (X INTEGER)", [], .tProposal, .tHttp, .tFault, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertStatusOK(tSC, "a plain CREATE TABLE is minted: " _ ..Said(tSC, tHttp, .tFault))
    If $IsObject($Get(tProposal)) {
        Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerTransfer).Stored(tProposal.%Get("proposalId"), "consequence"), "EXPLORER.SQL.CHANGESSCHEMA", "its consequence is the schema sentence")
        Set tRows = ""
        Set tIterator = tProposal.changed.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tRows = tRows _ $Select(tRows = "": "", 1: "|") _ tRow.field _ "=" _ tRow.after
        }
        Do $$$AssertTrue(tRows [ "Kind=ddl|StatementType=", "and its card reads the kind ddl: " _ tRows)
    }
    For tCase = $ListBuild("dml", "EXPLORER.SQL.CHANGESROWS"), $ListBuild("ddl", "EXPLORER.SQL.CHANGESSCHEMA"), $ListBuild("call", "EXPLORER.SQL.RUNSPROCEDURE"), $ListBuild("other", "EXPLORER.SQL.UNDECLARED") {
        Do $$$AssertEquals($ClassMethod(..#TOOLCLASS, "Consequence", {"Kind": ($List(tCase, 1))}), $List(tCase, 2), "kind " _ $List(tCase, 1))
    }
}

/// <p>AC8, AC9, AD-6, AD-15, AD-22, AD-39: at the baseline the agent's UPDATE is refused
/// <code>GOVERNANCE.DISABLED</code> with nothing minted; once the key is enabled it mints a card of the
/// destructive treatment and no typed name -- the statement, its values, <code>Kind</code> dml,
/// <code>StatementType</code> 3 and the table -- with the console's consequence code; its confirm changes
/// the table once and answers the run's outcome; and the marker and the ledger row carry no statement
/// text and no outcome.</p>
/// <p>Mutation (Rule 19): set <code>READSVALUES</code> 0 on
/// <class>OcuPilot.Screen.Tool.ExplorerSqlRun</class> -- the mint reads an empty guard, the card's
/// <code>Kind</code> row reads empty and the confirm closes as a moved target, and this goes red.</p>
Method TestTheAgentsUpdateIsGovernedThenMintedAndConfirmed()
{
    Set tText = "UPDATE OcuProbe196.Granted SET Num = 3"
    Set tSC = ..Dispatch(tText, [], .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError _ "|" _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent), "1|{""code"":""GOVERNANCE.DISABLED""}", "at the baseline the agent's UPDATE is refused by governance")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 820", "with the table unchanged")
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#TOOLNAME), 0, "and no proposal minted")

    Do $$$AssertStatusOK(..EnableKey(), "the key is enabled through its stored setting")
    Set tSince = $ZDateTime($ZTimeStamp, 3, 1, 3)
    Set tSC = ..Dispatch(tText, [], .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError, 0, "with the key enabled the call mints: " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent))
    If '$IsObject(tContent) || tIsError Quit
    Set tRows = ""
    Set tIterator = tContent.changed.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tRows = tRows _ $Select(tRows = "": "", 1: "|") _ tRow.field _ "=" _ tRow.after
    }
    Do $$$AssertEquals(tRows, "statement=" _ tText _ "|parameters=[]|Kind=dml|StatementType=3|Tables=OCUPROBE196.GRANTED", "the card shows the statement, its values, the kind, the type and the table: " _ tRows)
    Do $$$AssertEquals(tContent.target.type _ " " _ tContent.target.scope _ " " _ tContent.target.id, "class " _ ..#NAMESPACE _ " sql", "its target is the console's")
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerTransfer).Stored(tContent.proposalId, "destructive"), 1, "it takes the destructive treatment")
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerTransfer).Stored(tContent.proposalId, "consequence"), "EXPLORER.SQL.CHANGESROWS", "with the console's consequence for DML")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 820", "and nothing ran at the mint")

    Set tSC = ..ConfirmIn(tContent, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm answers: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals($Select($IsObject(tResult.%Get("output")): tResult.output.kind _ " " _ tResult.output.outcome _ " " _ tResult.output.rowCount, 1: ""), "dml done 40", "it answers the run's outcome")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 120", "and the table changed once")
    Do $$$AssertEquals(tResult.%Get("auditMarked"), 1, "marked (AD-15)")
    Set tMarkers = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, ##class(OcuPilot.Test.AuditMarker).MarkerName(), ..#TOOLNAME, .tData)
    Do $$$AssertEquals(tMarkers, 1, "one agent marker names the run")
    Do $$$AssertTrue((tData '[ "UPDATE") && (tData '[ "OcuProbe196") && (tData '[ "rowCount"), "and carries no statement text and no outcome: " _ tData)
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(Name) = ? AND Kind = 'write'", ..#TOOLNAME)
    Do $$$AssertEquals($Select((tRS.%SQLCODE = 0) && tRS.%Next(): tRS.%Get("N"), 1: -1), 1, "one ledger row records the write")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(Name) = ? AND (Arguments [ 'rowCount' OR Fields [ 'rowCount' OR Target [ 'rowCount' OR Code [ 'rowCount')", ..#TOOLNAME)
    Do $$$AssertEquals($Select((tRS.%SQLCODE = 0) && tRS.%Next(): tRS.%Get("N"), 1: -1), 0, "and none holds the run's rows, SQLCODE or message")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC9, AD-6: a statement whose table is dropped between the mint and the confirm closes as a moved
/// target, because the fingerprint covers the statement's tables; nothing runs. A person's own Run reads
/// the same guard on its fresh read as the mint did.</p>
/// <p>Mutation (Rule 19): set <code>READSVALUES</code> 0 -- the screen action's fresh read answers an
/// empty guard and the second leg goes red.</p>
Method TestAMovedTargetIsRefusedAndAPersonsRunReadsTheSameGuard()
{
    Do $$$AssertStatusOK(..EnableKey(), "the key is enabled")
    Do ..Confirmed("CREATE TABLE OcuProbe196.Moved (X INTEGER)", "[]", .tStatus, .tAnswer)
    Do ..Confirmed("INSERT INTO OcuProbe196.Moved (X) VALUES (1)", "[]", .tStatus, .tAnswer)
    Set tText = "UPDATE OcuProbe196.Moved SET X = 2"
    Set tSC = ..MintFor(tText, [], .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's UPDATE of the probe table is minted")
    If '$IsObject($Get(tProposal)) Quit

    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tBody = {"action": "run", "id": "sql", "values": {"parameters": "[]", "maxRows": "10"}}
    Do tBody.values.%Set("statement", tText, "string")
    Set tSC = ##class(OcuPilot.Test.ScreenActionProbe).PreviewOf(..#DESCRIPTOR, tBody, .tPreview)
    Do $$$AssertStatusOK(tSC, "a person's Run resolves up to its write")
    If $IsObject($Get(tPreview)) {
        Do $$$AssertEquals(tPreview.fresh.Kind _ " " _ tPreview.fresh.StatementType _ " " _ tPreview.fresh.Tables.%ToJSON(), "dml 3 [""OCUPROBE196.MOVED""]", "its fresh read is the statement's own guard")
        Set tRows = ""
        Set tIterator = tPreview.diff.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tRows = tRows _ $Select(tRows = "": "", 1: "|") _ tRow.field _ "=" _ tRow.after
        }
        Do $$$AssertTrue(tRows [ "Kind=dml|StatementType=3|Tables=OCUPROBE196.MOVED", "and its rows read the kind, the type and the table the mint's card did: " _ tRows)
    }

    Do ..Confirmed("DROP TABLE OcuProbe196.Moved", "[]", .tStatus, .tAnswer)
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "HoldsTable", "OcuProbe196.Moved"), "the table is dropped under the card")
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a moved target")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "HoldsTable", "OcuProbe196.Moved"), "and nothing was re-created or run")
}

/// <p>DW-1964: a principal granted SELECT on one table is refused the mint of a change to another with
/// <code>EXPLORER.SQL.NOTPREPARED</code> and the instance's -99, with no proposal; the same principal
/// is minted a change to the table it may update only if the instance prepares it.</p>
/// <p>Mutation (Rule 19): prepare with privilege checks off in <method>OcuPilot.Port.SqlPort.Prepared</method>
/// -- the mint succeeds for the ungranted table and this goes red.</p>
Method TestAPrincipalWithoutThePrivilegeIsRefusedTheMint()
{
    Do $$$AssertStatusOK(..EnableKey(), "the key is enabled")
    Set tUser = $Parameter(..#PROBE, "USER")
    Set tLegs = [{"op": "mint", "namespace": (..#NAMESPACE), "statement": "UPDATE OcuProbe196.Hidden SET Num = 3"}, {"op": "mint", "namespace": (..#NAMESPACE), "statement": "CREATE TABLE OcuProbe196.Made (X INTEGER)"}]
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", tUser, tLegs.%ToJSON())
    For tI = 0, 1 {
        Set tLeg = $Select($IsObject(tProbe) && (tProbe.%GetTypeOf("legs") = "array"): tProbe.legs.%Get(tI), 1: "")
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.http _ " " _ tLeg.code _ " " _ tLeg.faultSqlcode, 1: "absent " _ $Select($IsObject(tProbe): tProbe.%Get("error"), 1: "")), "422 " _ ##class(OcuPilot.Api.AtelierError).#SQLNOTPREPARED _ " -99", "the principal's change to a table it holds no privilege on is not minted (leg " _ tI _ ")")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted", $Parameter(..#PROBE, "HIDDEN")), "2 3", "the ungranted table is unchanged")
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#TOOLNAME), 0, "and no proposal was written")
}

}
