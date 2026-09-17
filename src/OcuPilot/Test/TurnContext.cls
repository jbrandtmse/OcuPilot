/// <p>Story 4.4's screen context over HTTP, driven by a real armed turn against the
/// <code>turnprobe</code> row (AD-7, AD-9, AD-11, AD-24): the Integration acceptance criterion, a
/// secret screen, sharing off, the default off, a model-issued <code>screen_context</code> call, a
/// malformed context, an unknown route, a read tool's own field bound, and
/// <code>GET</code>/<code>PUT /agent/context</code> over the wire.</p>
/// <p><b>It creates an IRIS user and a role and spawns turn jobs, so
/// <method>OnBeforeAllTests</method> refuses to run unless both</b>
/// <parameter>ARMINGVARIABLE</parameter> <b>and</b> <parameter>PROVIDERVARIABLE</parameter>
/// <b>read 1.</b> Only <file>scripts/ci-throwaway.sh</file> sets them. The principal's second role
/// carries the audit screen's own privilege pairs beyond
/// <class>OcuPilot.Test.TurnWireFixture</class>'s shared set, so this class alone can exercise the
/// real <code>logs.audit.read</code> tool.</p>
/// <p><b>Wire message shape, precisely.</b> A recorded request's <code>messages</code> array holds
/// one object per message; its <code>content</code> is <i>either</i> a plain string (a text-only
/// message) <i>or</i> an array of blocks already parsed by the one outer
/// <method>%FromJSON</method> call on the whole array -- never a second JSON-encoded string
/// needing a parse of its own. One level deeper, a block's own <code>content</code> -- the
/// <code>tool_result</code>'s payload -- <i>is</i> a genuine JSON-encoded string
/// (<method>OcuPilot.Kernel.Agent.Loop</method> sets it with <code>%Set(..., "string")</code>), so
/// that one call is where a second <method>%FromJSON</method> belongs.</p>
Class OcuPilot.Test.TurnContext Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "turncontext-probe";

Parameter APIBASE = "/api/ocupilot";

/// <p>The pairs <code>logs/audit</code> declares beyond the shared fixture's own set, so this
/// class's principal can call the real <code>logs.audit.read</code> tool.</p>
Parameter AUDITRESOURCES = "%Admin_Secure:U,%DB_IRISSYS:R";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnContext creates an IRIS user and a role and runs turn jobs, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnContext runs turn jobs against the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"), ..#AUDITRESOURCES)
    If $$$ISERR(tSC) Quit tSC
    ; A second, least-privileged principal, for AC3's two-principal wire test (DW-1030): the
    ; sharing choice is per user, so a wire-level check needs a second caller who has stored none.
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", $Parameter(..#FIXTURE, "USERB"), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"))
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tId
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = ##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnContext teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds)
    Do ##class(OcuPilot.Kernel.State.Sharing).DeleteAllGuarded()
    Quit $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds)
    Do ##class(OcuPilot.Kernel.State.Sharing).DeleteAllGuarded()
    Quit $$$OK
}

