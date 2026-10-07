/// <p>Pins Story 20.2's five writes end to end against a probe production in <code>USER</code> (AD-6,
/// AD-7, AD-15, AD-51, AD-52, AD-53, AD-59, AD-62): the Productions row actions over
/// <code>POST /screens/interop.productions/action</code> moving the probe through Stopped, Running,
/// Troubled and Suspended with the list's read agreeing; each action refused by its own code from every
/// state the vendor would answer as a silent success, with the probe left as it was; the agent's start,
/// stop, restart, update and recover minted with their state row and consequence, confirmed, read back
/// and ledgered; a stale proposal refused at the confirm; a confirm sent from another namespace's scope
/// acting on the namespace the proposal read; a stop, restart and update refused 409
/// <code>INTEROP.PRODUCTION.BUSY</code> while an item's message outlasts a shortened cap; and each
/// tool's script.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving
/// over HTTP as <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code>
/// namespace, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it compiles and
/// <b>runs a probe production in <code>USER</code></b>: <class>OcuPilot.Test.ProductionProbe</class>
/// creates the classes <code>OcuPilotProbe.Interop.*</code>, starts, stops and troubles the production
/// and removes everything it made, including its messages, after the last test. It refuses to run while a
/// production of its own is not the one current in <code>USER</code>. One class per run.</p>
Class OcuPilot.Test.InteropControl Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter SEAM = "OcuPilot.Test.InteropGateSeam";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter NAMESPACE = "USER";

/// <p>The scope a confirm is sent from to pin that it acts where the proposal read.</p>
Parameter OTHERSCOPE = "HSCUSTOM";

Parameter SCREEN = "/screens/interop.productions";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OTHER = "OcuPilotProbe.Interop.Other";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropControl compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

/// <p>Remove the probe production, its classes, its messages and its proposals; a failing status when
/// <code>USER</code> still runs a production.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && ($ClassMethod(..#PROBE, "Current") '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropControl left a production current in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#PROBE, "Settle")
}

/// <p>The probe is left stopped, its proposals removed and its seam restored, whether the test passed or
/// failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Restore")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>One request over the wire as the test account, scoped to <parameter>NAMESPACE</parameter>.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pBody, Output pStatus As %Integer, Output pAnswer) As %Status
{
    Set pAnswer = ""
    Kill tExtra
    Set tJson = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, tJson, $Select(tJson = "": "", 1: "application/json"), .tExtra, 90)
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
    Quit tSC
}

/// <p>One row action as <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod Act(pAction As %String, pId As %String, Output pAnswer) As %String
{
    Do ..Call("POST", ..#SCREEN _ "/action", {"action": (pAction), "id": (pId)}, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The state word the Productions list's read gives <var>pId</var>, <code>""</code> when unlisted.</p>
ClassMethod Listed(pId As %String) As %String
{
    Do ..Call("GET", ..#SCREEN _ "/read?maxRows=1000", "", .tStatus, .tAnswer)
    Set tWord = ""
    If (tStatus = 200) && $IsObject(tAnswer) && $IsObject(tAnswer.%Get("rows")) {
        Set tIterator = tAnswer.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.Name = pId Set tWord = tRow.Status
        }
    }
    Quit tWord
}

/// <p>The probe production's state read through the port as the running account, as
/// <code>State|NeedsUpdate</code>.</p>
ClassMethod State(pId As %String = {..#PRODUCTION}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "STATE", .tQuery, "", .tResult, .tHttp, .tFault)
    If '$IsObject($Get(tResult)) Quit "unread " _ $Get(tHttp)
    Quit tResult.State _ "|" _ tResult.NeedsUpdate
}

/// <p>The probe production's <code>LastStartTime</code> as the Productions list reads it, <code>""</code>
/// when unlisted.</p>
ClassMethod LastStart() As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tTime = ""
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.Name = ..#PRODUCTION Set tTime = tRow.LastStartTime
        }
    }
    Quit tTime
}

