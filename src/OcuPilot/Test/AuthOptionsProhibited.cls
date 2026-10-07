/// <p>Pins AD-10's authentication options arm on both callers of
/// <class>OcuPilot.Screen.Tool.AuthOptionsUpdate</class> (A4, A5 as amended 2026-10-07): the form's Save
/// (<class>OcuPilot.Test.AuthOptionsSaveFixture</class>) and the agent's confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>) are each refused
/// <code>PROHIBITED.OCUPILOTSIGNIN</code> for turning off Password or Unauthenticated, and
/// <code>PROHIBITED.OCUPILOTSTART</code> for turning O/S authentication off, before any <code>PUT</code>; a
/// read that fails refuses; a change to <code>JWTIssuer</code> or <code>JWTSigAlg</code> is permitted, minted
/// destructive with <code>WEBAUTH.SIGNOUT</code>, and confirmed through the seam.</p>
/// <p><b>Nothing is changed for real</b>, beyond the signing keys an instance with none gets from the one sign-in
/// <method>OcuPilot.Test.AuthOptionsProbe.EnsureKeys</method> makes before the first snapshot, which needs
/// OcuPilot serving. The seam records every settings <code>PUT</code> and its guard
/// refuses one that would change a sign-in, start or token setting, so a mutation that lets a refusal through
/// reddens a test instead of cutting off the throwaway's sign-in. Every test reads the facts it starts from
/// and checks they read the same after.</p>
Class OcuPilot.Test.AuthOptionsProhibited Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.AuthOptionsProbe";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter SEAM = "OcuPilot.Test.AuthOptionsSeamPort";

Parameter SAVE = "OcuPilot.Test.AuthOptionsSaveFixture";

Parameter TOOL = "OcuPilot.Screen.Tool.AuthOptionsUpdate";