/// <p>One request as the probe principal.</p>
Method Call(pMethod As %String, pPath As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String, Output pHeaders) As %Status
{
    Quit ..CallAs(pMethod, pPath, $Parameter(..#FIXTURE, "USERA"), pBody, .pStatus, .pText, .pHeaders)
}

/// <p>One request as <var>pUser</var>, both prepared principals sharing one password.</p>
Method CallAs(pMethod As %String, pPath As %String, pUser As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ pPath, pUser, ..PreparedPassword, .pStatus, .pText, .pHeaders, pBody, "application/json")
}

/// <p>Post a start carrying <var>pContext</var>; the turn id when it answered 202.</p>
Method Start(pMessage As %String, pContext As %DynamicObject, Output pStatus As %Integer, Output pText As %String) As %String
{
    Do ..Call("POST", "/turn", $ClassMethod(..#FIXTURE, "StartBody", pMessage, pContext), .pStatus, .pText, .tHeaders)
    If pStatus '= 202 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(pText).turnId
}

Method AwaitEnd(pTurnId As %String, pSeconds As %Integer, Output pView) As %String
{
    Quit $ClassMethod(..#FIXTURE, "AwaitEnd", pTurnId, $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, pSeconds, .pView)
}

/// <p>A <code>context.view.rows</code> array of <var>pCount</var> rows, each
/// <code>{TimeStamp, Description}</code>. Row <var>pLongAt</var> (1-based, 0 for none) carries a
/// <var>pLongLength</var>-character <code>Description</code>; every other row's is short.</p>
ClassMethod Rows(pCount As %Integer, pLongAt As %Integer = 0, pLongLength As %Integer = 0) As %DynamicArray
{
    Set tRows = []
    For tI = 1:1:pCount {
        Set tDescription = "row " _ tI
        If tI = pLongAt Set tDescription = $TR($Justify("", pLongLength), " ", "d")
        Do tRows.%Push({"TimeStamp": ("2026-09-17 00:00:0" _ (tI # 10)), "Description": (tDescription)})
    }
    Quit tRows
}

/// <p>The Integration acceptance criterion (consumer 4.1's turn loop): a <code>logs/audit</code>
/// context with 250 rows, cap 5, one <code>Description</code> of 3,000 characters, reaches call
/// 1's messages as the three specified blocks, and the payload is bounded.</p>
/// <p>Mutation: skip the per-field cut in <method>OcuPilot.Kernel.Agent.Bound.Apply</method> --
/// the 1,000-character assertion below goes red.</p>
Method TestTheIntegrationAcceptanceCriterion()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 0), "start clean")
    Set tRow("contextRowCap") = 5
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tRow), "the row cap is 5")

    Set tContext = {}
    Do tContext.%Set("route", "logs/audit", "string")
    Do tContext.%Set("namespace", "HSCUSTOM", "string")
    Do tContext.%Set("view", {})
    Do tContext.view.%Set("rows", ..Rows(250, 3, 3000))
    Do tContext.view.%Set("rowsAvailable", 250, "number")

    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Set tTurnId = ..Start("what happened", tContext, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 1, 10), "call 1 lands")
    Do ..AwaitEnd(tTurnId, 5, .tView)

    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "messages"))
    Do $$$AssertEquals(tMessages.%Size(), 3, "three messages")
    Do $$$AssertEquals(tMessages.%Get(0).role, "user", "message 1 is the user preamble")
    Do $$$AssertEquals(tMessages.%Get(0).%GetTypeOf("content"), "string", "as plain content, not blocks")
    Do $$$AssertEquals(tMessages.%Get(1).role, "assistant", "message 2 is the synthetic call")
    ; A message's own content is already an array once the outer %FromJSON above has run --
    ; never a JSON-encoded string needing a %FromJSON of its own (see this class's header).
    Set tUseBlocks = tMessages.%Get(1).content
    Do $$$AssertEquals(tUseBlocks.%Size(), 1, "one block")
    Set tUse = tUseBlocks.%Get(0)
    Do $$$AssertEquals(tUse.type _ "|" _ tUse.id _ "|" _ tUse.name, "tool_use|ocupilot_screen_context|screen_context", "the synthetic tool_use")
    Do $$$AssertEquals(tMessages.%Get(2).role, "user", "message 3 carries the result and the real message")
    Set tUserBlocks = tMessages.%Get(2).content
    Do $$$AssertEquals(tUserBlocks.%Size(), 2, "the tool_result and the text")
    Set tResultBlock = tUserBlocks.%Get(0)
    Do $$$AssertEquals(tResultBlock.type _ "|" _ tResultBlock."tool_use_id", "tool_result|ocupilot_screen_context", "the synthetic tool_result")
    Do $$$AssertEquals(tUserBlocks.%Get(1).type _ "|" _ tUserBlocks.%Get(1).text, "text|what happened", "the caller's own message, verbatim")

    ; The tool_result block's own content IS a JSON-encoded string (Loop.cls sets it with the
    ; "string" type hint), so this %FromJSON is the one genuine second-level parse.
    Set tPayload = ##class(%DynamicAbstractObject).%FromJSON(tResultBlock.content)
    Do $$$AssertEquals(tPayload.screen, "logs.audit", "the descriptor's own tool identifier")
    Do $$$AssertEquals(tPayload.rowsSent, 5, "cut to the row cap")
    Do $$$AssertEquals(tPayload.rowsAvailable, 250, "the pre-cut count")
    Do $$$AssertEquals(tPayload.truncated, 1, "marked truncated")
    Do $$$AssertEquals(tPayload.truncatedFields.%ToJSON(), "[""Description""]", "the cut field is named")
    Set tCutDescription = tPayload.rows.%Get(2)."Description"
    Do $$$AssertEquals($Length(tCutDescription), 1000, "cut to 1,000 characters")
    Do $$$AssertEquals($Extract(tCutDescription, 1000), $Char(8230), "ending U+2026")
}

