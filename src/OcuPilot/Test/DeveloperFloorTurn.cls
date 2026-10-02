/// <p>Story 19.12's integration criterion (AD-8, AD-29, AD-31): a principal holding
/// <code>%Development</code> and no <code>%Admin_*</code> resource runs a real turn job against the
/// armed <code>turnprobe</code> row. The turn calls a tool the principal holds, then one it lacks:
/// the first answers rows, the second is refused <code>AUTH.NOPRIVILEGE</code> by name, and the turn
/// completes -- the provider port admits it and no step boundary abandons it.</p>
/// <p>The principal is <class>OcuPilot.Test.TurnWireFixture</class>'s, holding that fixture's
/// <method>OcuPilot.Test.TurnWireFixture.Resources</method>(0) and a second role granting
/// <code>%Development:U</code>, read back before the test runs. It needs both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>PROVIDERVARIABLE</parameter> armed; after the
/// method no probe job, turn, slot or stub node remains, and the principal, its roles and the probe
/// definition are removed in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.DeveloperFloorTurn Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "developerfloor-probe";

/// <p>What the second role grants.</p>
Parameter DEVELOPMENTGRANT = "%Development:U";

/// <p>The tool the principal holds, and the one it lacks, as the provider names them.</p>
Parameter HELDTOOL = "explorer_classes_read";

/// <p>See <parameter>HELDTOOL</parameter>.</p>
Parameter LACKEDTOOL = "webapp_list_read";

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
/// <code>turnprobe</code> definition, and read back that the principal holds
/// <code>%Development:USE</code> and none of <parameter>OcuPilot.Screen.Gate.ADMINRESOURCES</parameter>.</p>
Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DeveloperFloorTurn creates IRIS users and roles and runs turn jobs against the turnprobe row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources", 0), ..#DEVELOPMENTGRANT)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tId
    Set tAdmin = 0
    Set tList = ##class(OcuPilot.Screen.Gate).#ADMINRESOURCES
    For tI = 1:1:$Length(tList, ",") {
        If $SYSTEM.Security.CheckUserPermission(tUser, $Piece(tList, ",", tI), "USE") = 1 Set tAdmin = 1
    }
    Set ..PreparedSetupOk = ($SYSTEM.Security.CheckUserPermission(tUser, "%Development", "USE") = 1) && 'tAdmin
    If '..PreparedSetupOk Quit $$$ERROR($$$GeneralError, "Setup could not read back that " _ tUser _ " holds %Development:USE and no administrative resource (administrative " _ tAdmin _ ")")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DeveloperFloorTurn teardown left:" _ tLeft)
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
    Quit $$$OK
}

/// <p><b>The integration row (AC3).</b> The turn's first tool call reads System Explorer's Classes
/// list and answers rows; its second asks for Web applications and is refused
/// <code>AUTH.NOPRIVILEGE</code>, naming <code>%Admin_Secure:USE</code>; the turn completes, never
/// <code>TURN.ABANDONED.PRIVILEGE</code>, and its provider calls all ran.</p>
/// <p>Mutations: <class>OcuPilot.Api.Turn</class> passing
/// <parameter>OcuPilot.Api.Router.ADMINRESOURCES</parameter> to the job -> the first step boundary
/// abandons the turn; <parameter>OcuPilot.Port.ProviderPort.INVOKEPAIRS</parameter> set to
/// <method>OcuPilot.Screen.Gate.AdminPairSpec</method> -> the provider port refuses the first call;
/// either way this goes red.</p>
Method TestATurnCallsAHeldToolAndIsRefusedALackedOne()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principal's grants")
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tHeld = [{"id": "toolu_held", "input": {}}]
    Do tHeld.%Get(0).%Set("name", ..#HELDTOOL, "string")
    Set tLacked = [{"id": "toolu_lacked", "input": {}}]
    Do tLacked.%Get(0).%Set("name", ..#LACKEDTOOL, "string")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tHeld))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tLacked))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))

    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedPassword, .tStatus, .tText)
    Do $$$AssertNotEquals(tConvId, "", "the principal starts a conversation: " _ tStatus _ " " _ $Extract(tText, 1, 200))
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "StartBody", "list the classes, then the web applications", tConvId), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the turn starts: " _ $Extract(tText, 1, 200))
    If tStatus '= 202 Quit
    Set tId = ##class(%DynamicObject).%FromJSON(tText).turnId
    Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", tId, tUser, ..PreparedPassword, 60, .tView)
    Set tCode = $Select($IsObject(tView) && $IsObject(tView.%Get("error")): tView.error.%Get("code"), 1: "")
    Do $$$AssertEquals(tState _ "|" _ tCode, "completed|", "the turn completes, neither abandoned nor refused: " _ tState _ "|" _ tCode)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 3, "and the provider answered all three calls")
    If '$IsObject(tView) Quit

    Set tHeldStep = ""
    Set tLackedStep = ""
    Set tIterator = tView.steps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        If tStep.kind '= "tool" Continue
        If tStep.name = $Translate(..#HELDTOOL, "_", ".") Set tHeldStep = tStep
        If tStep.name = $Translate(..#LACKEDTOOL, "_", ".") Set tLackedStep = tStep
    }
    Do $$$AssertTrue($IsObject(tHeldStep), "the held tool ran as a step")
    If $IsObject(tHeldStep) {
        Do $$$AssertEquals(tHeldStep.status, "ok", "the held tool answers: " _ tHeldStep.code)
        Set tRows = tHeldStep.%Get("result")
        Do $$$AssertTrue($IsObject(tRows) && (+tRows.%Get("rowsReturned") > 0), "with rows")
    }
    Do $$$AssertTrue($IsObject(tLackedStep), "the lacked tool ran as a step")
    If $IsObject(tLackedStep) {
        Do $$$AssertEquals(tLackedStep.status _ "|" _ tLackedStep.code _ "|" _ tLackedStep.failedPair, "error|AUTH.NOPRIVILEGE|%Admin_Secure:USE", "the lacked tool is refused by name")
    }
}

}
