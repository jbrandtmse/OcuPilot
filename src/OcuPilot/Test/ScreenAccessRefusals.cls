/// <p>Story 20.15's refusals over HTTP, as Dev (AC6, AD-10, AD-39, AD-64): a change that leaves a screen with
/// no pair, names a resource the instance does not define, is not a resource and a permission, removes a pair
/// the set lacks, adds one it holds or adds a ninth is 422 with one violation on <code>Pair</code>; an action
/// on one of OcuPilot's own screens is refused <code>PROHIBITED.OCUPILOTSCREEN</code>; one on an identifier no
/// screen carries is 404 <code>ACCESS.SCREEN.UNKNOWN</code>. Every case asserts the store is as it was.</p>
/// <p>It needs <parameter>ARMINGVARIABLE</parameter> armed (<class>OcuPilot.Test.ScreenAccessFixture</class>);
/// every adjustment is removed before and after each test.</p>
Class OcuPilot.Test.ScreenAccessRefusals Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it: <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.ScreenAccessFixture";

Parameter SCREEN = "agent.screenpermissions";

/// <p>A screen whose declared set is the single pair <code>%Development:USE</code>.</p>
Parameter ONEPAIR = "explorer.classes";

/// <p>Seven defined resources, which with the declared pair fill a set to its eight.</p>
Parameter FILLERS = "%Admin_Manage,%Admin_Operate,%Admin_Task,%Admin_Journal,%Admin_Wallet,%Admin_OAuth2_Client,%Admin_OAuth2_Server";

Property PreparedPassword As %String;

Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ScreenAccessRefusals creates IRIS users and roles, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set ..PreparedPassword = "OcuPilotRef" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#FIXTURE, "Prepare", ..PreparedPassword)
    Set ..PreparedSetupOk = $$$ISOK(tSC)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "ResetAll")
}

Method OnAfterOneTest() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "ResetAll")
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Do $ClassMethod(..#FIXTURE, "ResetAll")
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ScreenAccessRefusals teardown left:" _ tLeft)
    Quit $$$OK
}

/// <p>One action as Dev: its status in <var>pStatus</var> and the parsed refusal or answer.</p>
Method Act(pAction As %String, pScreen As %String, pPair As %String, Output pStatus As %Integer, Output pObject) As %Status
{
    Set pObject = ""
    Set tBody = {"action": (pAction), "id": (pScreen)}
    If pPair '= "" Do tBody.%Set("values", {"Pair": (pPair)})
    Set tSC = $ClassMethod(..#FIXTURE, "Call", "POST", "/screens/" _ ..#SCREEN _ "/action", $ClassMethod(..#FIXTURE, "Dev"), ..PreparedPassword, .pStatus, .tText, tBody.%ToJSON())
    Try {
        If $Get(tText) '= "" Set pObject = ##class(%DynamicAbstractObject).%FromJSON(tText)
    } Catch {
        Set pObject = ""
    }
    Quit tSC
}

/// <p>The stored rows as one comparable text.</p>
ClassMethod Stored() As %String
{
    Do ##class(OcuPilot.Kernel.State.Access).GuardedAll(.tAll)
    Set tText = ""
    Set tScreen = ""
    For {
        Set tScreen = $Order(tAll(tScreen), 1, tPairs)
        If tScreen = "" Quit
        Set tText = tText _ tScreen _ "=" _ tPairs _ ";"
    }
    Quit tText
}

/// <p>Assert that <var>pAction</var> on <var>pScreen</var> with <var>pPair</var> is refused with status
/// <var>pStatus</var> and code <var>pCode</var>, with one violation on <code>Pair</code> where it is a 422,
/// and that the store is unchanged.</p>
Method Refused(pAction As %String, pScreen As %String, pPair As %String, pStatus As %Integer, pCode As %String)
{
    Set tBefore = ..Stored()
    Set tSC = ..Act(pAction, pScreen, pPair, .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, pAction _ " " _ pScreen _ " " _ pPair _ ": the request completes")
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), pStatus _ "|" _ pCode, pAction _ " " _ pScreen _ " " _ pPair _ ": refused with its code")
    If pStatus = 422 {
        Set tViolation = $Select($IsObject(tAnswer) && $IsObject(tAnswer.detail) && $IsObject(tAnswer.detail.%Get("violations")): tAnswer.detail.violations.%Get(0), 1: "")
        Do $$$AssertEquals($Select($IsObject(tViolation): tViolation.field _ "|" _ tViolation.code, 1: ""), "Pair|" _ pCode, "naming one violation on Pair")
        Do $$$AssertEquals($Select($IsObject(tViolation): tViolation.reason, 1: ""), ##class(OcuPilot.Api.AccessError).ReasonFor(pCode), "and the published sentence")
    }
    Do $$$AssertEquals(..Stored(), tBefore, "nothing was stored")
}

