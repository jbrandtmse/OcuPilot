/// <p>Pins Story 12.5's dynamic registration (AD-51, AD-53, AD-35): against the local issuer fixture,
/// the tab's Register sets the client ID the authorization server issues, presenting the initial
/// access token the editor's Save stored as the Bearer, and no read carries the secrets it returns; a
/// registered client, one whose server description has no registration endpoint, and a registration
/// the authorization server cannot answer are each refused by name; and a Save of a registered client
/// whose registration cannot be updated is answered as saved, with the notice, on the screen's caller
/// and in the agent's ledger.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture,
/// an account holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because it creates and deletes OAuth 2.0 client configurations and server
/// descriptions. The authorization server is <class>OcuPilot.Test.OAuthIssuerFixture</class>, started
/// around every method; two methods stop it, and each then waits the vendor's own connect timeout,
/// about 30 seconds (measured).</p>
Class OcuPilot.Test.OAuthClientRegister Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthClientRegister";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.OAuthClientUpdate";

Parameter CONFIRM = "OcuPilot.Test.OAuthClientConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthClientRecordPort";

Parameter FAILPORT = "OcuPilot.Test.OAuthClientFailPort";

Parameter PROBE = "OcuPilot.Test.OAuthClientProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter FIXTURE = "OcuPilot.Test.OAuthIssuerFixture";

Parameter ENDPOINT = "Security.OAuth2.Client.ClientConfiguration";

Parameter CREATEPATH = "/oauth/client-configuration";

Parameter ACTIONPATH = "/screens/security.oauthclients/action";

/// <p>How long a request waits for its answer, in seconds.</p>
Parameter WAIT As INTEGER = 90;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthClientRegister creates and deletes OAuth 2.0 client configurations on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#FIXTURE, "Start", , .tIssuer)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do $ClassMethod(..#FAILPORT, "Disarm")
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

