/// <p>The <code>parentId</code> half of <code>shell.screen.open</code> (AD-5, AD-13, DW-1462):
/// literal pins of which screens take <code>entityId</code>, which take <code>parentId</code> and
/// which refuse both, then a turn through <class>OcuPilot.Test.TurnLoopProbe</class> in
/// <class>OcuPilot.Test.TurnNavigate</class>'s pattern. The registry-wide partition is
/// <class>OcuPilot.Test.ToolNavigate</class>'s sweep.</p>
/// <p>Every turn reserved here runs as <code>$Username</code> on
/// <class>OcuPilot.Test.TurnToolsCase</class>'s harness, whose teardown removes each turn, its
/// ledger rows and the probe definitions. Needs no arming variable.</p>
Class OcuPilot.Test.ToolNavigateParent Extends OcuPilot.Test.TurnToolsCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.Navigate";

/// <p>A parent-scoped screen whose parent's id is one part (a task's id): it takes
/// <code>parentId</code>.</p>
Parameter DETAILS = "tasks/schedule/details";

/// <p>The base's setup, then the navigation limits: a navigating turn's model, tool and announce
/// steps need more than the base probe's step cap.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##super()
    Do $ClassMethod(..#LOOP, "SetLimitsClass", "OcuPilot.Test.TurnLimitsNav")
    Quit tSC
}

/// <p>A turn stopped during the wait is never finished, and a reserve holds the user's slot lock
/// until a finish releases it, so the slot is handed back before the base's teardown checks it.</p>
Method OnAfterOneTest() As %Status
{
    Lock -^OcuPilotTurnSlot($Username)
    Quit ##super()
}

