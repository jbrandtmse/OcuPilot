/// <p>Story 20.14's integration criterion (AD-8, AD-29, AD-31): a principal holding
/// <code>%Ens_Portal</code> and no <code>%Admin_*</code> resource and no <code>%Development</code> runs a real turn job against the
/// armed <code>turnprobe</code> row. The turn calls a tool the principal holds, then one it lacks:
/// the first answers, the second is refused <code>AUTH.NOPRIVILEGE</code> by name, and the turn
/// completes -- the provider port admits it and no step boundary abandons it.</p>
/// <p>The principal is <class>OcuPilot.Test.TurnWireFixture</class>'s, holding that fixture's
/// <method>OcuPilot.Test.TurnWireFixture.Resources</method>(0) and a second role granting
/// <code>%Ens_Portal:U,%Ens_ProductionConfig:R</code>, read back before the test runs. It needs both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>PROVIDERVARIABLE</parameter> armed; after the
/// method no probe job, turn, slot or stub node remains, and the principals, their roles and the probe
/// definition are removed in <method>OnAfterAllTests</method>.</p>
/// <p><b>The in-process leg.</b> <method>TestTheShippedProviderGateAdmitsByTheLastFloorPairAndRefusesNone</method>
/// calls <method>OcuPilot.Port.ProviderPort.Invoke</method> directly, as the turn owner, for a definition
/// no row holds. The shipped gate admits that principal by the floor's last member alone, and refuses
/// <parameter>OcuPilot.Test.TurnWireFixture.USERB</parameter>, which holds the fixture's
/// <method>OcuPilot.Test.TurnWireFixture.Resources</method>(0) and no member of
/// <method>OcuPilot.Screen.Gate.FloorResources</method> at <code>USE</code>, read back before the test runs.</p>
Class OcuPilot.Test.InteropFloorTurn Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "interopfloor-probe";

/// <p>What the second role grants.</p>
Parameter INTEROPGRANT = "%Ens_Portal:U,%Ens_ProductionConfig:R";

/// <p>The tool the principal holds, and the one it lacks, as the provider names them.</p>
Parameter HELDTOOL = "interop_productions_read";

/// <p>See <parameter>HELDTOOL</parameter>.</p>
Parameter LACKEDTOOL = "webapp_list_read";

Property PreparedPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Property PreparedUserBOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Set ..PreparedSetupOk = 0
    Set ..PreparedUserBOk = 0
    Quit $$$OK
}

/// <p>Refuse unless both variables arm the instance, create the principal and the default
/// <code>turnprobe</code> definition, and read back through
/// <method>OcuPilot.Test.InteropFloorFixture.Composed</method> that the principal holds
/// <code>%Ens_Portal:USE</code>, not <code>%Development:USE</code> and none of <parameter>OcuPilot.Screen.Gate.ADMINRESOURCES</parameter>.
/// It also creates <parameter>OcuPilot.Test.TurnWireFixture.USERB</parameter> with the same first role and no second,
/// and reads back that it holds no member of <method>OcuPilot.Screen.Gate.FloorResources</method> at <code>USE</code>.
/// The first floor member the first principal holds is the floor's last, <code>%Ens_Portal</code>.</p>
Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropFloorTurn creates IRIS users and roles and runs turn jobs against the turnprobe row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources", 0), ..#INTEROPGRANT)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tId
    Set tSC = ##class(OcuPilot.Test.InteropFloorFixture).Composed(tUser, .tComposed)
    If $$$ISERR(tSC) Quit tSC
    Set tAdmin = ##class(OcuPilot.Test.InteropFloorFixture).HoldsAdministrative(tComposed)
    Set ..PreparedSetupOk = ##class(OcuPilot.Test.InteropFloorFixture).Holds(tComposed, "%Ens_Portal", "USE") && '##class(OcuPilot.Test.InteropFloorFixture).Holds(tComposed, "%Development", "USE") && 'tAdmin
    If '..PreparedSetupOk Quit $$$ERROR($$$GeneralError, "Setup could not read back that " _ tUser _ " holds %Ens_Portal:USE, no %Development:USE and no administrative resource (administrative " _ tAdmin _ ")")
    Set tFirstHeld = ..FloorMemberHeld(tComposed)
    If tFirstHeld '= "%Ens_Portal" Quit $$$ERROR($$$GeneralError, "Setup could not read back that " _ tUser _ " holds the floor's last member and no earlier one (its first is " _ tFirstHeld _ ")")
    Set tUserB = $Parameter(..#FIXTURE, "USERB")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", tUserB, ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources", 0))
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Test.InteropFloorFixture).Composed(tUserB, .tComposedB)
    If $$$ISERR(tSC) Quit tSC
    Set tFloorHeld = ..FloorMemberHeld(tComposedB)
    Set ..PreparedUserBOk = (tFloorHeld = "")
    If '..PreparedUserBOk Quit $$$ERROR($$$GeneralError, "Setup could not read back that " _ tUserB _ " holds no floor resource at USE (it holds " _ tFloorHeld _ ")")
    Quit $$$OK
}