/// <p>Total size -- 200 rows of about 900 characters each stay within the size cap, with
/// <code>rowsSent</code> below 200 and only whole rows kept.</p>
Method TestTotalSize()
{
    Set tRows = []
    For tI = 1:1:200 {
        Do tRows.%Push({"TimeStamp": "2026-09-17 00:00:00", "Description": ($TR($Justify("", 900), " ", "d"))})
    }
    Set tContext = {"route": "logs/audit", "namespace": "HSCUSTOM"}
    Do tContext.%Set("view", {"rows": (tRows)})

    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Set tTurnId = ..Start("size check", tContext, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 1, 10), "call 1 lands")
    Do ..AwaitEnd(tTurnId, 5, .tView)

    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "messages"))
    Set tUserBlocks = tMessages.%Get(2).content
    Set tResultBlock = tUserBlocks.%Get(0)
    Set tPayload = ##class(%DynamicAbstractObject).%FromJSON(tResultBlock.content)
    Do $$$AssertTrue($Length(tResultBlock.content) <= 65536, "the payload JSON is at most 65,536 characters")
    Do $$$AssertTrue(tPayload.rowsSent < 200, "rowsSent is below 200")
    Do $$$AssertEquals(tPayload.rows.%Size(), tPayload.rowsSent, "whole rows only")
}

/// <p>A non-scalar row field (an object or array value) is dropped from the projected row, and its
/// name is merged into <code>truncatedFields</code> beside whatever
/// <method>OcuPilot.Kernel.Agent.Bound.Apply</method>'s own per-field cut already named --
/// <method>OcuPilot.Api.Turn.HandleStart</method>'s merge step, exercised end to end.</p>
/// <p>Mutation: drop the <code>$ListLength(tDroppedFields) &gt; 0</code> merge branch in
/// <method>OcuPilot.Api.Turn.HandleStart</method> -- the dropped field stops being named and this
/// goes red.</p>
Method TestANonScalarRowFieldIsDroppedAndNamedInTruncatedFields()
{
    Set tContext = {"route": "logs/audit", "namespace": "HSCUSTOM"}
    Do tContext.%Set("view", {})
    Do tContext.view.%Set("rows", [{}])
    Do tContext.view.rows.%Get(0).%Set("TimeStamp", "2026-09-17 00:00:00", "string")
    Do tContext.view.rows.%Get(0).%Set("Description", {"nested": "object"})

    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Set tTurnId = ..Start("dropped field", tContext, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 1, 10), "call 1 lands")
    Do ..AwaitEnd(tTurnId, 5, .tView)

    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "messages"))
    Set tUserBlocks = tMessages.%Get(2).content
    Set tResultBlock = tUserBlocks.%Get(0)
    Set tPayload = ##class(%DynamicAbstractObject).%FromJSON(tResultBlock.content)
    Do $$$AssertEquals(tPayload.rows.%Get(0).%GetTypeOf("Description"), "unassigned", "the object value is dropped from the row")
    Do $$$AssertEquals(tPayload.rows.%Get(0).TimeStamp, "2026-09-17 00:00:00", "an untouched field is untouched")
    Do $$$AssertEquals(tPayload.truncatedFields.%ToJSON(), "[""Description""]", "the dropped field is named")
    Do $$$AssertEquals(tPayload.truncated, 1, "and the payload is marked truncated")
}

/// <p>Secret screen -- <code>agent/definitions/edit</code> (which declares
/// <code>context.secretFields</code>) answers identity only, with no <code>rows</code> key.</p>
/// <p>Mutation: drop the secret-descriptor identity-only branch in
/// <method>OcuPilot.Screen.Context.Build</method> -- this goes red.</p>
Method TestASecretScreenAnswersIdentityOnly()
{
    Set tContext = {"route": "agent/definitions/edit", "namespace": "HSCUSTOM", "entity": "some-id"}
    Do tContext.%Set("view", {"rows": [{"apiKey": "sk-ant-should-never-leave"}]})

    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Set tTurnId = ..Start("edit this", tContext, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 1, 10), "call 1 lands")
    Do ..AwaitEnd(tTurnId, 5, .tView)

    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "messages"))
    Do $$$AssertEquals(tMessages.%Size(), 3, "context still opens the turn with three messages")
    Set tUserBlocks = tMessages.%Get(2).content
    Set tResultBlock = tUserBlocks.%Get(0)
    Set tPayload = ##class(%DynamicAbstractObject).%FromJSON(tResultBlock.content)
    Do $$$AssertEquals(tPayload.screen, "agent.definition", "identity is still projected")
    Do $$$AssertEquals(tPayload.%GetTypeOf("rows"), "unassigned", "no rows key at all")
    Do $$$AssertEquals(tPayload.rowsSent, 0, "rowsSent is still reported, at 0")
    Do $$$AssertTrue((tResultBlock.content [ "sk-ant") = 0, "the secret never reaches the payload text")
}

