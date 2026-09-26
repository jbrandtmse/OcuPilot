/// <p>Pins Story 12.5's client configuration edit (AD-4, AD-39, AD-55): the Save sends the complete
/// settable set over a fresh read, so one field changed and a list cleared leave every other field and
/// member -- the vendor's algorithm defaults among them -- as they were; a member that is not settable
/// is refused before anything is sent; and the agent's edit, whose <code>Metadata</code> names no
/// registration member, leaves a registered client's registration as the instance holds it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed with the demo fixture, an account
/// holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because
/// it creates and deletes OAuth 2.0 client configurations and server descriptions. The registered
/// client's registration URI is <class>OcuPilot.Test.OAuthIssuerFixture</class>'s, started and stopped
/// around every method.</p>
Class OcuPilot.Test.OAuthClientUpdate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthClientUpdate";

Parameter SCREEN = "OcuPilot.Test.OAuthClientSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthClientConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthClientRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthClientProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter FIXTURE = "OcuPilot.Test.OAuthIssuerFixture";

Parameter RULES = "OcuPilot.Area.Security.OAuthClientRules";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthClientUpdate creates and deletes OAuth 2.0 client configurations on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#FIXTURE, "Start", , .tIssuer)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "AddServer", $ClassMethod(..#PROBE, "Issuer", "update"), .tId)
    Set ..ServerId = $Get(tId)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    ; The fixture is running while a registered client is deleted, which asks it to deregister.
    Do $ClassMethod(..#FIXTURE, "Start", , .tIssuer)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Stop"), "the issuer fixture stops")
    Quit $$$OK
}

/// <p>AC2: an edit through the Save that changes the description and clears the contacts list sends
/// the complete settable set -- the cleared list as <code>[]</code>, every member the form did not
/// touch as the fresh read has it -- and the instance then holds exactly that change: every other
/// field and member, the vendor's algorithm defaults among them, reads as before.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthClientRules.Expand</method> skips the
/// empty members -- the cleared list survives and this goes red.</p>
Method TestAnEditSendsTheCompleteSetAndClearsAMember()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Edit")
    Set tMetadata = {"client_name": "Before", "contacts": ["ops@example.com"], "logo_uri": "https://ocupilotprobe125.invalid/logo.png", "grant_types": ["authorization_code"]}
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId, "confidential", {"Description": "before", "Metadata": (tMetadata)}), "a configuration is created")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tName)
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, {"Description": "after", "Metadata": {"contacts": []}}, .tHttp, .tFault, .tViolations, .tAnswer, .tServer)
    Do $$$AssertStatusOK(tSC, "the edit completes: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(+$Get(tViolations) _ " " _ $ClassMethod(..#RECORD, "WriteTypes"), "0 PUT", "with no violation, as one vendor PUT")
    Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#RECORD, "LastWriteBody"))
    Do $ClassMethod(..#RULES, "Members", .tNames, .tKinds, .tValues)
    Set tMissing = ""
    For tI = 1:1:$ListLength(tNames) {
        If $ClassMethod(..#RULES, "Settable", $List(tNames, tI)) && (tSent.%Get("Metadata").%GetTypeOf($List(tNames, tI)) = "unassigned") Set tMissing = tMissing _ " " _ $List(tNames, tI)
    }
    Do $$$AssertEquals(tMissing, "", "carrying every settable member")
    Do $$$AssertEquals(tSent.%Get("Metadata").%Get("contacts").%ToJSON() _ "|" _ tSent.%Get("Metadata").%Get("client_name"), "[]|Before", "the cleared list as [], an untouched member as it was")
    Set tAfter = $ClassMethod(..#PROBE, "Stored", tName)
    Do $$$AssertEquals(tAfter.%Get("Description"), "after", "the instance holds the change")
    Do $$$AssertEquals(tAfter.%Get("Metadata").%GetTypeOf("contacts"), "unassigned", "and the clearance")
    Do tBefore.%Set("Description", "after", "string")
    Do tBefore.%Get("Metadata").%Remove("contacts")
    Do $$$AssertEquals(tAfter.%ToJSON(), tBefore.%ToJSON(), "and every other field and member reads as before, the algorithm defaults among them")
    Do $$$AssertEquals(tAfter.%Get("Metadata").%Get("id_token_signed_response_alg"), "RS256", "RS256 among them")
}

/// <p>A settable member cleared with its empty form and a flag unset are held; a member the form may
/// not set is refused on its field, with nothing sent.</p>
Method TestAnUnsettableMemberIsRefusedBeforeAnythingIsSent()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Unsettable")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId), "a configuration is created")
    For tMember = "registration_client_uri", "client_id", "client_secret", "registration_access_token", "jwks" {
        Set tChanges = {}
        Do tChanges.%Set(tMember, "", "string")
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Update", tName, {"Metadata": (tChanges)}, .tHttp, .tFault, .tViolations, .tAnswer, .tServer)
        Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, "Metadata." _ tMember), "OAUTH.METADATA.UNKNOWN", tMember _ ": refused on its field")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, tMember _ ": and nothing is sent")
    }
}

