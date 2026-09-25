/// <p>Pins Story 12.4's Discover (AD-27, AD-39): the two vendor methods the port completes calls
/// through keep the signatures it calls them with; a discovery of the local issuer answers its
/// published members over the editor's route and saves nothing, a stored description included; a Save
/// then stores the discovered members; and each of the four causes a discovery fails for is refused
/// by name.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo
/// fixture, an account holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because it creates and deletes OAuth 2.0 server descriptions. The issuer is
/// <class>OcuPilot.Test.OAuthIssuerFixture</class>, started and stopped around every method; nothing
/// leaves the instance. The unreachable cause waits out the vendor's own connect timeout, about 30
/// seconds.</p>
Class OcuPilot.Test.OAuthServerDiscover Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.OAuthServerProbe";

Parameter FIXTURE = "OcuPilot.Test.OAuthIssuerFixture";

Parameter PORT = "OcuPilot.Port.OAuthServerPort";

Parameter SCREEN = "OcuPilot.Test.OAuthServerSaveFixture";

/// <p>The editor's discovery route, under the test helper's base path.</p>
Parameter DISCOVERPATH = "/oauth/server-description/discover";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthServerDiscover creates and deletes OAuth 2.0 server descriptions on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#FIXTURE, "Start", , .tIssuer)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Stop"), "the issuer fixture stops")
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe description is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>AD-27: <code>GetServerMetadata</code> is an <code>[Internal]</code> class method taking the
/// issuer, the SSL/TLS configuration and an output metadata object and answering a status, and
/// <code>RefreshJWKS</code> an instance method taking force, save and an output status and answering
/// a boolean, as the port calls them.</p>
Method TestTheVendorMethodsKeepTheSignaturesThePortCalls()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId("OAuth2.ServerDefinition||GetServerMetadata")
        Set tGet = $Select($IsObject(tMethod): tMethod.ClassMethod _ "|" _ tMethod.FormalSpec _ "|" _ tMethod.ReturnType, 1: "")
        Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId("OAuth2.ServerDefinition||RefreshJWKS")
        Set tRefresh = $Select($IsObject(tMethod): tMethod.ClassMethod _ "|" _ tMethod.FormalSpec _ "|" _ tMethod.ReturnType, 1: "")
        Set tMethod = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set (tGet, tRefresh) = ""
    }
    Do $$$AssertEquals(tGet, "1|issuerEndpoint:%String,sslConfiguration:%String,*metadata:OAuth2.Server.Metadata|%Library.Status", "GetServerMetadata is the class method the port calls")
    Do $$$AssertEquals(tRefresh, "0|force:%Boolean=0,save:%Boolean=1,*sc:%Status|%Library.Boolean", "RefreshJWKS is the instance method the port calls")
}

/// <p>AC4: a discovery of the local issuer over the editor's route answers its issuer and its
/// published members -- both endpoints, the JWKS URL, the lists and the flag -- and saves nothing:
/// the instance holds no description at that issuer and its count is unchanged.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthServerPort.Discover</method> saves the discovered
/// definition before it answers -- the nothing-saved assertions go red.</p>
Method TestADiscoveryAnswersThePublishedMembersAndSavesNothing()
{
    Set tIssuer = $ClassMethod(..#FIXTURE, "Issuer")
    Set tCount = $ClassMethod(..#PROBE, "Count")
    Set tRequest = {"SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG"))}
    Do tRequest.%Set("IssuerEndpoint", tIssuer, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#DISCOVERPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Do $$$AssertStatusOK(tSC, "the route answers")
    Do $$$AssertEquals(tStatus, 200, "at 200")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as JSON")
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tBody = "" }
    Do $$$AssertTrue($IsObject(tBody), "one envelope")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.%Get("issuer"), tIssuer, "naming the issuer")
    Set tExpected = $ClassMethod(..#FIXTURE, "Document", $Parameter(..#FIXTURE, "DEFAULTPORT"), tIssuer)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Keys", tBody.%Get("metadata")), $ClassMethod(..#PROBE, "Keys", tExpected), "carrying every member the issuer publishes")
    Do $$$AssertEquals(tBody.%Get("metadata").%Get("token_endpoint") _ "|" _ tBody.%Get("metadata").%Get("scopes_supported").%ToJSON() _ "|" _ tBody.%Get("metadata").%Get("claims_parameter_supported"), tIssuer _ "/token|[""openid"",""profile""]|1", "with its values")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tIssuer), 0, "and nothing is saved")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count"), tCount, "the instance's descriptions are as they were")
}

