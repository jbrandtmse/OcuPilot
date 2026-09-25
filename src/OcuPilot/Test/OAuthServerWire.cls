/// <p>Story 12.4's routes and tools against the instance itself, as real principals (AD-8, AD-12,
/// AD-29, AD-39, AD-53, AD-55): each editor route answers one JSON envelope; every route, row action
/// and agent confirm is refused to a principal without <code>%Admin_OAuth2_Client</code>, naming the
/// pair, and so are the port's Discover and key-set refresh; a principal holding only the screen's
/// pairs and the install namespace's code read discovers, creates, edits, refreshes, stores a token
/// and deletes, with no agent marker; and each of the five tools is minted and confirmed over the wire
/// with one agent marker.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo
/// fixture, an account holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because the legs create and delete two users, two roles and OAuth 2.0 server
/// descriptions. The issuer is <class>OcuPilot.Test.OAuthIssuerFixture</class>, started and stopped
/// around every method.</p>
Class OcuPilot.Test.OAuthServerWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FORMPATH = "/oauth/server-description/form";

Parameter DISCOVERPATH = "/oauth/server-description/discover";

Parameter CREATEPATH = "/oauth/server-description";

/// <p>The edit route; <method>EditPath</method> fills its one segment.</p>
Parameter EDITPATH = "/oauth/server-description/:id";

Parameter ACTIONPATH = "/screens/security.oauthserverdescriptions/action";

Parameter PROBE = "OcuPilot.Test.OAuthServerProbe";

Parameter FIXTURE = "OcuPilot.Test.OAuthIssuerFixture";

Parameter RECORD = "OcuPilot.Test.OAuthServerRecordPort";

Parameter ENDPOINT = "Security.OAuth2.Client.ServerDefinition";

Parameter PAIR = "%Admin_OAuth2_Client:USE";

/// <p>What every one of the five tools' names begins with, and so what an agent-write marker for any
/// of them carries.</p>
Parameter TOOLPREFIX = "security.oauthserverdescriptions.";

/// <p>The principal holding the install namespace's code read, the system database read and the
/// secure resource, and not <code>%Admin_OAuth2_Client</code>.</p>
Parameter NOOAUTHUSER = "OcuPilotWireOAuthServerNone";

Parameter NOOAUTHROLE = "OcuPilotWireOAuthServerNoneRole";

/// <p>The principal holding the install namespace's code read and the screen's two declared pairs,
/// and nothing else.</p>
Parameter LEASTUSER = "OcuPilotWireOAuthServerLeast";

Parameter LEASTROLE = "OcuPilotWireOAuthServerLeastRole";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthServerWire creates and deletes users, roles and OAuth 2.0 server descriptions on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotOAuth" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ..EnsurePrincipals()
}