/// <p>Start the probe through the port, as the running account.</p>
ClassMethod StartIt() As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION
    Quit $ClassMethod(..#PORT, "Invoke", "Productions", "START", .tQuery, "", .tResult, .tHttp, .tFault)
}

/// <p>Bring the probe to the state <var>pAction</var> needs: stopped for a start, running for a stop or a
/// restart, running with an update pending for an update, and troubled for a recover.</p>
Method Prepare(pAction As %String) As %Status
{
    If pAction = "START" Quit $$$OK
    Set tSC = ..StartIt()
    If $$$ISERR(tSC) Quit tSC
    ; A production started a moment ago is still taking its items' settings, so a setting changed now
    ; may not read as pending; the start settles first.
    Hang 3
    If pAction = "UPDATE" {
        Set tSC = $ClassMethod(..#PROBE, "SetHang", 1)
        If $$$ISERR(tSC) Quit tSC
        For tTry = 1:1:10 {
            If $Piece(..State(), "|", 2) Quit
            Hang 0.5
        }
        Quit $$$OK
    }
    If pAction = "RECOVER" Quit $ClassMethod(..#PROBE, "MakeTroubled")
    Quit $$$OK
}

/// <p>The agent's call of <var>pTool</var> for <var>pName</var>, scoped to <parameter>NAMESPACE</parameter>
/// and minted on a seeded turn.</p>
Method MintFor(pTool As %String, pName As %String, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault, Output pTurn As %String) As %Status
{
    Set pProposal = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurn)
    If $$$ISERR(tSC) Quit tSC
    Set tArgs = {"rationale": "probe", "expectedImpact": "probe"}
    Do tArgs.%Set("Name", pName, "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pTurn)
    Set tSC = $ClassMethod(pTool, "View", "", tArgs, 0, .pProposal, .pHttp, .pFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit tSC
}

/// <p>Confirm <var>pProposal</var> in process as the running account, scoped to <var>pScope</var>.</p>
ClassMethod ConfirmIn(pProposal As %DynamicObject, Output pResult, Output pHttp As %Integer, Output pCode As %String, pScope As %String = {..#NAMESPACE}) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(pScope)
    Quit ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(pProposal)): pProposal.%Get("proposalId"), 1: ""), "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p>The five tools, <code>&lt;class&gt;|&lt;write type&gt;|&lt;state before&gt;|&lt;state after&gt;|&lt;consequence&gt;</code>.</p>
Parameter TOOLS = "InteropProductionStart|START|Stopped|Running|;InteropProductionStop|STOP|Running|Stopped|INTEROP.STOP;InteropProductionRestart|RESTART|Running|Running|INTEROP.RESTART;InteropProductionUpdate|UPDATE|Running|Running|INTEROP.UPDATE;InteropProductionRecover|RECOVER|Troubled|Suspended|INTEROP.RECOVER";

/// <p>Mint and confirm one action as the agent: the card's one state row, the consequence code, the
/// confirm's result (updated, marked, nothing sent, read back), the state the probe is left in, and the
/// ledger row of the confirmed write.</p>
Method Through(pRow As %String)
{
    Set tTool = "OcuPilot.Screen.Tool." _ $Piece(pRow, "|", 1)
    Set tType = $Piece(pRow, "|", 2)
    Set tName = $Parameter(tTool, "TOOLNAME")
    Do $$$AssertStatusOK(..Prepare(tType), tName _ ": the probe is brought to its precondition")
    Set tSC = ..MintFor(tTool, ..#PRODUCTION, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, tName _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%ToJSON() _ "|" _ tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "[{""field"":""State"",""before"":""" _ $Piece(pRow, "|", 3) _ """,""after"":""" _ $Piece(pRow, "|", 4) _ """}]|production|USER|" _ ..#PRODUCTION, tName _ ": its card shows one State row, and the target is the production")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence"), $Piece(pRow, "|", 5), tName _ ": its consequence code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0, 0, tName _ ": it is not destructive")
    Set tStartedBefore = ..LastStart()
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertStatusOK(tSC, tName _ " confirms: " _ $Get(tCode))
    If tType = "RESTART" {
        Set tStartedAfter = ..LastStart()
        Do $$$AssertTrue((tStartedBefore '= "") && (tStartedAfter '= "") && (tStartedAfter ] tStartedBefore), tName _ ": the restart started the production again (LastStartTime " _ tStartedBefore _ " to " _ tStartedAfter _ ")")
    }
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("auditMarked") _ "|" _ tResult.action _ "|" _ tResult.readBack.verdict, 1: ""), "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTHINGSENT, tName _ ": updated, marked (AD-15) and nothing sent")
    Do $$$AssertEquals($Piece(..State(), "|", 1), $Piece(pRow, "|", 4), tName _ ": the probe is left " _ $Piece(pRow, "|", 4))
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ? AND %EXACT(Name) = ?", tTurn, tName)
    Do $$$AssertEquals($Select((tRS.%SQLCODE = 0) && tRS.%Next(): tRS.%Get("N"), 1: -1), 1, tName _ ": the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC2: the agent's start of the stopped probe mints one State row, Stopped to Running, and its
/// confirm starts it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.Perform</method>'s start call
/// <code>RecoverProduction</code> -- the probe is not left Running and this goes red.</p>
Method TestTheAgentsStartConfirms()
{
    Do ..Through($Piece(..#TOOLS, ";", 1))
}

/// <p>AC2: the agent's stop of the running probe carries the 15 second warning as its consequence and
/// leaves it Stopped.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.Perform</method>'s stop call
/// <code>StartProduction</code> -- the production stays Running and this goes red.</p>
Method TestTheAgentsStopConfirms()
{
    Do ..Through($Piece(..#TOOLS, ";", 2))
}

/// <p>AC2: the agent's restart of the running probe leaves it Running, and its <code>LastStartTime</code>
/// has advanced.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.Perform</method>'s restart call a no-op --
/// the probe stays Running and the <code>LastStartTime</code> leg goes red.</p>
Method TestTheAgentsRestartConfirms()
{
    Do ..Through($Piece(..#TOOLS, ";", 3))
}

/// <p>AC2: the agent's update of the running probe whose setting changed leaves it Running and up to
/// date.</p>
Method TestTheAgentsUpdateConfirms()
{
    Do ..Through($Piece(..#TOOLS, ";", 4))
    Do $$$AssertEquals($Piece(..State(), "|", 2), 0, "and nothing is left pending")
}

/// <p>AC2: the agent's recover of the troubled probe carries the recover-before-clean sentence and leaves
/// it Suspended; starting it then gives Running.</p>
/// <p>Mutation (Rule 19): drop <code>Consequence()</code> from
/// <class>OcuPilot.Screen.Tool.InteropProductionAction</class> -- the consequence leg goes red.</p>
Method TestTheAgentsRecoverConfirms()
{
    Do ..Through($Piece(..#TOOLS, ";", 5))
    Do $$$AssertStatusOK(..StartIt(), "a start of the recovered probe is accepted")
    Do $$$AssertEquals($Piece(..State(), "|", 1), "Running", "and reads Running")
}

/// <p>AC2: the Productions row actions take the probe through its states, the list's read agreeing at
/// each: Start, Update (after a setting changed), Restart and Stop, then a Start after the production was
/// troubled and recovered. Each answers 200 with the <code>updated</code> event for the production.</p>
Method TestTheRowActionsMoveTheProbeThroughItsStates()
{
    Do $$$AssertEquals(..Listed(..#PRODUCTION), "Stopped", "the probe is listed Stopped")
    Set tText = ..Act("start", ..#PRODUCTION, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Start answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id, 1: ""), "updated|production|" _ ..#PRODUCTION, "publishing the updated event for the production")
    Do $$$AssertEquals(..Listed(..#PRODUCTION), "Running", "the list then reads Running")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetHang", 1), "a setting changes while it runs")
    Do $$$AssertEquals(..State(), "Running|1", "which reads as an update pending")
    Do $$$AssertEquals(..Act("update", ..#PRODUCTION, .tAnswer), "200 ", "Update answers 200")
    Do $$$AssertEquals(..State(), "Running|0", "and nothing is pending")
    Do $$$AssertEquals(..Act("restart", ..#PRODUCTION, .tAnswer), "200 ", "Restart answers 200")
    Do $$$AssertEquals(..Listed(..#PRODUCTION), "Running", "and the list reads Running again")
    Do $$$AssertEquals(..Act("stop", ..#PRODUCTION, .tAnswer), "200 ", "Stop answers 200")
    Do $$$AssertEquals(..Listed(..#PRODUCTION), "Stopped", "and the list reads Stopped")
    Do $$$AssertStatusOK(..StartIt(), "a start through the port")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeTroubled"), "the production is troubled")
    Do $$$AssertEquals(..Listed(..#PRODUCTION), "Troubled", "the list reads Troubled")
    Do $$$AssertEquals(..Act("recover", ..#PRODUCTION, .tAnswer), "200 ", "Recover answers 200")
    Do $$$AssertEquals(..Listed(..#PRODUCTION), "Suspended", "and the list reads Suspended")
    Do $$$AssertEquals(..Act("start", ..#PRODUCTION, .tAnswer), "200 ", "a Start of the suspended production answers 200")
    Do $$$AssertEquals(..Listed(..#PRODUCTION), "Running", "and the list reads Running")
}

/// <p>AC3: each action the vendor would answer as a silent success, or refuse, is refused by its own 409
/// code with the published sentence before any vendor call, and the probe is left as it was: a start of
/// a running, troubled or other-blocked production, a stop, restart or update of a stopped, suspended or
/// troubled one, an update with nothing pending, and a recover of one that is not troubled.</p>
/// <p>Mutation (Rule 19): remove the <code>NOTRUNNING</code> refusal of stop from
/// <method>OcuPilot.Port.InteropPort.Refusal</method> -- the vendor answers OK, the state is unchanged
/// and the stop legs go red.</p>
Method TestARefusedActionAnswersItsCodeAndLeavesTheProbeAsItWas()
{
    Set tE = "OcuPilot.Api.InteropError"
    ; Stopped.
    For tCase = $ListBuild("stop", "NOTRUNNING"), $ListBuild("restart", "NOTRUNNING"), $ListBuild("update", "NOTRUNNING"), $ListBuild("recover", "NOTTROUBLED") {
        Set tText = ..Act($List(tCase, 1), ..#PRODUCTION, .tAnswer)
        Do $$$AssertEquals(tText _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "409 " _ $Parameter(tE, $List(tCase, 2)) _ "|" _ $Parameter(tE, "REASON" _ $List(tCase, 2)), "Stopped: " _ $List(tCase, 1) _ " is refused")
    }
    Do $$$AssertEquals(..State(), "Stopped|0", "and the probe is still stopped")
    ; Running and up to date.
    Do $$$AssertStatusOK(..StartIt(), "the probe is started")
    For tCase = $ListBuild("start", "RUNNING"), $ListBuild("update", "UPTODATE"), $ListBuild("recover", "NOTTROUBLED") {
        Set tText = ..Act($List(tCase, 1), ..#PRODUCTION, .tAnswer)
        Do $$$AssertEquals(tText _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "409 " _ $Parameter(tE, $List(tCase, 2)) _ "|" _ $Parameter(tE, "REASON" _ $List(tCase, 2)), "Running: " _ $List(tCase, 1) _ " is refused")
    }
    Do $$$AssertEquals(..Act("start", ..#OTHER, .tAnswer) _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "409 " _ $Parameter(tE, "OTHER") _ "|" _ $Parameter(tE, "REASONOTHER"), "another production's Start is refused while this one runs")
    Do $$$AssertEquals(..State(), "Running|0", "and the probe is still running")
    ; Troubled.
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeTroubled"), "the probe is troubled")
    For tCase = $ListBuild("start", "TROUBLED"), $ListBuild("stop", "NOTRUNNING"), $ListBuild("restart", "NOTRUNNING"), $ListBuild("update", "NOTRUNNING") {
        Set tText = ..Act($List(tCase, 1), ..#PRODUCTION, .tAnswer)
        Do $$$AssertEquals(tText _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "409 " _ $Parameter(tE, $List(tCase, 2)) _ "|" _ $Parameter(tE, "REASON" _ $List(tCase, 2)), "Troubled: " _ $List(tCase, 1) _ " is refused")
    }
    Do $$$AssertEquals($Piece(..State(), "|", 1), "Troubled", "and the probe is still troubled")
    ; Suspended.
    Do $$$AssertEquals(..Act("recover", ..#PRODUCTION, .tAnswer), "200 ", "Recover answers 200")
    Do $$$AssertEquals(..Act("stop", ..#PRODUCTION, .tAnswer), "409 " _ $Parameter(tE, "NOTRUNNING"), "Suspended: a stop is refused")
    Do $$$AssertEquals(..Act("recover", ..#PRODUCTION, .tAnswer), "409 " _ $Parameter(tE, "NOTTROUBLED"), "Suspended: a recover is refused")
    Do $$$AssertEquals(..Listed(..#PRODUCTION), "Suspended", "and the probe is still suspended")
    Do $$$AssertEquals(..Act("start", "OcuPilotProbe.No.Such", .tAnswer), "404 PORT.NOTFOUND", "an unknown production is not found")
}

/// <p>AC3, AD-51: a stop minted while the probe runs is refused at the mint when the probe is stopped,
/// with its own code and nothing stored; and a stop minted while it ran, then made unfit out of band, is
/// refused at its confirm as a moved target and stops nothing.</p>
/// <p>Mutation (Rule 19): empty <method>OcuPilot.Screen.Tool.InteropProductionAction.PreconditionCodes</method>
/// -- the confirm's re-read is no longer read as a moved target and this goes red.</p>
Method TestAStopIsRefusedAtTheMintAndAtAMovedConfirm()
{
    Set tTool = "OcuPilot.Screen.Tool.InteropProductionStop"
    Set tSC = ..MintFor(tTool, ..#PRODUCTION, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 " _ ##class(OcuPilot.Api.InteropError).#NOTRUNNING, "a stop of the stopped probe is refused at the mint by its own code")
    Do $$$AssertTrue('$IsObject($Get(tProposal)), "and nothing is minted")
    Do $$$AssertStatusOK(..StartIt(), "the probe is started")
    Set tSC = ..MintFor(tTool, ..#PRODUCTION, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a stop is minted while it runs")
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe is stopped out of band")
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertEquals(+$Get(tConfirmHttp) _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a moved target")
    Do $$$AssertEquals($Piece(..State(), "|", 1), "Stopped", "and the probe is still stopped")
}

/// <p>AD-52: a start minted with <parameter>NAMESPACE</parameter> as its scope and confirmed by a request
/// scoped to <parameter>OTHERSCOPE</parameter> starts the probe in <code>USER</code>, the namespace the
/// proposal read.</p>
/// <p>Mutation (Rule 19): empty <method>OcuPilot.Screen.Tool.InteropProductionAction.PortQuery</method>
/// -- the confirm reads and acts in <parameter>OTHERSCOPE</parameter>, where the production is unknown,
/// and this goes red.</p>
Method TestAConfirmFromAnotherScopeActsInTheProposalsNamespace()
{
    Set tSC = ..MintFor("OcuPilot.Screen.Tool.InteropProductionStart", ..#PRODUCTION, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the start is minted in USER")
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tConfirmHttp, .tCode, ..#OTHERSCOPE)
    Do $$$AssertStatusOK(tSC, "and confirms from " _ ..#OTHERSCOPE _ "'s scope: " _ $Get(tCode))
    Do $$$AssertEquals($Piece(..State(), "|", 1), "Running", "the probe runs in USER")
}

/// <p>AC3, AD-7: with an item's message outlasting a shortened cap, a stop, a restart and an update are
/// each refused 409 <code>INTEROP.PRODUCTION.BUSY</code> within the cap and leave the production
/// Running, which the vendor measured; none waits the shipped 15 seconds.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.Statused</method> answer a busy status
/// as OK -- the busy legs go red.</p>
Method TestABusyProductionIsRefusedAndLeftRunning()
{
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetHang", 12), "the probe operation will hold a message for twelve seconds")
    Do $$$AssertStatusOK(..StartIt(), "the probe is started")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Send"), "a message is queued to the operation")
    Hang 1
    For tPair = $ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_ProductionConfig", "READ"), $ListBuild("%Ens_ProductionRun", "USE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
    }
    Do $ClassMethod(tSeam, "Shorten", 2)
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION
    For tType = "STOP", "RESTART" {
        Set tStart = $ZHorolog
        Set tSC = $ClassMethod(tSeam, "Invoke", "Productions", tType, .tQuery, "", .tResult, .tHttp, .tFault)
        Set tTook = $ZHorolog - tStart
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 " _ ##class(OcuPilot.Api.InteropError).#BUSY, tType _ " of a busy production is refused BUSY")
        Do $$$AssertTrue(tTook < 10, tType _ " waited the shortened cap, not the shipped one: " _ tTook _ " s")
        Do $$$AssertEquals($Piece(..State(), "|", 1), "Running", tType _ ": the production is still Running")
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetHang", 13), "an item's setting changes, so an update is pending")
    Set tSC = $ClassMethod(tSeam, "Invoke", "Productions", "UPDATE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 " _ ##class(OcuPilot.Api.InteropError).#BUSY, "an update that must restart the busy item is refused BUSY")
    Do $$$AssertEquals(..State(), "Running|1", "the production is still Running and still needs the update")
}

/// <p>AD-59: each tool's copy-out draft renders one ObjectScript step that switches to the namespace the
/// proposal read and calls <code>Ens.Director</code> for its action, closes the proposal as a draft, and
/// changes nothing.</p>
Method TestEachToolsDraftRendersItsScript()
{
    Set tCalls = $ListBuild("StartProduction(""" _ ..#PRODUCTION _ """)", "StopProduction(tTimeout, 0)", "RestartProduction(tTimeout, 0)", "UpdateProduction(tTimeout, 0)", "RecoverProduction()")
    For tI = 1:1:5 {
        Set tRow = $Piece(..#TOOLS, ";", tI)
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece(tRow, "|", 1)
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), $Parameter(tTool, "TOOLNAME") _ ": the probe is stopped")
        Do $$$AssertStatusOK(..Prepare($Piece(tRow, "|", 2)), $Parameter(tTool, "TOOLNAME") _ ": the probe is brought to its precondition")
        Set tSC = ..MintFor(tTool, ..#PRODUCTION, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, $Parameter(tTool, "TOOLNAME") _ " mints")
        If '$IsObject($Get(tProposal)) Continue
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(tProposal.proposalId, $Username, "https://draft.example:52773", .tAnswer, .tDraftHttp, .tCode)
        Do $$$AssertStatusOK(tSC, $Parameter(tTool, "TOOLNAME") _ ": the draft is taken: " _ $Get(tCode))
        If '$IsObject($Get(tAnswer)) Continue
        Set tText = tAnswer.draft.steps.%Get(0).text
        Do $$$AssertEquals(tAnswer.state _ "|" _ tAnswer.closedReason _ "|" _ tAnswer.draft.steps.%Get(0).kind, "canceled|draft|objectscript", $Parameter(tTool, "TOOLNAME") _ ": an ObjectScript draft that closes the proposal")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ $List(tCalls, tI)) && (tText '[ "CleanProduction"), $Parameter(tTool, "TOOLNAME") _ ": " _ tText)
        Do $$$AssertEquals($Piece(..State(), "|", 1), $Piece(tRow, "|", 3), $Parameter(tTool, "TOOLNAME") _ ": and nothing changed")
    }
}

}
