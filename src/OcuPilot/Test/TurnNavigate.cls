/// <p>The navigation directive's wire and ordering behaviors (Story 4.7, AD-11 rule 3):
/// <class>OcuPilot.Kernel.State.Nav</class>'s own read-back and settle contract, the client-fulfilled
/// branch of <class>OcuPilot.Kernel.Agent.Loop</class> end to end through
/// <class>OcuPilot.Test.TurnLoopProbe</class> (announce, wait, settle, lapse), and
/// <code>POST /turn/:id/navigation</code>'s closed body vocabulary and HTTP status mapping. The
/// registry and schema refusals are <class>OcuPilot.Test.ToolNavigate</class>'s.</p>
/// <p><b>Live-safe.</b> Every turn reserved here runs as <code>$Username</code> -- the suite's own
/// already-authenticated identity -- so nothing new is created on the instance except one HTTP
/// round trip as <code>_SYSTEM</code> (<method>TestAC10WireStatusCodes</method>), which reserves and
/// removes its own turn and skips its assertions rather than failing if <code>_SYSTEM</code>
/// already holds a turn slot on this shared instance.</p>
Class OcuPilot.Test.TurnNavigate Extends %UnitTest.TestCase
{

Parameter LOOP = "OcuPilot.Test.TurnLoopProbe";

Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

Parameter PROBEKEY = "probe-local-abcdefghijklmnop";

/// <p>Literal, so <file>scripts/check-objectscript.py</file>'s wire-test rule finds this route
/// named in this file (Consistency Conventions; the same idiom
/// <class>OcuPilot.Test.TurnWire</class>'s own <parameter>PROGRESSROUTE</parameter> uses).</p>
Parameter NAVIGATIONROUTE = "/turn/:id/navigation";

Property PreparedKeys [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Kill ..PreparedKeys
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do $ClassMethod(..#PORT, "SetSslState", "present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do $ClassMethod(..#LOOP, "Reset")
    ; Every method in this class runs a navigating turn, whose model, tool and announce steps
    ; need more than the base probe's narrowed step cap of 2, and whose wait must not run out the
    ; shipped 60-second NAVWAITSECONDS.
    Do $ClassMethod(..#LOOP, "SetLimitsClass", "OcuPilot.Test.TurnLimitsNav")
    Kill ..PreparedKeys
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#LOOP, "Reset")
    Set tKey = ""
    For {
        Set tKey = $Order(..PreparedKeys(tKey))
        If tKey = "" Quit
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tKey), "turn " _ tKey _ " is removed")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining), "the probe definitions are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>An enabled probe definition on the stub transport, narrow iteration cap so a scripted
/// two-call turn (tool call, then the reply) lands on a clean natural completion.</p>
Method Definition() As %String
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = "OcuPilotProbeAgentTurnNavigate"
    Set tRow.Provider = "probe-local"
    Set tRow.Model = "probe-local-model-1"
    Set tRow.EndpointUrl = "https://api.anthropic.com/v1/messages"
    Set tRow.CredType = "env"
    Set tRow.EnvVarName = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tRow.MaxTokens = 4000
    Set tRow.MaxIterationsPerTurn = 10
    Set tRow.Enabled = 1
    Set tRow.ConnectionVerified = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow), "a probe definition is created")
    Set tId = tRow.%Id()
    Set tRow = ""
    Quit tId
}