/// <p>Sharing off -- a caller who has <code>PUT</code> <code>{share:false}</code> gets the
/// no-context message shape even though a context was posted.</p>
/// <p>Mutation: ignore the <code>Sharing</code> row in <method>OcuPilot.Api.Turn.HandleStart</method>
/// -- this goes red.</p>
Method TestSharingOffSuppressesContext()
{
    Do ..Call("PUT", "/agent/context", "{""share"":false}", .tPutStatus, .tPutText, .tPutHeaders)
    Do $$$AssertEquals(tPutStatus, 200, "the choice is stored: " _ tPutText)

    Set tContext = {"route": "logs/audit", "namespace": "HSCUSTOM"}
    Do tContext.%Set("view", {"rows": [{"Description": "should not be sent"}]})
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Set tTurnId = ..Start("hello", tContext, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 1, 10), "call 1 lands")
    Do ..AwaitEnd(tTurnId, 5, .tView)

    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "messages"))
    Do $$$AssertEquals(tMessages.%Size(), 1, "the plain, no-context shape")
    Do $$$AssertEquals(tMessages.%Get(0).role _ "|" _ tMessages.%Get(0).content, "user|hello", "the message alone")
}

/// <p>Default off -- with no user row and the instance default off, sharing off behaves the same
/// as an explicit choice, and <code>GET /agent/context</code> reports <code>userChoice</code>
/// null and <code>share</code> false.</p>
Method TestDefaultOffBehavesLikeSharingOff()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 0), "start clean")
    Set tRow("shareContextByDefault") = 0
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tRow), "the instance default is off")

    Do ..Call("GET", "/agent/context", "", .tGetStatus, .tGetText, .tGetHeaders)
    Do $$$AssertEquals(tGetStatus, 200, "the read answers: " _ tGetText)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tGetText)
    Do $$$AssertEquals(tAnswer.share, 0, "share follows the instance default")
    Do $$$AssertEquals(tAnswer.%Get("userChoice"), "", "userChoice is null with no row")

    Set tContext = {"route": "logs/audit", "namespace": "HSCUSTOM"}
    Do tContext.%Set("view", {"rows": [{"Description": "should not be sent"}]})
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Set tTurnId = ..Start("hello", tContext, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 1, 10), "call 1 lands")
    Do ..AwaitEnd(tTurnId, 5, .tView)
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "messages"))
    Do $$$AssertEquals(tMessages.%Size(), 1, "no context reached the turn")
}