/// <p>The directive's answer for a call of <var>pArgs</var>: the status, then the route, the row id,
/// the parent id and the fault.</p>
ClassMethod Ask(pArgs As %DynamicObject, Output pRoute As %String, Output pEntityId As %String, Output pParentId As %String, Output pFault As %DynamicObject) As %Status
{
    Quit $ClassMethod(..#TOOL, "Directive", "", pArgs, .pRoute, .pEntityId, .pFault, .tCriterion, .tCriteria, .pParentId)
}

/// <p>A parent-scoped screen takes <code>parentId</code> and answers it as the parent, and refuses
/// <code>entityId</code> before any announcement, naming the argument it refused.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Screen.Tool.Navigate.AcceptsEntityId</method>'s
/// <code>ParentScope</code> clause -- the <code>entityId</code> refusal goes red; make
/// <method>OcuPilot.Screen.Tool.Navigate.RefusalFault</method> omit <code>detail.argument</code> --
/// both refusal assertions go red.</p>
Method TestAParentScopedScreenTakesParentIdAndRefusesEntityId()
{
    Set tSC = ..Ask({"route": (..#DETAILS), "parentId": "7"}, .tRoute, .tEntityId, .tParentId, .tFault)
    Do $$$AssertStatusOK(tSC, "a parent-scoped screen accepts a parentId")
    Do $$$AssertEquals(tRoute _ "|" _ tEntityId _ "|" _ tParentId, ..#DETAILS _ "||7", "and answers the route and the parent, no row")
    Do $$$AssertEquals(tFault, "", "with no fault")

    Set tSC2 = ..Ask({"route": (..#DETAILS), "entityId": "7"}, .tRoute2, .tEntityId2, .tParentId2, .tFault2)
    Do $$$AssertStatusNotOK(tSC2, "the same screen refuses an entityId")
    Do $$$AssertEquals(tFault2.code, "NAV.ENTITYNOTALLOWED", "naming the code")
    Do $$$AssertEquals(tFault2.detail.argument, "entityId", "and the argument")
    Do $$$AssertEquals(tRoute2 _ tEntityId2 _ tParentId2, "", "and validates nothing")
}

/// <p>A screen with no parent scope refuses <code>parentId</code>, naming it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.Navigate.AcceptsParentId</method>
/// answer 1 for a screen with no parent scope -- this goes red.</p>
Method TestAScreenWithNoParentRefusesParentId()
{
    Set tSC = ..Ask({"route": "tasks/schedule", "parentId": "7"}, .tRoute, .tEntityId, .tParentId, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a screen of its own rows refuses a parentId")
    Do $$$AssertEquals(tFault.code, "NAV.ENTITYNOTALLOWED", "naming the code")
    Do $$$AssertEquals(tFault.detail.argument, "parentId", "and the argument")
    Do $$$AssertEquals(tRoute _ tEntityId _ tParentId, "", "and validates nothing")
    Do $$$AssertEquals($ClassMethod(##class(OcuPilot.Screen.Registry).DescriptorForRoute("tasks/schedule"), "ParentScope"), "", "that screen really has no parent scope")
}

/// <p>A screen whose parent's id is composite of two parts refuses both arguments: the model would
/// have to compose the shared encoder's join, the second grammar AD-5 forbids. A composite id
/// written out is refused the same way.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.Navigate.AcceptsParentId</method> read
/// the screen's own id shape -- this goes red.</p>
Method TestAParentWithACompositeIdRefusesBothArguments()
{
    Set tRoute = "interoperability/productions/items/jobs"
    Set tDescriptor = ##class(OcuPilot.Screen.Registry).DescriptorForRoute(tRoute)
    Set tParent = ##class(OcuPilot.Screen.Registry).DescriptorForRoute($ClassMethod(tDescriptor, "ParentScope"))
    Do $$$AssertEquals($ClassMethod(tParent, "IdKind") _ "/" _ $ListLength($ClassMethod(tParent, "IdParts")), "composite/2", "the parent's id really has two parts")
    For tArgument = "entityId", "parentId" {
        Set tArgs = {"route": (tRoute)}
        Do tArgs.%Set(tArgument, "P||N", "string")
        Set tSC = ..Ask(tArgs, .tOut, .tEntity, .tParentOut, .tFault)
        Do $$$AssertStatusNotOK(tSC, tArgument _ " is refused")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.code _ "|" _ tFault.detail.argument, 1: ""), "NAV.ENTITYNOTALLOWED|" _ tArgument, "naming the code and the argument")
    }
}

/// <p>The history of a task opens for its parent: it was refused while the screen's own id kind
/// was read in place of its parent's.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.Navigate.AcceptsParentId</method> read
/// the screen's own id shape -- this goes red.</p>
Method TestTheTaskHistoryOpensForItsParent()
{
    Set tSC = ..Ask({"route": "tasks/schedule/history", "parentId": "7"}, .tRoute, .tEntityId, .tParentId, .tFault)
    Do $$$AssertStatusOK(tSC, "the history screen accepts a parentId")
    Do $$$AssertEquals(tRoute _ "|" _ tEntityId _ "|" _ tParentId, "tasks/schedule/history||7", "and answers the route and the parent")
}

/// <p>The settled result echoes <code>parentId</code> and no <code>entityId</code>.</p>
/// <p>Mutation (Rule 19): drop the <code>parentId</code> echo from
/// <method>OcuPilot.Kernel.Agent.Dispatch.SettleClient</method> -- this goes red.</p>
Method TestTheSettledResultEchoesParentId()
{
    Set tDetail = {}
    Do tDetail.%Set("route", ..#DETAILS, "string")
    Do tDetail.%Set("parentId", "7", "string")
    Do ##class(OcuPilot.Kernel.Agent.Dispatch).SettleClient(tDetail, "opened", "", .tContent)
    Set tResult = ##class(%DynamicAbstractObject).%FromJSON(tContent)
    Do $$$AssertEquals(tResult.parentId, "7", "parentId is echoed: " _ tContent)
    Do $$$AssertEquals(tResult.%IsDefined("entityId"), 0, "and no entityId is")
    Do $$$AssertEquals(tResult.navigated, 1, "the screen opened")
}

/// <p>A provider reply requesting <code>shell_screen_open</code> on <var>pRoute</var> with the id
/// argument <var>pArgument</var> (<code>entityId</code> or <code>parentId</code>) set to
/// <var>pId</var>.</p>
ClassMethod NavReply(pRoute As %String, pArgument As %String, pId As %String) As %String
{
    Set tInput = {"route": (pRoute)}
    Do tInput.%Set(pArgument, pId, "string")
    Quit ..Reply("", [{"id": "toolu_nav", "name": "shell_screen_open", "input": (tInput)}])
}

/// <p>Reserve and begin a turn for <var>pDefinitionId</var>, answering its key and start time. Apart
/// from the base's <method>RunTurn</method>, so a test can start the browser's settle job between
/// the begin and the run.</p>
Method Begin(pDefinitionId As %String, Output pStarted As %Integer) As %String
{
    Set tLimits = $ClassMethod(..#LOOP, "LimitsClass")
    Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedReserve($Username, pDefinitionId, "TURN.ABANDONED.JOBLOST", tLimits, .tKey, .tBusy, .tSweep)
    Do $$$AssertStatusOK(tSC, "the turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and the slot was free")
    If tKey '= "" Set ..PreparedKeys(tKey) = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, $Username, tLimits, .tBegun, .pStarted), "the turn begins")
    Do $$$AssertEquals(tBegun, 1, "in this process")
    Quit tKey
}

/// <p>Run the scripted turn <var>pKey</var>, begun by <method>Begin</method>, to its end and
/// finish it.</p>
Method RunBegun(pKey As %String, pDefinitionId As %String, pStarted As %Integer)
{
    Set tSC = $ClassMethod(..#LOOP, "Run", pKey, $Username, pDefinitionId, "open it", 0, ##class(OcuPilot.Api.Router).#ADMINRESOURCES, pStarted, .tOutcome)
    Do $$$AssertStatusOK(tSC, "the loop returns")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(pKey, $Username, tOutcome("state"), tOutcome("code"), tOutcome("limit"), tOutcome("reply"), tOutcome("errorSeq"), $ClassMethod(..#LOOP, "LimitsClass")), "and finished")
}

/// <p>Run a scripted turn whose call names <var>pArgument</var> (<code>entityId</code> or
/// <code>parentId</code>) as <var>pId</var> on <var>pRoute</var>, and the browser opens it: the
/// pending navigation and the announce step carry the route's one id, and the model is told the
/// screen opened under the argument it named, with no member for the other.</p>
Method OpenedTurn(pRoute As %String, pArgument As %String, pId As %String)
{
    Set tOther = $Select(pArgument = "parentId": "entityId", 1: "parentId")
    Set tId = ..NewDefinition()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..NavReply(pRoute, pArgument, pId))
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..Reply("opened"))
    Set tKey = ..Begin(tId, .tStarted)
    Job ##class(OcuPilot.Test.NavSettleJob).SettleWhenPending(tKey, "opened", "", 10)
    Do ..RunBegun(tKey, tId, tStarted)

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Nav).GuardedPending(tKey, .tPSeq, .tPRoute, .tPEntity, .tPSettled, .tPOutcome, .tPCode), "the directive reads")
    Do $$$AssertEquals(tPRoute, pRoute, "the pending navigation names the route")
    Do $$$AssertEquals(tPEntity, pId, "and holds the route's id")
    Do $$$AssertEquals(tPOutcome, "opened", "and settled opened")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedRows(tKey, .tRows), "the steps read")
    Set tAnnounceText = "unset"
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.kind = "announce" Set tAnnounceText = tRow.text
    }
    Do $$$AssertEquals(tAnnounceText, pId, "the announce step carries the route's id, and settling keeps it")

    Set tSettled = ##class(OcuPilot.Test.TurnNavigate).NavToolResult(2)
    Do $$$AssertTrue($IsObject(tSettled), "the settled tool_result reached the next provider call")
    Set tBody = ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tSettled.content, .tWrapped)
    Set tContent = ##class(%DynamicAbstractObject).%FromJSON(tBody)
    Do $$$AssertEquals(tContent.%Get(pArgument), pId, "the model is told the " _ pArgument _ " it opened for: " _ tSettled.content)
    Do $$$AssertEquals(tContent.%IsDefined(tOther), 0, "and no " _ tOther)
    Do $$$AssertEquals(tContent.route, pRoute, "on the route it asked for")
    Do $$$AssertEquals(''tContent.navigated, 1, "reporting the navigation as performed")
}

/// <p>A turn whose scripted call names <code>parentId</code>: the announce step and the pending
/// navigation carry the route's id (the parent's), and the model is told the screen opened for that
/// parent -- <code>parentId</code>, no <code>entityId</code>.</p>
/// <p>Mutation (Rule 19): hand <method>OcuPilot.Kernel.State.Nav.GuardedRequest</method>
/// <code>tEntityId</code> in <method>OcuPilot.Kernel.Agent.Loop.AnswerClientCall</method> in place
/// of the route's id -- the pending navigation and the announce assertions go red; settle with
/// <code>entityId</code> in place of <code>parentId</code> -- the settled-content assertions go
/// red; drop <code>.tParentId</code> from the <code>ResolveClientCall</code> call -- all three go
/// red.</p>
Method TestAParentIdTurnStoresTheRouteIdAndSettlesWithParentId()
{
    Do ..OpenedTurn(..#DETAILS, "parentId", "7")
}

/// <p>A turn whose scripted call names <var>pArgument</var> as <var>pId</var> on <var>pRoute</var>
/// is refused before any announcement: no announce step, no directive, the tool step carries the
/// code and the written sentence, and the model's result names the code and the refused
/// argument.</p>
Method RefusedTurn(pRoute As %String, pArgument As %String, pId As %String)
{
    Set tId = ..NewDefinition()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..NavReply(pRoute, pArgument, pId))
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..Reply("refused"))
    Set tKey = ..Begin(tId, .tStarted)
    Do ..RunBegun(tKey, tId, tStarted)

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedRows(tKey, .tRows), "the steps read")
    Set tHasAnnounce = 0
    Set tToolCode = ""
    Set tToolReason = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.kind = "announce" Set tHasAnnounce = 1
        If tRow.kind = "tool" {
            Set tToolCode = tRow.code
            Set tToolReason = tRow.reason
        }
    }
    Do $$$AssertEquals(tHasAnnounce, 0, "no announce step was written")
    Do $$$AssertEquals(tToolCode, "NAV.ENTITYNOTALLOWED", "the tool step carries the refusal")
    Do $$$AssertEquals(tToolReason, "This screen cannot be opened on that item.", "and the sentence a person reads in the trace")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Nav).GuardedPending(tKey, .tPSeq, .tPRoute, .tPEntity, .tPSettled, .tPOutcome, .tPCode), "the directive reads")
    Do $$$AssertEquals(tPSeq, 0, "and no directive was requested")

    Set tResult = ##class(OcuPilot.Test.TurnNavigate).NavToolResult(2)
    Do $$$AssertTrue($IsObject(tResult), "the refusal reached the next provider call")
    Set tBody = ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tResult.content, .tWrapped)
    Set tContent = ##class(%DynamicAbstractObject).%FromJSON(tBody)
    Do $$$AssertEquals(tContent.code, "NAV.ENTITYNOTALLOWED", "the model is told the code: " _ tResult.content)
    Do $$$AssertEquals(tContent.detail.argument, pArgument, "and the argument it must send differently")
}

/// <p>A turn whose scripted call names <code>entityId</code> on a parent-scoped screen is refused
/// before any announcement, and the model's result names the argument it must send differently.</p>
/// <p>Mutation (Rule 19): drop the <code>entityId</code> refusal's <code>detail.argument</code> --
/// the result assertion goes red; let <method>OcuPilot.Screen.Tool.Navigate.AcceptsEntityId</method>
/// ignore the parent scope -- the refusal assertions go red; reword
/// <parameter>OcuPilot.Api.Error.REASONNAVENTITYNOTALLOWED</parameter> -- the sentence assertion
/// goes red.</p>
Method TestAnEntityIdOnAParentScopedScreenIsRefusedBeforeAnyAnnouncement()
{
    Do ..RefusedTurn(..#DETAILS, "entityId", "7")
}

/// <p>The same refusal for <code>parentId</code> on a screen with no parent, naming
/// <code>parentId</code>.</p>
/// <p>Mutation (Rule 19): build the <code>parentId</code> refusal's fault with the argument
/// <code>entityId</code> -- this goes red on the argument the model is told.</p>
Method TestAParentIdOnAScreenWithNoParentIsRefusedBeforeAnyAnnouncement()
{
    Do ..RefusedTurn("tasks/schedule", "parentId", "7")
}

/// <p>The same refusal for a model-composed two-part id on an item tab, as <code>entityId</code>
/// and as <code>parentId</code>: the second composite grammar the four item tabs used to accept
/// (AD-5).</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Screen.Tool.Navigate.AcceptsEntityId</method> ignore
/// the parent scope -- the <code>entityId</code> turn goes red; let
/// <method>OcuPilot.Screen.Tool.Navigate.AcceptsParentId</method> read the screen's own id shape --
/// the <code>parentId</code> turn goes red.</p>
Method TestAComposedIdOnAnItemTabIsRefusedBeforeAnyAnnouncementAsEntityId()
{
    Do ..RefusedTurn("interoperability/productions/items/jobs", "entityId", "Prod||Item")
}

Method TestAComposedIdOnAnItemTabIsRefusedBeforeAnyAnnouncementAsParentId()
{
    Do ..RefusedTurn("interoperability/productions/items/jobs", "parentId", "Prod||Item")
}

/// <p>A row of a screen's own still travels as <code>entityId</code>: the pending navigation and
/// the announce step hold it, and the model is told <code>entityId</code> with no
/// <code>parentId</code>.</p>
/// <p>Mutation (Rule 19): hand <method>OcuPilot.Kernel.State.Nav.GuardedRequest</method> the parent
/// id alone in <method>OcuPilot.Kernel.Agent.Loop.AnswerClientCall</method> -- the pending
/// assertion goes red.</p>
Method TestAnOwnRowTurnStillStoresTheRowAndSettlesWithEntityId()
{
    Do ..OpenedTurn("permissions/users", "entityId", "_SYSTEM")
}

/// <p>A parent-scoped call the browser answers, or that no browser answers before the wait lapses,
/// settles with <code>parentId</code> and no <code>entityId</code>: the Nav row settles to
/// <var>pOutcome</var>, the announce step ends in error with the code and still holds the parent's
/// id, and the model is told the code with the parent.</p>
Method SettledTurn(pBrowserAnswers As %Boolean, pOutcome As %String, pCode As %String)
{
    Set tId = ..NewDefinition()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..NavReply(..#DETAILS, "parentId", "7"))
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..Reply("settled"))
    Set tKey = ..Begin(tId, .tStarted)
    If pBrowserAnswers Job ##class(OcuPilot.Test.NavSettleJob).SettleWhenPending(tKey, pOutcome, pCode, 10)
    Do ..RunBegun(tKey, tId, tStarted)

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Nav).GuardedPending(tKey, .tPSeq, .tPRoute, .tPEntity, .tPSettled, .tPOutcome, .tPCode), "the directive reads")
    Do $$$AssertEquals(tPSettled _ "|" _ tPOutcome _ "|" _ tPCode, "1|" _ pOutcome _ "|" _ pCode, "the navigation settled " _ pOutcome)
    Do $$$AssertEquals(tPEntity, "7", "and still holds the parent's id")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedRows(tKey, .tRows), "the steps read")
    Set tAnnounce = "unset"
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.kind = "announce" Set tAnnounce = tRow.status _ "|" _ tRow.code _ "|" _ tRow.text
    }
    Do $$$AssertEquals(tAnnounce, "error|" _ pCode _ "|7", "the announce step ends in error with the code and keeps the parent's id")

    Set tSettled = ##class(OcuPilot.Test.TurnNavigate).NavToolResult(2)
    Do $$$AssertTrue($IsObject(tSettled), "the result reached the next provider call")
    Set tBody = ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tSettled.content, .tWrapped)
    Set tContent = ##class(%DynamicAbstractObject).%FromJSON(tBody)
    Do $$$AssertEquals(''tContent.navigated, 0, "reporting that nothing moved")
    Do $$$AssertEquals(tContent.code, pCode, "with the code: " _ tSettled.content)
    Do $$$AssertEquals(tContent.parentId, "7", "naming the parent it was for")
    Do $$$AssertEquals(tContent.%IsDefined("entityId"), 0, "and no row")
}