Method Reserve(pDefinitionId As %String, pUser As %String = {$Username}) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedReserve(pUser, pDefinitionId, "TURN.ABANDONED.JOBLOST", $ClassMethod(..#LOOP, "LimitsClass"), .tKey, .tBusy, .tSweep)
    Do $$$AssertStatusOK(tSC, "the turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and the slot was free")
    If tKey '= "" Set ..PreparedKeys(tKey) = ""
    Quit tKey
}

Method Begin(pKey As %String, pUser As %String = {$Username}) As %Integer
{
    Set tLimits = $ClassMethod(..#LOOP, "LimitsClass")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(pKey, pUser, tLimits, .tBegun, .tStarted), "the turn begins")
    Do $$$AssertEquals(tBegun, 1, "in this process")
    Quit tStarted
}

/// <p>A provider reply requesting <code>shell_screen_open</code> with <var>pRoute</var> /
/// <var>pEntityId</var>.</p>
ClassMethod NavReply(pRoute As %String, pEntityId As %String = "") As %String
{
    Set tInput = {"route": (pRoute)}
    If pEntityId '= "" Do tInput.%Set("entityId", pEntityId, "string")
    Set tBody = {"content": [], "usage": {"input_tokens": 1, "output_tokens": 0}}
    Do tBody.%Set("stop_reason", "tool_use", "string")
    Do tBody.content.%Push({"type": "tool_use", "id": "toolu_nav", "name": "shell_screen_open", "input": (tInput)})
    Quit tBody.%ToJSON()
}

/// <p>A plain <code>end_turn</code> reply, so a scripted second call ends the turn naturally.</p>
ClassMethod EndReply(pText As %String = "done") As %String
{
    Quit {"content": [{"type": "text", "text": (pText)}], "stop_reason": "end_turn", "usage": {"input_tokens": 1, "output_tokens": 1}}.%ToJSON()
}

/// <hr/>
/// <p>AD-11 rule 3, AC3: <code>Nav.GuardedRequest</code> refuses a <code>Seq</code> naming no
/// committed <code>announce</code> step for that turn -- the ordering guarantee that makes a
/// directive impossible to observe before its announcement is in the transcript.</p>
Method TestAC3RequestRefusesOrphanSeq()
{
    Set tId = ..Definition()
    Set tKey = ..Reserve(tId)
    Set tSC = ##class(OcuPilot.Kernel.State.Nav).GuardedRequest(tKey, 999, "tasks/schedule", "")
    Do $$$AssertStatusNotOK(tSC, "a seq naming no announce step is refused")
}

/// <p>AC3: with a genuine announce step, <code>Turn.GuardedView</code> pairs the pending directive
/// with it; once the step is gone (the shape a fixture-written orphan row takes), the view omits
/// <code>navigation</code> even though the Nav row itself still exists and is unsettled.</p>
Method TestAC3ViewPairsThenOmitsOrphan()
{
    Set tId = ..Definition()
    Set tKey = ..Reserve(tId)
    Set tLimits = $ClassMethod(..#LOOP, "LimitsClass")
    Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey, "announce", "shell.screen.open", "running", "", "", "", tLimits, .tSeq, .tStored, "tasks/schedule", "", "", "", "", 0)
    Do $$$AssertStatusOK(tSC, "the announce step is appended")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Nav).GuardedRequest(tKey, tSeq, "tasks/schedule", ""), "the directive is requested")

    Set tViewSC = ##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, $Username, .tFound, .tView)
    Do $$$AssertStatusOK(tViewSC, "the view reads")
    Do $$$AssertTrue(tFound, "found")
    Do $$$AssertTrue(tView.%IsDefined("navigation"), "paired with its announcement, the directive is exposed")
    Do $$$AssertEquals(tView.navigation.seq, tSeq, "naming the announce step's own seq")
    Do $$$AssertEquals(tView.navigation.route, "tasks/schedule", "and the route")

    Set tDel = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ? AND Seq = ?", tKey, tSeq)
    Do $$$AssertTrue(tDel.%SQLCODE >= 0, "the step is removed directly")

    Set tViewSC2 = ##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, $Username, .tFound2, .tView2)
    Do $$$AssertStatusOK(tViewSC2, "the view still reads")
    Do $$$AssertTrue('tView2.%IsDefined("navigation"), "an orphaned directive is never surfaced")
}

/// <p>AC10: the settle claim itself -- a second settle for the same directive, and one naming the
/// wrong seq, both answer <var>pClaimed</var> 0 (the caller renders 409); a directive settled once
/// stays settled.</p>
Method TestAC10SettleClaimIsExactlyOnce()
{
    Set tId = ..Definition()
    Set tKey = ..Reserve(tId)
    Set tLimits = $ClassMethod(..#LOOP, "LimitsClass")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey, "announce", "shell.screen.open", "running", "", "", "", tLimits, .tSeq, .tStored, "tasks/schedule", "", "", "", "", 0), "announced")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Nav).GuardedRequest(tKey, tSeq, "tasks/schedule", ""), "requested")

    Do ##class(OcuPilot.Kernel.State.Nav).GuardedSettle(tKey, tSeq, "opened", "", .tClaimed1)
    Do $$$AssertEquals(tClaimed1, 1, "the first settle claims it")

    Do ##class(OcuPilot.Kernel.State.Nav).GuardedSettle(tKey, tSeq, "opened", "", .tClaimed2)
    Do $$$AssertEquals(tClaimed2, 0, "a second settle of the same directive does not")

    Do ##class(OcuPilot.Kernel.State.Nav).GuardedSettle(tKey, tSeq + 1, "opened", "", .tClaimed3)
    Do $$$AssertEquals(tClaimed3, 0, "nor does one naming the wrong seq")

    ; An unrelated key naming no directive at all -- Nav.GuardedSettle answers purely from its own
    ; table, so this needs no second reserved turn (which would race this user's own one-turn
    ; slot).
    Do ##class(OcuPilot.Kernel.State.Nav).GuardedSettle("OcuPilotProbeNoSuchTurn", tSeq, "opened", "", .tClaimed4)
    Do $$$AssertEquals(tClaimed4, 0, "nor a turn with no pending directive at all")
}

/// <p>AC10: <code>Api.Turn.NavigationViolation</code>'s closed body vocabulary --
/// <code>{seq, outcome, code}</code> only, <code>outcome</code> one of
/// <code>opened</code>/<code>refused</code>, and <code>code</code> exactly
/// <code>NAV.REFUSEDUNSAVED</code> or <code>null</code> -- so the client can never author
/// model-visible text.</p>
Method TestAC10NavigationBodyVocabulary()
{
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).NavigationViolation({"seq": 1, "outcome": "opened", "code": ""}, .s1, .o1, .c1), 1, "opened may not carry a string code")
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).NavigationViolation({"seq": 1, "outcome": "opened"}, .s2, .o2, .c2), 0, "opened with no code key validates")
    Do $$$AssertEquals(o2, "opened", "outcome is answered")
    Do $$$AssertEquals(c2, "", "code is empty")
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).NavigationViolation({"seq": 1, "outcome": "refused", "code": "NAV.REFUSEDUNSAVED"}, .s3, .o3, .c3), 0, "refused with the one accepted code validates")
    Do $$$AssertEquals(c3, "NAV.REFUSEDUNSAVED", "carried through")
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).NavigationViolation({"seq": 1, "outcome": "refused", "code": "NAV.UNAVAILABLE"}, .s4, .o4, .c4), 1, "any other code on refused is refused")
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).NavigationViolation({"seq": 1, "outcome": "maybe", "code": (0)}, .s5, .o5, .c5), 1, "an outcome outside the closed set is refused")
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).NavigationViolation({"seq": 0, "outcome": "opened"}, .s6, .o6, .c6), 1, "seq must be at least 1")
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).NavigationViolation({"seq": 1, "outcome": "opened", "extra": 1}, .s7, .o7, .c7), 1, "an unknown key is refused")
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).NavigationViolation("not an object", .s8, .o8, .c8), 1, "a non-object body is refused")
}

