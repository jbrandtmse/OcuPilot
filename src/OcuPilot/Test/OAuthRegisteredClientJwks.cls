/// <p>Pins Story 12.8's Update JWKS (AD-27, AD-32, AD-51): the port's key-set read answers the JWKS URL,
/// the credentials and the key count and never the secret; a refresh from the authorization server's
/// own key set inside the container grows the key count, on the tab's row action and on the agent's
/// confirm; a client with no JWKS URL is refused 409 by name at the port and at the mint; a URL that is
/// neither https nor http is refused; an https URL is fetched through OcuPilot's own client SSL/TLS
/// configuration and, where it cannot be fetched, named; and the port's gate comes before the vendor
/// class.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the vendor's
/// <code>/oauth2</code> application answering on the container's own port 52773, an account holding
/// <code>%All</code>, no authorization server configuration and no registered client, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. Nothing reaches the internet: the
/// unreachable case names a reserved <code>.invalid</code> host.</p>
Class OcuPilot.Test.OAuthRegisteredClientJwks Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthRegisteredClientUpdateJwks";

Parameter CONFIRM = "OcuPilot.Test.OAuthRegisteredClientConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthRegisteredClientRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthRegisteredClientProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter ENDPOINT = "Security.OAuth2.ServerClients";

Parameter ACTIONPATH = "/screens/security.oauthserverclients/action";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthRegisteredClientJwks creates and deletes this instance's OAuth 2.0 authorization server configuration and clients and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    Do $$$AssertStatusOK(tSC, "the configuration and every client are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>A configuration and one client whose JWKS URL is <var>pUri</var>, its id in
/// <var>pClientId</var>.</p>
Method SeedClient(pUri As %String, Output pClientId As %String) As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Seed")
    If $$$ISERR(tSC) Quit tSC
    Set tSettings = {"Metadata": {}}
    If pUri '= "" Do tSettings.%Get("Metadata").%Set("jwks_uri", pUri, "string")
    Quit $ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "Jwks"), .pClientId, tSettings)
}

/// <p>The port's <code>JWKS</code> read of client <var>pClientId</var>, through the record port.</p>
ClassMethod KeySet(pClientId As %String, Output pHttp As %Integer, Output pFault) As %DynamicObject
{
    Kill tQuery
    Set tQuery("clientId") = pClientId
    Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "JWKS", .tQuery, "", .tResult, .pHttp, .pFault)
    Quit $Get(tResult)
}

/// <p>The port's <code>REFRESHJWKS</code> write for client <var>pClientId</var>, through the record
/// port, as <code>&lt;http&gt; &lt;code&gt;</code>.</p>
ClassMethod Refresh(pClientId As %String, Output pFault) As %String
{
    Kill tQuery
    Set tQuery("clientId") = pClientId
    Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "REFRESHJWKS", .tQuery, "", .tResult, .tHttp, .pFault)
    Quit tHttp _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>AC5 on the screen's caller: the key-set read answers the URL, the credentials and no key; the