Parameter PUT = "Security.WebAuth/PUT";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureKeys"), "the instance holds its signing keys before the snapshot")
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts").%ToJSON()
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.AuthOptionsSet")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts").%ToJSON(), ..PreparedFacts, "the authentication facts read as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>A4: turning Password or Unauthenticated off is refused <code>PROHIBITED.OCUPILOTSIGNIN</code> on both
/// callers with the published sentence, before any <code>PUT</code>, and the stored flag is unchanged; the
/// seam's guard did not have to refuse anything.</p>
/// <p>Mutation (Rule 19): remove the <code>OCUPILOTSIGNIN</code> refusal from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.AuthOptions</method> -- both callers' legs send the
/// <code>PUT</code> to the seam and this goes red.</p>
Method TestTurningOffAnOnlyMethodIsRefusedOnBothCallers()
{
    For tField = "AutheCache", "AutheUnauthenticated" {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#SAVE, "Handle", ..Full(tField, 0), .tAnswer, .tStatus)
        Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ tParsed.%Get("code") _ " " _ tParsed.%Get("reason"), "403 PROHIBITED.OCUPILOTSIGNIN " _ $Parameter(..#PROHIBITED, "OCUPILOTSIGNINREASON"), tField _ " off: the form's Save is refused with the published sentence: " _ $Extract(tAnswer, 1, 200))
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ "|" _ $ClassMethod(..#SEAM, "Refused"), "|0", tField _ " off: before any PUT")
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", ..Change(tField, 0), .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, tField _ " off: the agent's change is minted (" _ tProblem _ ")")
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "403 PROHIBITED.OCUPILOTSIGNIN", tField _ " off: its confirm is refused")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ "|" _ $ClassMethod(..#SEAM, "Refused"), "|0", tField _ " off: before any PUT")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts").%Get("raw"), ##class(%DynamicObject).%FromJSON(..PreparedFacts).%Get("raw"), tField _ " off: and the stored flags are as they were")
    }
}

/// <p>A4: turning O/S authentication off is refused <code>PROHIBITED.OCUPILOTSTART</code> on both callers with
/// the published sentence, before any <code>PUT</code>, whatever else the write carries.</p>
/// <p>Mutation (Rule 19): remove the <code>OCUPILOTSTART</code> refusal from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.AuthOptions</method> -- both legs record a <code>PUT</code>
/// and this goes red.</p>
Method TestTurningOffOsAuthenticationIsRefusedOnBothCallers()
{
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", ..Full("AutheOS", 0), .tAnswer, .tStatus)
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tParsed.%Get("code") _ " " _ tParsed.%Get("reason"), "403 PROHIBITED.OCUPILOTSTART " _ $Parameter(..#PROHIBITED, "OCUPILOTSTARTREASON"), "the form's Save is refused with the published sentence: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "before any PUT")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", ..Change("AutheOS", 0), .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "403 PROHIBITED.OCUPILOTSTART", "its confirm is refused")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "before any PUT")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", "answer")
    Set tSC = $ClassMethod(..#SAVE, "Handle", ..FullBody1({"AutheOS": true, "LoginCookieTimeout": 30}), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "Writes"), "200 " _ ..#PUT, "O/S authentication left on is not refused")
}

/// <p>Arm every mask the arm reads that the failing endpoint leaves readable with a method besides cache
/// authentication, so that turning cache authentication off cuts nothing and only the failed read can refuse.</p>
ClassMethod ArmSpareMethod() [ Private ]
{
    For tPath = "/ocupilot", "/api/ocupilot", "/api/ocupilot/readiness" {
        Do $ClassMethod(..#SEAM, "ArmMask", "WebApp.App", tPath, 96)
    }
    Do $ClassMethod(..#SEAM, "ArmMask", "Security.Service", "%Service_WebGateway", 96)
}

/// <p>A4, AD-10: a read of an application's or the service's methods that fails refuses a write that turns a
/// method off, on both callers; a write that turns none off needs no such read and is not refused by it. A
/// widened application is cut only when all its methods go (<method>OcuPilot.Test.AuthOptionsDescriptor</method>
/// holds the predicate itself).</p>
/// <p>Mutation (Rule 19): answer success from <method>OcuPilot.Kernel.Proposal.Prohibited.SignInMasks</method>
/// on a failed read -- the failed-read legs send the <code>PUT</code> and this goes red.</p>
Method TestAFailedMaskReadRefuses()
{
    For tEndpoint = "WebApp.App", "Security.Service" {
        Do $ClassMethod(..#SEAM, "Clear")
        Do $ClassMethod(..#SEAM, "ArmFail", tEndpoint)
        Do ..ArmSpareMethod()
        Set tSC = $ClassMethod(..#SAVE, "Handle", ..Full("AutheCache", 0), .tAnswer, .tStatus)
        Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ tParsed.%Get("code") _ " " _ $ClassMethod(..#SEAM, "Writes"), "403 PROHIBITED.OCUPILOTSIGNIN ", "a failed " _ tEndpoint _ " read refuses the Save with no PUT: " _ $Extract(tAnswer, 1, 200))
        Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", ..Change("AutheCache", 0), .tProposal, .tHttp, .tProblem)
        Do $ClassMethod(..#SEAM, "Clear")
        Do $ClassMethod(..#SEAM, "ArmFail", tEndpoint)
        Do ..ArmSpareMethod()
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "403 PROHIBITED.OCUPILOTSIGNIN", "and the agent's confirm")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with no PUT")
    }
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", "answer")
    Do $ClassMethod(..#SEAM, "ArmFail", "WebApp.App")
    Set tSC = $ClassMethod(..#SAVE, "Handle", ..FullBody1({"LoginCookieTimeout": 30}), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "Writes"), "200 " _ ..#PUT, "a write that turns no method off is not refused by a failed mask read")
}

/// <p>A5: a changed <code>JWTIssuer</code> or <code>JWTSigAlg</code> is permitted. The agent's proposal is
/// minted destructive with <code>WEBAUTH.SIGNOUT</code> and its confirm sends the one <code>PUT</code> to the
/// seam; the form's Save states the same consequence; and unarmed, the seam's guard refuses a real one, so no
/// test ever replaces the signing keys.</p>
/// <p>Mutation (Rule 19): answer <code>""</code> from
/// <method>OcuPilot.Screen.Tool.AuthOptionsUpdate.Consequence</method> and the kernel's effect -- the
/// destructive leg goes red.</p>
Method TestATokenSettingChangeIsPermittedAndNamesItsConsequence()
{
    For tField = "JWTSigAlg", "JWTIssuer" {
        Set tValue = $Select(tField = "JWTSigAlg": "RS256", 1: "ocuprobe188")
        Do $ClassMethod(..#SEAM, "Clear")
        Do $ClassMethod(..#SEAM, "Arm", "answer")
        Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", ..Change(tField, tValue), .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, tField _ ": the agent's change is minted (" _ tProblem _ ")")
        Do $$$AssertEquals(..Stored(tProposal, "destructive") _ " " _ ..Stored(tProposal, "consequence"), "1 WEBAUTH.SIGNOUT", tField _ ": minted destructive, naming the sign-out")
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", tField _ ": its confirm is permitted")
        Set tSent = ##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT))
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ tSent.%Get(tField), ..#PUT _ " " _ tValue, tField _ ": one PUT carrying the new value, recorded by the seam")
        Do $ClassMethod(..#SEAM, "Clear")
        Do $ClassMethod(..#SEAM, "Arm", "answer")
        Set tSC = $ClassMethod(..#SAVE, "Handle", ..FullBody1(..Change1(tField, tValue)), .tAnswer, .tStatus)
        Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ tParsed.%Get("consequence"), "200 WEBAUTH.SIGNOUT", tField _ ": the form's Save states the sign-out: " _ $Extract(tAnswer, 1, 200))
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#SAVE, "Handle", ..FullBody1(..Change1(tField, tValue)), .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "Refused"), "409 1", tField _ ": unarmed, the seam's guard refuses a real change")
    }
    Set tFacts = $ClassMethod(..#PROBE, "Facts")
    Do $$$AssertEquals(tFacts.%Get("JWTSigAlg") _ "|" _ tFacts.%Get("JWTIssuer") _ "|" _ tFacts.%Get("privateKeys"), ##class(%DynamicObject).%FromJSON(..PreparedFacts).%Get("JWTSigAlg") _ "|" _ ##class(%DynamicObject).%FromJSON(..PreparedFacts).%Get("JWTIssuer") _ "|" _ ##class(%DynamicObject).%FromJSON(..PreparedFacts).%Get("privateKeys"), "the instance's algorithm, issuer and signing keys are as they were")
}

/// <p>The agent's arguments for a change of <var>pName</var> to <var>pValue</var>.</p>
ClassMethod Change(pName As %String, pValue) As %DynamicObject
{
    Set tArgs = {"Name": "SYSTEM"}
    Do tArgs.%Set(pName, pValue, $Select(pValue = 0: "boolean", $IsValidNum(pValue): "number", 1: "string"))
    Quit tArgs
}

/// <p>One change as an object, for <method>FullBody1</method>.</p>
ClassMethod Change1(pName As %String, pValue) As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set(pName, pValue, $Select($IsValidNum(pValue): "number", 1: "string"))
    Quit tArgs
}

/// <p>The complete set the form sends with the flag <var>pName</var> set to <var>pValue</var>.</p>
ClassMethod Full(pName As %String, pValue As %Boolean) As %DynamicObject
{
    Set tBody = ##class(OcuPilot.Test.AuthOptionsWrite).FullBody({})
    Do tBody.%Set(pName, pValue, "boolean")
    Quit tBody
}

/// <p>The complete set the form sends with <var>pChanges</var> applied.</p>
ClassMethod FullBody1(pChanges As %DynamicObject) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.AuthOptionsWrite).FullBody(pChanges)
}

/// <p>The stored value <var>pName</var> of the proposal <var>pProposal</var>.</p>
ClassMethod Stored(pProposal As %DynamicObject, pName As %String) As %String
{
    If '$IsObject(pProposal) Quit ""
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposal.%Get("proposalId"), .tFound, .tValues)
    Quit $Get(tValues(pName))
}

}