/// <hr/>
/// <p>AC2: a call refused before <code>Directive</code> answers (an off-list route already failed
/// the schema, so this exercises a route the target descriptor cannot resolve for -- the
/// <code>NAV.ROUTEUNKNOWN</code> re-check) writes no announce step and no directive.</p>
Method TestAC2RefusalWritesNoAnnounceOrDirective()
{
    Set tId = ..Definition()
    ; A built, enum-listed route, so the schema (AC2's own first row) admits the call and this
    ; exercises the *tool body's* refusal instead -- entityId against a none-id screen.
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..NavReply("agent/switches", "x"))
    Set tKey = ..Reserve(tId)
    Set tStarted = ..Begin(tKey)
    Set tSC = $ClassMethod(..#LOOP, "Run", tKey, $Username, tId, "open something", 0, ##class(OcuPilot.Api.Router).#ADMINRESOURCES, tStarted, .tOutcome)
    Do $$$AssertStatusOK(tSC, "the loop returns")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, $Username, tOutcome("state"), tOutcome("code"), tOutcome("limit"), tOutcome("reply"), tOutcome("errorSeq"), $ClassMethod(..#LOOP, "LimitsClass")), "and finished")

    Set tRowsSC = ##class(OcuPilot.Kernel.State.Step).GuardedRows(tKey, .tRows)
    Do $$$AssertStatusOK(tRowsSC, "the steps read")
    Set tHasAnnounce = 0
    Set tToolError = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.kind = "announce" Set tHasAnnounce = 1
        If tRow.kind = "tool" Set tToolError = tRow.code
    }
    Do $$$AssertEquals(tHasAnnounce, 0, "no announce step was ever written")
    Do $$$AssertEquals(tToolError, "NAV.ENTITYNOTALLOWED", "the tool step itself carries the refusal")

    Set tPendingSC = ##class(OcuPilot.Kernel.State.Nav).GuardedPending(tKey, .tPSeq, .tPRoute, .tPEntity, .tPSettled, .tPOutcome, .tPCode)
    Do $$$AssertStatusOK(tPendingSC, "the directive reads")
    Do $$$AssertEquals(tPSeq, 0, "no directive was ever requested")
}

/// <hr/>
/// <p>AC7: the departing screen refuses (the browser posts <code>refused</code> /
/// <code>NAV.REFUSEDUNSAVED</code>) -- an ordinary result, <code>is_error</code> false, and the
/// announce step settles <code>error</code> so the panel withdraws it.</p>
Method TestAC7BrowserRefusesUnsaved()
{
    Set tId = ..Definition()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..NavReply("tasks/schedule"))
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..EndReply("acknowledged"))
    Set tKey = ..Reserve(tId)
    Set tStarted = ..Begin(tKey)

    Job ##class(OcuPilot.Test.NavSettleJob).SettleWhenPending(tKey, "refused", "NAV.REFUSEDUNSAVED", 10)

    Set tSC = $ClassMethod(..#LOOP, "Run", tKey, $Username, tId, "open tasks", 0, ##class(OcuPilot.Api.Router).#ADMINRESOURCES, tStarted, .tOutcome)
    Do $$$AssertStatusOK(tSC, "the loop returns")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, $Username, tOutcome("state"), tOutcome("code"), tOutcome("limit"), tOutcome("reply"), tOutcome("errorSeq"), $ClassMethod(..#LOOP, "LimitsClass")), "and finished")

    Set tSC2 = ##class(OcuPilot.Kernel.State.Step).GuardedRows(tKey, .tRows)
    Do $$$AssertStatusOK(tSC2, "the steps read")
    Set tAnnounceStatus = ""
    Set tToolContent = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.kind = "announce" Set tAnnounceStatus = tRow.status _ "|" _ tRow.code
        If (tRow.kind = "tool") && (tRow.name = "shell.screen.open") Set tToolContent = tRow.status
    }
    Do $$$AssertEquals(tAnnounceStatus, "error|NAV.REFUSEDUNSAVED", "the announce step settles error, withdrawn")
    Do $$$AssertEquals(tToolContent, "ok", "the tool step itself is an ordinary, not-error outcome (AD-11 invariant 3)")
}

