/// <p>Pins Story 21.6's four statement writes on both permitted callers (AC2, AC3, AC5; AD-6, AD-10, AD-22, AD-51, AD-53, AD-58): a plan frozen and
/// unfrozen by the screen's row action and by the agent's confirmed proposal, each read back as nothing sent and each refused before any write when
/// the statement is not in the state the action needs; a statement's statistics and plan error cleared the same way; a proposal whose statement
/// changed after it was minted closed target-changed; the instance's own refusal answered 409 <code>SQL.STATEMENT.VENDOR</code> with its message in
/// <code>detail</code> alone; and a statement over one of OcuPilot's own tables refused <code>PROHIBITED.OCUPILOTSQL</code> on both callers, before
/// any write.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, which holds
/// <code>%Development:USE</code> and WRITE on <code>USER</code>'s and the install namespace's routines databases, and a <code>USER</code> namespace,
/// where each test makes <class>OcuPilot.Test.SqlTuningProbe</class>'s objects and removes them after. The own-statement test runs one statement over
/// OcuPilot's own table in the install namespace and puts its plan state and plan error back, which a mutation that lets the write through changes
/// and the test restores. It snapshots the stored governance policy before and puts it back after.</p>
Class OcuPilot.Test.SqlStatementWrite Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter FIXTURE = "OcuPilot.Test.SqlTuningPortFixture";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter SCREEN = "explorer.sqlstatements";

Parameter NAMESPACE = "USER";

Parameter OWNNAMESPACE = "HSCUSTOM";

Parameter FREEZE = "OcuPilot.Screen.Tool.ExplorerSqlStatementFreeze";

Parameter UNFREEZE = "OcuPilot.Screen.Tool.ExplorerSqlStatementUnfreeze";

Parameter CLEARSTATISTICS = "OcuPilot.Screen.Tool.ExplorerSqlStatementClearStatistics";

Parameter CLEARERROR = "OcuPilot.Screen.Tool.ExplorerSqlStatementClearError";

Parameter CLEAN = "OcuPilot.Screen.Tool.ExplorerSqlStatementClean";

Property PreparedPolicy [ MultiDimensional ];

