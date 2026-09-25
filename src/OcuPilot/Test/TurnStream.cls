/// <p>Story 11.7 through real turn jobs against the <code>turnprobe</code> row (AD-7, AD-33,
/// AD-42): while a streamed call runs, its model step's <code>text</code> is a non-empty prefix of
/// the reply; the turn ends with the reply and step text a plain run ends with; a stream broken at
/// half fails the turn <code>PROVIDER.TRANSPORT</code> after one call with the step text cleared and
/// no reply; the same write proposal is minted streamed and plain; a refusal fails the turn
/// <code>PROVIDER.DECLINED</code> either way; and <class>OcuPilot.Kernel.Agent.StreamStep</class>
/// writes at most once per interval and never past the cap.</p>
/// <p><b>It creates an IRIS user and a role and spawns turn jobs, so
/// <method>OnBeforeAllTests</method> refuses to run unless <parameter>ARMINGVARIABLE</parameter>
/// reads 1</b>, which only <file>scripts/ci-throwaway.sh</file> sets. The principal also holds the
/// web application screen's pairs, so the write tool mints; every proposal it minted, and every
/// probe job, turn, slot and stub node, is removed after each method.</p>
Class OcuPilot.Test.TurnStream Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "turnstream-probe";

/// <p>The tag a plain run of the same script answers under.</p>
Parameter PLAINTAG = "turnstream-plain";

/// <p>The class declaring the name the turn's model step carries.</p>
Parameter LOOP = "OcuPilot.Kernel.Agent.Loop";

/// <p>The limits the cadence probe writes under: a 16-character text cap.</p>
Parameter PROBELIMITS = "OcuPilot.Test.TurnLimits";

/// <p>The owner of the cadence probe's turn row.</p>
Parameter PROBEUSER = "OcuPilotProbeTurnStreamStep";

/// <p>The web application the write proposal targets, which the demo fixture serves.</p>
Parameter TARGET = "/csp/myapp";

Property PreparedPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnStream creates an IRIS user and a role and runs turn jobs against the turnprobe provider row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources") _ ",%Admin_Secure:U,%DB_IRISSYS:R")
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tId
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnStream teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG, ..#PLAINTAG))
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds)
    Set tSC = ##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly(..PreparedDefinitionId, 0)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser($Parameter(..#FIXTURE, "USERA"))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG, ..#PLAINTAG)), "", "no probe job, turn, slot or stub node survives the method")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds), "the switches are reset")
    Do ##class(OcuPilot.Test.StreamStepProbe).ResetClock()
    Quit $$$OK
}

/// <p>A Markdown reply long enough to stream across many snapshots.</p>
ClassMethod LongReply() As %String
{
    Set tText = "## Findings" _ $Char(10, 10)
    For tI = 1:1:12 Set tText = tText _ "- Row " _ tI _ " of the list, with `code` and **bold** text in it." _ $Char(10)
    Quit tText _ $Char(10) _ "Done."
}

/// <p>Start a turn on the definition's current tag, and answer its id.</p>
Method Start(pMessage As %String = "what is on this screen") As %String
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedPassword, .tConvStatus, .tConvText)
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "StartBody", pMessage, tConvId), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    If tStatus '= 202 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tText).turnId
}