/// <hr/>
/// <p>AC8: no browser ever answers -- the wait lapses at <code>NAVWAITSECONDS</code> (narrowed to
/// 2 seconds by <class>OcuPilot.Test.TurnLimitsNav</class>), the announcement is withdrawn, and the
/// turn continues to its next provider call rather than hanging.</p>
Method TestAC8NoBrowserAnswerLapsesToUnavailable()
{
    Set tId = ..Definition()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..NavReply("tasks/schedule"))
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..EndReply("no browser answered"))
    Set tKey = ..Reserve(tId)
    Set tStarted = ..Begin(tKey)

    Set tBefore = $ZHorolog
    Set tSC = $ClassMethod(..#LOOP, "Run", tKey, $Username, tId, "open tasks", 0, ##class(OcuPilot.Api.Router).#ADMINRESOURCES, tStarted, .tOutcome)
    Set tElapsed = $ZHorolog - tBefore
    Do $$$AssertStatusOK(tSC, "the loop returns")
    Do $$$AssertTrue(tElapsed < 30, "the wait was bounded by NAVWAITSECONDS, not a real clock (" _ tElapsed _ "s)")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn continues to its next provider call rather than hanging")
    Do $$$AssertEquals(tOutcome("reply"), "no browser answered", "with that call's own reply")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, $Username, tOutcome("state"), tOutcome("code"), tOutcome("limit"), tOutcome("reply"), tOutcome("errorSeq"), $ClassMethod(..#LOOP, "LimitsClass")), "and finished")

    Set tSC2 = ##class(OcuPilot.Kernel.State.Step).GuardedRows(tKey, .tRows)
    Do $$$AssertStatusOK(tSC2, "the steps read")
    Set tAnnounceStatus = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.kind = "announce" Set tAnnounceStatus = tRow.status _ "|" _ tRow.code
    }
    Do $$$AssertEquals(tAnnounceStatus, "error|NAV.UNAVAILABLE", "the announcement is withdrawn")

    Set tPendingSC = ##class(OcuPilot.Kernel.State.Nav).GuardedPending(tKey, .tPSeq, .tPRoute, .tPEntity, .tPSettled, .tPOutcome, .tPCode)
    Do $$$AssertStatusOK(tPendingSC, "the directive reads")
    Do $$$AssertEquals(tPSettled, 1, "the loop settled it itself so a late answer cannot land")
    Do $$$AssertEquals(tPOutcome, "unavailable", "as unavailable")
}

