/// <p>Pins Story 12.5's Rotate Keys (AD-51, AD-53): the tab's row action adds a key pair to a client's
/// public key set; a client whose keys come from its X.509 credential is refused by name, at the port
/// and at the agent's mint, and its key set is unchanged; and the agent's rotation is minted and
/// confirmed.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed with the demo fixture -- whose
/// X.509 credential holds a private key -- an account holding <code>%All</code>, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes OAuth
/// 2.0 client configurations and server descriptions.</p>
Class OcuPilot.Test.OAuthClientKeys Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthClientRotateKeys";

Parameter CONFIRM = "OcuPilot.Test.OAuthClientConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthClientRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthClientProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter ENDPOINT = "Security.OAuth2.Client.ClientConfiguration";

Parameter ACTIONPATH = "/screens/security.oauthclients/action";

/// <p>The server description the class's clients are configured against, made per method.</p>
Property ServerId As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..ServerId = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthClientKeys creates and deletes OAuth 2.0 client configurations on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "AddServer", $ClassMethod(..#PROBE, "Issuer", "keys"), .tId)
    Set ..ServerId = $Get(tId)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>A request over the wire as the test account, answering the status and the raw body.</p>
ClassMethod Request(pMethod As %String, pPath As %String, pBody As %DynamicObject, Output pStatus As %Integer, Output pRaw As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pRaw, .tHeaders, $Select($IsObject(pBody): pBody.%ToJSON(), 1: ""), "application/json")
}

/// <p>AC6: the tab's Rotate Keys, on a client without X.509 credentials, answers 200 publishing an
/// update, and the client's public key set changes, a pair added.</p>
Method TestTheRowActionRotatesTheKeys()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Rotate")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId), "a configuration is created")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tName).%Get("PublicJWKS")
    Do $$$AssertTrue(tBefore '= "", "with a key set of its own")
    Set tSC = ..Request("POST", ..#ACTIONPATH, {"action": "rotatekeys", "id": (tName)}, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the row action answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue(tRaw [ """action"":""updated""", "publishing an update")
    Set tAfter = $ClassMethod(..#PROBE, "Stored", tName).%Get("PublicJWKS")
    Do $$$AssertTrue((tAfter '= tBefore) && ($Length(tAfter) > $Length(tBefore)), "and the public key set changes, a pair added (" _ $Length(tBefore) _ " to " _ $Length(tAfter) _ " bytes)")
}

/// <p>AC6: a client whose keys come from its X.509 credential is refused by name at the port -- which
/// the row action reaches -- and at the agent's mint, and its key set is unchanged.</p>
/// <p>Mutation (Rule 19): the <code>ClientCredentials</code> precondition is dropped from the port's
/// <code>ROTATEKEYS</code> -- the vendor answers 200 and the port's refusal assertion goes red.</p>
Method TestAClientWithCredentialsIsRefusedByName()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Credentials")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId, "confidential", {"ClientCredentials": ($Parameter(..#PROBE, "CREDENTIAL"))}), "a configuration with X.509 credentials is created")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tName).%Get("PublicJWKS")
    Set tSC = ..Request("POST", ..#ACTIONPATH, {"action": "rotatekeys", "id": (tName)}, .tStatus, .tRaw)
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(tRaw).%Get("code") } Catch { Set tCode = "" }
    Do $$$AssertEquals(tStatus _ " " _ tCode, "409 OAUTH.CLIENTKEYSFROMCREDENTIALS", "the row action is refused naming why: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("PublicJWKS"), tBefore, "and the key set is unchanged")
    Set tArgs = {}
    Do tArgs.%Set("ApplicationName", tName, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTKEYSFROMCREDENTIALS), "and the agent's mint is refused with the same sentence")
}

/// <p>AC7's rotation half: the agent's rotation is minted over the client's credentials alone, with
/// one row naming the key set, and its confirm sends the vendor's own rotation with no body and
/// changes the key set.</p>
Method TestTheAgentsRotationIsConfirmed()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "AgentRotate")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId), "a configuration is created")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tName).%Get("PublicJWKS")
    Set tArgs = {}
    Do tArgs.%Set("ApplicationName", tName, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the rotation is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRow = tProposal.%Get("changed").%Get(0)
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("field"), 1: ""), "PublicJWKS", "one row naming the key set")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and it is confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ "|" _ $ClassMethod(..#RECORD, "LastWriteBody"), "ROTATEKEYS|", "sending the vendor's rotation with no body")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Stored", tName).%Get("PublicJWKS") '= tBefore, "which changes the key set")
}

}