/// <p>Model calls it -- a <code>screen_context</code> <code>tool_use</code> the model issues
/// itself answers <code>TOOL.UNKNOWN</code>, a result rather than a failure, because the name is
/// never advertised.</p>
/// <p>Mutation: advertise or resolve <code>screen_context</code> as a real tool -- this goes
/// red.</p>
Method TestAModelIssuedScreenContextCallIsUnknown()
{
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply("screen_context"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Set tTurnId = ..Start("try the tool", "", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    Set tState = ..AwaitEnd(tTurnId, 10, .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes: " _ tView.%ToJSON())
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 2, 10), "call 2 lands")
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Set tResultBlocks = tMessages.%Get(tMessages.%Size() - 1).content
    Set tContent = ##class(%DynamicAbstractObject).%FromJSON(tResultBlocks.%Get(0).content)
    Do $$$AssertEquals(tContent.code, "TOOL.UNKNOWN", "answered as an ordinary unknown-tool result")
}

/// <p>Bad context -- a <code>context</code> that is a string, whose <code>namespace</code> differs
/// from the request's resolved scope, or whose <code>entity</code> is over the field maximum, is
/// refused 422 <code>TURN.CONTEXT.INVALID</code> on the field <code>context</code>, and no turn is
/// reserved.</p>
/// <p>Mutation: drop the <code>entity</code> length check in
/// <method>OcuPilot.Api.Turn.ContextViolation</method> -- the third case below goes red.</p>
Method TestBadContextIsRefusedAndNothingIsReserved()
{
    Do ..Call("POST", "/turn", "{""message"":""hi"",""context"":""not-an-object""}", .tStatus1, .tText1, .tHeaders1)
    Do $$$AssertEquals(tStatus1, 422, "a string context is refused: " _ tText1)
    Set tAnswer1 = ##class(%DynamicObject).%FromJSON(tText1)
    Do $$$AssertEquals(tAnswer1.detail.violations.%Get(0).field _ "|" _ tAnswer1.detail.violations.%Get(0).code, "context|TURN.CONTEXT.INVALID", "named on the context field")

    Set tContext = {"route": "logs/audit", "namespace": "NOTHSCUSTOM"}
    Set tBody = {"message": "hi"}
    Do tBody.%Set("context", tContext)
    Do ..Call("POST", "/turn", tBody.%ToJSON(), .tStatus2, .tText2, .tHeaders2)
    Do $$$AssertEquals(tStatus2, 422, "a mismatched namespace is refused: " _ tText2)

    Set tLongEntity = {"route": "logs/audit", "namespace": "HSCUSTOM", "entity": ($TR($Justify("", 1001), " ", "e"))}
    Set tBody3 = {"message": "hi"}
    Do tBody3.%Set("context", tLongEntity)
    Do ..Call("POST", "/turn", tBody3.%ToJSON(), .tStatus3, .tText3, .tHeaders3)
    Do $$$AssertEquals(tStatus3, 422, "an over-long entity is refused: " _ tText3)
    Set tAnswer3 = ##class(%DynamicObject).%FromJSON(tText3)
    Do $$$AssertEquals(tAnswer3.detail.violations.%Get(0).field _ "|" _ tAnswer3.detail.violations.%Get(0).code, "context|TURN.CONTEXT.INVALID", "named on the context field")

    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).Keys(.tKeys), "the turn keys can be read")
    Do $$$AssertEquals(+tKeys, 0, "no turn was reserved by any of the three refusals")
}

/// <p>Unknown route -- a route no descriptor declares builds no <code>screen_context</code> call,
/// and the turn runs with the plain message shape.</p>
Method TestAnUnknownRouteBuildsNoContext()
{
    Set tContext = {"route": "no/such/screen", "namespace": "HSCUSTOM"}
    Do tContext.%Set("view", {"rows": [{"x": 1}]})
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Set tTurnId = ..Start("hello", tContext, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 1, 10), "call 1 lands")
    Do ..AwaitEnd(tTurnId, 5, .tView)
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "messages"))
    Do $$$AssertEquals(tMessages.%Size(), 1, "no screen_context was built")
}