/// <p>Wait for turn <var>pId</var> to end, and answer its last progress view.</p>
Method AwaitView(pId As %String, pSeconds As %Integer = 60) As %DynamicObject
{
    Do $ClassMethod(..#FIXTURE, "AwaitEnd", pId, $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, pSeconds, .tView)
    Quit $Select($IsObject($Get(tView)): tView, 1: "")
}

/// <p>The last model step of <var>pView</var>, or <code>""</code>.</p>
ClassMethod ModelStep(pView As %DynamicObject) As %DynamicObject
{
    Set tStep = ""
    If '$IsObject(pView) || '$IsObject(pView.steps) Quit tStep
    Set tIterator = pView.steps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tOne) {
        If (tOne.kind = "model") && (tOne.name = $Parameter(..#LOOP, "MODELSTEP")) Set tStep = tOne
    }
    Quit tStep
}

/// <p>Poll turn <var>pId</var>'s progress until its running model step carries text, and answer
/// the distinct non-empty texts seen while it ran, in order, in <var>pTexts</var>.</p>
Method AwaitSnapshots(pId As %String, pSeconds As %Integer, Output pTexts) As %Integer
{
    Kill pTexts
    Set pTexts = 0
    Set tDeadline = $ZHorolog + pSeconds
    For {
        Do $ClassMethod(..#FIXTURE, "Call", "GET", "/turn/" _ pId _ "/progress", $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, "", .tStatus, .tText, .tHeaders)
        Set tView = $Select(tStatus = 200: ##class(%DynamicObject).%FromJSON(tText), 1: "")
        Set tStep = ..ModelStep(tView)
        If $IsObject(tStep) && (tStep.status = "running") && (tStep.text '= "") && ($Get(pTexts(pTexts)) '= tStep.text) Set pTexts($Increment(pTexts)) = tStep.text
        If (pTexts >= 2) || ($ZHorolog > tDeadline) Quit
        If $IsObject(tView) && ##class(OcuPilot.Kernel.State.Turn).IsTerminal(tView.state) Quit
        Hang 0.2
    }
    Quit pTexts
}

/// <p>Mid-call the running model step's text is non-empty, grows, and is a prefix of the reply;
/// the turn ends with the reply and step text a plain run of the same script ends with.</p>
/// <p>mutation: pass no sink from <method>OcuPilot.Kernel.Agent.Loop.Run</method>'s
/// <code>Invoke</code> -- the mid-call snapshot assertions go red.</p>
Method TestAStreamedReplyGrowsAndEndsAsThePlainOne()
{
    Set tReply = ..LongReply()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).ScriptStream(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply(tReply), 4), "the streamed reply is scripted")
    Set tId = ..Start()
    If tId = "" Quit
    Set tSeen = ..AwaitSnapshots(tId, 20, .tTexts)
    Do $$$AssertTrue(tSeen >= 1, "mid-call, the running model step carries text")
    Do $$$AssertTrue(tSeen >= 2, "which grows between two reads: " _ tSeen _ " distinct")
    For tI = 1:1:tSeen {
        Do $$$AssertEquals($Extract(tReply, 1, $Length(tTexts(tI))), tTexts(tI), "snapshot " _ tI _ " is a prefix of the reply")
    }
    Set tView = ..AwaitView(tId)
    Do $$$AssertEquals($Select($IsObject(tView): tView.state, 1: ""), "completed", "the streamed turn completes")
    If '$IsObject(tView) Quit
    Set tStep = ..ModelStep(tView)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "stream"), 1, "the call asked for a stream")

    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).Plain(..#PLAINTAG), "the plain tag is plain")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).Script(..#PLAINTAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply(tReply)), "the plain reply is scripted")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#PLAINTAG), "the definition names the plain tag")
    Set tPlainId = ..Start()
    If tPlainId = "" Quit
    Set tPlainView = ..AwaitView(tPlainId)
    If '$IsObject(tPlainView) Quit
    Set tPlainStep = ..ModelStep(tPlainView)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(..#PLAINTAG, 1, "stream"), 0, "the plain call asked for no stream")
    Do $$$AssertEquals(tView.reply, tPlainView.reply, "the streamed reply equals the plain one")
    Do $$$AssertEquals(tView.reply, tReply, "and is the scripted reply")
    Do $$$AssertEquals($Select($IsObject(tStep): tStep.status _ "|" _ tStep.text, 1: ""), $Select($IsObject(tPlainStep): tPlainStep.status _ "|" _ tPlainStep.text, 1: "-"), "and the model step ends as the plain one does")
}

/// <p>A stream broken at half fails the turn <code>PROVIDER.TRANSPORT</code> after one call, the
/// model step <code>error</code> with its text cleared, and no reply.</p>
/// <p>mutation: in <method>OcuPilot.Kernel.Agent.Loop.Run</method>'s fault branch, pass the step's
/// streamed text to <code>GuardedUpdate</code> instead of <code>""</code> -- the step-text
/// assertion goes red.</p>
Method TestABreakAtHalfFailsTheTurnWithNoReply()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).ScriptStream(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply(..LongReply()), 1, 1), "the broken stream is scripted")
    Set tId = ..Start()
    If tId = "" Quit
    Set tView = ..AwaitView(tId)
    Do $$$AssertEquals($Select($IsObject(tView): tView.state, 1: ""), "failed", "the turn fails")
    If '$IsObject(tView) Quit
    Do $$$AssertEquals($Select($IsObject(tView.error): tView.error.code, 1: ""), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "PROVIDER.TRANSPORT")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 1, "after one call, never retried")
    Set tStep = ..ModelStep(tView)
    Do $$$AssertEquals($Select($IsObject(tStep): tStep.status _ "|" _ tStep.text, 1: ""), "error|", "the model step is error with its streamed text cleared")
    Do $$$AssertEquals(tView.%GetTypeOf("reply"), "null", "and there is no reply")
}

