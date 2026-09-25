/// <p>Story 11.9 over HTTP, driven by real armed turns against the <code>turnprobe</code> row: the
/// recorded provider request's <code>screen_context</code> result carries the two members the
/// instance derives (<code>tools</code> and <code>readOnly</code>), <code>readOnly</code> follows
/// the verdict dispatch enforces under enforced read-only and under a read-only definition, a
/// request that supplies either member is refused before anything is reserved, and the error
/// list's rows reach the turn narrowed to its summary fields and capped (AD-11, AD-24, AD-30,
/// AD-48). Story 11.1: an explain turn carries the screen's read tool and the prompt's explain
/// statement, and Home's empty route reaches the turn as Home's identity.</p>
/// <p><b>It creates an IRIS user and a role and spawns turn jobs, so
/// <method>OnBeforeAllTests</method> refuses to run unless both</b>
/// <parameter>ARMINGVARIABLE</parameter> <b>and</b> <parameter>PROVIDERVARIABLE</parameter>
/// <b>read 1.</b> Only <file>scripts/ci-throwaway.sh</file> sets them. Each method resets the
/// switches and restores the prepared definition's read-only flag.</p>
Class OcuPilot.Test.TurnGrounding Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "turngrounding-probe";

Parameter APIBASE = "/api/ocupilot";

/// <p>The message the panel's "Explain this screen" button sends, the client's
/// <code>STRINGS.agentExplainScreenAction</code>.</p>
Parameter EXPLAINMESSAGE = "Explain this screen";

/// <p>The process list's tools, as the registry names them.</p>
Parameter PROCESSTOOLS = "[""osmgmt_processes_read"",""osmgmt_processes_resume"",""osmgmt_processes_suspend"",""osmgmt_processes_terminate"",""osmgmt_processes_terminatewitherror""]";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnGrounding creates an IRIS user and a role and runs turn jobs, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnGrounding runs turn jobs against the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"))
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
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnGrounding teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds)
    Do ##class(OcuPilot.Kernel.State.Sharing).DeleteAllGuarded()
    Set tSC = ##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly(..PreparedDefinitionId, 0)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds), "the switches are reset")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly(..PreparedDefinitionId, 0), "the prepared definition's read-only flag is restored")
    Do ##class(OcuPilot.Kernel.State.Sharing).DeleteAllGuarded()
    Quit $$$OK
}

/// <p>One request as the probe principal.</p>
Method Call(pMethod As %String, pPath As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ pPath, $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, .pStatus, .pText, .tHeaders, pBody, "application/json")
}

/// <p>Start a turn carrying <var>pContext</var> that answers one text reply, wait for its one
/// provider call, and answer the <code>screen_context</code> payload that call recorded, or
/// <code>""</code> when none was.</p>
Method RecordedContext(pMessage As %String, pContext As %DynamicObject) As %DynamicObject
{
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, .tConvStatus, .tConvText)
    Do ..Call("POST", "/turn", $ClassMethod(..#FIXTURE, "StartBody", pMessage, tConvId, pContext), .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    If tStatus '= 202 Quit ""
    Set tTurnId = ##class(%DynamicObject).%FromJSON(tText).turnId
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 1, 10), "call 1 lands")
    Do $ClassMethod(..#FIXTURE, "AwaitEnd", tTurnId, $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, 5, .tView)
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "messages"))
    Do $$$AssertEquals(tMessages.%Size(), 3, "the turn opens with the synthetic screen_context pair")
    If tMessages.%Size() '= 3 Quit ""
    Set tResultBlock = tMessages.%Get(2).content.%Get(0)
    Do $$$AssertEquals(tResultBlock.type _ "|" _ tResultBlock."tool_use_id", "tool_result|ocupilot_screen_context", "the synthetic tool_result")
    Quit ##class(%DynamicAbstractObject).%FromJSON(tResultBlock.content)
}

/// <p>A process-list context of two rows.</p>
ClassMethod ProcessContext() As %DynamicObject
{
    Set tContext = {"route": "os-management/processes", "namespace": "HSCUSTOM", "view": {"rows": [{"Pid": "11", "Routine": "a"}, {"Pid": "12", "Routine": "b"}], "rowsAvailable": 2}}
    Quit tContext
}