/// <p>Read tool field bound (DW-1033) -- the real <code>logs.audit.read</code> tool, called by the
/// model, carries a value cut with U+2026 when the underlying row's field is over 1,000
/// characters, and names the field in <code>truncatedFields</code>.</p>
/// <p><b>Deterministic, not conditional on whatever the live audit log happens to hold.</b> This
/// method writes its own audit row first (<method>OcuPilot.Kernel.Audit.Event.Record</method>, a
/// real <code>$System.Security.Audit</code> call under this project's own registered Source), with
/// an <code>EventData</code> payload built past 1,000 characters and carrying a marker unique to
/// this run, then asks the tool for that Source alone (<code>eventSources</code>, a declared
/// server-search criterion) so the search is narrowed to this project's own rows rather than the
/// whole instance-wide audit population, and the freshly written row is found and its own cut
/// verified by name, not inferred from an incidental match.</p>
/// <p>Mutation: the per-field cut disabled in <method>OcuPilot.Kernel.Agent.Bound.Apply</method> --
/// this goes red (the seeded row's own field is found whole, not cut to 1,000 characters).</p>
Method TestAReadToolResultsOwnFieldIsBound()
{
    Set tMarker = "OcuPilotProbeFieldBound" _ $Increment(^||OcuPilotProbeFieldBoundSeq)
    Set tChanges = {}
    Do tChanges.%Set("note", (tMarker _ $TR($Justify("", 1500), " ", "d")))
    Set tRecordSC = ##class(OcuPilot.Kernel.Audit.Event).Record("update", "agent-switch", "OcuPilotProbeTurnContextFieldBound", tChanges, 0)
    Do $$$AssertStatusOK(tRecordSC, "a long-EventData audit row is seeded")

    Set tCalls = [{"name": "logs_audit_read", "input": {"eventSources": (##class(OcuPilot.Kernel.Audit.Event).Source())}}]
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tCalls))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Set tTurnId = ..Start("read the audit log", "", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    Set tState = ..AwaitEnd(tTurnId, 20, .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes: " _ tView.%ToJSON())
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 2, 10), "call 2 lands")
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Set tResultBlocks = tMessages.%Get(tMessages.%Size() - 1).content
    Set tResultBlock = tResultBlocks.%Get(0)
    Do $$$AssertEquals(tResultBlock."is_error", 0, "the read tool answers, not an error: " _ tResultBlock.content)
    Set tContent = ##class(%DynamicAbstractObject).%FromJSON(tResultBlock.content)
    Set tIterator = tContent.rows.%GetIterator()
    Set tFoundSeeded = 0
    Set tSeededCut = 0
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tValue = tRow.%Get("EventData")
        If (tValue = "") || (tValue '[ tMarker) Continue
        Set tFoundSeeded = 1
        Set tSeededCut = ($Length(tValue) = 1000) && ($Extract(tValue, 1000) = $Char(8230))
    }
    Do $$$AssertTrue(tFoundSeeded, "this test's own seeded row is in the result: " _ tContent.%ToJSON())
    Do $$$AssertTrue(tSeededCut, "the seeded row's own EventData is cut to 1,000 characters, ending U+2026")
    Do $$$AssertTrue(tContent.truncatedFields.%ToJSON() [ """EventData""", "EventData is named in truncatedFields: " _ tContent.truncatedFields.%ToJSON())
}

/// <p><code>GET</code>/<code>PUT /agent/context</code> over the wire: a stored choice reads back
/// for its own caller, and <code>leavesInstance</code> follows the marked-local flag against the
/// armed <code>turnprobe</code> row's own endpoint (<code>192.0.2.10</code>, a public test-net
/// address).</p>
Method TestContextStatusOverTheWire()
{
    Do ..Call("GET", "/agent/context", "", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the read answers: " _ tText)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "JSON content type")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tAnswer.provider, "turnprobe", "the enabled default's provider")
    Do $$$AssertEquals(tAnswer.endpointHost, "192.0.2.10", "the armed row's own host")
    Do $$$AssertEquals(tAnswer.leavesInstance, 1, "a public test-net address leaves the instance")

    Do ..Call("PUT", "/agent/context", "{""share"":false}", .tPutStatus, .tPutText, .tPutHeaders)
    Do $$$AssertEquals(tPutStatus, 200, "the choice is stored: " _ tPutText)
    Set tAfter = ##class(%DynamicObject).%FromJSON(tPutText)
    Do $$$AssertEquals(tAfter.share _ "|" _ tAfter.userChoice, "0|0", "the caller's own choice reads back")

    Do ..Call("PUT", "/agent/context", "{""share"":""not-a-boolean""}", .tBadStatus, .tBadText, .tBadHeaders)
    Do $$$AssertEquals(tBadStatus, 422, "a badly typed share is refused: " _ tBadText)
    Set tBadAnswer = ##class(%DynamicObject).%FromJSON(tBadText)
    Do $$$AssertEquals(tBadAnswer.code, "AGENT.CONTEXT.SHARE", "with its own code")

    Do ..Call("PUT", "/agent/context", "{""share"":false,""extra"":1}", .tExtraStatus, .tExtraText, .tExtraHeaders)
    Do $$$AssertEquals(tExtraStatus, 422, "an extra member is refused too: " _ tExtraText)
}

/// <p><code>GET /agent/context</code> with no enabled default (Story 4.4's own boundary): the
/// prepared <code>turnprobe</code> definition is disabled for the call, so
/// <method>OcuPilot.Kernel.State.Agent.ResolveDefault</method> finds nothing and the wire answers
/// <code>provider ""</code>, <code>endpointHost ""</code> and <code>leavesInstance</code>
/// JSON null.</p>
Method TestContextStatusWithNoEnabledDefault()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedDefinitionId, 0, 1), "the prepared definition is disabled")
    Try {
        Do ..Call("GET", "/agent/context", "", .tStatus, .tText, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, "the read still answers: " _ tText)
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
        Do $$$AssertEquals(tAnswer.provider, "", "no provider with no enabled default")
        Do $$$AssertEquals(tAnswer.endpointHost, "", "no host either")
        Do $$$AssertEquals(tAnswer.%Get("leavesInstance"), "", "and leavesInstance is JSON null")
    } Catch ex {
        Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedDefinitionId, 1, 1), "the prepared definition is re-enabled even after a failure")
        Throw ex
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedDefinitionId, 1, 1), "the prepared definition is re-enabled")
}