/// <hr/>
/// <p>The I/O matrix's "Stop pressed during the wait" row: a stop lands while
/// <code>AnswerClientCall</code>'s own wait loop is running (before <code>NAVWAITSECONDS</code>
/// elapses and before any browser answers), and <code>Boundary</code> ends the turn at its next
/// 250 ms pass rather than the wait running out -- the same bound this class's own header
/// promises ("cut short by the turn's own stop... on every pass") for the browser-never-answers
/// case above, exercised here for the sibling case where the wait is cut short deliberately.</p>
/// <p>Mutation: drop the <code>Boundary</code> call from
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerClientCall</method>'s wait loop -> this test times out
/// waiting for a "stopped" outcome that never comes, since only the 2-second
/// <parameter>NAVWAITSECONDS</parameter> lapse would end it instead.</p>
Method TestStopDuringTheWaitEndsTheTurnAtTheNextPass()
{
    Set tId = ..Definition()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..NavReply("tasks/schedule"))
    Set tKey = ..Reserve(tId)
    Set tStarted = ..Begin(tKey)

    Job ##class(OcuPilot.Test.NavSettleJob).StopWhenPending(tKey, $Username, 10)

    Set tBefore = $ZHorolog
    Set tSC = $ClassMethod(..#LOOP, "Run", tKey, $Username, tId, "open tasks", 0, ##class(OcuPilot.Api.Router).#ADMINRESOURCES, tStarted, .tOutcome)
    Set tElapsed = $ZHorolog - tBefore
    Do $$$AssertStatusOK(tSC, "the loop returns")
    Do $$$AssertTrue(tElapsed < 30, "the stop landed well inside NAVWAITSECONDS, not the 2s lapse itself (" _ tElapsed _ "s)")
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("code"), "stopped|TURN.STOPPED", "the turn stops rather than lapsing to NAV.UNAVAILABLE")

    Set tSC2 = ##class(OcuPilot.Kernel.State.Step).GuardedRows(tKey, .tRows)
    Do $$$AssertStatusOK(tSC2, "the steps read")
    Set tToolStatus = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.kind = "tool") && (tRow.name = "shell.screen.open") Set tToolStatus = tRow.status
    }
    Do $$$AssertEquals(tToolStatus, "stopped", "the tool step itself settles stopped, the only record of where the turn stopped")
}

/// <hr/>
/// <p>AC9: the client-fulfilled branch never invokes <code>View</code> -- a successful navigated
/// call's tool step reads <code>ok</code>, never the <code>NAV.NOTINSTANCE</code> mis-wiring fault
/// <class>OcuPilot.Test.ToolNavigate</class> pins directly against <code>View</code> itself.</p>
Method TestAC9SuccessfulCallNeverInvokesView()
{
    Set tId = ..Definition()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..NavReply("permissions/users", "_SYSTEM"))
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..EndReply("opened"))
    Set tKey = ..Reserve(tId)
    Set tStarted = ..Begin(tKey)

    Job ##class(OcuPilot.Test.NavSettleJob).SettleWhenPending(tKey, "opened", "", 10)

    Set tSC = $ClassMethod(..#LOOP, "Run", tKey, $Username, tId, "open users", 0, ##class(OcuPilot.Api.Router).#ADMINRESOURCES, tStarted, .tOutcome)
    Do $$$AssertStatusOK(tSC, "the loop returns")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, $Username, tOutcome("state"), tOutcome("code"), tOutcome("limit"), tOutcome("reply"), tOutcome("errorSeq"), $ClassMethod(..#LOOP, "LimitsClass")), "and finished")

    Set tSC2 = ##class(OcuPilot.Kernel.State.Step).GuardedRows(tKey, .tRows)
    Do $$$AssertStatusOK(tSC2, "the steps read")
    Set tToolStatus = ""
    Set tToolResult = ""
    Set tAnnounceText = "unset"
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.kind = "tool") && (tRow.name = "shell.screen.open") {
            Set tToolStatus = tRow.status
            Set tToolResult = tRow.arguments
        }
        If tRow.kind = "announce" Set tAnnounceText = tRow.text
    }
    Do $$$AssertEquals(tToolStatus, "ok", "the tool step is an ordinary success, never NAV.NOTINSTANCE")
    Do $$$AssertEquals(tAnnounceText, "_SYSTEM", "the announce step's own entity id survives settling, not wiped to empty")
}