/// <p>The departing screen refuses a navigation to a parent-scoped screen.</p>
/// <p>Mutation (Rule 19): emit <code>parentId</code> from
/// <method>OcuPilot.Kernel.Agent.Dispatch.SettleClient</method> for an opened outcome only -- this
/// goes red.</p>
Method TestAParentIdCallTheBrowserRefusesSettlesWithParentId()
{
    Do ..SettledTurn(1, "refused", "NAV.REFUSEDUNSAVED")
}

/// <p>No browser answers a navigation to a parent-scoped screen before the wait lapses.</p>
/// <p>Mutation (Rule 19): hand <method>OcuPilot.Kernel.State.Step.GuardedUpdate</method> an empty
/// text in the settle in <method>OcuPilot.Kernel.Agent.Loop.AnswerClientCall</method> -- the announce
/// assertion goes red.</p>
Method TestAParentIdCallWhoseWaitLapsesSettlesWithParentId()
{
    Do ..SettledTurn(0, "unavailable", "NAV.UNAVAILABLE")
}

/// <p>While a navigation to a parent-scoped screen waits for the browser, the announce step already
/// carries the parent's id. A stop during the wait leaves the text the step was appended with, where
/// a settle would rewrite it, so this reads the append alone.</p>
/// <p>Mutation (Rule 19): hand <method>OcuPilot.Kernel.State.Step.GuardedAppend</method> the entity
/// id in place of the route's id in <method>OcuPilot.Kernel.Agent.Loop.AnswerClientCall</method> --
/// this goes red.</p>
Method TestTheAnnouncementCarriesTheParentIdWhileTheBrowserWaits()
{
    Set tId = ..NewDefinition()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..NavReply(..#DETAILS, "parentId", "7"))
    Set tKey = ..Begin(tId, .tStarted)
    Job ##class(OcuPilot.Test.NavSettleJob).StopWhenPending(tKey, $Username, 10)

    Set tSC = $ClassMethod(..#LOOP, "Run", tKey, $Username, tId, "open it", 0, ##class(OcuPilot.Api.Router).#ADMINRESOURCES, tStarted, .tOutcome)
    Do $$$AssertStatusOK(tSC, "the loop returns")
    Do $$$AssertEquals(tOutcome("state"), "stopped", "the stop ended the wait before any settle")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedRows(tKey, .tRows), "the steps read")
    Set tAnnounceText = "unset"
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.kind = "announce" Set tAnnounceText = tRow.text
    }
    Do $$$AssertEquals(tAnnounceText, "7", "the announce step was appended with the parent's id")
}