/// <p>AC3, two principals over the wire (DW-1030): user A's <code>PUT {share:false}</code> is read
/// back by A alone; user B, who has stored no choice, reads the instance default with
/// <code>userChoice</code> null, never A's.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.State.Sharing.GuardedForUser</method>'s per-user lookup
/// removed -- B would read A's stored choice instead of not-found, and this goes red.</p>
Method TestTwoPrincipalsGetTheirOwnSharingChoiceOverTheWire()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 0), "start clean")
    Set tRow("shareContextByDefault") = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tRow), "the instance default is on")

    Do ..CallAs("PUT", "/agent/context", $Parameter(..#FIXTURE, "USERA"), "{""share"":false}", .tPutStatus, .tPutText, .tPutHeaders)
    Do $$$AssertEquals(tPutStatus, 200, "A's choice is stored: " _ tPutText)

    Do ..CallAs("GET", "/agent/context", $Parameter(..#FIXTURE, "USERA"), "", .tAStatus, .tAText, .tAHeaders)
    Do $$$AssertEquals(tAStatus, 200, "A reads back: " _ tAText)
    Set tA = ##class(%DynamicObject).%FromJSON(tAText)
    Do $$$AssertEquals(tA.share _ "|" _ tA.userChoice, "0|0", "A reads its own stored choice, off")

    Do ..CallAs("GET", "/agent/context", $Parameter(..#FIXTURE, "USERB"), "", .tBStatus, .tBText, .tBHeaders)
    Do $$$AssertEquals(tBStatus, 200, "B reads back: " _ tBText)
    Set tB = ##class(%DynamicObject).%FromJSON(tBText)
    Do $$$AssertEquals(tB.share, 1, "B, with no row, follows the instance default, on")
    Do $$$AssertEquals(tB.%Get("userChoice"), "", "B's userChoice is null, not A's stored false")
}

/// <p>Job scope (DW-1031) -- a turn started with <code>?ns=HSLIB</code> runs the shell namespaces
/// read tool inside the spawned job, whose execution namespace is always the install namespace;
/// the tool's own <code>scope</code> field is <code>OcuPilot.Kernel.Scope.Current()</code> as the
/// job reads it, which is <code>HSLIB</code> only if <method>OcuPilot.Kernel.Agent.Job.Run</method>
/// actually <code>Scope.Set</code>s the route's resolved scope before the loop runs.
/// <code>%DB_HSLIB</code> carries public READ on this build, so <var>USERA</var> -- the account
/// <method>Call</method> runs as -- may enter it with no extra grant.</p>
/// <p>Mutation: drop <code>Do ##class(OcuPilot.Kernel.Scope).Set(pScope)</code> from
/// <method>OcuPilot.Kernel.Agent.Job.Run</method> -- the reported scope falls back to the job's
/// own execution namespace instead of HSLIB, and this goes red.</p>
Method TestATurnStartedUnderNsSetsTheJobsScope()
{
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply("shell_namespaces_read"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Do ..Call("POST", "/turn?ns=HSLIB", $ClassMethod(..#FIXTURE, "StartBody", "which namespace"), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the start under ?ns=HSLIB is accepted: " _ tText)
    Set tTurnId = ##class(%DynamicObject).%FromJSON(tText).turnId
    Set tState = ..AwaitEnd(tTurnId, 15, .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes: " _ tView.%ToJSON())
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 2, 10), "call 2 lands")
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Set tResultBlocks = tMessages.%Get(tMessages.%Size() - 1).content
    Set tContent = ##class(%DynamicAbstractObject).%FromJSON(tResultBlocks.%Get(0).content)
    Do $$$AssertEquals(tContent.scope, "HSLIB", "the job's own scope is the route's ?ns=, not its execution namespace")
}

/// <p>Restore the prepared definition's <code>MarkedLocal</code> and <code>EndpointUrl</code> to
/// what <method>OcuPilot.Test.TurnWireFixture.EnsureDefinition</method> set them to, and re-enable
/// and re-verify it -- a security-field edit through <method>OcuPilot.Kernel.State.Agent.GuardedUpdate</method>
/// clears both flags (AC5), whatever a test left them at.</p>
Method RestorePreparedDefinition()
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(..PreparedDefinitionId, .tRow)
    If $$$ISOK(tSC) && $IsObject(tRow) {
        Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tRow, .tSnapshot)
        Set tRow.MarkedLocal = 0
        Set tRow.EndpointUrl = ##class(OcuPilot.Test.TurnWireFixture).#ENDPOINTURL
        Do ##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tRow, .tSnapshot)
        Set tRow = ""
    }
    Do ##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedDefinitionId, 1, 1)
}

/// <p>Legs of <code>GET /agent/context</code>'s body left unasserted elsewhere (DW-1034):
/// <code>shareDefault</code> distinct from the caller's own effective <code>share</code>,
/// <code>contextRowCap</code> against a resolved value, a definition marked local overriding a
/// public-looking host, and an empty <code>EndpointUrl</code> falling back to the catalog's own
/// <code>defaultEndpoint</code>.</p>
Method TestContextStatusUnassertedLegs()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 0), "start clean")
    Set tRow("shareContextByDefault") = 1
    Set tRow("contextRowCap") = 37
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tRow), "the instance default is on, the row cap 37")

    Do ..Call("PUT", "/agent/context", "{""share"":false}", .tPutStatus, .tPutText, .tPutHeaders)
    Do $$$AssertEquals(tPutStatus, 200, "the caller's own choice is stored off: " _ tPutText)

    Do ..Call("GET", "/agent/context", "", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the read answers: " _ tText)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tAnswer.share, 0, "the caller's own choice, not the default")
    Do $$$AssertEquals(tAnswer.shareDefault, 1, "shareDefault is the instance's, distinct from share")
    Do $$$AssertEquals(tAnswer.contextRowCap, 37, "contextRowCap is the resolved switch value")

    ; A second read with the switch flipped off, so shareDefault is pinned against the switch it
    ; actually reads, not merely against a value a hardcoded constant would also produce (review
    ; pass finding: the first read alone cannot fail a hardcoded shareDefault=1 regression).
    Set tRowOff("shareContextByDefault") = 0
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tRowOff), "the instance default flips off")
    Do ..Call("GET", "/agent/context", "", .tOffStatus, .tOffText, .tOffHeaders)
    Do $$$AssertEquals(tOffStatus, 200, "the read still answers: " _ tOffText)
    Set tOffAnswer = ##class(%DynamicObject).%FromJSON(tOffText)
    Do $$$AssertEquals(tOffAnswer.share, 0, "the caller's own choice is unchanged")
    Do $$$AssertEquals(tOffAnswer.shareDefault, 0, "shareDefault follows the switch off")

    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(..PreparedDefinitionId, .tDefRow)
        Do $$$AssertStatusOK(tSC, "the prepared definition opens")
        Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tDefRow, .tSnapshot)
        Set tDefRow.MarkedLocal = 1
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tDefRow, .tSnapshot), "marked local")
        Set tDefRow = ""
        Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedDefinitionId, 1, 1), "re-enabled after the security-field edit")

        Do ..Call("GET", "/agent/context", "", .tLocalStatus, .tLocalText, .tLocalHeaders)
        Do $$$AssertEquals(tLocalStatus, 200, "the read still answers: " _ tLocalText)
        Set tLocalAnswer = ##class(%DynamicObject).%FromJSON(tLocalText)
        Do $$$AssertEquals(tLocalAnswer.endpointHost, "192.0.2.10", "still the same public-looking host")
        Do $$$AssertEquals(tLocalAnswer.leavesInstance, 0, "but marked local overrides it")

        Set tSC2 = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(..PreparedDefinitionId, .tDefRow2)
        Do $$$AssertStatusOK(tSC2, "the prepared definition opens again")
        Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tDefRow2, .tSnapshot2)
        Set tDefRow2.MarkedLocal = 0
        Set tDefRow2.EndpointUrl = ""
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tDefRow2, .tSnapshot2), "unmarked local, endpoint blanked")
        Set tDefRow2 = ""
        Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedDefinitionId, 1, 1), "re-enabled after the second security-field edit")

        Do ..Call("GET", "/agent/context", "", .tDefaultStatus, .tDefaultText, .tDefaultHeaders)
        Do $$$AssertEquals(tDefaultStatus, 200, "the read still answers: " _ tDefaultText)
        Set tDefaultAnswer = ##class(%DynamicObject).%FromJSON(tDefaultText)
        Do $$$AssertEquals(tDefaultAnswer.endpointHost, "192.0.2.10", "an empty EndpointUrl falls back to the catalog's own defaultEndpoint")
    } Catch ex {
        Do ..RestorePreparedDefinition()
        Throw ex
    }
    Do ..RestorePreparedDefinition()
}

}