/// <p>The same write proposal streamed and plain mints the same proposal: tool, target, changed and
/// unchanged fields, the three sentences, and the stored fingerprint and arguments, ids and times
/// excluded.</p>
/// <p>mutation: drop the <code>input_json_delta</code> branch of
/// <method>OcuPilot.Kernel.Provider.StreamAdapter.TakeAnthropic</method> -- the streamed turn mints
/// nothing and this goes red.</p>
Method TestAStreamedWriteProposalEqualsThePlainOne()
{
    Set tInput = {"rationale": "The application carries no description.", "expectedImpact": "the list names what it is for", "reverse": "clear the description again"}
    Do tInput.%Set("Name", ..#TARGET, "string")
    Do tInput.%Set("Description", "Streamed probe " _ $ZTimeStamp, "string")
    Set tCalls = [{"id": "toolu_stream", "name": "webapp_list_update"}]
    Do tCalls.%Get(0).%Set("input", tInput)
    Set tUse = ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tCalls)
    Set tDone = ##class(OcuPilot.Test.TurnProvider).TextReply("I proposed the change.")

    Do ##class(OcuPilot.Test.TurnProvider).ScriptStream(..#TAG, 0, tUse)
    Do ##class(OcuPilot.Test.TurnProvider).ScriptStream(..#TAG, 0, tDone)
    Set tId = ..Start("describe my application")
    If tId = "" Quit
    Set tView = ..AwaitView(tId)
    Do $$$AssertEquals($Select($IsObject(tView): tView.state, 1: ""), "completed", "the streamed turn completes")

    Do ##class(OcuPilot.Test.TurnProvider).Plain(..#PLAINTAG)
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#PLAINTAG, 0, tUse)
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#PLAINTAG, 0, tDone)
    Do $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#PLAINTAG)
    Set tPlainId = ..Start("describe my application")
    If tPlainId = "" Quit
    Set tPlainView = ..AwaitView(tPlainId)
    Do $$$AssertEquals($Select($IsObject(tPlainView): tPlainView.state, 1: ""), "completed", "the plain turn completes")
    If '$IsObject(tView) || '$IsObject(tPlainView) Quit

    Do $$$AssertEquals(tView.proposals.%Size() _ "|" _ tPlainView.proposals.%Size(), "1|1", "each turn minted one proposal")
    If (tView.proposals.%Size() '= 1) || (tPlainView.proposals.%Size() '= 1) Quit
    Do $$$AssertEquals(..Comparable(tView.proposals.%Get(0)), ..Comparable(tPlainView.proposals.%Get(0)), "the streamed proposal's card equals the plain one's")
    Do $$$AssertEquals(..Stored(tId), ..Stored(tPlainId), "and so do the stored tool, target, fingerprint and arguments")
    Do $$$AssertTrue(..Stored(tId) [ "webapp.list.update", "naming the write tool")
}

/// <p><var>pRow</var>, a wire proposal, with its id and expiry removed, as JSON.</p>
ClassMethod Comparable(pRow As %DynamicObject) As %String
{
    Set tCopy = ##class(%DynamicAbstractObject).%FromJSON(pRow.%ToJSON())
    Do tCopy.%Remove("proposalId")
    Do tCopy.%Remove("expiresAt")
    Quit tCopy.%ToJSON()
}

/// <p>The stored tool, target, fingerprint and arguments of turn <var>pTurnKey</var>'s one
/// proposal, joined.</p>
ClassMethod Stored(pTurnKey As %String) As %String
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(TurnKey) = ?", pTurnKey)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit "(none)"
    Set tRow = ##class(OcuPilot.Kernel.State.Propose).%OpenId(tRS.%GetData(1))
    If '$IsObject(tRow) Quit "(unreadable)"
    Set tArguments = ""
    If $IsObject(tRow.Arguments) {
        Do tRow.Arguments.Rewind()
        Set tArguments = tRow.Arguments.Read(1000000)
    }
    Quit tRow.ToolName _ "|" _ tRow.TargetRef _ "|" _ tRow.Fingerprint _ "|" _ tArguments
}

