/// <p>Tools in a real turn job, over the wire (AD-1, AD-8, AD-11, AD-31): a turn posted as the suite's
/// account advertises every tool and answers the shell instance read and the users read with their
/// results; a tool the turn searches for is deferred, found and then called (Story 18.45); and a principal whose role carrying <code>%Admin_Secure:USE</code> is removed while its
/// turn runs is refused that pair from its current grants, although the job's <code>$ROLES</code>
/// still names the role -- observed on the requests <class>OcuPilot.Test.TurnProvider</class>
/// recorded and on the turn's progress.</p>
/// <p><b>It creates an IRIS user and two roles and spawns turn jobs, so
/// <method>OnBeforeAllTests</method> refuses to run unless both <parameter>ARMINGVARIABLE</parameter>
/// and <parameter>PROVIDERVARIABLE</parameter> read 1.</b> After every method no probe job, turn, ledger
/// row, slot, stub node, principal, role or probe definition remains.</p>
Class OcuPilot.Test.ToolWire Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "toolwire-probe";

Property PreparedPassword As %String;

Property PreparedPrior As %String;

/// <p>Turn keys of the suite's own account this class started, which the probe sweep does not reach.</p>
Property PreparedKeys [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedPrior = ""
    Kill ..PreparedKeys
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ToolWire creates an IRIS user and roles and runs turn jobs, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ToolWire runs turn jobs against the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Kill ..PreparedKeys
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = ##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal($Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"), "%Admin_Secure:U")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Do ..Teardown()
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Set tLeft = ..Teardown()
    Do $$$AssertEquals(tLeft, "", "no probe job, turn, ledger row, slot, stub node, principal, role or probe definition survives the method")
    Quit $$$OK
}