/// <p>The Integration acceptance criterion: a list screen's recorded payload carries its tools, and
/// <code>readOnly</code> false while neither the switch nor the definition restrains the turn.</p>
Method TestAListScreenCarriesItsToolsAndReadOnly()
{
    Set tPayload = ..RecordedContext("what is running", ..ProcessContext())
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.screen, "osmgmt.processes", "the process list's context")
    Do $$$AssertEquals(tPayload.tools.%ToJSON(), ..#PROCESSTOOLS, "carrying its read and its four action tools")
    Do $$$AssertEquals(tPayload.%GetTypeOf("readOnly") _ "|" _ tPayload.readOnly, "boolean|0", "and readOnly false, as a boolean")
    Do $$$AssertEquals(tPayload.rowsSent, 2, "beside its rows")
}

/// <p>Enforced read-only makes <code>readOnly</code> true.</p>
Method TestEnforcedReadOnlyReadsTrue()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 1), "enforced read-only is on")
    Set tPayload = ..RecordedContext("what is running", ..ProcessContext())
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.readOnly, 1, "readOnly is true under enforced read-only")
    Do $$$AssertEquals(tPayload.tools.%ToJSON(), ..#PROCESSTOOLS, "and the tools are still named")
}

/// <p>A read-only definition makes <code>readOnly</code> true with the switch off, because the
/// member is the verdict's <code>blocked</code> and not the switch alone.</p>
Method TestAReadOnlyDefinitionReadsTrue()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 0), "the switches are off")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly(..PreparedDefinitionId, 1), "the definition is read-only")
    Set tPayload = ..RecordedContext("what is running", ..ProcessContext())
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.readOnly, 1, "readOnly is true under a read-only definition")
}

/// <p>A request carrying <code>tools</code> or <code>readOnly</code> is refused 422
/// <code>TURN.CONTEXT.INVALID</code> on <code>context</code>, and no turn is reserved.</p>
Method TestARequestSupplyingAMemberIsRefusedAndNothingIsReserved()
{
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, .tConvStatus, .tConvText)
    Do $$$AssertTrue(tConvId '= "", "a conversation is started, so only the member stands between the body and a reservation: " _ tConvText)
    For tMember = "tools", "readOnly" {
        Set tContext = ..ProcessContext()
        If tMember = "tools" Do tContext.%Set("tools", ["osmgmt_processes_read"])
        If tMember = "readOnly" Do tContext.%Set("readOnly", 0, "boolean")
        Do ..Call("POST", "/turn", $ClassMethod(..#FIXTURE, "StartBody", "hi", tConvId, tContext), .tStatus, .tText)
        Do $$$AssertEquals(tStatus, 422, "a context carrying " _ tMember _ " is refused: " _ tText)
        If tStatus '= 422 Continue
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
        Do $$$AssertEquals(tAnswer.detail.violations.%Get(0).field _ "|" _ tAnswer.detail.violations.%Get(0).code, "context|TURN.CONTEXT.INVALID", tMember _ " is refused on the context field")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).Keys(.tKeys), "the turn keys can be read")
    Do $$$AssertEquals(+tKeys, 0, "no turn was reserved by either refusal")
}

/// <p>A detail screen's <code>tools</code> resolve through its <code>parentScope</code> over the
/// wire, not only through the direct <code>ScreenTools</code> and <code>BoundedContext</code>
/// calls <code>ScreenGrounding</code> pins in process: the detail's own read, then the parent
/// list's four action tools.</p>
Method TestADetailScreenNamesItsParentsToolsOverTheWire()
{
    Set tContext = {"route": "os-management/processes/details", "namespace": "HSCUSTOM", "entity": "11", "view": {"rows": [{"Pid": "11", "JobType": "GET"}], "rowsAvailable": 1}}
    Set tPayload = ..RecordedContext("what is this process", tContext)
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.screen, "osmgmt.processdetails", "the detail's own identity")
    Do $$$AssertEquals(tPayload.tools.%ToJSON(), "[""osmgmt_processdetails_read"",""osmgmt_processes_resume"",""osmgmt_processes_suspend"",""osmgmt_processes_terminate"",""osmgmt_processes_terminatewitherror""]", "the detail's own read, then the parent list's four action tools, resolved through parentScope over the wire")
}

