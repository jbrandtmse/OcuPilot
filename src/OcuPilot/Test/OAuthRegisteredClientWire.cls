/// <p>Story 12.8's routes and tools against the instance itself, as real principals (AD-8, AD-12,
/// AD-15, AD-28, AD-29, AD-39, AD-53, AD-55): each editor route answers one JSON envelope; every route,
/// both row actions, the tab's read, the mint and every agent confirm are refused to a principal
/// without either of the tab's two pairs, naming it; a principal holding the two pairs and nothing else
/// registers a client with its secret, edits it, updates its public keys and deletes it, with no agent
/// marker; each of the five tools is minted and confirmed over the wire with one agent marker; and
/// OcuPilot's own sign-in is untouched by clients coming and going.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the vendor's
/// <code>/oauth2</code> application answering on the container's own port 52773, an account holding
/// <code>%All</code>, no authorization server configuration and no registered client, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the legs create and delete
/// three users, three roles, the instance's configuration and its clients.</p>
Class OcuPilot.Test.OAuthRegisteredClientWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FORMPATH = "/oauth/server-client/form";

Parameter SAVEPATH = "/oauth/server-client";

/// <p>The edit route, as the router declares it.</p>
Parameter EDITPATH = "/oauth/server-client/:id";

Parameter ACTIONPATH = "/screens/security.oauthserverclients/action";

Parameter READPATH = "/screens/security.oauthserverclients/read";

Parameter PROBE = "OcuPilot.Test.OAuthRegisteredClientProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter WIRE = "OcuPilot.Test.OAuthServerWire";

/// <p>What every one of the five tools' names begins with.</p>
Parameter TOOLPREFIX = "security.oauthserverclients.";

/// <p>The principal holding the install namespace's code read, the system database read and the OAuth
/// 2.0 client resource -- an administrative resource, so OcuPilot signs it in -- and not the
/// registration resource.</p>
Parameter NONEUSER = "OcuPilotWireOAuthClientNone";

Parameter NONEROLE = "OcuPilotWireOAuthClientNoneRole";

/// <p>The principal holding the install namespace's code read and the registration resource, and not
/// the system database read.</p>
Parameter NODBUSER = "OcuPilotWireOAuthClientNoDb";

Parameter NODBROLE = "OcuPilotWireOAuthClientNoDbRole";

/// <p>The principal holding the install namespace's code read and the tab's two declared pairs, and
/// nothing else.</p>
Parameter LEASTUSER = "OcuPilotWireOAuthClientLeast";