/// <p>The edit's form rules, read against the fresh read, on both callers: each change below is
/// refused on its field by the Save's <method>OcuPilot.Area.Security.OAuthClientSave.Update</method>
/// with nothing sent, and by the update tool's <method>OcuPilot.Screen.Tool.OAuthClientUpdate.ArgumentProblem</method>
/// naming the field. The last case changes a resource server, stored with no redirect URL, to a
/// public client. Two edits that leave a rule's other field unsent are accepted, each rule reading
/// that field from the fresh read.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthClientRules.Changes</method> answers
/// <var>pCreates</var> alone -- the edit's rules stop applying and this goes red;
/// <method>OcuPilot.Area.Security.OAuthClientRules.Effective</method> answers <code>""</code> for an
/// unsent field -- the accepted edits are refused and this goes red.</p>
Method TestTheEditsFormRulesRefuseOnBothCallers()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Rules")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId), "a configuration is created")
    Set tResource = $ClassMethod(..#PROBE, "Name", "Resource")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tResource, ..ServerId, "resource"), "and a resource server with no redirect URL")
    Kill tCases
    Set tCases($Increment(tCases)) = $ListBuild(tName, "{""ClientType"": ""bogus""}", "ClientType", "OAUTHCLIENTTYPEVALUE")
    Set tCases($Increment(tCases)) = $ListBuild(tName, "{""Metadata"": {""id_token_signed_response_alg"": ""bogus""}}", "Metadata.id_token_signed_response_alg", "OAUTHMETADATAVALUE")
    Set tCases($Increment(tCases)) = $ListBuild(tName, "{""JWTInterval"": ""abc""}", "JWTInterval", "OAUTHJWTINTERVALSHAPE")
    Set tCases($Increment(tCases)) = $ListBuild(tName, "{""ClientCredentials"": ""ocupilotprobe000nosuchalias""}", "ClientCredentials", "OAUTHCLIENTCREDENTIALSABSENT")
    Set tCases($Increment(tCases)) = $ListBuild(tName, "{""SSLConfiguration"": """"}", "SSLConfiguration", "OAUTHSSLCONFIGURATIONREQUIRED")
    Set tCases($Increment(tCases)) = $ListBuild(tName, "{""ServerDefinition"": """"}", "ServerDefinition", "OAUTHSERVERDEFINITIONREQUIRED")
    Set tCases($Increment(tCases)) = $ListBuild(tResource, "{""ClientType"": ""public""}", "RedirectionEndpoint", "OAUTHREDIRECTIONENDPOINTREQUIRED")
    For tI = 1:1:tCases {
        Set tCase = tCases(tI)
        Set tField = $List(tCase, 3)
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Update", $List(tCase, 1), ##class(%DynamicObject).%FromJSON($List(tCase, 2)), .tHttp, .tFault, .tViolations, .tAnswer, .tServer)
        Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, tField), $Parameter("OcuPilot.Api.Error", $List(tCase, 4)), $List(tCase, 2) _ ": the Save refuses it on " _ tField)
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, $List(tCase, 2) _ ": and sends nothing")
        Set tSC = $ClassMethod(..#TOOL, "ArgumentProblem", $List(tCase, 1), ##class(%DynamicObject).%FromJSON($List(tCase, 2)), .tProblem)
        Do $$$AssertTrue($$$ISOK(tSC) && ($Get(tProblem) [ ("'" _ tField _ "': ")), $List(tCase, 2) _ ": the update tool refuses it naming " _ tField _ ": " _ $Get(tProblem))
    }
    ; Accepted because a field the edit does not send is read from the fresh read: a client stored
    ; with a redirect URL may become public, and a resource server's redirect URL may stay empty.
    For tCase = $ListBuild(tName, "{""ClientType"": ""public""}"), $ListBuild(tResource, "{""RedirectionEndpoint"": """"}") {
        Set tSC = $ClassMethod(..#SCREEN, "Update", $List(tCase, 1), ##class(%DynamicObject).%FromJSON($List(tCase, 2)), .tHttp, .tFault, .tViolations, .tAnswer, .tServer)
        Do $$$AssertTrue($$$ISOK(tSC) && (+$Get(tViolations) = 0), $List(tCase, 2) _ ": the Save accepts it: " _ $ClassMethod(..#HELPER, "CodeFor", .tViolations, "RedirectionEndpoint"))
        Set tSC = $ClassMethod(..#TOOL, "ArgumentProblem", $List(tCase, 1), ##class(%DynamicObject).%FromJSON($List(tCase, 2)), .tProblem)
        Do $$$AssertTrue($$$ISOK(tSC) && ($Get(tProblem) = ""), $List(tCase, 2) _ ": and so does the update tool: " _ $Get(tProblem))
    }
}

/// <p>AC7's update half: the agent's edit carries <code>Metadata</code> whole, naming no registration
/// member; confirmed, it lands the member it names and leaves the registered client's client ID and
/// registration URI as the instance held them, because the port sends those as its own fresh read has
/// them.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthClientPort</method>'s <code>PUT</code> sends a
/// managed member the body lacks in its empty form -- the registration URI is sent as
/// <code>""</code>, the instance clears it, and this goes red.</p>
Method TestTheAgentsEditKeepsTheRegistrationMembers()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Registered")
    Set tClientId = $Parameter(..#FIXTURE, "CLIENTID")
    Set tUri = $ClassMethod(..#FIXTURE, "Issuer") _ "/register/" _ tClientId
    Set tSettings = {"ClientId": (tClientId), "Metadata": {"client_id": (tClientId), "client_name": "Before"}}
    Do tSettings.%Get("Metadata").%Set("registration_client_uri", tUri, "string")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId, "confidential", tSettings), "a registered configuration is created")
    Set tArgs = {"Metadata": {"client_name": "Agent"}}
    Do tArgs.%Set("ApplicationName", tName, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the edit is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#RECORD, "LastWriteBody"))
    Do $$$AssertEquals(tSent.%Get("Metadata").%GetTypeOf("registration_client_uri"), "unassigned", "the tool's body names no registration member")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tName)
    Do $$$AssertEquals(tStored.%Get("Metadata").%Get("client_name"), "Agent", "the member the agent named lands")
    Do $$$AssertEquals(tStored.%Get("Metadata").%Get("registration_client_uri") _ "|" _ tStored.%Get("Metadata").%Get("client_id"), tUri _ "|" _ tClientId, "and the registration is as the instance held it")
}

/// <p>The agent's edit refuses a <code>Metadata</code> naming a registration member at the mint, so an
/// argument cannot clear a client's registration.</p>
Method TestTheAgentCannotClearARegistration()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId), "a configuration is created")
    Set tArgs = {"Metadata": {"registration_client_uri": ""}}
    Do tArgs.%Set("ApplicationName", tName, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ "'Metadata.registration_client_uri': "), "the mint refuses the registration member by name")
}

}