/// tab's Update JWKS row action over the wire fetches the authorization server's own key set through no
/// SSL/TLS configuration and stores it, and the read then counts its keys; no answer carries the
/// secret.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthRegisteredClientPort.RefreshKeySet</method>
/// answers 200 without <method>OcuPilot.Port.OAuthRegisteredClientPort.Fetch</method> -- the key count
/// stays 0 and this goes red.</p>
Method TestTheInContainerUrlGrowsThePublicKeys()
{
    Do $$$AssertStatusOK(..SeedClient($Parameter(..#PROBE, "JWKSURL"), .tClientId), "a client with the in-container JWKS URL is seeded")
    Set tRead = ..KeySet(tClientId, .tHttp, .tFault)
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Keys", tRead) _ " " _ $Select($IsObject(tRead): tRead.%Get("JwksUri") _ " " _ tRead.%Get("PublicKeys"), 1: ""), "ClientCredentials,JwksUri,PublicKeys " _ $Parameter(..#PROBE, "JWKSURL") _ " 0", "the read answers the URL and no key, and nothing else")
    Set tRequest = {"action": "updatejwks"}
    Do tRequest.%Set("id", tClientId, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#ACTIONPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 200, "the tab's row action answers 200: " _ $Extract(tRaw, 1, 300))
    Set tStored = $ClassMethod(..#PROBE, "Stored", tClientId)
    Do $$$AssertTrue(tStored.%Get("PublicKeys") > 0, "and the stored key set holds the fetched keys (" _ tStored.%Get("PublicKeys") _ ")")
    Set tRead = ..KeySet(tClientId, .tHttp, .tFault)
    Do $$$AssertEquals(tRead.%Get("PublicKeys"), tStored.%Get("PublicKeys"), "which the read counts")
}

/// <p>AC5 on the agent's caller: the tool is minted over the key-set read, one row naming the key count
/// and the URL, and its confirm refreshes the key set with no SSL/TLS configuration for an http URL.</p>
Method TestTheAgentsUpdateJwksRefreshesTheKeys()
{
    Do $$$AssertStatusOK(..SeedClient($Parameter(..#PROBE, "JWKSURL"), .tClientId), "a client with the in-container JWKS URL is seeded")
    Set tArgs = {}
    Do tArgs.%Set("ClientId", tClientId, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tClientId, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the refresh is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRow = tProposal.%Get("changed").%Get(0)
    Do $$$AssertEquals(tRow.%Get("field") _ "|" _ tRow.%Get("before") _ "|" _ tRow.%Get("after"), "PublicKeys|0|" _ $Parameter(..#PROBE, "JWKSURL"), "one row: the key count, from the URL")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the refresh is confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Fetches", .tSsl) _ " [" _ tSsl _ "]", "1 []", "one fetch, through no SSL/TLS configuration for an http URL")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Stored", tClientId).%Get("PublicKeys") > 0, "and the stored key set holds the fetched keys")
}

/// <p>A client with no JWKS URL is refused 409 <code>OAUTH.SERVERCLIENTJWKS.NOURI</code> by the port
/// with nothing fetched, and the agent's mint refuses it with that sentence; an absent client is
/// 404.</p>
Method TestNoUriIsRefusedByName()
{
    Do $$$AssertStatusOK(..SeedClient("", .tClientId), "a client with no JWKS URL is seeded")
    Do $$$AssertEquals(..Refresh(tClientId, .tFault), "409 OAUTH.SERVERCLIENTJWKS.NOURI", "the port refuses the refresh by name")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Fetches"), 0, "with nothing fetched")
    Set tArgs = {}
    Do tArgs.%Set("ClientId", tClientId, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tClientId, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCLIENTJWKSNOURI), "and the agent's mint refuses it with the port's sentence")
    Set tOutcome = ..Refresh("OcuPilotNoSuchClient128", .tFault)
    Set tRead = ..KeySet("OcuPilotNoSuchClient128", .tHttp, .tFault)
    Do $$$AssertEquals(tOutcome _ " " _ tHttp, "404 PORT.NOTFOUND 404", "and an absent client is 404 on the write and the read")
}

/// <p>A JWKS URL that is neither https nor http is refused 422 <code>OAUTH.SERVERCLIENTJWKS.SCHEME</code>
/// with nothing fetched.</p>
Method TestAnotherSchemeIsRefused()
{
    Do $$$AssertStatusOK(..SeedClient("ftp://app.ocupilotprobe128.invalid/jwks", .tClientId), "a client with an ftp JWKS URL is seeded")
    Do $$$AssertEquals(..Refresh(tClientId, .tFault), "422 OAUTH.SERVERCLIENTJWKS.SCHEME", "the refresh is refused naming the scheme")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Fetches"), 0, "with nothing fetched")
}

/// <p>AD-32: an https JWKS URL is fetched through OcuPilot's own client SSL/TLS configuration; one it
/// cannot fetch -- the in-container server speaks no TLS, which stands for a certificate only the
/// authorization server's own configuration trusts -- is refused 422
/// <code>OAUTH.SERVERCLIENTJWKS.FETCH</code> naming the URL, with nothing stored.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthRegisteredClientPort.RefreshKeySet</method>
/// passes no SSL/TLS configuration for https -- the recorded configuration is empty and this goes
/// red.</p>
Method TestAnHttpsUrlIsFetchedThroughOcuPilotsConfiguration()
{
    Set tUri = "https://localhost:52773/oauth2/jwks"
    Do $$$AssertStatusOK(..SeedClient(tUri, .tClientId), "a client with an https JWKS URL is seeded")
    Do $$$AssertEquals(..Refresh(tClientId, .tFault), "422 OAUTH.SERVERCLIENTJWKS.FETCH", "the fetch fails and is named")
    Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.%Get("reason") [ tUri), "the sentence names the URL")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Fetches", .tSsl) _ " " _ tSsl, "1 " _ ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG, "through OcuPilot's own client configuration")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tClientId).%Get("PublicKeys"), 0, "and nothing is stored")
}

/// <p>An unreachable JWKS URL is named: <code>OAUTH.SERVERCLIENTJWKS.FETCH</code>, after the vendor's own
/// connect timeout.</p>
Method TestAnUnreachableUrlIsNamed()
{
    Do $$$AssertStatusOK(..SeedClient("http://unreachable.ocupilotprobe128.invalid/jwks", .tClientId), "a client with an unreachable JWKS URL is seeded")
    Do $$$AssertEquals(..Refresh(tClientId, .tFault), "422 OAUTH.SERVERCLIENTJWKS.FETCH", "the refresh is named")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tClientId).%Get("PublicKeys"), 0, "and nothing is stored")
}

/// <p>AD-29, AD-27: the port refuses a caller without either of its pairs before it opens the vendor
/// class -- no fetch is made, and the stored key set is unchanged.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Port.OAuthRegisteredClientPort.Invoke</method>'s
/// <method>OcuPilot.Port.OAuthRegisteredClientPort.RefusedPair</method> check -- the fetch runs and this
/// goes red.</p>
Method TestThePortGateComesBeforeTheVendorClass()
{
    Do $$$AssertStatusOK(..SeedClient($Parameter(..#PROBE, "JWKSURL"), .tClientId), "a client with the in-container JWKS URL is seeded")
    For tPair = "%Admin_OAuth2_Registration:USE", "%DB_IRISSYS:READ" {
        Do $ClassMethod(..#RECORD, "Clear")
        Do $ClassMethod(..#RECORD, "DenyPair", tPair)
        Set tOutcome = ..Refresh(tClientId, .tFault)
        Set tNamed = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tOutcome _ " " _ tNamed, "403 " _ ##class(OcuPilot.Api.Error).#PORTACCESSDENIED _ " " _ tPair, tPair _ ": the refresh is refused naming the pair")
        Set tRead = ..KeySet(tClientId, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 403, tPair _ ": and so is the read")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "Fetches"), 0, tPair _ ": before any fetch")
    }
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tClientId).%Get("PublicKeys"), 0, "and the stored key set is unchanged")
}

}