/// <p>Remove the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#NOOAUTHUSER, ..#LEASTUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthServerWire left user " _ tUser))
        }
        For tRole = ..#NOOAUTHROLE, ..#LEASTROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthServerWire left role " _ tRole))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#FIXTURE, "Start", , .tIssuer)
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Stop"), "the issuer fixture stops")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe description is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>AD-12, AD-39: the form read, with an issuer and without, the create, the edit and the discovery
/// each answer exactly one JSON envelope over a real HTTP request; a create naming nothing is refused
/// on the editor's own envelope code, and an edit or a form read of an issuer the instance does not
/// hold is 404 on its own.</p>
Method TestEachRouteAnswersOneJsonEnvelopeOverTheWire()
{
    Set tIssuer = $ClassMethod(..#FIXTURE, "Issuer")
    Set tAbsent = $ClassMethod(..#PROBE, "Issuer", "Absent")
    Set tDiscover = {"SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG"))}
    Do tDiscover.%Set("IssuerEndpoint", tIssuer, "string")
    Set tCases = $ListBuild($ListBuild("GET", ..#FORMPATH, "", 200, ""))
    Set tCases = tCases _ $ListBuild($ListBuild("GET", ..#FORMPATH _ "?issuer=" _ $ZConvert(tAbsent, "O", "URL"), "", 404, ##class(OcuPilot.Api.Error).#OAUTHISSUERENDPOINTABSENT))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#CREATEPATH, "{}", 422, ##class(OcuPilot.Api.Error).#OAUTHVALIDATION))
    Set tCases = tCases _ $ListBuild($ListBuild("PUT", ..EditPath(tAbsent), "{}", 404, ##class(OcuPilot.Api.Error).#OAUTHISSUERENDPOINTABSENT))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#DISCOVERPATH, tDiscover.%ToJSON(), 200, ""))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tLabel = $List(tCase, 1) _ " " _ $List(tCase, 2)
        Set tSC = ..Request($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), "", .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus, $List(tCase, 4), tLabel _ ": at " _ $List(tCase, 4))
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tLabel _ ": as application/json")
        Do $$$AssertEquals((tRaw [ "}{"), 0, tLabel _ ": exactly one envelope")
        Set tBody = ""
        Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tBody = "" }
        Do $$$AssertTrue($IsObject(tBody), tLabel _ ": a JSON object")
        If ($List(tCase, 5) '= "") && $IsObject(tBody) Do $$$AssertEquals(tBody.%Get("code"), $List(tCase, 5), tLabel _ ": on its own code")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tIssuer), 0, "and the discovery saved nothing")
}

/// <p>AC8, AD-8: every editor route and both row actions are refused 403 to a real principal without
/// <code>%Admin_OAuth2_Client</code>, naming the pair, and nothing is created or deleted; the agent's
/// confirm of each tool, minted for that principal, is refused the same way over the wire.</p>
Method TestACallerWithoutTheResourceIsRefusedEverywhere()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "Denied")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer, $ClassMethod(..#PROBE, "Metadata", tIssuer, {"jwks_uri": (tIssuer _ "/jwks")})), "a description with a JWKS URL is created")
    Set tFresh = $ClassMethod(..#PROBE, "Issuer", "DeniedNew")
    Set tCreate = {"SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG"))}
    Do tCreate.%Set("IssuerEndpoint", tFresh, "string")
    Do tCreate.%Set("Metadata", $ClassMethod(..#PROBE, "Metadata", tFresh))
    Set tCases = $ListBuild($ListBuild("GET", ..#FORMPATH, ""), $ListBuild("GET", ..#FORMPATH _ "?issuer=" _ $ZConvert(tIssuer, "O", "URL"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#CREATEPATH, tCreate.%ToJSON()), $ListBuild("PUT", ..EditPath(tIssuer), "{""SSLConfiguration"":""""}"))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#DISCOVERPATH, "{""IssuerEndpoint"":""" _ tIssuer _ """}"))
    For tAction = "delete", "updatejwks" {
        Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#ACTIONPATH, {"action": (tAction), "id": (tIssuer)}.%ToJSON()))
    }
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tLabel = $List(tCase, 1) _ " " _ $List(tCase, 2) _ $Select($List(tCase, 2) = ..#ACTIONPATH: " " _ $List(tCase, 3), 1: "")
        Set tSC = ..Request($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ..#NOOAUTHUSER, .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tRaw), "403 AUTH.NOPRIVILEGE " _ ..#PAIR, tLabel _ ": refused naming the pair: " _ tStatus _ " " _ $Extract(tRaw, 1, 200))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tIssuer) _ $ClassMethod(..#PROBE, "Holds", tFresh), "10", "nothing is deleted or created")
    Set tCases = $ListBuild($ListBuild("Create", tFresh), $ListBuild("Update", tIssuer), $ListBuild("Delete", tIssuer), $ListBuild("UpdateJwks", tIssuer), $ListBuild("SetToken", tIssuer))
    For tI = 1:1:$ListLength(tCases) {
        Set tTool = "OcuPilot.Screen.Tool.OAuthServerDescription" _ $List($List(tCases, tI), 1)
        Set tTarget = $List($List(tCases, tI), 2)
        ; The update names a changed key-set URL: a merge that changes nothing is refused at mint (DW-1577).
        Set tArgs = $Select(tTool [ "Create": tCreate, tTool [ "Update" && '(tTool [ "Jwks"): {"Metadata": ($ClassMethod(..#PROBE, "Metadata", tTarget, {"jwks_uri": (tTarget _ "/jwks-changed")}))}, 1: {})
        Do tArgs.%Set("IssuerEndpoint", tTarget, "string")
        Set tSC = ..Mint(tTool, tTarget, tArgs, ..#NOOAUTHUSER, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tTool _ ": is minted for the principal: " _ $ClassMethod(..#PROBE, "Problem", $Get(tFault)))
        If '$IsObject($Get(tProposal)) Continue
        Set tSC = ..Request("POST", "/proposal/" _ tProposal.%Get("proposalId") _ "/confirm", "", ..#NOOAUTHUSER, .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tRaw), "403 AUTH.NOPRIVILEGE " _ ..#PAIR, tTool _ ": its confirm is refused naming the pair: " _ tStatus _ " " _ $Extract(tRaw, 1, 200))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tIssuer) _ $ClassMethod(..#PROBE, "Holds", tFresh), "10", "and still nothing is deleted or created")
}

/// <p>AC8 at the port: a caller without <code>%Admin_OAuth2_Client</code> is refused 403 naming the
/// pair on the port's Discover and key-set refresh, before anything is fetched.</p>
/// <p>Mutation (Rule 19): remove the resource check from
/// <method>OcuPilot.Port.OAuthServerPort.Discover</method> -> the discovery fetches and this goes
/// red.</p>
Method TestThePortRefusesDiscoverAndRefreshWithoutTheResource()
{
    Set tIssuer = $ClassMethod(..#FIXTURE, "Issuer")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer), "the issuer is described")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tIssuer).%ToJSON()
    Do $ClassMethod(..#RECORD, "Deny", $Piece(..#PAIR, ":", 1))
    Set tSC = $ClassMethod(..#RECORD, "Discover", tIssuer, $Parameter(..#PROBE, "SSLCONFIG"), .tMetadata, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("detail").%Get("failedPair"), 1: ""), "403 " _ ..#PAIR, "the discovery is refused naming the pair")
    Do $$$AssertTrue('$IsObject($Get(tMetadata)), "and answers no members")
    Kill tQuery
    Set tQuery("issuer") = tIssuer
    Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "REFRESHJWKS", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("detail").%Get("failedPair"), 1: ""), "403 " _ ..#PAIR, "the refresh is refused naming the pair")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%ToJSON(), tBefore, "and the stored description is unchanged")
}

/// <p>AD-29: a real principal holding only the install namespace's code read and the screen's two
/// declared pairs discovers the local issuer, creates its description with a token, reads and edits
/// it, refreshes its key set and deletes it, on the screen's own routes and row actions. None of those
/// Saves and row actions emits an OcuPilot agent-write marker (AD-53), where
/// <method>TestEachToolIsMintedAndConfirmedWithAMarker</method> shows each agent confirm does, naming
/// its tool.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthServerSave.HandleUpdate</method> emits
/// the agent-write marker after its write -- the marker assertion goes red.</p>
Method TestTheDeclaredPairsAloneDoEveryWrite()
{
    Set tIssuer = $ClassMethod(..#FIXTURE, "Issuer")
    Set tUser = ..#LEASTUSER
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tRequest = {"SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG"))}
    Do tRequest.%Set("IssuerEndpoint", tIssuer, "string")
    Set tSC = ..Request("POST", ..#DISCOVERPATH, tRequest.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the principal's discovery answers 200: " _ $Extract(tRaw, 1, 300))
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tBody = "" }
    If '$IsObject(tBody) Quit
    Do tRequest.%Set("Metadata", tBody.%Get("metadata"))
    Do tRequest.%Set("InitialAccessToken", "ocupilotwireprobe000" _ $Job, "string")
    Set tSC = ..Request("POST", ..#CREATEPATH, tRequest.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 201, "its create answers 201: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals(tRaw [ "tokenRefused", 0, "and stores the token")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("TokenLength") > 0, "which the instance holds")
    Set tSC = ..Request("GET", ..#FORMPATH _ "?issuer=" _ $ZConvert(tIssuer, "O", "URL"), "", tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its form read answers the principal")
    Set tSC = ..Request("PUT", ..EditPath(tIssuer), "{""Metadata"":{""scopes_supported"":[""openid""]}}", tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its edit answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("Metadata").%Get("scopes_supported").%ToJSON(), "[""openid""]", "which the instance applied")
    Set tSC = ..Request("POST", ..#ACTIONPATH, {"action": "updatejwks", "id": (tIssuer)}.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its Update JWKS answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("PublicJWKS") '= "", "and the instance holds the key set")
    Set tSC = ..Request("POST", ..#ACTIONPATH, {"action": "delete", "id": (tIssuer)}.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its delete answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tIssuer), 0, "which deletes the description")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, ..#TOOLPREFIX, .tData), 0, "and no Save or row action emitted an agent-write marker (AD-53): " _ $Extract($Get(tData), 1, 200))
}

/// <p>AD-5: the form read offers the SSL/TLS configurations and X.509 credentials only through those
/// screens' own gates -- the demo names to a caller holding their pairs, and nothing to the least
/// principal, who holds the editor's pairs but not <code>%Admin_Secure</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthServerRules.ReadableNames</method>
/// answers <code>[]</code> for every caller -- the test account's leg goes red. Its screen gate alone
/// removed stays green: the admin port's own <code>ResourcesOR()</code> gate refuses the least
/// principal's read as well (AD-29).</p>
Method TestTheFormReadOffersOnlyTheNamesTheCallerCanRead()
{
    For tUser = "", ..#LEASTUSER {
        Set tLabel = $Select(tUser = "": "the test account", 1: "the least principal")
        Set tSC = ..Request("GET", ..#FORMPATH, "", tUser, .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tLabel _ ": the form read answers")
        Set tBody = ""
        Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tBody = "" }
        Set tAnswer = ""
        If $IsObject(tBody) && $IsObject(tBody.%Get("sslConfigurations")) && $IsObject(tBody.%Get("credentials")) {
            Set tAnswer = tBody.%Get("sslConfigurations").%ToJSON() _ "|" _ tBody.%Get("credentials").%ToJSON()
        }
        If tUser = "" {
            Do $$$AssertTrue((tAnswer [ ("""" _ $Parameter(..#PROBE, "SSLCONFIG") _ """")) && (tAnswer [ ("""" _ $Parameter(..#PROBE, "CREDENTIAL") _ """")), tLabel _ ": offered the demo configuration and credential: " _ tAnswer)
        } Else {
            Do $$$AssertEquals(tAnswer, "[]|[]", tLabel _ ": offered neither list")
        }
    }
}

/// <p>AD-53, AD-55: each of the five tools, minted for the least principal and confirmed over the
/// wire as that principal, applies its write and leaves exactly one agent marker naming its
/// proposal; the token's confirm takes the token in its body, and no marker carries it.</p>
Method TestEachToolIsMintedAndConfirmedWithAMarker()
{
    Set tIssuer = $ClassMethod(..#FIXTURE, "Issuer")
    Set tUser = ..#LEASTUSER
    Set tToken = "ocupilotmarkerprobe000" _ $Job
    Set tCreate = {"SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG"))}
    Do tCreate.%Set("IssuerEndpoint", tIssuer, "string")
    Do tCreate.%Set("Metadata", $ClassMethod(..#FIXTURE, "Document", $Parameter(..#FIXTURE, "DEFAULTPORT"), tIssuer))
    Set tUpdate = {"Metadata": ($ClassMethod(..#FIXTURE, "Document", $Parameter(..#FIXTURE, "DEFAULTPORT"), tIssuer))}
    Do tUpdate.%Get("Metadata").%Set("scopes_supported", ["openid"])
    Do tUpdate.%Set("IssuerEndpoint", tIssuer, "string")
    Set tSteps = $ListBuild($ListBuild("Create", tCreate.%ToJSON(), "", "created"), $ListBuild("Update", tUpdate.%ToJSON(), "", "updated"))
    Set tSteps = tSteps _ $ListBuild($ListBuild("SetToken", "{""IssuerEndpoint"":""" _ tIssuer _ """}", "{""InitialAccessToken"":""" _ tToken _ """}", "updated"))
    Set tSteps = tSteps _ $ListBuild($ListBuild("UpdateJwks", "{""IssuerEndpoint"":""" _ tIssuer _ """}", "", "updated"), $ListBuild("Delete", "{""IssuerEndpoint"":""" _ tIssuer _ """}", "", "deleted"))
    For tI = 1:1:$ListLength(tSteps) {
        Set tStep = $List(tSteps, tI)
        Set tTool = "OcuPilot.Screen.Tool.OAuthServerDescription" _ $List(tStep, 1)
        Set tSC = ..Mint(tTool, tIssuer, ##class(%DynamicObject).%FromJSON($List(tStep, 2)), tUser, .tProposal, .tHttp, .tFault, .tTurnKey)
        Do $$$AssertStatusOK(tSC, tTool _ ": is minted: " _ $ClassMethod(..#PROBE, "Problem", $Get(tFault)))
        If '$IsObject($Get(tProposal)) Quit
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tSC = ..Request("POST", "/proposal/" _ tProposal.%Get("proposalId") _ "/confirm", $List(tStep, 3), tUser, .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tTool _ ": is confirmed over the wire: " _ $Extract(tRaw, 1, 300))
        Do $$$AssertTrue(tRaw [ ("""action"":""" _ $List(tStep, 4) _ """"), tTool _ ": publishing " _ $List(tStep, 4))
        Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposal.%Get("proposalId") _ """", .tData), 1, tTool _ ": one agent marker names its proposal")
        Do $$$AssertEquals($Get(tData) [ tToken, 0, tTool _ ": and carries no token")
        Do $$$AssertTrue($Get(tData) [ ..#TOOLPREFIX, tTool _ ": and names its tool, which the screen path's zero is read against")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    }
    Set tStored = $ClassMethod(..#PROBE, "Stored", tIssuer)
    Do $$$AssertEquals($IsObject(tStored), 0, "the last confirm deleted the description")
}

/// <p>One request as <var>pUser</var>, the test account when empty.</p>
Method Request(pMethod As %String, pPath As %String, pBody As %String, pUser As %String, Output pStatus As %Integer, Output pRaw As %String, Output pHeaders) As %Status
{
    Set tUser = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestUsername(), 1: pUser)
    Set tPassword = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestPassword(), 1: ..PreparedPassword)
    Set tBody = $Select(pMethod = "GET": "", 1: pBody)
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath, tUser, tPassword, .pStatus, .pRaw, .pHeaders, tBody, $Select(pMethod = "GET": "", 1: "application/json"))
}

/// <p>A refusal envelope's <code>code failedPair</code>, or <code>""</code>.</p>
ClassMethod Refusal(pRaw As %String) As %String
{
    Set tAnswer = ""
    Try {
        Set tBody = ##class(%DynamicObject).%FromJSON(pRaw)
        Set tAnswer = tBody.%Get("code") _ " " _ $Select($IsObject(tBody.%Get("detail")): tBody.%Get("detail").%Get("failedPair"), 1: "")
    } Catch {
        Set tAnswer = ""
    }
    Quit tAnswer
}

/// <p>Mint one write of tool <var>pTool</var> against <var>pIssuer</var> for <var>pUser</var>
/// through the shipped mint, on a completed turn seeded for that user.</p>
ClassMethod Mint(pTool As %String, pIssuer As %String, pArgs As %DynamicObject, pUser As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTurnKey As %String) As %Status
{
    Set pProposal = ""
    Set pFault = ""
    Set pHttpStatus = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), pUser, "", pTurnKey, pArgs, "OcuPilot.Kernel.Agent.Limits", .pProposal, .pHttpStatus, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pIssuer, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p><parameter>EDITPATH</parameter> for <var>pIssuer</var>, its segment encoded by the one shared
/// encoder (AD-13).</p>
ClassMethod EditPath(pIssuer As %String) As %String
{
    Quit $Replace(..#EDITPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pIssuer))
}

/// <p>Create the two throwaway roles and the accounts that hold them, then read the grants back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCodeRead = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        Set tRows = $ListBuild($ListBuild(..#NOOAUTHUSER, ..#NOOAUTHROLE, tCodeRead _ ",%DB_IRISSYS:R,%Admin_Secure:U"), $ListBuild(..#LEASTUSER, ..#LEASTROLE, tCodeRead _ ",%DB_IRISSYS:R,%Admin_OAuth2_Client:U"))
        For tI = 1:1:$ListLength(tRows) {
            Set tRow = $List(tRows, tI)
            If ##class(Security.Users).Exists($List(tRow, 1)) Do ##class(Security.Users).Delete($List(tRow, 1))
            If ##class(Security.Roles).Exists($List(tRow, 2)) Do ##class(Security.Roles).Delete($List(tRow, 2))
            Set tSC = ##class(Security.Roles).Create($List(tRow, 2), "OcuPilot test: OAuth 2.0 server description principal (throwaway)", $List(tRow, 3), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create($List(tRow, 1), $List(tRow, 2), ..PreparedPassword, "OcuPilot OAuth test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.OAuthServerWire; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#NOOAUTHUSER, "%Admin_OAuth2_Client", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_OAuth2_Client", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%DB_IRISSYS", "WRITE") = 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the throwaway principals' grants did not read back as declared")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