/// <p>Remove everything a method may have created, and answer what survives, <code>""</code> when
/// nothing does.</p>
Method Teardown() As %String
{
    Set tLeft = ""
    Set tKey = ""
    For {
        Set tKey = $Order(..PreparedKeys(tKey))
        If tKey = "" Quit
        Do ##class(OcuPilot.Test.TurnFixture).AwaitTerminal(tKey, 15)
        Set tPid = ##class(OcuPilot.Test.TurnFixture).Field(tKey, "JobId")
        If (tPid '= "") && $Data(^$JOB(tPid)) && '##class(OcuPilot.Kernel.State.Turn).IsTerminal(##class(OcuPilot.Test.TurnFixture).Field(tKey, "State")) Do $SYSTEM.Process.Terminate(tPid)
        Set tGone = $ZHorolog + 10
        While (tPid '= "") && $Data(^$JOB(tPid)) && ($ZHorolog < tGone) {
            Hang 0.25
        }
        If (tPid '= "") && $Data(^$JOB(tPid)) Set tLeft = tLeft _ " job " _ tPid
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tKey)
        Set tLedgerRows = ""
        If $$$ISERR(##class(OcuPilot.Kernel.State.Ledger).GuardedCountForTurn(tKey, .tLedgerRows)) || tLedgerRows Set tLeft = tLeft _ " ledger rows of " _ tKey
        Do ##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tKey)
        If (##class(OcuPilot.Test.TurnFixture).Field(tKey, "State") '= "") || ##class(OcuPilot.Test.TurnFixture).StepCount(tKey) || $Data(^OcuPilotTurnSignal(tKey)) Set tLeft = tLeft _ " turn " _ tKey
    }
    Kill ..PreparedKeys
    If ##class(OcuPilot.Test.TurnFixture).SlotOwner(##class(OcuPilot.Test.Http).GetTestUsername()) '= "" Set tLeft = tLeft _ " the suite account's slot"
    Set tLeft = tLeft _ $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    If $$$ISERR(tSC) Set tLeft = tLeft _ " definitions (" _ $System.Status.GetErrorText(tSC) _ ")"
    Set tLeft = tLeft _ ##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()
    Quit $ZStrip(tLeft, "<>W")
}

/// <p>Post a start as <var>pUser</var> with <var>pPassword</var>; the turn id when it answered 202.</p>
Method Start(pUser As %String, pPassword As %String, pMessage As %String, Output pStatus As %Integer, Output pText As %String) As %String
{
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", pUser, pPassword, .tConvStatus, .tConvText)
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn", pUser, pPassword, $ClassMethod(..#FIXTURE, "StartBody", pMessage, tConvId), .pStatus, .pText, .tHeaders)
    If pStatus '= 202 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(pText).turnId
}

/// <p>The kind, name, status and code of every step in <var>pView</var>, one
/// <code>kind:name:status:code</code> per step, joined by <code>;</code>.</p>
ClassMethod Steps(pView As %DynamicObject) As %String
{
    Set tSteps = ""
    If '$IsObject(pView) || '$IsObject(pView.steps) Quit ""
    For tI = 0:1:pView.steps.%Size() - 1 {
        Set tStep = pView.steps.%Get(tI)
        Set tSteps = tSteps _ tStep.kind _ ":" _ tStep.name _ ":" _ tStep.status _ ":" _ tStep.code _ ";"
    }
    Quit tSteps
}

/// <p>Integration -- a turn posted as the suite's account: call 1 advertises every wire name and the
/// stub asks for the shell instance read and the users read; call 2 carries both results, the
/// instance's own name and user rows; the turn completes with two ok tool steps.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Dispatch.Answer</method> renders every call as an error
/// -> this goes red.</p>
Method TestATurnAnswersTheShellAndUsersReads()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tCalls = [{"id": "toolu_instance", "name": "shell_instance_read", "input": {}}, {"id": "toolu_users", "name": "permissions_users_read", "input": {"maxRows": 5}}]
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tCalls))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tId = ..Start(tUser, ##class(OcuPilot.Test.Http).GetTestPassword(), "which instance is this", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    If tId = "" Quit
    Set ..PreparedKeys(tId) = ""
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AwaitEnd", tId, tUser, ##class(OcuPilot.Test.Http).GetTestPassword(), 60, .tView), "completed", "the turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 2, "after two provider calls")

    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tExpected), "the registry advertises")
    Set tWires = ""
    For tI = 1:1:+$Get(tExpected) Set tWires = tWires _ $Select(tI = 1: "", 1: ",") _ tExpected(tI, "name")
    Set tTools = ##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "tools")
    Set tAdvertised = ""
    If tTools '= "" {
        Set tArray = ##class(%DynamicArray).%FromJSON(tTools)
        For tI = 0:1:tArray.%Size() - 1 Set tAdvertised = tAdvertised _ $Select(tI = 0: "", 1: ",") _ tArray.%Get(tI).name
    }
    Do $$$AssertEquals(tAdvertised, tWires, "call 1 advertised every wire name")
    Do $$$AssertTrue(tAdvertised [ "shell_instance_read", "the shell reads among them")

    Set tMessages = ##class(%DynamicArray).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Set tResults = tMessages.%Get(2).content
    Do $$$AssertEquals(tResults.%Size(), 2, "call 2 carries two tool results")
    If tResults.%Size() '= 2 Quit
    Set tInstance = tResults.%Get(0)
    Do $$$AssertEquals(tInstance."tool_use_id" _ "|" _ tInstance."is_error", "toolu_instance|0", "the instance read answered: " _ $Extract(tInstance.content, 1, 200))
    Set tInstanceBody = ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tInstance.content, .tInstanceWrapped)
    Do $$$AssertTrue(tInstanceWrapped, "the instance read arrives framed as data")
    If 'tInstance."is_error" Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tInstanceBody).instanceName, ##class(%SYS.System).GetInstanceName(), "with the instance's own name")
    Set tUsers = tResults.%Get(1)
    Do $$$AssertEquals(tUsers."tool_use_id" _ "|" _ tUsers."is_error", "toolu_users|0", "the users read answered: " _ $Extract(tUsers.content, 1, 200))
    Set tUsersBody = ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tUsers.content, .tUsersWrapped)
    Do $$$AssertTrue(tUsersWrapped, "the users read arrives framed as data")
    If 'tUsers."is_error" Do $$$AssertTrue(##class(%DynamicObject).%FromJSON(tUsersBody).rows.%Size() > 0, "with user rows")
    Do $$$AssertEquals(..Steps(tView), "model:provider:ok:;tool:shell.instance.read:ok:;tool:permissions.users.read:ok:;model:provider:ok:;", "two ok tool steps under their dotted names")
}

