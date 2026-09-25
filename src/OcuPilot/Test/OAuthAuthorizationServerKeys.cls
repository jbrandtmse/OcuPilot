/// <p>Pins Story 12.7's Rotate Keys (AD-27, AD-51, AD-53): the tab's row action and the agent's
/// confirmed proposal each add a key pair to the stored key set; a configuration whose keys come from
/// its server credentials is refused by name on both callers; an absent configuration is 404; the port
/// refuses a caller without its pairs before the vendor is reached; the row action names the singleton;
/// and OcuPilot's own sign-in keeps answering with no configuration and across a rotation and a
/// delete.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture,
/// an account holding <code>%All</code>, no authorization server configuration, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes the
/// instance's configuration and X.509 credentials
/// (<class>OcuPilot.Test.OAuthAuthorizationServerProbe</class>).</p>
Class OcuPilot.Test.OAuthAuthorizationServerKeys Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthAuthorizationServerRotateKeys";

Parameter CONFIRM = "OcuPilot.Test.OAuthAuthorizationServerConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthAuthorizationServerRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthAuthorizationServerProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter ENDPOINT = "Security.OAuth2.Server";

Parameter ACTIONPATH = "/screens/security.oauthserver/action";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthAuthorizationServerKeys creates and deletes this instance's OAuth 2.0 authorization server configuration and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "the configuration and every probe object are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

ClassMethod Id() As %String
{
    Quit ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
}

/// <p>AC5: the tab's row action over the wire, sent the issuer as its row's id, answers 200 naming the
/// target <code>(oauth2-server, instance, SYSTEM)</code>, and the stored key set grows; the agent's
/// proposal, minted with the key row and confirmed, grows it again.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthAuthorizationServerPort.RotateKeys</method> skips
/// the vendor's <code>RotateKeys()</code> and answers 200 -- the key count holds and this goes red.</p>
Method TestRotatingGrowsTheKeySet()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tBefore = $ClassMethod(..#PROBE, "Stored").%Get("KeyCount")
    Do $$$AssertTrue(tBefore > 0, "with a generated key set: " _ tBefore)
    Set tSC = ..Action("rotatekeys", .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the row action answers 200: " _ $Extract(tRaw, 1, 300))
    Set tTarget = ""
    Try { Set tTarget = ##class(%DynamicObject).%FromJSON(tRaw).%Get("target").%ToJSON() } Catch { Set tTarget = "" }
    Do $$$AssertEquals(tTarget, "{""type"":""oauth2-server"",""scope"":""instance"",""id"":""" _ ..Id() _ """}", "naming the singleton, not the issuer the row sent")
    Set tAfter = $ClassMethod(..#PROBE, "Stored").%Get("KeyCount")
    Do $$$AssertTrue(tAfter > tBefore, "and the key set grows: " _ tBefore _ " to " _ tAfter)
    Set tArgs = {}
    Do tArgs.%Set("Name", ..Id(), "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, ..Id(), tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's rotation is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%ToJSON(), "[{""field"":""Keys"",""before"":"""",""after"":""""}]", "with the key row alone")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes"), "ROTATEKEYS", "through one rotation")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Stored").%Get("KeyCount") > tAfter, "which grows the key set again")
}

/// <p>A configuration whose keys come from its server credentials: the port refuses the rotation 409
/// <code>OAUTH.SERVERKEYS.CREDENTIALS</code> with the key set unchanged, and the agent's mint refuses
/// it with the same sentence.</p>
Method TestARotationIsRefusedWithCredentials()
{
    Set tAlias = $ClassMethod(..#PROBE, "Name", "Keys")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddCredential", tAlias, 1), "a credential with a private key is made")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", {"ServerCredentials": (tAlias)}), "and a configuration signing with it")
    Set tBefore = $ClassMethod(..#PROBE, "Stored").%Get("KeyCount")
    Kill tQuery
    Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "ROTATEKEYS", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 OAUTH.SERVERKEYS.CREDENTIALS", "the port refuses the rotation by name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%Get("KeyCount"), tBefore, "and the key set is unchanged")
    Set tArgs = {}
    Do tArgs.%Set("Name", ..Id(), "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, ..Id(), tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) = ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERKEYSCREDENTIALS), "the agent's mint refuses it with the same sentence: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
}

/// <p>With no configuration the port answers a rotation 404, and the row action is refused.</p>
Method TestARotationWithNoConfigurationIsRefused()
{
    Kill tQuery
    Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "ROTATEKEYS", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ " " _ tHttp, "1 404", "the port answers 404")
    Set tSC = ..Action("rotatekeys", .tStatus, .tRaw)
    Do $$$AssertTrue(tStatus >= 400, "and the row action is refused: " _ tStatus _ " " _ $Extract(tRaw, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds"), 0, "and nothing is created")
}

/// <p>AD-27: the rotation repeats the endpoint's own gate before the vendor class is reached: a caller
/// without <code>%Admin_OAuth2_Server:USE</code> is refused 403 naming it, and the key set is
/// unchanged.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Port.OAuthAuthorizationServerPort.Invoke</method>'s
/// <method>OcuPilot.Port.OAuthAuthorizationServerPort.RefusedPair</method> check -- the rotation runs
/// and this goes red.</p>
Method TestThePortGateComesBeforeTheVendorClass()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tBefore = $ClassMethod(..#PROBE, "Stored").%Get("KeyCount")
    Do $ClassMethod(..#RECORD, "DenyPair", "%Admin_OAuth2_Server:USE")
    Kill tQuery
    Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "ROTATEKEYS", .tQuery, "", .tResult, .tHttp, .tFault)
    Set tPair = ""
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set tPair = tFault.%Get("detail").%Get("failedPair")
    Do $$$AssertEquals(tHttp _ " " _ tPair, "403 %Admin_OAuth2_Server:USE", "the rotation is refused naming the pair")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%Get("KeyCount"), tBefore, "before the vendor class is reached")
}

/// <p>OcuPilot signs in with its web application's own token, not through this server (AD-28): a
/// sign-in answers 200 with no configuration, with one, after a rotation and after a delete.</p>
Method TestSignInIsUntouched()
{
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds") _ " " _ ..SignIn(), "0 200", "a sign-in answers with no configuration")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Do $$$AssertEquals(..SignIn(), 200, "a sign-in answers with a configuration")
    Set tSC = ..Action("rotatekeys", .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus _ " " _ ..SignIn(), "200 200", "and after a rotation")
    Set tSC = ..Action("delete", .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#PROBE, "Holds") _ " " _ ..SignIn(), "200 0 200", "and after a delete")
}

/// <p>The status of a password sign-in to OcuPilot's own API as the test account.</p>
ClassMethod SignIn() As %Integer
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/login", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, "", "application/json")
    Quit +$Get(tStatus)
}

/// <p>The tab's row action <var>pAction</var> over the wire as the test account.</p>
ClassMethod Action(pAction As %String, Output pStatus As %Integer, Output pRaw As %String) As %Status
{
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", $ClassMethod(..#PROBE, "Issuer"), "string")
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#ACTIONPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
}

}