/// <p>A request over the wire as the test account, answering the status, the raw body and the
/// envelope's code. The client waits <parameter>WAIT</parameter> seconds, past the vendor's own connect
/// timeout to a server that is down.</p>
ClassMethod Request(pMethod As %String, pPath As %String, pBody As %DynamicObject, Output pStatus As %Integer, Output pRaw As %String, Output pCode As %String) As %Status
{
    Kill tExtra
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pRaw, .tHeaders, $Select($IsObject(pBody): pBody.%ToJSON(), 1: ""), "application/json", .tExtra, ..#WAIT)
    Set pCode = ""
    Try { Set pCode = ##class(%DynamicObject).%FromJSON(pRaw).%Get("code") } Catch { Set pCode = "" }
    Quit tSC
}

/// <p>The fixture's registration endpoint.</p>
ClassMethod Endpoint() As %String
{
    Quit $ClassMethod(..#FIXTURE, "Issuer") _ "/register"
}

/// <p>AC5: a client created through the editor's Save with an initial access token typed is
/// registered by the tab's row action against the fixture: its client ID and registration URI are the
/// fixture's, the Bearer the fixture received is the typed token, and no read carries the client
/// secret or the registration access token the fixture issued.</p>
/// <p>Mutation (Rule 19): skip the Save's initial-token step
/// (<method>OcuPilot.Area.Security.OAuthClientSave.StoreToken</method> answers at once) -- no Bearer is
/// presented and the Bearer-hash assertion goes red.</p>
Method TestTheRowActionRegistersPresentingTheInitialToken()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "register")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddServer", tIssuer, .tServerId, ..Endpoint()), "a description publishing the fixture's registration endpoint is created")
    Set tName = $ClassMethod(..#PROBE, "Name", "Register")
    Set tToken = $ClassMethod(..#PROBE, "Secret", "initial")
    Set tBody = {"ClientType": "confidential", "SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG")), "RedirectionEndpoint": ($Parameter(..#PROBE, "REDIRECT"))}
    Do tBody.%Set("ApplicationName", tName, "string")
    Do tBody.%Set("ServerDefinition", tServerId, "string")
    Do tBody.%Set("InitialAccessToken", tToken, "string")
    Set tSC = ..Request("POST", ..#CREATEPATH, tBody, .tStatus, .tRaw, .tCode)
    Do $$$AssertEquals(tStatus, 201, "the Save creates the client and stores the token: " _ $Extract(tRaw, 1, 300))
    Set tSC = ..Request("POST", ..#ACTIONPATH, {"action": "register", "id": (tName)}, .tStatus, .tRaw, .tCode)
    Do $$$AssertEquals(tStatus, 200, "the row action registers it: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "LastAuthorizationHash"), $ClassMethod(..#FIXTURE, "BearerHash", tToken), "presenting the typed initial access token as the Bearer")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tName)
    Set tClientId = $Parameter(..#FIXTURE, "CLIENTID")
    Do $$$AssertEquals(tStored.%Get("ClientId") _ "|" _ tStored.%Get("Metadata").%Get("registration_client_uri"), tClientId _ "|" _ ..Endpoint() _ "/" _ tClientId, "the client ID and registration URI are the ones issued")
    Do $$$AssertTrue((tStored.%Get("SecretLength") > 0) && (tStored.%Get("TokenLength") > 0), "and the instance holds the issued secret and registration access token")
    Kill tQuery
    Set tQuery("applicationName") = tName
    Set tSC = ##class(OcuPilot.Port.OAuthClientPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Set tText = $Select($IsObject($Get(tRead)): tRead.%ToJSON(), 1: "")
    Do $$$AssertTrue((tText '= "") && '(tText [ $Parameter(..#FIXTURE, "CLIENTSECRET")) && '(tText [ $Parameter(..#FIXTURE, "ACCESSTOKEN")), "no read carries either")
}

/// <p>A registered client, and one whose server description has no registration endpoint, are each
/// refused by name at the port -- which the row action reaches -- and at the agent's mint, with
/// nothing sent to an authorization server.</p>
Method TestARegisteredClientAndOneWithNoEndpointAreRefusedByName()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "refused")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddServer", tIssuer, .tWithEndpoint, ..Endpoint()), "a description with an endpoint is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddServer", $ClassMethod(..#PROBE, "Issuer", "noendpoint"), .tWithout), "and one without")
    Set tRegistered = $ClassMethod(..#PROBE, "Name", "Registered")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tRegistered, tWithEndpoint, "confidential", {"ClientId": "ocupilotprobe000issued"}), "a client with a client ID is created")
    Set tNoEndpoint = $ClassMethod(..#PROBE, "Name", "NoEndpoint")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tNoEndpoint, tWithout), "and an unregistered one against the description without")
    Set tCases = $ListBuild($ListBuild(tRegistered, "OAUTH.CLIENTREGISTERED", ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTREGISTERED), $ListBuild(tNoEndpoint, "OAUTH.CLIENTNOREGISTRATIONENDPOINT", ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTNOREGISTRATIONENDPOINT))
    For tI = 1:1:$ListLength(tCases) {
        Set tName = $List($List(tCases, tI), 1)
        Set tSC = ..Request("POST", ..#ACTIONPATH, {"action": "register", "id": (tName)}, .tStatus, .tRaw, .tCode)
        Do $$$AssertEquals(tStatus _ " " _ tCode, "409 " _ $List($List(tCases, tI), 2), tName _ ": the row action is refused by name")
        Set tArgs = {}
        Do tArgs.%Set("ApplicationName", tName, "string")
        Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ $List($List(tCases, tI), 3)), tName _ ": and the agent's mint with the same sentence")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "LastAuthorizationHash"), "", "and no registration reached the fixture")
}

/// <p>A registration the authorization server cannot answer -- the fixture stopped -- is refused by
/// name, naming the issuer, and the client stays unregistered.</p>
Method TestAStoppedServerIsANamedRefusal()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "stopped")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddServer", tIssuer, .tServerId, ..Endpoint()), "a description with the fixture's endpoint is created")
    Set tName = $ClassMethod(..#PROBE, "Name", "Stopped")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, tServerId), "an unregistered client is created")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Stop"), "the fixture is stopped")
    Set tSC = ..Request("POST", ..#ACTIONPATH, {"action": "register", "id": (tName)}, .tStatus, .tRaw, .tCode)
    Do $$$AssertEquals(tStatus _ " " _ tCode, "422 OAUTH.CLIENTREGISTRATIONFAILED", "the registration is refused by name: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue(tRaw [ $Replace(##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTREGISTRATIONFAILED, "{issuer}", tIssuer), "naming the issuer")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("ClientId"), "", "and the client stays unregistered")
}

/// <p>A Save of a registered client whose registration cannot be updated stores the change and is
/// answered as saved with the notice, on the screen's caller with the authorization server down and
/// through the agent's confirm with it refusing, whose ledger row records the write as applied.</p>
/// <p>Mutation (Rule 19): the port answers a registered client's 500 as
/// <code>OAUTH.CLIENTVALIDATION</code> without re-reading -- the Save's 200 and the ledger's applied
/// assertions go red.</p>
Method TestANotUpdatedSaveIsAnsweredAsSaved()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "notupdated")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddServer", tIssuer, .tServerId, ..Endpoint()), "a description with the fixture's endpoint is created")
    Set tName = $ClassMethod(..#PROBE, "Name", "NotUpdated")
    Set tUri = $ClassMethod(..#FIXTURE, "Issuer") _ "/register/unknown"
    Set tSettings = {"ClientId": "ocupilotprobe000issued", "Metadata": {"client_id": "ocupilotprobe000issued"}}
    Do tSettings.%Get("Metadata").%Set("registration_client_uri", tUri, "string")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, tServerId, "confidential", tSettings), "a registered client whose registration the fixture does not know is created")

    ; The agent's caller, the fixture answering the update 404.
    Set tArgs = {"Description": "agent edit"}
    Do tArgs.%Set("ApplicationName", tName, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#UPDATETOOL, tName, tArgs, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the agent's edit is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If $IsObject($Get(tProposal)) {
        Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        Do $$$AssertStatusOK(tSC, "and confirmed as applied: " _ $Get(tCode))
        Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tLedger), 1, "one write-kind ledger row")
        Do $$$AssertEquals($Get(tLedger("Status")), "ok", "recording the write as applied")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Description"), "agent edit", "which the instance holds")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    }

    ; The screen's caller, the fixture down.
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Stop"), "the fixture is stopped")
    Set tSC = ..Request("PUT", ..#CREATEPATH _ "/" _ ##class(OcuPilot.Kernel.EntityId).Encode(tName), {"Description": "screen edit"}, .tStatus, .tRaw, .tCode)
    Do $$$AssertEquals(tStatus, 200, "the Save is answered as saved: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue(tRaw [ ("""registrationNotUpdated"":""" _ ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTREGISTRATIONNOTUPDATED _ """"), "with the notice")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Description"), "screen edit", "and the instance holds the change")
}

/// <p>A registered client whose <code>PUT</code> the vendor answers 500 having stored nothing is
/// refused as <code>OAUTH.CLIENTVALIDATION</code>, with no <code>registrationNotUpdated</code>: the
/// port's re-read finds the sent change absent, and the instance holds the configuration as it was.
/// The 500 is <class>OcuPilot.Test.OAuthClientFailPort</class>'s, so the vendor is never called.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthClientPort.SentStored</method> answers 1 --
/// the refusal is answered as saved and this goes red.</p>
Method TestARegisteredPutThatStoredNothingIsRefused()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "storednothing")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddServer", tIssuer, .tServerId, ..Endpoint()), "a description with the fixture's endpoint is created")
    Set tName = $ClassMethod(..#PROBE, "Name", "StoredNothing")
    Set tSettings = {"ClientId": "ocupilotprobe000issued", "Description": "before", "Metadata": {"client_id": "ocupilotprobe000issued"}}
    Do tSettings.%Get("Metadata").%Set("registration_client_uri", $ClassMethod(..#FIXTURE, "Issuer") _ "/register/unknown", "string")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, tServerId, "confidential", tSettings), "a registered client is created")
    Do $ClassMethod(..#FAILPORT, "Arm", "PUT", 500)
    Kill tQuery
    Set tQuery("applicationName") = tName
    Set tSC = $ClassMethod(..#FAILPORT, "Invoke", ..#ENDPOINT, "PUT", .tQuery, {"Description": "refused edit"}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($ClassMethod(..#FAILPORT, "Reached", "PUT"), 1, "the PUT is answered by the armed override, not the vendor")
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "422 OAUTH.CLIENTVALIDATION", "the port refuses the write")
    Do $$$AssertTrue('$IsObject($Get(tResult)) || (tResult.%GetTypeOf("registrationNotUpdated") = "unassigned"), "with no registrationNotUpdated")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Description"), "before", "and the instance holds the configuration as it was")
}

}