Property PreparedOwn As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedOwn = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do $ClassMethod(..#SEAM, "Reset")
    Kill ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Make", ..#NAMESPACE)
    Do $$$AssertStatusOK(tSC, "the probe objects are created in " _ ..#NAMESPACE)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "RemoveOwn", ..#OWNNAMESPACE, ..PreparedOwn)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#NAMESPACE), "every probe object is removed")
    Do $ClassMethod(..#SEAM, "Reset")
    Kill ^||OcuPilotDatabaseWritePort
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>The screen action <var>pAction</var> on <var>pId</var> over HTTP, in namespace <var>pNamespace</var>, as the suite's account: the status, and
/// the parsed answer in <var>pAnswer</var>.</p>
ClassMethod Act(pAction As %String, pId As %String, pNamespace As %String = {..#NAMESPACE}, Output pAnswer As %DynamicObject, pScreen As %String = {..#SCREEN}) As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/" _ pScreen _ "/action?ns=" _ pNamespace, .tStatus, .pAnswer, tBody.%ToJSON())
    Quit $Select($$$ISOK(tSC): tStatus, 1: 0)
}

/// <p>The status and refusal code an answer carries, as <code>status code</code>.</p>
ClassMethod Verdict(pStatus As %Integer, pAnswer As %DynamicObject) As %String
{
    Quit pStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The agent's proposal of tool <var>pTool</var> for <var>pId</var> -- named under <var>pArgument</var> -- minted and confirmed in
/// <var>pNamespace</var>: <code>mint &lt;problem&gt;</code> when the mint refused, else the confirm's <code>http code</code>. The proposal is in
/// <var>pProposal</var> and the confirm's answer in <var>pResult</var>.</p>
ClassMethod Agent(pTool As %String, pId As %String, pArgument As %String = "Hash", pNamespace As %String = {..#NAMESPACE}, Output pProposal As %DynamicObject, Output pResult As %DynamicObject) As %String
{
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Set ^||OcuPilotDatabaseWritePort = $Parameter(pTool, "PORTCLASS")
    Set tArgs = {}
    Do tArgs.%Set(pArgument, pId, "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", pTool, pId, tArgs, .pProposal, .tHttp, .tProblem)
    If $$$ISERR(tSC) Quit "mint " _ tHttp _ " " _ tProblem
    Quit $ClassMethod(..#AGENT, "Confirm", pProposal, .pResult)
}

/// <p>The probe statement's hash, <code>SELECT A</code> on the first table by default.</p>
ClassMethod Hash(pToken As %String = "SELECT A FROM") As %String
{
    Quit $ClassMethod(..#PROBE, "HashOf", ..#NAMESPACE, pToken)
}

/// <p>The instance's own call <var>pWhat</var>, <code>freeze</code> or <code>error</code> (the plan error text <var>pText</var>), on <var>pHash</var> in
/// <var>pNamespace</var>, made outside the product's write path, so a test puts a statement in the state an action needs.</p>
ClassMethod Call(pNamespace As %String, pWhat As %String, pHash As %String, pText As %String = "")
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If pWhat = "freeze" Do $SYSTEM.SQL.Statement.FreezeStatement(pHash)
        If pWhat = "error" Do UpdateSQLIndex^%SYS.SQLSRV(pHash, pText)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>The probe statement's plan state, plan error and executions as the information schema holds them, as <code>PlanState|PlanError|Executions</code>.</p>
ClassMethod State(pHash As %String, pNamespace As %String = {..#NAMESPACE}) As %String
{
    Set tFacts = $ClassMethod(..#PROBE, "Facts", pNamespace, pHash)
    Quit tFacts.PlanState _ "|" _ tFacts.PlanError _ "|" _ tFacts.Executions
}

/// <p>The five tools declare what the story rules: names, the one port, endpoint, request types, who reaches each, that none is destructive and
/// none sends a body, the screen actions each carries, the governance keys -- on for the writes that can be undone and off for the two whose effect
/// cannot -- the target the clean names, and the pairs each requires, the classic SQL page's resource among them.</p>
/// <p>Mutation (Rule 19): set <code>DESTRUCTIVE</code> 1 on the freeze -> the destructive assertion goes red.</p>
Method TestTheToolsDeclareTheirWritePath()
{
    For tCase = $ListBuild(..#FREEZE, "explorer.sqlstatements.freeze", "FREEZE", "freeze", 1), $ListBuild(..#UNFREEZE, "explorer.sqlstatements.unfreeze", "UNFREEZE", "unfreeze", 1), $ListBuild(..#CLEARSTATISTICS, "explorer.sqlstatements.clearstatistics", "CLEARSTATISTICS", "clear-statistics", 0), $ListBuild(..#CLEARERROR, "explorer.sqlstatements.clearerror", "CLEARERROR", "clear-error", 1), $ListBuild(..#CLEAN, "explorer.sqlstatements.clean", "CLEAN", "clean", 0) {
        Set tTool = $List(tCase, 1)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "WriteType"), $List(tCase, 2) _ "|OcuPilot.Port.SqlPort|Statements|STATEMENT|" _ $List(tCase, 3), $List(tCase, 2) _ ": name, port, endpoint and request types")
        Do $$$AssertEquals($ClassMethod(tTool, "Advertised") _ $ClassMethod(tTool, "Destructive") _ $ClassMethod(tTool, "SendsBody") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")), "100|" _ $List(tCase, 4), $List(tCase, 2) _ ": advertised, not destructive, no body, one screen action")
        Do ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 2), .tListed)
        Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve($List(tCase, 2), "write", .tEnabled, .tSource)
        Do $$$AssertEquals(tListed _ " " _ ''$Get(tEnabled), "1 " _ $List(tCase, 5), $List(tCase, 2) _ ": its key is in the baseline and ships " _ $Select($List(tCase, 5): "enabled", 1: "disabled"))
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved && ($ListFind(tPairs, $ListBuild("%Development", "USE")) > 0), $List(tCase, 2) _ ": its pairs hold the Explorer's")
    }
    Do $$$AssertEquals($ClassMethod(..#FREEZE, "Consequence", {}) _ "|" _ $ClassMethod(..#UNFREEZE, "Consequence", {}) _ "|" _ $ClassMethod(..#CLEARSTATISTICS, "Consequence", {}) _ "|" _ $ClassMethod(..#CLEARERROR, "Consequence", {}) _ "|" _ $ClassMethod(..#CLEAN, "Consequence", {}), "SQL.STATEMENT.FREEZE|SQL.STATEMENT.UNFREEZE|SQL.STATEMENT.CLEARSTATISTICS|SQL.STATEMENT.CLEARERROR|SQL.STATEMENT.CLEAN", "each carries its consequence code")
    Do $$$AssertEquals($ClassMethod(..#CLEAN, "IdProblem", "*") _ "|" _ ($ClassMethod(..#CLEAN, "IdProblem", ..Hash()) '= "") _ "|" _ ($ClassMethod(..#FREEZE, "IdProblem", "*") '= "") _ "|" _ ($ClassMethod(..#FREEZE, "IdProblem", ..Hash()) = "") _ "|" _ ($ClassMethod(..#FREEZE, "IdProblem", "a b") '= ""), "|1|1|1|1", "a clean takes the literal * alone, and each other tool a hash alone")
}

/// <p>AC2. The plan is frozen and unfrozen by the screen's action and by the agent's confirmed proposal; the row reads <code>Frozen/Explicit</code>
/// and then <code>Unfrozen</code> as the information schema holds it, each answer's read-back reads <code>nothingSent</code>, and a freeze of a
/// frozen plan and an unfreeze of an unfrozen one are refused with their sentences before any write, on both callers.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.StatementCall</code> calls <code>UnfreezeStatement</code> for <code>FREEZE</code> -> the frozen-state
/// assertions go red; the freeze tool's <code>Holds</code> admits a frozen plan -> its refusal assertions go red.</p>
Method TestAPlanIsFrozenAndUnfrozenOnBothCallers()
{
    Set tHash = ..Hash()
    Do $$$AssertEquals(..State(tHash), "Unfrozen||3", "the probe statement is unfrozen")
    Set tConfirm = ..Agent(..#FREEZE, tHash, , , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..State(tHash), "200 |Frozen/Explicit||3", "the agent's confirmed freeze freezes the plan: " _ tConfirm)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpDataServerWrite).Verdict($Get(tResult)), "nothingSent", "and its read-back reads nothing sent")
    Set tStatus = ..Act("freeze", tHash, , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "400 TOOL.ARGUMENTS", "the screen's freeze of a frozen plan is refused before any write")
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.detail): tAnswer.detail.problem, 1: ""), ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTALREADYFROZEN, "with its sentence")
    Set tConfirm = ..Agent(..#FREEZE, tHash, , , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm, "mint 400 " _ ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTALREADYFROZEN, "and so is the agent's")
    Set tStatus = ..Act("unfreeze", tHash, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..State(tHash), "200|Unfrozen||3", "the screen's unfreeze returns the plan to unfrozen")
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpDataServerWrite).Verdict(tAnswer), "nothingSent", "its read-back reads nothing sent")
    Set tConfirm = ..Agent(..#UNFREEZE, tHash, , , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm, "mint 400 " _ ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTNOTFROZEN, "the agent's unfreeze of an unfrozen plan is refused before any write")
    Set tStatus = ..Act("freeze", tHash, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..State(tHash), "200|Frozen/Explicit||3", "the screen freezes it again")
    Set tConfirm = ..Agent(..#UNFREEZE, tHash, , , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..State(tHash), "200 |Unfrozen||3", "and the agent's unfreeze returns it: " _ tConfirm)
    Set tStatus = ..Act("unfreeze", tHash, , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.detail): tAnswer.detail.problem, 1: ""), "400 TOOL.ARGUMENTS|" _ ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTNOTFROZEN, "the screen's unfreeze of an unfrozen plan is refused with its sentence")
}

/// <p>AC2. A plan in the <code>Unfrozen/Parallel</code> state is refused by the screen's freeze and by the agent's proposal with the parallel
/// plan's own sentence, not the already-frozen one, before any write, and the statement is unchanged. The state is written into the statement
/// index by the probe, since the throwaway's optimizer does not choose a parallel plan for the probe's statements (<code>%PARALLEL</code> over
/// 8,192 rows read <code>Unfrozen</code>); the refusal is keyed on what the fresh read answers.</p>
/// <p>Mutation (Rule 19): the freeze tool's <code>RefusalCode</code> answers its <code>REFUSALCODE</code> for every plan -> both sentence assertions go
/// red; <code>SqlTuningProbe.Remove</code> skips the reset of the plan-state flag -> the last assertion goes red.</p>
Method TestAParallelPlanIsRefusedItsOwnSentenceOnBothCallers()
{
    Set tHash = ..Hash()
    Do $ClassMethod(..#PROBE, "SetPlanFlag", tHash, ..#NAMESPACE, 3)
    Do $$$AssertEquals(..State(tHash), "Unfrozen/Parallel||3", "the probe statement's plan is in the Unfrozen/Parallel state")
    Set tStatus = ..Act("freeze", tHash, , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ ..State(tHash), "400 TOOL.ARGUMENTS|Unfrozen/Parallel||3", "the screen's freeze is refused before any write")
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.detail): tAnswer.detail.problem, 1: ""), ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTPARALLEL, "with the parallel plan's sentence")
    Set tConfirm = ..Agent(..#FREEZE, tHash, , , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..State(tHash), "mint 400 " _ ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTPARALLEL _ "|Unfrozen/Parallel||3", "and so is the agent's, and the plan is unchanged")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#NAMESPACE), "the probe's removal puts the plan-state flag back")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts", ..#NAMESPACE, tHash).PlanState, "Unfrozen", "so the statement reads Unfrozen again")
}

/// <p>AC3. A statement's statistics are cleared by the agent's confirmed proposal and its plan error by the screen's action, each reading blank
/// afterwards while its plan state is unchanged; a clear of the plan error of a statement that has none is refused with its sentence on both
/// callers, and the clear of statistics has no precondition.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.StatementCall</code> answers <code>$$$OK</code> for <code>CLEARSTATISTICS</code> without calling
/// -> the executions assertion goes red; the same for <code>CLEARERROR</code> -> the plan error assertion goes red.</p>
Method TestStatisticsAndAPlanErrorAreCleared()
{
    Set tOne = ..Hash()
    Set tTwo = ..Hash("SELECT B FROM")
    Kill tSettings
    Set tSettings($Parameter(..#CLEARSTATISTICS, "TOOLNAME")) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the clear of statistics, whose key ships disabled, is enabled through its stored setting")
    Do $$$AssertEquals(..State(tOne) _ "~" _ ..State(tTwo), "Unfrozen||3~Unfrozen|" _ ##class(OcuPilot.Test.SqlTuningProbe).#PLANERROR _ "|", "the probe holds statistics on one statement and a plan error on the other")
    Set tConfirm = ..Agent(..#CLEARSTATISTICS, tOne, , , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..State(tOne), "200 |Unfrozen||", "the agent's confirmed clear leaves the executions blank and the plan state as it was: " _ tConfirm)
    Do $ClassMethod(..#PROBE, "SetStatistics", tOne, ..#NAMESPACE)
    Do $$$AssertEquals(..State(tOne), "Unfrozen||3", "the statistics are set again")
    Set tStatus = ..Act("clear-statistics", tOne, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..State(tOne), "200|Unfrozen||", "so does the screen's, with the statistics set again")
    Set tStatus = ..Act("clear-error", tTwo, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..State(tTwo), "200|Unfrozen||", "the screen's clear of the plan error leaves it blank")
    Set tStatus = ..Act("clear-error", tTwo, , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.detail): tAnswer.detail.problem, 1: ""), "400 TOOL.ARGUMENTS|" _ ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTNOERROR, "a second clear is refused with its sentence")
    Set tConfirm = ..Agent(..#CLEARERROR, tTwo, , , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm, "mint 400 " _ ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTNOERROR, "and so is the agent's")
    Do ..Call(..#NAMESPACE, "error", tTwo, "again")
    Set tConfirm = ..Agent(..#CLEARERROR, tTwo, , , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..State(tTwo), "200 |Unfrozen||", "the agent's clear of a plan error set again leaves it blank: " _ tConfirm)
}

/// <p>A proposal whose statement was frozen after it was minted is refused <code>PROPOSAL.TARGETCHANGED</code> at its confirm, and the statement
/// holds the freeze somebody else made, not another change.</p>
/// <p>Mutation (Rule 19): the freeze tool's <code>FINGERPRINTSUBJECT</code> drops <code>PlanState</code> -> the confirm is not refused and goes red.</p>
Method TestAStatementFrozenAfterTheProposalIsRefusedTargetChanged()
{
    Set tHash = ..Hash()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set ^||OcuPilotDatabaseWritePort = $Parameter(..#FREEZE, "PORTCLASS")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#FREEZE, tHash, {"Hash": (tHash)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the proposal is minted: " _ $Get(tProblem))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..State(tHash), "Unfrozen||3", "and the mint changes nothing")
    Do ..Call(..#NAMESPACE, "freeze", tHash)
    Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(tConfirm, "409 PROPOSAL.TARGETCHANGED", "the confirm is refused target-changed: " _ tConfirm)
    Do $$$AssertEquals(..State(tHash), "Frozen/Explicit||3", "the statement holds only the freeze made outside the proposal")
}

/// <p>The instance's own refusal of a statement write is 409 <code>SQL.STATEMENT.VENDOR</code>, its ruled sentence on the wire and the instance's
/// message in <code>detail.message</code> alone; the call is made once, and the statement is unchanged.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.StatementWrite</code> puts the message in the reason -> the reason assertion goes red.</p>
Method TestTheInstancesRefusalIsAnsweredWithItsMessageInDetailAlone()
{
    Set tHash = ..Hash()
    Do $ClassMethod(..#SEAM, "Refuse", "the plan cannot be frozen over an external table")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tHash
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "Statements", "FREEZE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 SQL.STATEMENT.VENDOR", "the refusal is 409 with its code")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), "The instance did not apply this change to the statement.", "its reason is the ruled sentence")
    Do $$$AssertTrue($IsObject($Get(tFault)) && ($ZConvert(tFault.detail.message, "L") [ "external table") && (tFault.reason '[ "external"), "the instance's message is in detail alone: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ ..State(tHash), "1|Unfrozen||3", "one call was made and the statement is unchanged")
}

/// <p>AC5. A statement over <code>OcuPilot_Kernel_State</code> is refused <code>PROHIBITED.OCUPILOTSQL</code> with its published sentence by the
/// screen's four actions and by the agent's four confirmed proposals, and is unchanged: frozen, unfrozen, cleared of its statistics and of its plan
/// error only by the test itself, which freezes and sets an error through the instance's own calls so each precondition holds.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Kernel.Proposal.Prohibited.StatementEntry</code> skips the relations read -> the screen's and the agent's
/// refusals go red, and the test puts the statement back.</p>
Method TestAStatementOverOcuPilotsOwnTableIsRefusedOnBothCallers()
{
    Kill tSettings
    Set tSettings($Parameter(..#CLEARSTATISTICS, "TOOLNAME")) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the clear of statistics is enabled through its stored setting, so only the kernel's arm can refuse the agent's proposal")
    Set tHash = $ClassMethod(..#PROBE, "MakeOwn", ..#OWNNAMESPACE)
    Set ..PreparedOwn = tHash
    Do $$$AssertTrue(tHash '= "", "the statement over OcuPilot's own table is in the index")
    If tHash = "" Quit
    Do $ClassMethod(..#PROBE, "RemoveOwn", ..#OWNNAMESPACE, tHash)
    Do $$$AssertEquals(..State(tHash, ..#OWNNAMESPACE), "Unfrozen||", "unfrozen, with no plan error and no statistics")
    Set tReason = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor("PROHIBITED.OCUPILOTSQL")
    For tCase = $ListBuild(..#FREEZE, "freeze", "Unfrozen||"), $ListBuild(..#UNFREEZE, "unfreeze", "Frozen/Explicit||"), $ListBuild(..#CLEARSTATISTICS, "clear-statistics", "Unfrozen||3"), $ListBuild(..#CLEARERROR, "clear-error", "Unfrozen|probe plan error|") {
        Set tTool = $List(tCase, 1)
        Do $ClassMethod(..#PROBE, "RemoveOwn", ..#OWNNAMESPACE, tHash)
        If $List(tCase, 2) = "unfreeze" Do ..Call(..#OWNNAMESPACE, "freeze", tHash)
        If $List(tCase, 2) = "clear-error" Do ..Call(..#OWNNAMESPACE, "error", tHash, "probe plan error")
        If $List(tCase, 2) = "clear-statistics" Do $ClassMethod(..#PROBE, "SetStatistics", tHash, ..#OWNNAMESPACE)
        Do $$$AssertEquals(..State(tHash, ..#OWNNAMESPACE), $List(tCase, 3), $List(tCase, 2) _ ": the statement is as the action needs it")
        Set tStatus = ..Act($List(tCase, 2), tHash, ..#OWNNAMESPACE, .tAnswer)
        Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ ..State(tHash, ..#OWNNAMESPACE), "403 PROHIBITED.OCUPILOTSQL|" _ $List(tCase, 3), $List(tCase, 2) _ ": the screen's action is refused and the statement is unchanged")
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.reason, 1: ""), tReason, $List(tCase, 2) _ ": with its published sentence")
        Set tConfirm = ..Agent(tTool, tHash, , ..#OWNNAMESPACE, .tProposal, .tResult)
        Do $$$AssertTrue(tConfirm [ "PROHIBITED.OCUPILOTSQL", $List(tCase, 2) _ ": the agent's proposal is refused: " _ tConfirm)
        Do $$$AssertEquals(..State(tHash, ..#OWNNAMESPACE), $List(tCase, 3), $List(tCase, 2) _ ": and the statement is unchanged")
    }
}

}