/// <p>The first member of <method>OcuPilot.Screen.Gate.FloorResources</method> that <var>pComposed</var>,
/// a <method>OcuPilot.Test.InteropFloorFixture.Composed</method> answer, holds at <code>USE</code>, and
/// <code>""</code> when it holds none.</p>
ClassMethod FloorMemberHeld(pComposed As %DynamicObject) As %String
{
    Set tResource = ""
    Set tFloor = ##class(OcuPilot.Screen.Gate).FloorResources()
    For tI = 1:1:$Length(tFloor, ",") {
        Set tResource = $Piece(tFloor, ",", tI)
        If (tResource '= "") && ##class(OcuPilot.Test.InteropFloorFixture).Holds(pComposed, tResource, "USE") Quit
        Set tResource = ""
    }
    Quit tResource
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropFloorTurn teardown left:" _ tLeft)
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

/// <p><b>The integration row (AC3).</b> The turn's first tool call reads the Productions list and
/// answers; its second asks for Web applications and is refused
/// <code>AUTH.NOPRIVILEGE</code>, naming <code>%Admin_Secure:USE</code>; the turn completes, never
/// <code>TURN.ABANDONED.PRIVILEGE</code>, and its provider calls all ran.</p>
/// <p>Mutations: <class>OcuPilot.Api.Turn</class> passing
/// <parameter>OcuPilot.Api.Router.ADMINRESOURCES</parameter> to the job -> the first step boundary
/// abandons the turn; <parameter>OcuPilot.Port.ProviderPort.INVOKEPAIRS</parameter> set to the
/// <parameter>OcuPilot.Screen.Gate.ADMINRESOURCES</parameter> members alone, each at
/// <code>USE</code> -> the provider port refuses the first call; either way this goes red.</p>
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
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "StartBody", "list the productions, then the web applications", tConvId), .tStatus, .tText, .tHeaders)
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
    }
    Do $$$AssertTrue($IsObject(tLackedStep), "the lacked tool ran as a step")
    If $IsObject(tLackedStep) {
        Do $$$AssertEquals(tLackedStep.status _ "|" _ tLackedStep.code _ "|" _ tLackedStep.failedPair, "error|AUTH.NOPRIVILEGE|%Admin_Secure:USE", "the lacked tool is refused by name")
    }
}

/// <p><b>The shipped provider gate, in process.</b> <method>OcuPilot.Port.ProviderPort.Invoke</method>
/// is asked, as each principal, for a definition no row holds. <parameter>OcuPilot.Test.TurnWireFixture.USERA</parameter>
/// holds only the floor's last member, <code>%Ens_Portal:USE</code>: any one floor pair admits, so the
/// call passes the gate and ends at the missing definition, answering neither
/// <method>OcuPilot.Kernel.Denial.Code</method> nor its status. <parameter>OcuPilot.Test.TurnWireFixture.USERB</parameter>
/// holds no floor member, so the call is refused with the denial's status, code and sentence.</p>
/// <p>Mutations: <method>OcuPilot.Port.ProviderPort.GateAnyOfForUser</method> requiring every pair -> the
/// <code>USERA</code> legs go red; <method>OcuPilot.Port.ProviderPort.HoldsPairForUser</method> answering 1
/// -> the <code>USERB</code> legs go red.</p>
Method TestTheShippedProviderGateAdmitsByTheLastFloorPairAndRefusesNone()
{
    Do $$$AssertTrue(..PreparedSetupOk && ..PreparedUserBOk, "setup read back both principals' grants")
    Set tFloor = ##class(OcuPilot.Screen.Gate).FloorResources()
    Do $$$AssertEquals($Piece(tFloor, ",", $Length(tFloor, ",")), "%Ens_Portal", "the floor's last member is the resource USERA holds")
    Set tDefinition = "OcuPilotProbeNoSuchDefinition"
    Set tUserA = $Parameter(..#FIXTURE, "USERA")
    Set tUserB = $Parameter(..#FIXTURE, "USERB")

    Kill tMessages, tTools
    Do ##class(OcuPilot.Port.ProviderPort).Invoke(tDefinition, .tMessages, .tTools, "", .tResponse, .tHttpA, .tFaultA, tUserA)
    Set tCodeA = $Select($IsObject(tFaultA): tFaultA.%Get("code"), 1: "")
    Do $$$AssertNotEquals(tHttpA, ##class(OcuPilot.Kernel.Denial).#STATUS, "the floor-last holder is not answered the gate's status: " _ tHttpA _ " " _ tCodeA)
    Do $$$AssertNotEquals(tCodeA, ##class(OcuPilot.Kernel.Denial).Code(), "the floor-last holder is not refused by the gate: " _ tCodeA)
    Do $$$AssertEquals(tHttpA _ "|" _ tCodeA, "503|" _ ##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, "it ends at the definition no row holds")

    Kill tMessages, tTools
    Do ##class(OcuPilot.Port.ProviderPort).Invoke(tDefinition, .tMessages, .tTools, "", .tResponse, .tHttpB, .tFaultB, tUserB)
    Set tCodeB = $Select($IsObject(tFaultB): tFaultB.%Get("code"), 1: "")
    Set tReasonB = $Select($IsObject(tFaultB): tFaultB.%Get("reason"), 1: "")
    Do $$$AssertEquals(tHttpB, ##class(OcuPilot.Kernel.Denial).#STATUS, "the holder of no floor member is answered the gate's status")
    Do $$$AssertEquals(tCodeB, ##class(OcuPilot.Kernel.Denial).Code(), "and the gate's code")
    Do $$$AssertEquals(tReasonB, ##class(OcuPilot.Kernel.Denial).Reason(), "and the gate's sentence")
}

}
