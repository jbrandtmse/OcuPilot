/// <p>Story 20.18's integration criteria over the wire (AD-8, AD-24, AD-31, AD-64): a real turn job, run as the
/// principal <class>OcuPilot.Test.TurnWireFixture</class>'s <code>USERA</code> -- Locks' declared pairs and
/// <code>%DB_IRISSYS:READ</code> and <code>WRITE</code>, and not <code>%Admin_Secure:USE</code> -- against the armed
/// <code>turnprobe</code> row, once <code>osmgmt.locks</code> is raised to require <code>%Admin_Secure:USE</code>.
/// The turn's tool call to Locks' remove is refused naming the screen and the pair, no proposal row exists for the
/// turn and it completes; and the turn's <code>screen_context</code> carries the screen's verdict and marks each of
/// its tools unavailable, before and after the raise.</p>
/// <p>It needs both <parameter>ARMINGVARIABLE</parameter> and <parameter>PROVIDERVARIABLE</parameter> armed. After
/// each method no probe job, turn, slot or stub node remains and no screen is adjusted; the principal, its roles and
/// the probe definition are removed in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.ScreenAccessTurn Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "screenaccess-probe";

Parameter SCREEN = "osmgmt.locks";

Parameter ROUTE = "os-management/locks";

/// <p>What the second role grants.</p>
Parameter SECONDGRANT = "%DB_IRISSYS:RW";

/// <p>The pair the raise adds and the principal lacks.</p>
Parameter RAISED = "%Admin_Secure:USE";

Parameter RAISEDSET = "%Admin_Operate:USE,%DB_IRISSYS:READ,%Admin_Secure:USE";

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

/// <p>Refuse unless both variables arm the instance, create the principal and the default
/// <code>turnprobe</code> definition, and read back that the principal holds Locks' declared pairs and
/// <code>%DB_IRISSYS:WRITE</code> and not <parameter>RAISED</parameter>.</p>
Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ScreenAccessTurn creates IRIS users and roles and runs turn jobs against the turnprobe row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources", 1), ..#SECONDGRANT)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tId
    Set tHolds = $SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Operate", "USE") && $SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "READ") && $SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "WRITE")
    Set ..PreparedSetupOk = tHolds && '$SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Secure", "USE")
    If '..PreparedSetupOk Quit $$$ERROR($$$GeneralError, "Setup could not read back that " _ tUser _ " holds Locks' pairs and not " _ ..#RAISED)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Do ##class(OcuPilot.Kernel.State.Access).DeleteAllGuarded()
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ScreenAccessTurn teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.State.Access).DeleteAllGuarded()
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Quit $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Access).DeleteAllGuarded(), "no screen stays adjusted")
    Quit $$$OK
}

/// <p>Raise Locks to require <parameter>RAISED</parameter> as well.</p>
ClassMethod Raise() As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Access).GuardedPut(..#SCREEN, ..#RAISEDSET, 0, $Username)
}

/// <p>Start a turn as the principal that answers <var>pReplies</var>, wait for it to end and answer its state,
/// with the turn's wire view in <var>pView</var> and its id in <var>pTurnId</var>.</p>
Method RunTurn(pMessage As %String, pContext As %DynamicObject, Output pView, Output pTurnId As %String) As %String
{
    Set pTurnId = ""
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedPassword, .tStatus, .tText)
    Do $$$AssertNotEquals(tConvId, "", "the principal starts a conversation: " _ tStatus _ " " _ $Extract(tText, 1, 200))
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "StartBody", pMessage, tConvId, pContext), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the turn starts: " _ $Extract(tText, 1, 200))
    If tStatus '= 202 Quit ""
    Set pTurnId = ##class(%DynamicObject).%FromJSON(tText).turnId
    Quit $ClassMethod(..#FIXTURE, "AwaitEnd", pTurnId, tUser, ..PreparedPassword, 60, .pView)
}