/// <p>A navigating call the step cap drops lapses to <code>NAV.UNAVAILABLE</code>, and the result
/// the model reads names the parent it was for -- <code>parentId</code>, no <code>entityId</code>.</p>
/// <p>Mutation (Rule 19): put <method>OcuPilot.Kernel.Agent.Loop.AnswerClientCall</method>'s dropped
/// detail back to <code>entityId</code> -- this goes red.</p>
Method TestADroppedAnnouncementNamesTheParentInTheLapse()
{
    Do $ClassMethod(..#LOOP, "SetLimitsClass", "OcuPilot.Test.TurnLimitsNavCapped")
    Set tId = ..NewDefinition()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..NavReply(..#DETAILS, "parentId", "7"))
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..Reply("nothing was announced"))
    Set tKey = ..Begin(tId, .tStarted)
    Do ..RunBegun(tKey, tId, tStarted)

    Set tLapse = ##class(OcuPilot.Test.TurnNavigate).NavToolResult(2)
    Do $$$AssertTrue($IsObject(tLapse), "the lapse reached the next provider call as a tool result")
    Set tBody = ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tLapse.content, .tWrapped)
    Set tContent = ##class(%DynamicAbstractObject).%FromJSON(tBody)
    Do $$$AssertEquals(tContent.code, "NAV.UNAVAILABLE", "with the lapse code: " _ tLapse.content)
    Do $$$AssertEquals(tContent.parentId, "7", "naming the parent it was for")
    Do $$$AssertEquals(tContent.%IsDefined("entityId"), 0, "and no row")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Nav).GuardedPending(tKey, .tPSeq, .tPRoute, .tPEntity, .tPSettled, .tPOutcome, .tPCode), "the directive reads")
    Do $$$AssertEquals(tPSeq, 0, "and no directive was requested for the dropped announcement")
}

}
