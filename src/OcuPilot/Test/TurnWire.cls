/// <p>The three turn routes over HTTP, driven by two least-privileged principals whose turns run as
/// real jobs against the armed <code>turnprobe</code> row (AD-7, AD-8, AD-9, AD-31, AD-33, AD-41):
/// start, body refusals, refused starts, busy with a concurrent pair, the poll's shape, 404 for
/// another principal, the job's identity, revocation and deletion mid-turn, sign-out with both
/// principals running, a lost job, and a UTF-8 message.</p>
/// <p><b>It creates IRIS users and a role and spawns turn jobs, so <method>OnBeforeAllTests</method>
/// refuses to run unless both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PROVIDERVARIABLE</parameter> read 1.</b> Only <file>scripts/ci-throwaway.sh</file>
/// sets them. After every method no probe job is alive and no probe turn, slot or stub node
/// remains.</p>
Class OcuPilot.Test.TurnWire Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "turnwire-probe";

Parameter PROGRESSROUTE = "/turn/:id/progress";

Property PreparedPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnWire creates IRIS users and a role and runs turn jobs, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnWire runs turn jobs against the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tResources = $ClassMethod(..#FIXTURE, "Resources")
    Set tSC = ##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal($Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, tResources)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal($Parameter(..#FIXTURE, "USERB"), ..PreparedPassword, tResources)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tId
    Set ..PreparedSetupOk = ($SYSTEM.Security.CheckUserPermission($Parameter(..#FIXTURE, "USERA"), "%Admin_Operate", "USE") = 1)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = ##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnWire teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Quit $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds)
    Do ##class(OcuPilot.Test.TurnWireFixture).SetRoleResources($ClassMethod(..#FIXTURE, "Resources"))
    Quit $$$OK
}

/// <p>One request, as <var>pUser</var>, to <var>pPath</var> under the API.</p>
Method Call(pMethod As %String, pPath As %String, pUser As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, "/api/ocupilot" _ pPath, pUser, ..PreparedPassword, .pStatus, .pText, .pHeaders, pBody, "application/json")
}

/// <p>Post a start as <var>pUser</var>; the turn id when it answered 202, else <code>""</code>.</p>
Method Start(pUser As %String, pMessage As %String, Output pStatus As %Integer, Output pText As %String) As %String
{
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", pUser, ..PreparedPassword, .tConvStatus, .tConvText)
    Do ..Call("POST", "/turn", pUser, $ClassMethod(..#FIXTURE, "StartBody", pMessage, tConvId), .pStatus, .pText, .tHeaders)
    If pStatus '= 202 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(pText).turnId
}

Method Poll(pTurnId As %String, pUser As %String, Output pStatus As %Integer, Output pText As %String, Output pHeaders) As %Status
{
    Quit ..Call("GET", $Replace(..#PROGRESSROUTE, ":id", pTurnId), pUser, "", .pStatus, .pText, .pHeaders)
}

Method AwaitEnd(pTurnId As %String, pUser As %String, pSeconds As %Integer, Output pView) As %String
{
    Quit $ClassMethod(..#FIXTURE, "AwaitEnd", pTurnId, pUser, ..PreparedPassword, pSeconds, .pView)
}

/// <p>A start answers 202 with an opaque id within five seconds; the poll answers the declared
/// shape; the job ran as the principal, without OcuPilot's role; and a message carrying U+00E9 and
/// U+4E2D reached the provider intact (DW-23), under the built-in system prompt.</p>
/// <p>Mutation: spawn the job from an escalated frame in <class>OcuPilot.Kernel.State.Base</class>
/// -- the roles assertion goes red.</p>
Method TestAStartRunsAsTheCallerAndThePollAnswersItsShape()
{
    Do $$$AssertTrue(..PreparedSetupOk, "the principal holds %Admin_Operate")
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 1, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tMessage = "caf" _ $Char(233) _ " " _ $Char(20013)
    Set tStarted = $ZHorolog
    Set tId = ..Start(tUser, tMessage, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    Do $$$AssertTrue(($ZHorolog - tStarted) < 5, "within five seconds")
    Do $$$AssertTrue($Match(tId, "^[0-9a-f]{32}$"), "with an opaque turn id")
    Do $$$AssertEquals(..AwaitEnd(tId, tUser, 30, .tView), "completed", "the turn completes")
    Do ..Poll(tId, tUser, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the poll answers")
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Set tView = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(..KeysOf(tView), "turnId,state,startedAt,endedAt,iterations,tokens,limit,steps,stepsDropped,reply,error,proposals", "with the declared keys")
    Do $$$AssertEquals(tView.%GetTypeOf("proposals"), "array", "proposals is an array on every answer (Story 5.1)")
    If tView.%GetTypeOf("proposals") = "array" Do $$$AssertEquals(tView.proposals.%ToJSON(), "[]", "and empty for a turn that minted none")
    Do $$$AssertEquals(..KeysOf(tView.tokens), "input,output", "and the token keys")
    Do $$$AssertEquals(..KeysOf(tView.steps.%Get(0)), "seq,kind,name,status,summary,text,code,truncated,target,arguments,result,reason,failedPair", "and the step keys")
    Do $$$AssertEquals(tView.reply _ "|" _ tView.iterations _ "|" _ tView.%GetTypeOf("error"), "done|1|null", "reply, iterations and no error")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "user"), tUser, "the provider call ran as the principal")
    Set tRoles = $ZConvert(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "roles"), "U")
    Do $$$AssertTrue((tRoles '= "") && (tRoles '[ ##class(OcuPilot.Kernel.State.Base).#DBRESOURCE), "without OcuPilot's database role: " _ tRoles)
    Set tSent = ##class(%DynamicArray).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "messages"))
    Do $$$AssertEquals(tSent.%Get(0).content, tMessage, "and the message arrived with both characters intact")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "system"), ##class(OcuPilot.Kernel.Agent.Prompt).Builtin(), "under the built-in system prompt")
}

/// <p>A body that is not a JSON object is 400 <code>TURN.BADBODY</code> with its written sentence
/// and no vendor text; a missing, non-string, blank or over-long message is 422 with its violation
/// on <code>message</code>. Nothing is reserved.</p>
Method TestABadBodyIsRefusedAndReservesNothing()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tLong = $ZConvert("{""message"":""" _ $Translate($Justify("", $Parameter("OcuPilot.Kernel.Agent.Limits", "MESSAGEMAXLENGTH") + 1), " ", "x") _ """}", "O", "UTF8")
    For tCase = "[1]|400|TURN.BADBODY", "not json|400|TURN.BADBODY", "{}|422|TURN.MESSAGE.REQUIRED", "{""message"":5}|422|TURN.MESSAGE.REQUIRED", "{""message"":""  ""}|422|TURN.MESSAGE.REQUIRED", "LONG|422|TURN.MESSAGE.LENGTH" {
        Set tBody = $Piece(tCase, "|", 1)
        If tBody = "LONG" Set tBody = tLong
        Do ..Call("POST", "/turn", tUser, tBody, .tStatus, .tText, .tHeaders)
        Do $$$AssertEquals(tStatus, $Piece(tCase, "|", 2), $Extract(tBody, 1, 20) _ ": refused " _ $Extract(tText, 1, 200))
        If tStatus '= $Piece(tCase, "|", 2) Continue
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
        Do $$$AssertEquals(tAnswer.code, $Piece(tCase, "|", 3), $Extract(tBody, 1, 20) _ ": with its code")
        If tStatus = 400 Do $$$AssertEquals(tAnswer.reason, ##class(OcuPilot.Api.Error).#REASONTURNBADBODY, $Extract(tBody, 1, 20) _ ": and its sentence alone")
        If tStatus = 422 Do $$$AssertEquals(tAnswer.detail.violations.%Get(0).field _ "|" _ tAnswer.detail.violations.%Get(0).code, "message|" _ tAnswer.code, "on the message field")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).TurnCount(tUser), 0, "and no turn was reserved")
}

/// <p>A kill switch, a hold on the caller and no enabled default each refuse the start, and
/// reserve nothing.</p>
Method TestARefusedStartReservesNothing()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    For tLeg = "global|403|AGENT.KILLSWITCH.GLOBAL", "user|403|AGENT.KILLSWITCH.USER", "none|503|PROVIDER.UNCONFIGURED" {
        Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds)
        Do ##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedDefinitionId, 1, 1)
        Do ##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(..PreparedDefinitionId)
        If $Piece(tLeg, "|") = "global" Do ##class(OcuPilot.Test.SwitchFixture).SetSwitches(1, "probe", 0)
        If $Piece(tLeg, "|") = "user" Do ##class(OcuPilot.Test.SwitchFixture).Hold(tUser, "probe", .tHoldId)
        If $Piece(tLeg, "|") = "none" Do ##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedDefinitionId, 0, 1)
        Set tId = ..Start(tUser, "refused", .tStatus, .tText)
        Do $$$AssertEquals(tStatus, $Piece(tLeg, "|", 2), $Piece(tLeg, "|") _ ": the start is refused " _ tText)
        If tStatus = $Piece(tLeg, "|", 2) Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText).code, $Piece(tLeg, "|", 3), $Piece(tLeg, "|") _ ": by name")
    }
    Do ##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedDefinitionId, 1, 1)
    Do ##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(..PreparedDefinitionId)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).TurnCount(tUser), 0, "and no turn was reserved")
}

/// <p>A second start while a turn runs is 409 <code>TURN.BUSY</code> with the lock banner's
/// sentence; a start while another process holds the caller's slot is refused the same way and
/// inserts nothing; of two starts sent at once, exactly one is accepted.</p>
Method TestABusyCallerIsRefusedAndAConcurrentPairStartsOne()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 3, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tId = ..Start(tUser, "first", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the first start is accepted")
    Set tSecond = ..Start(tUser, "second", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 409, "a second start is refused")
    If tStatus = 409 {
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
        Do $$$AssertEquals(tAnswer.code _ "|" _ tAnswer.reason, "TURN.BUSY|A turn is in progress. Wait for it to finish before sending another message.", "as busy, with the lock banner's sentence")
    }
    Do $$$AssertEquals(..AwaitEnd(tId, tUser, 30, .tView), "completed", "the first turn completes")

    Lock +^OcuPilotTurnSlot(tUser):5
    Do $$$AssertTrue($Test, "this process holds the caller's slot")
    Do ..Start(tUser, "slot held", .tStatus, .tText)
    Lock -^OcuPilotTurnSlot(tUser)
    Do $$$AssertEquals(tStatus, 409, "a start while the slot is held elsewhere is refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).TurnCount(tUser), 1, "and inserts nothing")

    Set tRaceConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedPassword, .tRaceConvStatus, .tRaceConvText)
    Set tGate = $Job
    Kill ^IRIS.Temp.OcuPilotTurnWireRace(tGate)
    Lock +^IRIS.Temp.OcuPilotTurnWireRace(tGate)
    For tSlot = 1, 2 {
        Job ##class(OcuPilot.Test.TurnWire).RacePost(tUser, ..PreparedPassword, tGate, tSlot, tRaceConvId)::10
        Set tPid(tSlot) = $Select($Test: $ZChild, 1: "")
    }
    Hang 1
    Lock -^IRIS.Temp.OcuPilotTurnWireRace(tGate)
    Set tDeadline = $ZHorolog + 30
    While (($Get(^IRIS.Temp.OcuPilotTurnWireRace(tGate, 1)) = "") || ($Get(^IRIS.Temp.OcuPilotTurnWireRace(tGate, 2)) = "")) && ($ZHorolog < tDeadline) {
        Hang 0.25
    }
    For tSlot = 1, 2 {
        If ($Get(tPid(tSlot)) '= "") && $Data(^$JOB(tPid(tSlot))) Do $SYSTEM.Process.Terminate(tPid(tSlot))
        Set tGone = $ZHorolog + 10
        While ($Get(tPid(tSlot)) '= "") && $Data(^$JOB(tPid(tSlot))) && ($ZHorolog < tGone) {
            Hang 0.25
        }
        Do $$$AssertTrue(($Get(tPid(tSlot)) = "") || '$Data(^$JOB(tPid(tSlot))), "race poster " _ tSlot _ " has ended")
    }
    Set tStatuses = $Get(^IRIS.Temp.OcuPilotTurnWireRace(tGate, 1)) _ "," _ $Get(^IRIS.Temp.OcuPilotTurnWireRace(tGate, 2))
    Kill ^IRIS.Temp.OcuPilotTurnWireRace(tGate)
    Do $$$AssertTrue((tStatuses = "202,409") || (tStatuses = "409,202"), "exactly one of two concurrent starts is accepted: " _ tStatuses)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).TurnCount(tUser), 2, "so the pair added one turn")
}

/// <p>The body of one concurrent start: wait on the gate the test holds, post, record the status.
/// Both racing posts share <var>pConversationId</var> -- exactly one of them will actually reach
/// <method>OcuPilot.Kernel.Agent.Job.Run</method>, and the AD-41 slot lock is what this test
/// pins, not the conversation lock.</p>
ClassMethod RacePost(pUser As %String, pPassword As %String, pGate As %String, pSlot As %Integer, pConversationId As %String)
{
    Lock +^IRIS.Temp.OcuPilotTurnWireRace(pGate)#"S":30
    Lock -^IRIS.Temp.OcuPilotTurnWireRace(pGate)#"S"
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/turn", pUser, pPassword, .tStatus, .tText, .tHeaders, "{""message"":""race"",""conversationId"":""" _ pConversationId _ """}", "application/json")
    Set ^IRIS.Temp.OcuPilotTurnWireRace(pGate, pSlot) = +$Get(tStatus)
}

/// <p>Another principal's poll of a turn, and anyone's poll of an unknown id, are the same 404.</p>
/// <p>Mutation: drop the user predicate from <method>OcuPilot.Kernel.State.Turn.GuardedForOwner</method>
/// -- the second principal's poll goes red.</p>
Method TestAnotherPrincipalsTurnAnswersLikeAnUnknownId()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tOther = $Parameter(..#FIXTURE, "USERB")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 2, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tId = ..Start(tUser, "mine", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the owner's start is accepted")
    Do ..Poll(tId, tOther, .tStatus, .tOthers, .tHeaders)
    Do $$$AssertEquals(tStatus, 404, "another principal's poll is not found")
    Do ..Poll("0123456789abcdef0123456789abcdef", tOther, .tStatus, .tUnknown, .tHeaders)
    Do $$$AssertEquals(tStatus, 404, "and neither is an unknown id")
    Do $$$AssertEquals(tOthers, tUnknown, "with the same body: " _ tOthers)
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tOthers).code, "TURN.NOTFOUND", "naming TURN.NOTFOUND")
    Do $$$AssertEquals(..AwaitEnd(tId, tUser, 30, .tView), "completed", "and the owner's turn completes")
}

/// <p>Revoking the principal's only administrative resource, or deleting the account, while its
/// turn is in a provider call abandons the turn at the next boundary with no further call.</p>
/// <p>Mutation: remove the grants check from <method>OcuPilot.Kernel.Agent.Loop.Boundary</method>
/// -- both legs go red, the turns completing.</p>
Method TestRevokingOrDeletingThePrincipalAbandonsItsTurn()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    For tLeg = "revoke", "delete" {
        Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
        Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 4, ##class(OcuPilot.Test.TurnProvider).ToolUseReply("probe.tool"))
        Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
        Set tId = ..Start(tUser, tLeg, .tStatus, .tText)
        Do $$$AssertEquals(tStatus, 202, tLeg _ ": the start is accepted")
        Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 1, 15), tLeg _ ": the provider call began")
        If tLeg = "revoke" Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnWireFixture).SetRoleResources($ClassMethod(..#FIXTURE, "Resources", 0)), "the administrative resource is revoked")
        If tLeg = "delete" Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnWireFixture).DeletePrincipal(tUser), "the account is deleted")
        Do $$$AssertTrue(##class(OcuPilot.Kernel.State.Turn).IsTerminal(##class(OcuPilot.Test.TurnFixture).AwaitTerminal(tId, 20)), tLeg _ ": the turn ends")
        Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 1, tLeg _ ": with no further provider call")
        Do ##class(OcuPilot.Test.TurnWireFixture).SetRoleResources($ClassMethod(..#FIXTURE, "Resources"))
        If tLeg = "delete" Do ##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal(tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"))
        Do ..Poll(tId, tUser, .tStatus, .tText, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tLeg _ ": the restored principal's poll answers " _ tText)
        If tStatus = 200 Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText).error.code, "TURN.ABANDONED.PRIVILEGE", tLeg _ ": abandoned for privilege")
    }
}

/// <p>A sign-out abandons the caller's running turn at its next boundary and leaves the other
/// principal's turn running to completion.</p>
/// <p>Mutation: drop the user predicate from
/// <method>OcuPilot.Kernel.State.Turn.GuardedAbandonForUser</method> -- the other principal's turn
/// is abandoned too, and this goes red.</p>
Method TestSignOutAbandonsOnlyTheCallersTurn()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tOther = $Parameter(..#FIXTURE, "USERB")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 4, ##class(OcuPilot.Test.TurnProvider).ToolUseReply("probe.tool"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 4, ##class(OcuPilot.Test.TurnProvider).ToolUseReply("probe.tool"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tMine = ..Start(tUser, "mine", .tStatus, .tText)
    Set tTheirs = ..Start(tOther, "theirs", .tStatus2, .tText2)
    Do $$$AssertEquals(tStatus _ "|" _ tStatus2, "202|202", "both principals' starts are accepted")
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 2, 15), "both turns are in a provider call")
    Do ..Call("POST", "/turn/abandon", tUser, "", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the sign-out's abandon answers")
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    If tStatus = 200 Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText).abandoned, 1, "counting the caller's one turn")
    Do $$$AssertEquals(..AwaitEnd(tMine, tUser, 30, .tView), "abandoned", "the caller's turn is abandoned")
    Do $$$AssertEquals($Select($IsObject(tView): tView.error.code, 1: ""), "TURN.ABANDONED.SIGNOUT", "for the sign-out")
    Do $$$AssertEquals(..AwaitEnd(tTheirs, tOther, 30, .tView), "completed", "and the other principal's turn completes")
}

/// <p>A running turn whose job is gone is abandoned <code>TURN.ABANDONED.JOBLOST</code> by the
/// owner's next poll, and the slot is free for the next start.</p>
Method TestALostJobIsAbandonedByTheNextPoll()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 60, ##class(OcuPilot.Test.TurnProvider).TextReply("never"))
    Set tId = ..Start(tUser, "lost", .tStatus, .tText)
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 1, 15), "the job is in its provider call")
    Set tPid = ##class(OcuPilot.Test.TurnFixture).Field(tId, "JobId")
    Do $$$AssertNotEquals(tPid, "", "and recorded its process")
    If tPid '= "" Do $SYSTEM.Process.Terminate(tPid)
    Set tDeadline = $ZHorolog + 10
    While (tPid '= "") && $Data(^$JOB(tPid)) && ($ZHorolog < tDeadline) {
        Hang 0.25
    }
    Do ..Poll(tId, tUser, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the owner's poll answers")
    If tStatus = 200 Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText).state _ "|" _ ##class(%DynamicObject).%FromJSON(tText).error.code, "abandoned|TURN.ABANDONED.JOBLOST", "with the turn abandoned as lost")
    Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
    Set tNext = ..Start(tUser, "next", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "and the next start is accepted")
    Do $$$AssertEquals(..AwaitEnd(tNext, tUser, 30, .tView), "completed", "and completes")
}

/// <p>Enforced read-only on from the start does not end a turn, which runs on the snapshot it
/// started with; a hold, the instance kill switch, or enforced read-only turned on during the first
/// provider call ends the turn at the next step boundary with no second call.</p>
/// <p>Mutation: remove the kill-switch check from <method>OcuPilot.Kernel.Agent.Loop.Boundary</method>
/// -- the hold and global legs go red.</p>
Method TestTheSwitchesAreReadAgainAtEveryStepBoundary()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 1), "read-only is enforced before the start")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tId = ..Start(tUser, "read-only", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted under read-only: " _ tText)
    Do ##class(OcuPilot.Test.TurnFixture).AwaitTerminal(tId, 30)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tId, "State"), "completed", "and the turn completes on its snapshot")
    For tLeg = "hold|stopped|AGENT.KILLSWITCH.USER", "global|stopped|AGENT.KILLSWITCH.GLOBAL", "readonly|abandoned|TURN.ABANDONED.READONLY" {
        Set tName = $Piece(tLeg, "|")
        Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds)
        Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
        Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 4, ##class(OcuPilot.Test.TurnProvider).ToolUseReply("probe.tool"))
        Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
        Set tId = ..Start(tUser, tName, .tStatus, .tText)
        Do $$$AssertEquals(tStatus, 202, tName _ ": the start is accepted")
        If tStatus '= 202 Continue
        Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 1, 15), tName _ ": the provider call began")
        If tName = "hold" Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Hold(tUser, "probe", .tHoldId), "the caller is held")
        If tName = "global" Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(1, "probe", 0), "the agent is switched off")
        If tName = "readonly" Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 1), "read-only is enforced")
        Do ##class(OcuPilot.Test.TurnFixture).AwaitTerminal(tId, 30)
        Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tId, "State") _ "|" _ ##class(OcuPilot.Test.TurnFixture).Field(tId, "Code"), $Piece(tLeg, "|", 2, 3), tName _ ": the turn ends at the next boundary")
        Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 1, tName _ ": with no second provider call")
    }
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds)
}

/// <p>A job that cannot take its caller's slot within the queued limit finishes its turn
/// <code>failed</code> with <code>TURN.UNAVAILABLE</code> rather than leaving it queued. The slot is
/// held by a helper process; the job's entry point runs in this process.</p>
/// <p>Mutation: in <method>OcuPilot.Kernel.Agent.Job.Run</method>, quit without finishing a turn
/// that was not begun -- this goes red.</p>
Method TestAJobThatCannotBeginFinishesItsTurnFailed()
{
    Set tUser = $Username
    Set tLimits = ##class(OcuPilot.Kernel.Agent.Loop).LimitsClass()
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, ..PreparedDefinitionId, "TURN.ABANDONED.JOBLOST", tLimits, .tKey, .tBusy, .tSweep), "a turn is reserved")
    If $Get(tKey) = "" Quit
    Job ##class(OcuPilot.Test.TurnWire).HoldSlot(tUser, $Parameter(tLimits, "QUEUEDSECONDS") + 5)::10
    Set tPid = $Select($Test: $ZChild, 1: "")
    Set tHeld = $ZHorolog + 5
    While (##class(OcuPilot.Test.TurnFixture).SlotOwner(tUser) = "") && ($ZHorolog < tHeld) {
        Hang 0.1
    }
    Do $$$AssertNotEquals(##class(OcuPilot.Test.TurnFixture).SlotOwner(tUser), "", "another process holds the slot")
    Do ##class(OcuPilot.Kernel.Agent.Job).Run(tKey, tUser, ..PreparedDefinitionId, $Namespace, "blocked", 0, ##class(OcuPilot.Api.Router).#ADMINRESOURCES)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "State") _ "|" _ ##class(OcuPilot.Test.TurnFixture).Field(tKey, "Code"), "failed|TURN.UNAVAILABLE", "the turn is finished failed")
    If (tPid '= "") && $Data(^$JOB(tPid)) Do $SYSTEM.Process.Terminate(tPid)
    Set tGone = $ZHorolog + 10
    While (tPid '= "") && $Data(^$JOB(tPid)) && ($ZHorolog < tGone) {
        Hang 0.25
    }
    Do $$$AssertTrue((tPid = "") || '$Data(^$JOB(tPid)), "and the helper has ended")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tKey), "the turn is removed")
}

/// <p>A job entry point that finds itself running for a different user than the one it was
/// started for finishes that user's turn <code>failed</code> without beginning it, and logs the
/// mismatch to the instance's own console log -- no request is waiting to report it.
/// <method>OcuPilot.Kernel.Agent.Job.Run</method> is called directly in this process, so nothing is
/// spawned; the console log write is real, which is why this runs on a throwaway only.</p>
/// <p>Mutation: drop the <code>Do ..Log(...)</code> call from the identity-mismatch branch of
/// <method>OcuPilot.Kernel.Agent.Job.Run</method> -- the log assertion goes red; drop its
/// <code>Do ..Finish(...)</code> -- the state assertion goes red.</p>
Method TestAJobIdentityMismatchReachesTheConsoleLog()
{
    Do ##class(OcuPilot.Port.LogSourcePort).Page("messages", "", 64, "", .tSeed, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the console log is readable before the call")
    If tHttp '= 200 Quit
    Set tOffset = tSeed.size + 1
    Set tIdentity = tSeed.identity

    Set tOther = "OcuPilotProbeTurnWireNoSuchUser"
    Do $$$AssertNotEquals($Username, tOther, "the calling process is not that user")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tOther, ..PreparedDefinitionId, "TURN.ABANDONED.JOBLOST", ##class(OcuPilot.Kernel.Agent.Loop).LimitsClass(), .tKey, .tBusy, .tSweep), "a turn is reserved for that user")
    Do ##class(OcuPilot.Kernel.Agent.Job).Run(tKey, tOther, ..PreparedDefinitionId, $Namespace, "x", 0, "")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "State") _ "|" _ ##class(OcuPilot.Test.TurnFixture).Field(tKey, "Code") _ "|" _ ##class(OcuPilot.Test.TurnFixture).Field(tKey, "JobId"), "failed|TURN.UNAVAILABLE|", "the turn is finished failed, never begun")

    Set tCaptured = ""
    Set tDeadline = $ZHorolog + 5
    While (tCaptured = "") && ($ZHorolog < tDeadline) {
        Do ##class(OcuPilot.Port.LogSourcePort).Page("messages", tOffset, 65536, tIdentity, .tPage, .tHttp2, .tFault2)
        If tHttp2 = 200 {
            For tI = 0:1:tPage.lines.%Size() - 1 {
                Set tLine = tPage.lines.%Get(tI)
                If tLine [ "the turn job did not start as its caller" Set tCaptured = tLine
            }
        }
        If tCaptured = "" Hang 0.2
    }
    Do $$$AssertTrue(tCaptured '= "", "the identity mismatch reaches the console log")
    Do $$$AssertTrue((tCaptured [ "TURN.UNAVAILABLE"), "carrying the code the turn was finished with: " _ tCaptured)
}

/// <p>Hold <var>pUser</var>'s turn slot for <var>pSeconds</var>, then release it.</p>
ClassMethod HoldSlot(pUser As %String, pSeconds As %Integer)
{
    Lock +^OcuPilotTurnSlot(pUser):5
    If $Test Hang pSeconds
    Lock -^OcuPilotTurnSlot(pUser)
}

/// <p>The keys of <var>pObject</var>, comma-separated in order.</p>
ClassMethod KeysOf(pObject As %DynamicObject) As %String
{
    Set tKeys = ""
    If '$IsObject(pObject) Quit ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Quit tKeys
}

}
