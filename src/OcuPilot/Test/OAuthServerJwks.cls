/// <p>Pins Story 12.4's Update JWKS (AD-27, AD-51, AD-53): the tab's row action refreshes the stored
/// key set from the description's JWKS URL, storing exactly the key set fetched and clearing the
/// X.509 server credentials when it changed, and the vendor records its own audit event; a description
/// with no JWKS URL is refused by name on the row action and at the agent's mint; a fetch that fails
/// is refused by name and stores nothing; and the agent's refresh is minted and confirmed.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture,
/// auditing on, an account holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because it creates and deletes OAuth 2.0 server descriptions. The JWKS URL
/// is <class>OcuPilot.Test.OAuthIssuerFixture</class>'s, started and stopped around every method.</p>
Class OcuPilot.Test.OAuthServerJwks Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthServerDescriptionUpdateJwks";

Parameter PROBE = "OcuPilot.Test.OAuthServerProbe";

Parameter FIXTURE = "OcuPilot.Test.OAuthIssuerFixture";

/// <p>The tab's row-action route, under the test helper's base path.</p>
Parameter ACTIONPATH = "/screens/security.oauthserverdescriptions/action";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthServerJwks creates and deletes OAuth 2.0 server descriptions on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#FIXTURE, "Start", , .tIssuer)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Stop"), "the issuer fixture stops")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe description is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>A description whose JWKS URL is the fixture's, with <var>pCredentials</var>.</p>
Method Described(pSuffix As %String, pWithUrl As %Boolean = 1, pCredentials As %String = "") As %String
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", pSuffix)
    Set tMore = {}
    If pWithUrl Do tMore.%Set("jwks_uri", $ClassMethod(..#FIXTURE, "Issuer") _ "/jwks", "string")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer, $ClassMethod(..#PROBE, "Metadata", tIssuer, tMore), pCredentials), "description " _ pSuffix _ " is created")
    Quit tIssuer
}

/// <p>One row action on the tab over a real HTTP request as the test account.</p>
Method Act(pAction As %String, pId As %String, Output pStatus As %Integer, Output pBody) As %Status
{
    Set pBody = ""
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#ACTIONPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Try { Set pBody = ##class(%DynamicObject).%FromJSON($ZConvert(tRaw, "I", "UTF8")) } Catch { Set pBody = "" }
    Quit tSC
}

/// <p>AC5: the row action refreshes the key set of a description whose server credentials made its
/// stored one: the instance then holds exactly the fixture's key set, its server credentials are
/// cleared because the key set changed, and the vendor records its own modify event.</p>
/// <p>Mutation (Rule 19): the port calls <code>RefreshJWKS(0,1)</code> -- this goes red, and so does
/// the failed-fetch leg.</p>
Method TestTheRowActionStoresTheKeySetAndClearsTheCredentials()
{
    Set tIssuer = ..Described("Refresh", 1, $Parameter(..#PROBE, "CREDENTIAL"))
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tIssuer)
    Do $$$AssertTrue($IsObject(tBefore) && (tBefore.%Get("PublicJWKS") '= "") && (tBefore.%Get("PublicJWKS") '= $Parameter(..#FIXTURE, "JWKS")), "the stored key set is the credential's")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Act("updatejwks", tIssuer, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the row action answers 200")
    If $IsObject(tBody) && (tStatus = 200) Do $$$AssertEquals(tBody.%Get("action") _ " " _ tBody.%Get("target").%Get("id"), "updated " _ tIssuer, "publishing updated for the description")
    Set tAfter = $ClassMethod(..#PROBE, "Stored", tIssuer)
    Do $$$AssertEquals(tAfter.%Get("PublicJWKS"), $Parameter(..#FIXTURE, "JWKS"), "the instance holds exactly the key set fetched")
    Do $$$AssertEquals(tAfter.%Get("ServerCredentials"), "", "and its server credentials are cleared")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "VendorRows", tSince, tIssuer) [ "Modify OAuth2 Server Definition", "the vendor records its own modify event")
}

/// <p>A description with no JWKS URL is refused 409 <code>OAUTH.NOJWKSURI</code> by name on the row
/// action, and the agent's mint refuses it with the same sentence; nothing is stored.</p>
Method TestADescriptionWithNoJwksUrlIsRefusedByName()
{
    Set tIssuer = ..Described("NoUrl", 0)
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tIssuer).%ToJSON()
    Set tSC = ..Act("updatejwks", tIssuer, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.%Get("code") _ "|" _ tBody.%Get("reason"), 1: ""), "409 OAUTH.NOJWKSURI|" _ ##class(OcuPilot.Api.Error).#REASONOAUTHNOJWKSURI, "the row action is refused by name")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#TOOL, tIssuer, {"IssuerEndpoint": (tIssuer)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#PROBE, "Problem", $Get(tFault)) = ##class(OcuPilot.Api.Error).#REASONOAUTHNOJWKSURI), "and the agent's mint refuses it with the same sentence")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%ToJSON(), tBefore, "nothing is stored")
}

/// <p>A fetch that fails -- the fixture stopped -- is refused 422 <code>OAUTH.JWKSFAILED</code> naming
/// the URL, and the stored key set and credentials are unchanged.</p>
Method TestAFetchThatFailsIsRefusedAndStoresNothing()
{
    Set tIssuer = ..Described("Fails", 1, $Parameter(..#PROBE, "CREDENTIAL"))
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tIssuer).%ToJSON()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Stop"), "the issuer fixture is stopped")
    Set tSC = ..Act("updatejwks", tIssuer, .tStatus, .tBody)
    Set tUrl = $ClassMethod(..#FIXTURE, "Issuer") _ "/jwks"
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.%Get("code") _ "|" _ tBody.%Get("reason"), 1: ""), "422 OAUTH.JWKSFAILED|" _ $Replace(##class(OcuPilot.Api.Error).#REASONOAUTHJWKSFAILED, "{url}", tUrl), "the row action is refused naming the URL")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%ToJSON(), tBefore, "and nothing is stored")
}

/// <p>The agent's refresh is minted with one row naming the URL the key set comes from, fetches
/// nothing at the mint, and its confirm stores the key set.</p>
Method TestTheAgentsRefreshIsMintedAndConfirmed()
{
    Set tIssuer = ..Described("Agent", 1)
    Set tUrl = $ClassMethod(..#FIXTURE, "Issuer") _ "/jwks"
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#TOOL, tIssuer, {"IssuerEndpoint": (tIssuer)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the refresh is minted: " _ $ClassMethod(..#PROBE, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRow = tProposal.%Get("changed").%Get(0)
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("field") _ ">" _ tRow.%Get("after"), 1: ""), "PublicJWKS>" _ tUrl, "one row naming the URL the key set comes from")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("PublicJWKS"), "", "nothing is fetched at the mint")
    Set tSC = ##class(OcuPilot.Test.ConfirmFixture).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the refresh is confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("PublicJWKS"), $Parameter(..#FIXTURE, "JWKS"), "and the key set is stored")
}

}