/// <p>Revoked mid-turn -- the principal's second role, which alone carries
/// <code>%Admin_Secure:USE</code>, is removed during call 1; the users read that call asks for is
/// refused <code>AUTH.NOPRIVILEGE</code> naming that pair, from the current grants, while call 2's
/// recorded <code>$ROLES</code> still names the role; the turn reaches call 2 and completes.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Dispatch.HoldsPair</method> uses
/// <code>$System.Security.Check</code> -> this goes red.</p>
/// <p>Also pins the I/O & Edge-Case Matrix's "Failed tool" row (spec-4-5): the failed step's own
/// <property>OcuPilot.Kernel.State.Step.FailedPair</property> and <property>Reason</property>
/// (Story 4.5) reach the turn's wire view, not only the tool_result content already asserted
/// above.</p>
Method TestARoleRemovedMidTurnIsRefusedFromCurrentGrants()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tSecond = $Parameter(..#FIXTURE, "SECONDROLE")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Secure", "USE"), 1, "the principal holds %Admin_Secure:USE through its second role")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 4, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_users", "name": "permissions_users_read", "input": {}}]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tId = ..Start(tUser, ..PreparedPassword, "who are the users", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    If tId = "" Quit
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 1, 15), "the provider call began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnWireFixture).RemoveSecondRole(tUser), "the second role is removed")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Secure", "USE"), 0, "and the principal's grants no longer hold the pair")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AwaitEnd", tId, tUser, ..PreparedPassword, 60, .tView), "completed", "the turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 2, "after reaching call 2")
    Do $$$AssertTrue($ZConvert(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "roles"), "U") [ $ZConvert(tSecond, "U"), "the job's roles still name the removed role: " _ ##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "roles"))
    Set tMessages = ##class(%DynamicArray).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Set tResult = tMessages.%Get(2).content.%Get(0)
    Set tBody = ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tResult.content, .tWrapped)
    Do $$$AssertTrue(tWrapped, "the refusal arrives framed as data: " _ tResult.content)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tBody, "1|{""code"":""AUTH.NOPRIVILEGE"",""detail"":{""failedPair"":""%Admin_Secure:USE"",""screen"":""permissions.users""}}", "the users read is refused naming the pair and its screen")
    Do $$$AssertEquals(..Steps(tView), "model:provider:ok:;tool:permissions.users.read:error:AUTH.NOPRIVILEGE;model:provider:ok:;", "recorded as an error tool step, not retried")
    Set tFailedStep = tView.steps.%Get(1)
    Do $$$AssertEquals(tFailedStep.failedPair, "%Admin_Secure:USE", "the step itself carries the failed pair, not only the tool_result content")
    Do $$$AssertEquals(tFailedStep.failedScreen, "permissions.users", "and the screen it names")
    Do $$$AssertNotEquals(tFailedStep.reason, "", "and a published reason for the card's failed status")
}

/// <p>Story 4.7's own matrix row "Route the caller cannot open": <var>USERA</var>'s second role,
/// the only one carrying <code>%Admin_Secure:USE</code> (<method>OnBeforeOneTest</method>'s own
/// setup), is removed before the call this time -- rather than mid-turn, as
/// <method>TestARoleRemovedMidTurnIsRefusedFromCurrentGrants</method> does -- so the principal
/// never holds the pair <code>shell_screen_open</code> for <code>permissions/users</code> needs
/// (AD-8, the same pair that screen's own read tool requires). <code>Dispatch.ResolveClientCall</code>
/// refuses it at the same step-7 check <code>AnswerOne</code> uses, before any announcement
/// exists: no <code>announce</code> step is ever written, only the tool step's own refusal.</p>
/// <p>Mutation: skip the argument-pairs check in
/// <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> -> this goes red.</p>
Method TestANavigationTargetTheCallerCannotOpenIsRefusedBeforeAnyAnnouncement()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnWireFixture).RemoveSecondRole(tUser), "the second role, which alone carries %Admin_Secure:USE, is removed before the call")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Secure", "USE"), 0, "the principal now holds no %Admin_Secure:USE")
    Set tCalls = [{"id": "toolu_nav", "name": "shell_screen_open", "input": {"route": "permissions/users"}}]
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tCalls)), "the call is scripted")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done")), "and the reply")
    Set tId = ..Start(tUser, ..PreparedPassword, "open the users screen", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    If tId = "" Quit
    Set ..PreparedKeys(tId) = ""
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AwaitEnd", tId, tUser, ..PreparedPassword, 60, .tView), "completed", "the turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 2, "after reaching call 2")
    Set tMessages = ##class(%DynamicArray).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Set tResult = tMessages.%Get(2).content.%Get(0)
    Set tBody = ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tResult.content, .tWrapped)
    Do $$$AssertTrue(tWrapped, "the refusal arrives framed as data: " _ tResult.content)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tBody, "1|{""code"":""AUTH.NOPRIVILEGE"",""detail"":{""failedPair"":""%Admin_Secure:USE""}}", "the navigation call is refused naming the pair")
    Do $$$AssertEquals(..Steps(tView), "model:provider:ok:;tool:shell.screen.open:error:AUTH.NOPRIVILEGE;model:provider:ok:;", "the tool step itself is the refusal -- no announce step is ever recorded")
}