/// <p>A discovery of an issuer the instance already describes leaves the stored description as it
/// was; a Save of the discovered members then stores them.</p>
Method TestADiscoveryLeavesAStoredDescriptionAndASaveStoresTheMembers()
{
    Set tIssuer = $ClassMethod(..#FIXTURE, "Issuer")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer), "the issuer is described")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tIssuer).%ToJSON()
    Set tSC = $ClassMethod(..#PORT, "Discover", tIssuer, $Parameter(..#PROBE, "SSLCONFIG"), .tMetadata, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the discovery answers")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%ToJSON(), tBefore, "and the stored description is unchanged")
    If '$IsObject($Get(tMetadata)) Quit
    Set tMembers = {}
    Do tMembers.%Set("Metadata", tMetadata)
    Set tSC = $ClassMethod(..#SCREEN, "Update", tIssuer, tMembers, .tNew, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "a Save of the discovered members completes")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("Metadata").%ToJSON(), tMetadata.%ToJSON(), "and the instance holds exactly them")
}

/// <p>Each cause is refused 422 by name with its sentence filled: a status other than 200, a document
/// that is not JSON or does not parse, a document naming another issuer, and an issuer nothing
/// answers.</p>
Method TestEachCauseIsRefusedByName()
{
    Set tBase = $ClassMethod(..#FIXTURE, "Issuer")
    Set tSSL = $Parameter(..#PROBE, "SSLCONFIG")
    Set tCount = $ClassMethod(..#PROBE, "Count")
    Set tCases = $ListBuild($ListBuild(tBase _ "/status", "OAUTH.DISCOVERY.STATUS", "status", tBase _ "/status answered HTTP 503."))
    Set tCases = tCases _ $ListBuild($ListBuild(tBase _ "/not-json", "OAUTH.DISCOVERY.CONTENT", "content", tBase _ "/not-json did not answer JSON."))
    Set tCases = tCases _ $ListBuild($ListBuild(tBase _ "/bad-json", "OAUTH.DISCOVERY.CONTENT", "content", tBase _ "/bad-json did not answer JSON."))
    Set tCases = tCases _ $ListBuild($ListBuild(tBase _ "/wrong-issuer", "OAUTH.DISCOVERY.ISSUER", "issuer", "The document names a different issuer: " _ tBase _ "/another-issuer."))
    Set tClosed = $ClassMethod(..#FIXTURE, "Issuer", $Parameter(..#FIXTURE, "CLOSEDPORT"))
    Set tCases = tCases _ $ListBuild($ListBuild(tClosed, "OAUTH.DISCOVERY.UNREACHABLE", "unreachable", tClosed _ " could not be reached."))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tSC = $ClassMethod(..#PORT, "Discover", $List(tCase, 1), tSSL, .tMetadata, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 3) _ ": refused")
        Set tAnswer = ""
        If $IsObject($Get(tFault)) Set tAnswer = tHttp _ "|" _ tFault.%Get("code") _ "|" _ tFault.%Get("detail").%Get("cause") _ "|" _ tFault.%Get("reason")
        Do $$$AssertEquals(tAnswer, "422|" _ $List(tCase, 2) _ "|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4), $List(tCase, 3) _ ": at 422, by name")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count"), tCount, "and nothing is saved")
}

}