Parameter LEASTROLE = "OcuPilotWireOAuthClientLeastRole";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthRegisteredClientWire creates and deletes users, roles and this instance's OAuth 2.0 authorization server configuration and clients and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
        For tUser = ..#NONEUSER, ..#NODBUSER, ..#LEASTUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthRegisteredClientWire left user " _ tUser))
        }
        For tRole = ..#NONEROLE, ..#NODBROLE, ..#LEASTROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthRegisteredClientWire left role " _ tRole))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>Create the three throwaway roles and the accounts that hold them, then read the grants back.</p>
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
        Set tRows = $ListBuild($ListBuild(..#NONEUSER, ..#NONEROLE, tCodeRead _ ",%DB_IRISSYS:R,%Admin_OAuth2_Client:U"), $ListBuild(..#NODBUSER, ..#NODBROLE, tCodeRead _ ",%Admin_OAuth2_Registration:U"), $ListBuild(..#LEASTUSER, ..#LEASTROLE, tCodeRead _ ",%DB_IRISSYS:R,%Admin_OAuth2_Registration:U"))
        For tI = 1:1:$ListLength(tRows) {
            Set tRow = $List(tRows, tI)
            If ##class(Security.Users).Exists($List(tRow, 1)) Do ##class(Security.Users).Delete($List(tRow, 1))
            If ##class(Security.Roles).Exists($List(tRow, 2)) Do ##class(Security.Roles).Delete($List(tRow, 2))
            Set tSC = ##class(Security.Roles).Create($List(tRow, 2), "OcuPilot test: OAuth 2.0 server client principal (throwaway)", $List(tRow, 3), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create($List(tRow, 1), $List(tRow, 2), ..PreparedPassword, "OcuPilot OAuth test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.OAuthRegisteredClientWire; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#NONEUSER, "%Admin_OAuth2_Registration", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#NODBUSER, "%DB_IRISSYS", "READ") = 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_OAuth2_Registration", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_OAuth2_Server", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_Secure", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%DB_IRISSYS", "WRITE") = 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the throwaway principals' grants did not read back as declared")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "the configuration and every client are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>AD-12, AD-39: the form read, the create and the edit each answer exactly one JSON envelope over a
/// real HTTP request; a create naming nothing is refused on the editor's own envelope code, an edit of
/// an absent client is 404 on its own, and a key outside the editor's fields is refused.</p>
Method TestEachRouteAnswersOneJsonEnvelopeOverTheWire()
{
    Set tCases = $ListBuild($ListBuild("GET", ..#FORMPATH, "", 200, ""))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#SAVEPATH, "{}", 422, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTVALIDATION))
    Set tCases = tCases _ $ListBuild($ListBuild("PUT", $Replace(..#EDITPATH, ":id", "OcuPilotNoSuchClient128"), "{}", 404, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTABSENT))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#SAVEPATH, "{""Bogus"":1}", 400, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED))
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
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ClientCount"), 0, "and nothing is created")
}

/// <p>AC7, AD-8: for each of the tab's two pairs, a real principal without it is refused 403 naming it
/// on the form read, both Save routes, both row actions, the tab's read, the mint in its own process
/// and the confirm of every tool minted for it, and nothing is created, changed, fetched or
/// deleted.</p>
/// <p>Mutation (Rule 19): remove the form route's gate
/// (<method>OcuPilot.Area.Security.OAuthRegisteredClientRules.HandleForm</method> skips
/// <method>OcuPilot.Area.Security.OAuthRegisteredClientRules.Gate</method>) -- the form read answers and
/// this goes red.</p>
Method TestACallerWithoutEitherPairIsRefusedEverywhere()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tName = $ClassMethod(..#PROBE, "Name", "Denied")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", tName, .tClientId, {"Description": "seeded", "Metadata": {"jwks_uri": ($Parameter(..#PROBE, "JWKSURL"))}}), "a client with a JWKS URL is seeded")
    For tDenied = $ListBuild(..#NONEUSER, "%Admin_OAuth2_Registration:USE"), $ListBuild(..#NODBUSER, "%DB_IRISSYS:READ") {
        Set tUser = $List(tDenied, 1)
        Set tPair = $List(tDenied, 2)
        Set tCreate = $ClassMethod(..#PROBE, "Body", $ClassMethod(..#PROBE, "Name", "DeniedNew"))
        Do tCreate.%Set("ClientSecret", "ocupilotdeniedprobe000", "string")
        For tCase = $ListBuild("GET", ..#FORMPATH _ "?clientId=" _ tClientId, ""), $ListBuild("GET", ..#READPATH, ""), $ListBuild("POST", ..#SAVEPATH, tCreate.%ToJSON()), $ListBuild("PUT", ..#SAVEPATH _ "/" _ tClientId, "{""Description"":""denied""}"), $ListBuild("POST", ..#ACTIONPATH, ..ActionBody("delete", tClientId)), $ListBuild("POST", ..#ACTIONPATH, ..ActionBody("updatejwks", tClientId)) {
            Do ..AssertRefused(tUser, tPair, $List(tCase, 1), $List(tCase, 2), $List(tCase, 3))
        }
        Set tArgs = $ClassMethod(..#PROBE, "Body", $ClassMethod(..#PROBE, "Name", "DeniedAgent"))
        Do ..AssertConfirmRefused(tUser, tPair, "OAuthRegisteredClientCreate", tArgs.%Get("Name"), tArgs)
        For tSuffix = "OAuthRegisteredClientUpdate", "OAuthRegisteredClientSetSecret", "OAuthRegisteredClientUpdateJwks", "OAuthServerClientDelete" {
            Set tArgs = $Select(tSuffix = "OAuthRegisteredClientUpdate": {"Description": "agent"}, 1: {})
            Do tArgs.%Set("ClientId", tClientId, "string")
            Do ..AssertConfirmRefused(tUser, tPair, tSuffix, tClientId, tArgs)
        }
        Set tArgs = {"Description": "agent"}
        Do tArgs.%Set("ClientId", tClientId, "string")
        Set tOut = ..MintedAs(tUser, "OcuPilot.Screen.Tool.OAuthRegisteredClientUpdate", tClientId, tArgs)
        Do $$$AssertEquals(tOut.%Get("error") _ "|" _ tOut.%Get("http") _ "|" _ tOut.%Get("proposalId"), "|403|", tUser _ ": the principal's own mint is refused 403 with no proposal: " _ tOut.%ToJSON())
    }
    Set tStored = $ClassMethod(..#PROBE, "Stored", tClientId)
    Do $$$AssertEquals($Select($IsObject(tStored): tStored.%Get("Description") _ " " _ tStored.%Get("PublicKeys"), 1: "") _ " " _ $ClassMethod(..#PROBE, "ClientCount"), "seeded 0 1", "and nothing is created, changed, fetched or deleted")
}

/// <p>Assert that <var>pMethod</var> <var>pPath</var> as <var>pUser</var> is refused 403 naming
/// <var>pPair</var>.</p>
Method AssertRefused(pUser As %String, pPair As %String, pMethod As %String, pPath As %String, pBody As %String)
{
    Set tSC = ..Request(pMethod, pPath, pBody, pUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#WIRE, "Refusal", tRaw), "403 AUTH.NOPRIVILEGE " _ pPair, pUser _ " " _ pMethod _ " " _ $Piece(pPath, "?", 1) _ ": refused naming the pair: " _ tStatus _ " " _ $Extract(tRaw, 1, 200))
}

/// <p>Assert that tool <var>pSuffix</var>, minted for <var>pUser</var> on <var>pId</var> with
/// <var>pArgs</var>, has its confirm refused 403 naming <var>pPair</var>.</p>
Method AssertConfirmRefused(pUser As %String, pPair As %String, pSuffix As %String, pId As %String, pArgs As %DynamicObject)
{
    Set tTool = "OcuPilot.Screen.Tool." _ pSuffix
    Set tSC = $ClassMethod(..#WIRE, "Mint", tTool, pId, pArgs, pUser, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, tTool _ ": is minted for the principal: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ..Request("POST", "/proposal/" _ tProposal.%Get("proposalId") _ "/confirm", $Select(pSuffix [ "SetSecret": "{""ClientSecret"":""ocupilotdeniedprobe000""}", 1: ""), pUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#WIRE, "Refusal", tRaw), "403 AUTH.NOPRIVILEGE " _ pPair, pUser _ " " _ tTool _ ": its confirm is refused naming the pair: " _ tStatus _ " " _ $Extract(tRaw, 1, 200))
}

/// <p>AC7's second half, AD-29, AD-53: a real principal holding the tab's two pairs and nothing else
/// registers a client with its secret, reads the form and the tab, edits it with a new secret, updates
/// its public keys from the in-container URL and deletes it, on the screen's own routes and row
/// actions. None of those emits an OcuPilot agent-write marker.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthRegisteredClientSave.HandleUpdate</method>
/// emits the agent-write marker after its write -- the marker assertion goes red.</p>
Method TestTheDeclaredPairsDoEveryScreenWrite()
{
    Set tUser = ..#LEASTUSER
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tName = $ClassMethod(..#PROBE, "Name", "Least")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "least")
    Set tBody = $ClassMethod(..#PROBE, "Body", tName)
    Do tBody.%Set("ClientSecret", tSecret, "string")
    Set tSC = ..Request("POST", ..#SAVEPATH, tBody.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 201, "its create answers 201: " _ $Extract(tRaw, 1, 300))
    Set tClientId = $ClassMethod(..#PROBE, "IdOf", tName)
    Do $$$AssertTrue((tClientId '= "") && $ClassMethod(..#PROBE, "SecretIs", tClientId, tSecret), "which registers the client with its secret")
    Set tSC = ..Request("GET", ..#READPATH, "", tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ (tRaw [ tClientId), "200 1", "the tab's read answers the principal the client")
    Set tSC = ..Request("GET", ..#FORMPATH _ "?clientId=" _ tClientId, "", tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ (tRaw [ """credentials"":[]") _ " " _ (tRaw [ tSecret), "200 1 0", "the form read answers it, no credential listed, no secret: " _ $Extract(tRaw, 1, 200))
    Set tNew = $ClassMethod(..#PROBE, "Secret", "leastnew")
    Set tEdit = {"Description": "least edit", "ClientSecret": (tNew), "Metadata": {"jwks_uri": ($Parameter(..#PROBE, "JWKSURL"))}}
    Set tSC = ..Request("PUT", ..#SAVEPATH _ "/" _ tClientId, tEdit.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ (tRaw [ "secretRefused"), "200 0", "its edit answers 200 and stores the secret: " _ $Extract(tRaw, 1, 300))
    Set tStored = $ClassMethod(..#PROBE, "Stored", tClientId)
    Do $$$AssertEquals(tStored.%Get("Description") _ " " _ tStored.%Get("Metadata").%Get("jwks_uri") _ " " _ $ClassMethod(..#PROBE, "SecretIs", tClientId, tNew), "least edit " _ $Parameter(..#PROBE, "JWKSURL") _ " 1", "which the instance holds")
    Set tSC = ..Request("POST", ..#ACTIONPATH, ..ActionBody("updatejwks", tClientId), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its Update JWKS answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Stored", tClientId).%Get("PublicKeys") > 0, "and the key set holds the fetched keys")
    Set tSC = ..Request("POST", ..#ACTIONPATH, ..ActionBody("delete", tClientId), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its delete answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ClientCount"), 0, "which deletes the client")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, ..#TOOLPREFIX, .tData), 0, "and no Save or row action emitted an agent-write marker (AD-53): " _ $Extract($Get(tData), 1, 200))
}

/// <p>Tool <var>pTool</var>'s proposal of <var>pArgs</var> on <var>pId</var>, minted in a process
/// logged in as <var>pUser</var> (<method>MintAs</method>), as <code>{username, http, problem,
/// proposalId}</code> or <code>{error}</code>.</p>
Method MintedAs(pUser As %String, pTool As %String, pId As %String, pArgs As %DynamicObject) As %DynamicObject
{
    Set tOut = {"error": ""}
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit {"error": "no turn was seeded"}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.OAuthRegisteredClientWire).MintAs($Job, pUser, tTurnKey, pTool, pId, pArgs.%ToJSON())::10
        If '$Test {
            Do tOut.%Set("error", "the principal's process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 120)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the principal's process signalled nothing within 120 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Log in as <var>pUser</var>, mint <var>pTool</var>'s proposal of <var>pArgs</var> (JSON) on
/// <var>pId</var> under turn <var>pTurnKey</var>, and signal <code>{error, username, http, problem,
/// proposalId}</code> to process <var>pParent</var>.</p>
/// <p><b>Caller contract:</b> <code>JOB</code>ed by <method>MintedAs</method> and by nothing else;
/// <code>$System.Security.Login</code> switches this process's own user context.</p>
ClassMethod MintAs(pParent As %Integer, pUser As %String, pTurnKey As %String, pTool As %String, pId As %String, pArgs As %String)
{
    Set tOut = {"error": ""}
    Try {
        If '$SYSTEM.Security.Login(pUser) {
            Do tOut.%Set("error", "the login as " _ pUser _ " failed")
            Quit
        }
        Do tOut.%Set("username", $Username, "string")
        Set tArgs = ##class(%DynamicObject).%FromJSON(pArgs)
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), $Username, "", pTurnKey, tArgs, "OcuPilot.Kernel.Agent.Limits", .tProposal, .tHttp, .tFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pId, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
        Do tOut.%Set("http", +$Get(tHttp), "number")
        Set tProblem = ""
        If $IsObject($Get(tFault)) Set tProblem = $Select(tFault.%GetTypeOf("detail") = "object": tFault.%Get("detail").%Get("problem"), 1: tFault.%Get("reason"))
        Do tOut.%Set("problem", tProblem, "string")
        Do tOut.%Set("proposalId", $Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""), "string")
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>AC6, AD-15: each of the five tools, minted and confirmed over the wire, applies its write and
/// leaves exactly one agent marker naming its proposal; the secret confirm takes the secret in its
/// body, and no marker carries it.</p>
Method TestEachToolIsMintedAndConfirmedWithAMarker()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "marker")
    Set tName = $ClassMethod(..#PROBE, "Name", "Marker")
    Set tCreate = $ClassMethod(..#PROBE, "Body", tName)
    Set tUpdate = {"Description": "agent", "Metadata": {"jwks_uri": ($Parameter(..#PROBE, "JWKSURL"))}}
    Set tSteps = $ListBuild($ListBuild("OAuthRegisteredClientCreate", tCreate.%ToJSON(), "", "created"), $ListBuild("OAuthRegisteredClientUpdate", tUpdate.%ToJSON(), "", "updated"), $ListBuild("OAuthRegisteredClientSetSecret", "{}", "{""ClientSecret"":""" _ tSecret _ """}", "updated"), $ListBuild("OAuthRegisteredClientUpdateJwks", "{}", "", "updated"), $ListBuild("OAuthServerClientDelete", "{}", "", "deleted"))
    Set tClientId = ""
    For tI = 1:1:$ListLength(tSteps) {
        Set tStep = $List(tSteps, tI)
        Set tTool = "OcuPilot.Screen.Tool." _ $List(tStep, 1)
        Set tArgs = ##class(%DynamicObject).%FromJSON($List(tStep, 2))
        Set tId = $Select(tI = 1: tName, 1: tClientId)
        Do tArgs.%Set($ClassMethod(tTool, "IdArgument"), tId, "string")
        Set tSC = $ClassMethod(..#WIRE, "Mint", tTool, tId, tArgs, tUser, .tProposal, .tHttp, .tFault, .tTurnKey)
        Do $$$AssertStatusOK(tSC, tTool _ ": is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
        If '$IsObject($Get(tProposal)) Quit
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tSC = ..Request("POST", "/proposal/" _ tProposal.%Get("proposalId") _ "/confirm", $List(tStep, 3), "", .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tTool _ ": is confirmed over the wire: " _ $Extract(tRaw, 1, 300))
        Do $$$AssertTrue(tRaw [ ("""action"":""" _ $List(tStep, 4) _ """"), tTool _ ": publishing " _ $List(tStep, 4))
        Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposal.%Get("proposalId") _ """", .tData), 1, tTool _ ": one agent marker names its proposal")
        Do $$$AssertEquals($Get(tData) [ tSecret, 0, tTool _ ": and carries no secret")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
        If tI = 1 Set tClientId = $ClassMethod(..#PROBE, "IdOf", tName)
        If $List(tStep, 1) [ "SetSecret" Do $$$AssertTrue($ClassMethod(..#PROBE, "SecretIs", tClientId, tSecret), tTool _ ": the instance stores the secret")
        If $List(tStep, 1) [ "UpdateJwks" Do $$$AssertTrue($ClassMethod(..#PROBE, "Stored", tClientId).%Get("PublicKeys") > 0, tTool _ ": the key set holds the fetched keys")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ClientCount"), 0, "the last confirm deleted the client")
}

/// <p>AD-28: OcuPilot's own sign-in answers before any client, with one registered and after it is
/// deleted.</p>
Method TestSignInIsUntouched()
{
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ClientCount") _ " " _ ..SignIn(), "0 200", "a sign-in answers with no client")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "SignIn"), .tClientId), "a client is registered")
    Do $$$AssertEquals(..SignIn(), 200, "a sign-in answers with a client")
    Set tSC = ..Request("POST", ..#ACTIONPATH, ..ActionBody("delete", tClientId), "", .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#PROBE, "ClientCount") _ " " _ ..SignIn(), "200 0 200", "and after it is deleted")
}

/// <p>The status a password sign-in as the test account answers.</p>
ClassMethod SignIn() As %Integer
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/login", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, "", "application/json")
    Quit +$Get(tStatus)
}

/// <p>A row action's request body: <var>pAction</var> on client <var>pClientId</var>.</p>
ClassMethod ActionBody(pAction As %String, pClientId As %String) As %String
{
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pClientId, "string")
    Quit tRequest.%ToJSON()
}

/// <p>One request as <var>pUser</var>, the test account when empty.</p>
Method Request(pMethod As %String, pPath As %String, pBody As %String, pUser As %String, Output pStatus As %Integer, Output pRaw As %String, Output pHeaders) As %Status
{
    Set tUser = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestUsername(), 1: pUser)
    Set tPassword = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestPassword(), 1: ..PreparedPassword)
    Set tBody = $Select(pMethod = "GET": "", 1: pBody)
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath, tUser, tPassword, .pStatus, .pRaw, .pHeaders, tBody, $Select(pMethod = "GET": "", 1: "application/json"))
}

}