/// <p>The Locks screen context of one turn, as the recorded provider request carried it, unwrapped from the
/// sanitizer's frame, or <code>""</code>.</p>
Method RecordedContext() As %DynamicObject
{
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Set tContext = {"route": (..#ROUTE), "view": {"rows": [], "rowsAvailable": 0}}
    Do tContext.%Set("namespace", $Namespace, "string")
    Set tState = ..RunTurn("what are the locks", tContext, .tView, .tTurnId)
    Do $$$AssertEquals(tState, "completed", "the turn completes")
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "messages"))
    If tMessages.%Size() '= 3 Quit ""
    Set tBody = $ClassMethod(..#FIXTURE, "Unwrapped", tMessages.%Get(2).content.%Get(0).content, .tWrapped)
    Do $$$AssertTrue(tWrapped, "the context arrives framed as data")
    Quit ##class(%DynamicAbstractObject).%FromJSON(tBody)
}

/// <p><b>Screen closed (AC8)</b> -- with Locks raised, the turn's call to its remove is refused
/// <code>AUTH.NOPRIVILEGE</code> naming <code>osmgmt.locks</code> and <code>%Admin_Secure:USE</code>; the step
/// carries both, no proposal row exists for the turn, and the turn completes.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Gate.RequiredPairs</method> ignore the store -- the call
/// is no longer refused at the screen and this goes red.</p>
Method TestARefusalAtAClosedScreenCreatesNoProposalAndTheTurnCompletes()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principal's grants")
    Do $$$AssertStatusOK(..Raise(), "Locks is raised")
    Set tCalls = [{"id": "toolu_locks", "name": "osmgmt_locks_remove", "input": {}}]
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tCalls))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tState = ..RunTurn("remove a lock", "", .tView, .tTurnId)
    Set tCode = $Select($IsObject($Get(tView)) && $IsObject(tView.%Get("error")): tView.error.%Get("code"), 1: "")
    Do $$$AssertEquals(tState _ "|" _ tCode, "completed|", "the turn completes: " _ tState _ "|" _ tCode)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 2, "and the provider answered both calls")
    If '$IsObject($Get(tView)) Quit
    Set tStep = ""
    Set tIterator = tView.steps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.kind = "tool") && (tRow.name = "osmgmt.locks.remove") Set tStep = tRow
    }
    Do $$$AssertTrue($IsObject(tStep), "the remove ran as a step")
    If $IsObject(tStep) Do $$$AssertEquals(tStep.status _ "|" _ tStep.code _ "|" _ tStep.failedPair _ "|" _ tStep.failedScreen, "error|AUTH.NOPRIVILEGE|" _ ..#RAISED _ "|" _ ..#SCREEN, "it is refused naming the pair and the screen")
    Set tMessages = ##class(%DynamicArray).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Set tBlock = tMessages.%Get(2).content.%Get(0)
    Set tBody = $ClassMethod(..#FIXTURE, "Unwrapped", tBlock.content, .tWrapped)
    Do $$$AssertEquals(tBlock."is_error" _ "|" _ tBody, "1|{""code"":""AUTH.NOPRIVILEGE"",""detail"":{""failedPair"":""" _ ..#RAISED _ """,""screen"":""" _ ..#SCREEN _ """}}", "and the model's tool result says the same")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedCountForTurn(tTurnId, .tCount), "the turn's proposals are counted")
    Do $$$AssertEquals(tCount, 0, "no proposal row exists for the turn")
}

/// <p><b>Context</b> -- before the raise the Locks context carries <code>verdict {allowed: true}</code> and no
/// unavailable tool; after it, <code>{allowed: false, failedPair: %Admin_Secure:USE}</code>, and every tool in
/// <code>tools</code> maps to that pair.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Context.Unavailable</method> answer <code>{}</code> -- the
/// second leg goes red.</p>
Method TestTheContextCarriesTheVerdictAndMarksTheToolsUnavailable()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principal's grants")
    Set tBefore = ..RecordedContext()
    If $IsObject(tBefore) {
        Do $$$AssertEquals(tBefore.screen, ..#SCREEN, "the Locks context")
        Do $$$AssertEquals(tBefore.verdict.%ToJSON() _ "|" _ tBefore.unavailable.%ToJSON(), "{""allowed"":true}|{}", "before the raise the screen is open and every tool usable")
    }
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Do $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
    Do $$$AssertStatusOK(..Raise(), "Locks is raised")
    Set tAfter = ..RecordedContext()
    If '$IsObject(tAfter) Quit
    Do $$$AssertEquals(tAfter.verdict.%ToJSON(), "{""allowed"":false,""failedPair"":""" _ ..#RAISED _ """}", "after the raise the screen is closed, naming the pair")
    Set tAll = 1
    Set tCount = 0
    Set tIterator = tAfter.tools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tWire) {
        Set tCount = tCount + 1
        If tAfter.unavailable.%Get(tWire) '= ..#RAISED Set tAll = 0
    }
    Do $$$AssertTrue(tCount > 0, "the screen names tools")
    Set tMarked = 0
    Set tIterator = tAfter.unavailable.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tMarked = tMarked + 1
    }
    Do $$$AssertTrue(tAll && (tMarked = tCount), "and each maps to " _ ..#RAISED _ ": " _ tAfter.unavailable.%ToJSON())
}

}