/// <hr/>
/// <p>AC10: the real, routed <code>POST /turn/:id/navigation</code> handler over an actual HTTP
/// round trip -- the checker's own wire-marker rule
/// (<file>scripts/check-objectscript.py</file>) and one genuine end-to-end confirmation that the
/// route is wired into <class>OcuPilot.Api.Router</class>'s real <code>UrlMap</code>.</p>
/// <p>Reserved as <code>_SYSTEM</code> deliberately (not a throwaway principal): this route's
/// behavior does not depend on which administrative account calls it, and creating a new IRIS user
/// on a shared development instance is exactly what
/// <class>OcuPilot.Test.TurnWire</class>'s own arming gate exists to avoid outside a throwaway
/// container. If <code>_SYSTEM</code> already holds a turn slot on this instance the assertions are
/// skipped rather than failing -- a slot collision says nothing about this route.</p>
Method TestAC10WireStatusCodes()
{
    Set tId = ..Definition()
    Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedReserve("_SYSTEM", tId, "TURN.ABANDONED.JOBLOST", $ClassMethod(..#LOOP, "LimitsClass"), .tKey, .tBusy, .tSweep)
    Do $$$AssertStatusOK(tSC, "the reserve call itself succeeds")
    If tBusy {
        Do $$$AssertTrue(1, "_SYSTEM already holds a turn slot on this instance; the wire assertions were skipped")
        Quit
    }
    Set ..PreparedKeys(tKey) = ""
    Set tLimits = $ClassMethod(..#LOOP, "LimitsClass")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey, "announce", "shell.screen.open", "running", "", "", "", tLimits, .tSeq, .tStored, "tasks/schedule", "", "", "", "", 0), "announced")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Nav).GuardedRequest(tKey, tSeq, "tasks/schedule", ""), "requested")

    Set tPath = $Replace(..#NAVIGATIONROUTE, ":id", tKey)
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot" _ tPath, "_SYSTEM", "SYS", .tStatus, .tText, .tHeaders, "{""seq"":" _ tSeq _ ",""outcome"":""opened""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "a valid settle answers 200: " _ tText)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    If tStatus = 200 Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText).settled, 1, "carrying settled")

    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot" _ tPath, "_SYSTEM", "SYS", .tStatus2, .tText2, .tHeaders2, "{""seq"":" _ tSeq _ ",""outcome"":""opened""}", "application/json")
    Do $$$AssertEquals(tStatus2, 409, "settling the same directive twice is refused: " _ tText2)
    If tStatus2 = 409 Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText2).code, "STATE.CONFLICT", "naming STATE.CONFLICT")

    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot" _ tPath, "_SYSTEM", "SYS", .tStatus3, .tText3, .tHeaders3, "{""seq"":1,""outcome"":""maybe""}", "application/json")
    Do $$$AssertEquals(tStatus3, 422, "an outcome outside the closed set is refused: " _ tText3)
    If tStatus3 = 422 Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText3).code, "TURN.NAVIGATION.INVALID", "naming TURN.NAVIGATION.INVALID")

    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/turn/nosuchturn/navigation", "_SYSTEM", "SYS", .tStatus4, .tText4, .tHeaders4, "{""seq"":1,""outcome"":""opened""}", "application/json")
    Do $$$AssertEquals(tStatus4, 404, "an unknown turn id is not found: " _ tText4)
    If tStatus4 = 404 Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText4).code, "TURN.NOTFOUND", "naming TURN.NOTFOUND")
}

}