/// <p>A refusal, plain and streamed, fails the turn <code>PROVIDER.DECLINED</code> with the code's
/// sentence and no reply (DW-1181).</p>
/// <p>mutation: remove the refusal branch from <method>OcuPilot.Kernel.Agent.Loop.Run</method> --
/// both turns complete with a reply and this goes red.</p>
Method TestARefusalFailsTheTurnDeclinedEitherWay()
{
    Set tRefusal = "{""content"":[{""type"":""text"",""text"":""I can""}],""stop_reason"":""refusal"",""usage"":{""input_tokens"":5,""output_tokens"":2}}"
    Set tDeclined = ##class(OcuPilot.Api.Error).#PROVIDERDECLINED
    Do ##class(OcuPilot.Test.TurnProvider).ScriptStream(..#TAG, 0, tRefusal)
    Set tId = ..Start()
    If tId = "" Quit
    Set tView = ..AwaitView(tId)
    Do ##class(OcuPilot.Test.TurnProvider).Plain(..#PLAINTAG)
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#PLAINTAG, 0, tRefusal)
    Do $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#PLAINTAG)
    Set tPlainId = ..Start()
    If tPlainId = "" Quit
    Set tPlainView = ..AwaitView(tPlainId)
    For tCase = "streamed", "plain" {
        Set tOne = $Select(tCase = "streamed": tView, 1: tPlainView)
        Do $$$AssertEquals($Select($IsObject(tOne): tOne.state, 1: ""), "failed", tCase _ ": the turn fails")
        If '$IsObject(tOne) Continue
        Do $$$AssertEquals($Select($IsObject(tOne.error): tOne.error.code, 1: ""), tDeclined, tCase _ ": PROVIDER.DECLINED")
        Do $$$AssertEquals($Select($IsObject(tOne.error): tOne.error.reason, 1: ""), ##class(OcuPilot.Kernel.Provider.Base).ReasonFor(tDeclined), tCase _ ": with the code's one sentence")
        Do $$$AssertEquals(tOne.%GetTypeOf("reply"), "null", tCase _ ": and no reply")
        Set tStep = ..ModelStep(tOne)
        Do $$$AssertEquals($Select($IsObject(tStep): tStep.status _ "|" _ tStep.text _ "|" _ tStep.code, 1: ""), "error||" _ tDeclined, tCase _ ": the model step is error, empty, carrying the code")
        Do $$$AssertEquals(..LedgerOutcome($Select(tCase = "streamed": tId, 1: tPlainId)), "error|" _ tDeclined, tCase _ ": and so is the provider call's ledger row")
    }
}

/// <p>The status and code of turn <var>pTurnKey</var>'s provider-call ledger rows, joined.</p>
ClassMethod LedgerOutcome(pTurnKey As %String) As %String
{
    Set tOut = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Status, Code FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ? AND %EXACT(Kind) = ? ORDER BY Seq", pTurnKey, $Parameter("OcuPilot.Kernel.State.Ledger", "KINDLLM"))
    If tRS.%SQLCODE < 0 Quit "(unreadable)"
    While tRS.%Next() {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ";") _ tRS.%GetData(1) _ "|" _ tRS.%GetData(2)
    }
    Quit tOut
}

