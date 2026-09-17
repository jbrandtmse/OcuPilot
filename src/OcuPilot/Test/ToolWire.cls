/// <p>Tools in a real turn job, over the wire (AD-1, AD-8, AD-11, AD-31): a turn posted as the suite's
/// account advertises every tool and answers the shell instance read and the users read with their
/// results; and a principal whose role carrying <code>%Admin_Secure:USE</code> is removed while its
/// turn runs is refused that pair from its current grants, although the job's <code>$ROLES</code>
/// still names the role -- observed on the requests <class>OcuPilot.Test.TurnProvider</class>
/// recorded and on the turn's progress.</p>
/// <p><b>It creates an IRIS user and two roles and spawns turn jobs, so
/// <method>OnBeforeAllTests</method> refuses to run unless both <parameter>ARMINGVARIABLE</parameter>
/// and <parameter>PROVIDERVARIABLE</parameter> read 1.</b> After every method no probe job, turn, slot,
/// stub node, principal, role or probe definition remains.</p>
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
    Do $$$AssertEquals(tLeft, "", "no probe job, turn, slot, stub node, principal, role or probe definition survives the method")
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
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn", pUser, pPassword, $ClassMethod(..#FIXTURE, "StartBody", pMessage), .pStatus, .pText, .tHeaders)
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
    If 'tInstance."is_error" Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tInstance.content).instanceName, ##class(%SYS.System).GetInstanceName(), "with the instance's own name")
    Set tUsers = tResults.%Get(1)
    Do $$$AssertEquals(tUsers."tool_use_id" _ "|" _ tUsers."is_error", "toolu_users|0", "the users read answered: " _ $Extract(tUsers.content, 1, 200))
    If 'tUsers."is_error" Do $$$AssertTrue(##class(%DynamicObject).%FromJSON(tUsers.content).rows.%Size() > 0, "with user rows")
    Do $$$AssertEquals(..Steps(tView), "model:provider:ok:;tool:shell.instance.read:ok:;tool:permissions.users.read:ok:;model:provider:ok:;", "two ok tool steps under their dotted names")
}

/// <p>Revoked mid-turn -- the principal's second role, which alone carries
/// <code>%Admin_Secure:USE</code>, is removed during call 1; the users read that call asks for is
/// refused <code>AUTH.NOPRIVILEGE</code> naming that pair, from the current grants, while call 2's
/// recorded <code>$ROLES</code> still names the role; the turn reaches call 2 and completes.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Dispatch.HoldsPair</method> uses
/// <code>$System.Security.Check</code> -> this goes red.</p>
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
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""AUTH.NOPRIVILEGE"",""detail"":{""failedPair"":""%Admin_Secure:USE""}}", "the users read is refused naming the pair")
    Do $$$AssertEquals(..Steps(tView), "model:provider:ok:;tool:permissions.users.read:error:AUTH.NOPRIVILEGE;model:provider:ok:;", "recorded as an error tool step, not retried")
}

}