/// <p>The identity-only branch -- a descriptor declaring <code>context.secretFields</code> --
/// carries both members with no <code>rows</code> key at all, over the wire, not only through the
/// direct <code>BoundedContext</code> call <code>ScreenGrounding.TestBothMembersRideBothBranches</code>
/// pins in process.</p>
Method TestTheIdentityOnlyBranchCarriesBothMembersOverTheWire()
{
    Set tContext = {"route": "security/wallet/secrets/edit", "namespace": "HSCUSTOM", "entity": "probe"}
    Set tPayload = ..RecordedContext("what secret is this", tContext)
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.screen, "security.secretform", "identity is still projected")
    Do $$$AssertEquals(tPayload.%GetTypeOf("rows"), "unassigned", "no rows key at all")
    Do $$$AssertEquals(tPayload.rowsSent, 0, "rowsSent is still reported, at 0")
    Do $$$AssertEquals(tPayload.tools.%ToJSON(), "[]", "the form names no tool")
    Do $$$AssertEquals(tPayload.%GetTypeOf("readOnly"), "boolean", "and readOnly rides the identity-only branch too")
}

/// <p>The error list's rows reach the turn narrowed to the five summary fields and capped at the
/// row cap, with its read and delete tools named.</p>
Method TestTheErrorListsRowsAreNarrowedAndCapped()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 0), "start clean")
    Set tRow("contextRowCap") = 2
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tRow), "the row cap is 2")
    Set tRows = []
    For tI = 1:1:3 {
        Do tRows.%Push({"errorNumber": (tI), "time": "17:01:38", "errorText": "<DIVIDE>x^y", "routine": "y", "line": " s x=1/0", "username": "Dana", "process": "4711"})
    }
    Set tContext = {"route": "logs/errors", "namespace": "HSCUSTOM", "view": {"sort": "", "direction": "", "filter": "", "rowsAvailable": 3}}
    Do tContext.view.%Set("rows", tRows)
    Set tPayload = ..RecordedContext("why did this fail", tContext)
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.rowsSent _ "|" _ tPayload.rowsAvailable _ "|" _ tPayload.truncated, "2|3|1", "cut to the row cap and marked")
    Set tKeys = ""
    Set tIterator = tPayload.rows.%Get(0).%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $ListBuild(tKey)
    }
    Do $$$AssertEquals($ListToString(tKeys), "errorNumber,time,errorText,routine,line", "a row holds the five summary fields alone")
    Do $$$AssertTrue(tPayload.%ToJSON() '[ "Dana", "the user name never reaches the payload")
    Do $$$AssertTrue(tPayload.%ToJSON() '[ "4711", "nor the process")
    Do $$$AssertEquals(tPayload.tools.%ToJSON(), "[""logs_applicationerrors_read"",""logs_applicationerrors_delete""]", "the error list's read and delete are named")
}

/// <p>An explain turn on the process list: its <code>screen_context</code> names the screen's read
/// tool first, the recorded system prompt carries the explain statement, and the user's own message
/// is the explain sentence, after the context.</p>
Method TestAnExplainTurnCarriesTheReadToolAndTheStatement()
{
    Set tPayload = ..RecordedContext(..#EXPLAINMESSAGE, ..ProcessContext())
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.tools.%Get(0), "osmgmt_processes_read", "the screen's read tool is named first")
    Set tSystem = ##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "system")
    Do $$$AssertTrue(tSystem [ ##class(OcuPilot.Test.ScreenGrounding).Statement(7), "the recorded system prompt carries the explain statement")
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "messages"))
    Set tLast = tMessages.%Get(tMessages.%Size() - 1)
    Set tText = ""
    Set tIterator = tLast.content.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tBlock) {
        If tBlock.type = "text" Set tText = tText _ tBlock.text
    }
    Do $$$AssertEquals(tLast.role _ "|" _ tText, "user|" _ ..#EXPLAINMESSAGE, "the last user message is the explain sentence")
}

/// <p>Home's context reaches the turn: its empty route is accepted, and the recorded payload is
/// Home's identity with no tool, no row and a boolean <code>readOnly</code>.</p>
Method TestHomesContextReachesTheTurn()
{
    Set tContext = {"route": "", "namespace": "HSCUSTOM"}
    Set tPayload = ..RecordedContext("what is this screen", tContext)
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.screen _ "|" _ tPayload.route, "shell.home|", "Home's identity")
    Do $$$AssertEquals(tPayload.tools.%ToJSON(), "[]", "naming no tool")
    Do $$$AssertEquals(tPayload.rowsSent, 0, "sending no row")
    Do $$$AssertEquals(tPayload.%GetTypeOf("readOnly"), "boolean", "and carrying readOnly as a boolean")
}

}