/// <p>The stream step writes the first text at once, then at most once per
/// <code>STREAMINTERVALMS</code> and only when the text grew, never past
/// <code>TEXTMAXLENGTH</code>, and never onto a step that is no longer running.</p>
/// <p>mutation: ignore <code>STREAMINTERVALMS</code> in
/// <method>OcuPilot.Kernel.Agent.StreamStep.Publish</method> -- the second assertion goes red.</p>
Method TestTheStreamStepKeepsItsCadenceAndCap()
{
    Set tUser = ..#PROBEUSER
    Set tLimits = ..#PROBELIMITS
    Set tInterval = +$Parameter(tLimits, "STREAMINTERVALMS")
    Do $$$AssertEquals(tInterval, 400, "the interval is 400 ms")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", tLimits, .tKey, .tBusy, .tSweep), "a turn is reserved")
    If $Get(tKey) = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, tLimits, .tBegun, .tStarted), "and begun")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey, "model", $Parameter(..#LOOP, "MODELSTEP"), "running", "", "", "", tLimits, .tSeq), "a running model step is appended")
    Set tSink = ##class(OcuPilot.Test.StreamStepProbe).%New(tKey, tSeq, tLimits)
    Set tFull = "abcdefghijklmnopqrstuvwxyz"

    Do ##class(OcuPilot.Test.StreamStepProbe).SetClock(1000)
    Do tSink.Publish($Extract(tFull, 1, 2))
    Do $$$AssertEquals(..StepText(tKey), "ab", "the first text is written at once")
    Do ##class(OcuPilot.Test.StreamStepProbe).SetClock(1000 + tInterval - 1)
    Do tSink.Publish($Extract(tFull, 1, 6))
    Do $$$AssertEquals(..StepText(tKey), "ab", "a longer text inside the interval is not written")
    Do ##class(OcuPilot.Test.StreamStepProbe).SetClock(1000 + tInterval)
    Do tSink.Publish($Extract(tFull, 1, 8))
    Do $$$AssertEquals(..StepText(tKey), "abcdefgh", "once the interval has passed it is")
    Do ##class(OcuPilot.Test.StreamStepProbe).SetClock(1000 + (3 * tInterval))
    Do tSink.Publish($Extract(tFull, 1, 8))
    Do $$$AssertEquals(tSink.LastWriteMs, 1000 + tInterval, "a text that did not grow is not written")
    Do tSink.Publish($Extract(tFull, 1, 20))
    Do $$$AssertEquals(..StepText(tKey), $Extract(tFull, 1, 16), "a text past the cap is cut at TEXTMAXLENGTH")
    Do ##class(OcuPilot.Test.StreamStepProbe).SetClock(1000 + (5 * tInterval))
    Do tSink.Publish(tFull)
    Do $$$AssertEquals(tSink.LastLength, 20, "and nothing is written once the cap was reached")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedUpdate(tKey, tSeq, "ok", "done", "final", "", tLimits), "the step ends")
    Set tLate = ##class(OcuPilot.Test.StreamStepProbe).%New(tKey, tSeq, tLimits)
    Do tLate.Publish("a late snapshot")
    Do $$$AssertEquals(..StepText(tKey), "final", "a snapshot after the outcome changes nothing")
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "final", 0, tLimits)
}

/// <p>The text of turn <var>pKey</var>'s first step.</p>
ClassMethod StepText(pKey As %String) As %String
{
    Do ##class(OcuPilot.Kernel.State.Step).GuardedRows(pKey, .tRows)
    If '$IsObject($Get(tRows)) || (tRows.%Size() = 0) Quit "(no step)"
    Quit tRows.%Get(0).%Get("text")
}

}