/// <p>Integration (Story 18.45) -- a turn posted as the suite's account searches and then calls the
/// tool it found: call 1 asks <code>shell_tools_find</code> for "permissions users read", call 2 calls
/// <code>permissions_users_read</code> with <code>maxRows</code> 5 and call 3 ends. Every request
/// carries the same <code>tools</code> text, holding the whole advertised roster, with the users read
/// deferred, only the shell's tools undeferred and the cache marker on the last of those; call 2's
/// result for the search is a list of <code>tool_reference</code> blocks naming the users read first;
/// call 3 carries the users read's own answer; and both tool steps are ok.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> keeps the search's content as
/// the text it was answered with, not the references -> this goes red.</p>
Method TestASearchedToolIsCalledOverAnUnchangedArray()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tFind = [{"id": "toolu_find", "name": "shell_tools_find", "input": {"query": "permissions users read"}}]
    Set tUsers = [{"id": "toolu_users", "name": "permissions_users_read", "input": {"maxRows": 5}}]
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tFind))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tUsers))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tId = ..Start(tUser, ##class(OcuPilot.Test.Http).GetTestPassword(), "which tool lists users", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    If tId = "" Quit
    Set ..PreparedKeys(tId) = ""
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AwaitEnd", tId, tUser, ##class(OcuPilot.Test.Http).GetTestPassword(), 60, .tView), "completed", "the turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 3, "after three provider calls")

    Set tFirst = ##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "tools")
    Do $$$AssertEquals(tFirst, ##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "tools"), "call 2 carries call 1's tools, byte for byte")
    Do $$$AssertEquals(tFirst, ##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 3, "tools"), "and so does call 3")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tAdvertised), "the registry advertises")
    Set tTools = ##class(%DynamicArray).%FromJSON(tFirst)
    Do $$$AssertEquals(tTools.%Size(), +$Get(tAdvertised), "every advertised tool is sent")
    Set tDeferredUsers = 0
    Set tUndeferred = ""
    Set tLast = -1
    For tI = 0:1:tTools.%Size() - 1 {
        Set tTool = tTools.%Get(tI)
        If tTool.name = "permissions_users_read" Set tDeferredUsers = ''tTool."defer_loading"
        If tTool."defer_loading" Continue
        Set tUndeferred = tUndeferred _ $Select(tUndeferred = "": "", 1: ",") _ tTool.name
        Set tLast = tI
    }
    Do $$$AssertEquals(tDeferredUsers, 1, "the users read is deferred")
    Do $$$AssertTrue($Length(tUndeferred, ",") >= 2, "the shell's tools are not: " _ tUndeferred)
    Set tOutside = 0
    For tI = 1:1:$Length(tUndeferred, ",") If $Extract($Piece(tUndeferred, ",", tI), 1, 6) '= "shell_" Set tOutside = tOutside + 1
    Do $$$AssertEquals(tOutside, 0, "and are the only ones, with no screen context: " _ tUndeferred)
    Do $$$AssertTrue(("," _ tUndeferred _ ",") [ ",shell_tools_find,", "shell_tools_find is among them")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).Marks(tFirst), 1, "one tool carries the cache marker")
    If tLast >= 0 Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).MarkOf(tTools.%Get(tLast)), ##class(OcuPilot.Test.TurnBudget).#EPHEMERAL, "the last tool that is not deferred, " _ tTools.%Get(tLast).name)

    Set tSecond = ##class(%DynamicArray).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Set tSearch = tSecond.%Get(2).content.%Get(0)
    Do $$$AssertEquals(tSearch."tool_use_id" _ "|" _ tSearch."is_error" _ "|" _ tSearch.%GetTypeOf("content"), "toolu_find|0|array", "call 2's result for the search is a list, not text")
    If tSearch.%GetTypeOf("content") = "array" {
        Do $$$AssertEquals(tSearch.content.%Get(0).%ToJSON(), "{""type"":""tool_reference"",""tool_name"":""permissions_users_read""}", "naming the users read first")
        Set tNotReferences = 0
        For tI = 0:1:tSearch.content.%Size() - 1 If (tSearch.content.%Get(tI).type '= "tool_reference") || (tSearch.content.%Get(tI).%Size() '= 2) Set tNotReferences = tNotReferences + 1
        Do $$$AssertEquals(tNotReferences, 0, "and every entry is exactly a reference")
    }
    Set tThird = ##class(%DynamicArray).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 3, "messages"))
    Set tAnswer = tThird.%Get(4).content.%Get(0)
    Do $$$AssertEquals(tAnswer."tool_use_id" _ "|" _ tAnswer."is_error", "toolu_users|0", "call 3 carries the users read's answer: " _ $Extract(tAnswer.content, 1, 200))
    Set tBody = ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tAnswer.content, .tWrapped)
    Do $$$AssertTrue(tWrapped, "framed as data")
    If 'tAnswer."is_error" Do $$$AssertTrue(##class(%DynamicObject).%FromJSON(tBody).rows.%Size() > 0, "with user rows")
    Do $$$AssertEquals(..Steps(tView), "model:provider:ok:;tool:shell.tools.find:ok:;model:provider:ok:;tool:permissions.users.read:ok:;model:provider:ok:;", "both tool steps are ok")
}

}