/// <p>The Empty and Bad pair rows: removing the only pair is <code>ACCESS.PAIRS.EMPTY</code>; a resource the
/// instance does not define is <code>ACCESS.RESOURCE.UNKNOWN</code>; a permission that is not READ, WRITE or
/// USE, and a pair with no permission, are <code>ACCESS.PAIR.MALFORMED</code>.</p>
/// <p>Mutation (Rule 19): drop the empty check from <method>OcuPilot.Port.ScreenAccessPort.Apply</method>,
/// then the <code>ResourceDefined</code> call, in turn -- the matching case goes red.</p>
Method TestAnEmptySetAnUnknownResourceAndAMalformedPairAreRefused()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Do ..Refused("remove-pair", ..#ONEPAIR, "%Development:USE", 422, "ACCESS.PAIRS.EMPTY")
    Do ..Refused("add-pair", ..#ONEPAIR, "NoSuchRes:USE", 422, "ACCESS.RESOURCE.UNKNOWN")
    Do ..Refused("add-pair", ..#ONEPAIR, "%Admin_Secure:RUN", 422, "ACCESS.PAIR.MALFORMED")
    Do ..Refused("add-pair", ..#ONEPAIR, "x", 422, "ACCESS.PAIR.MALFORMED")
}

/// <p>The Absent, present and too many rows: removing a pair the set lacks is <code>ACCESS.PAIR.ABSENT</code>,
/// adding one it holds <code>ACCESS.PAIR.PRESENT</code> (in any letter case), and adding a ninth
/// <code>ACCESS.PAIRS.TOOMANY</code>.</p>
/// <p>Mutation (Rule 19): drop the full-set check from <method>OcuPilot.Port.ScreenAccessPort.Apply</method>
/// -- the ninth pair is stored and the last case goes red.</p>
Method TestAbsentPresentAndNinthPairsAreRefused()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Do ..Refused("remove-pair", ..#ONEPAIR, "%Admin_Secure:USE", 422, "ACCESS.PAIR.ABSENT")
    Do ..Refused("add-pair", ..#ONEPAIR, "%development:use", 422, "ACCESS.PAIR.PRESENT")
    For tI = 1:1:$Length(..#FILLERS, ",") {
        Set tPair = $Piece(..#FILLERS, ",", tI) _ ":USE"
        Set tSC = ..Act("add-pair", ..#ONEPAIR, tPair, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus, 200, "pair " _ (tI + 1) _ " (" _ tPair _ ") is accepted")
    }
    Do ..Refused("add-pair", ..#ONEPAIR, "%Admin_Secure:USE", 422, "ACCESS.PAIRS.TOOMANY")
}

/// <p>The Own screens row: an action on Home, Switches or Screen permissions itself is refused
/// <code>PROHIBITED.OCUPILOTSCREEN</code> -- a screen in an area that declares no pair cannot be adjusted --
/// whatever the action, and nothing is stored.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Gate.Adjustable</method> answer 1 -- every case goes
/// red.</p>
Method TestOcuPilotsOwnScreensCannotBeAdjusted()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    For tScreen = "shell.home", "agent.switches", "agent.screenpermissions" {
        Do ..Refused("add-pair", tScreen, "%Admin_Secure:USE", 403, "PROHIBITED.OCUPILOTSCREEN")
        Do ..Refused("remove-pair", tScreen, "%Development:USE", 403, "PROHIBITED.OCUPILOTSCREEN")
        Do ..Refused("reset", tScreen, "", 403, "PROHIBITED.OCUPILOTSCREEN")
    }
}

/// <p>The Unknown screen row: an identifier no built screen carries is 404 <code>ACCESS.SCREEN.UNKNOWN</code>
/// on every action, and nothing is stored.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Gate.BasePairs</method> answer a descriptor for an
/// unknown identifier -- this goes red.</p>
Method TestAnUnknownScreenIsNotFound()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Do ..Refused("add-pair", "no.such", "%Admin_Secure:USE", 404, "ACCESS.SCREEN.UNKNOWN")
    Do ..Refused("remove-pair", "no.such", "%Admin_Secure:USE", 404, "ACCESS.SCREEN.UNKNOWN")
    Do ..Refused("reset", "no.such", "", 404, "ACCESS.SCREEN.UNKNOWN")
}

}
