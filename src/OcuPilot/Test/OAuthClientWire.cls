/// <p>Story 12.5's routes and tools against the instance itself, as real principals (AD-8, AD-12,
/// AD-15, AD-29, AD-39, AD-53, AD-55): each editor route answers one JSON envelope; every route, row
/// action and agent confirm is refused to a principal without <code>%Admin_OAuth2_Client</code>,
/// naming the pair; a principal holding only the screen's pairs and the install namespace's code read
/// creates with secrets, reads, edits, rotates, registers and deletes, with no agent marker; and each
/// of the six tools is minted and confirmed over the wire with one agent marker.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo
/// fixture, an account holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because the legs create and delete two users, two roles and OAuth 2.0 client
/// configurations and server descriptions. The authorization server is
/// <class>OcuPilot.Test.OAuthIssuerFixture</class>, started and stopped around every method.</p>
Class OcuPilot.Test.OAuthClientWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FORMPATH = "/oauth/client-configuration/form";

Parameter CREATEPATH = "/oauth/client-configuration";

Parameter EDITPATH = "/oauth/client-configuration/:id";

Parameter ACTIONPATH = "/screens/security.oauthclients/action";

Parameter PROBE = "OcuPilot.Test.OAuthClientProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter FIXTURE = "OcuPilot.Test.OAuthIssuerFixture";

Parameter PAIR = "%Admin_OAuth2_Client:USE";

/// <p>What every one of the six tools' names begins with, and so what an agent-write marker for any
/// of them carries.</p>
Parameter TOOLPREFIX = "security.oauthclients.";

/// <p>The principal holding the install namespace's code read, the system database read and the
/// secure resource, and not <code>%Admin_OAuth2_Client</code>.</p>
Parameter NOOAUTHUSER = "OcuPilotWireOAuthClientNone";

Parameter NOOAUTHROLE = "OcuPilotWireOAuthClientNoneRole";

/// <p>The principal holding the install namespace's code read and the screen's two declared pairs,
/// and nothing else.</p>
Parameter LEASTUSER = "OcuPilotWireOAuthClientLeast";

Parameter LEASTROLE = "OcuPilotWireOAuthClientLeastRole";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The server description the method's clients are configured against, publishing the fixture's
/// registration endpoint.</p>
Property ServerId As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..ServerId = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthClientWire creates and deletes users, roles and OAuth 2.0 client configurations on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
            If ##class(Security.Users).Exists(tUser) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthClientWire left user " _ tUser))
        }
        For tRole = ..#NOOAUTHROLE, ..#LEASTROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthClientWire left role " _ tRole))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
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
            Set tSC = ##class(Security.Roles).Create($List(tRow, 2), "OcuPilot test: OAuth 2.0 client configuration principal (throwaway)", $List(tRow, 3), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create($List(tRow, 1), $List(tRow, 2), ..PreparedPassword, "OcuPilot OAuth test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.OAuthClientWire; deleted in OnAfterAllTests")
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

Method OnBeforeOneTest() As %Status
{
    Set tSC = $ClassMethod(..#FIXTURE, "Start", , .tIssuer)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "AddServer", $ClassMethod(..#PROBE, "Issuer", "wire"), .tId, $ClassMethod(..#FIXTURE, "Issuer") _ "/register")
    Set ..ServerId = $Get(tId)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Do $ClassMethod(..#FIXTURE, "Start", , .tIssuer)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe object is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Stop"), "the issuer fixture stops")
    Quit $$$OK
}

/// <p>A create's body for client <var>pName</var>.</p>
Method Body(pName As %String) As %DynamicObject
{
    Set tBody = {"ClientType": "confidential", "SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG")), "RedirectionEndpoint": ($Parameter(..#PROBE, "REDIRECT"))}
    Do tBody.%Set("ApplicationName", pName, "string")
    Do tBody.%Set("ServerDefinition", ..ServerId, "string")
    Quit tBody
}

/// <p>AD-12, AD-39: the form read, with a name and without, the create and the edit each answer
/// exactly one JSON envelope over a real HTTP request; a create naming nothing is refused on the
/// editor's own envelope code, and an edit or a form read of a name the instance does not hold is 404
/// on its own.</p>
Method TestEachRouteAnswersOneJsonEnvelopeOverTheWire()
{
    Set tAbsent = $ClassMethod(..#PROBE, "Name", "Absent")
    Set tCases = $ListBuild($ListBuild("GET", ..#FORMPATH, "", 200, ""))
    Set tCases = tCases _ $ListBuild($ListBuild("GET", ..#FORMPATH _ "?applicationName=" _ tAbsent, "", 404, ##class(OcuPilot.Api.Error).#OAUTHAPPLICATIONNAMEABSENT))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#CREATEPATH, "{}", 422, ##class(OcuPilot.Api.Error).#OAUTHCLIENTVALIDATION))
    Set tCases = tCases _ $ListBuild($ListBuild("PUT", ..EditPath(tAbsent), "{}", 404, ##class(OcuPilot.Api.Error).#OAUTHAPPLICATIONNAMEABSENT))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#CREATEPATH, "{""Bogus"":1}", 400, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED))
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
}

/// <p>AC8, AD-8: the form read, both Save routes and the three row actions are refused 403 to a real
/// principal without <code>%Admin_OAuth2_Client</code>, naming the pair, and nothing is created,
/// changed or deleted; the agent's confirm of each tool, minted for that principal, is refused the
/// same way over the wire.</p>
/// <p>Mutation (Rule 19): remove the form route's gate (<method>OcuPilot.Area.Security.OAuthClientRules.HandleForm</method>
/// skips <method>OcuPilot.Area.Security.OAuthClientRules.Gate</method>) -- the form read answers and
/// this goes red.</p>
Method TestACallerWithoutTheResourceIsRefusedEverywhere()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Denied")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId, "confidential", {"Description": "before"}), "a configuration is created")
    Set tFresh = $ClassMethod(..#PROBE, "Name", "DeniedNew")
    Set tCases = $ListBuild($ListBuild("GET", ..#FORMPATH, ""), $ListBuild("GET", ..#FORMPATH _ "?applicationName=" _ tName, ""))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#CREATEPATH, ..Body(tFresh).%ToJSON()), $ListBuild("PUT", ..EditPath(tName), "{""Description"":""after""}"))
    For tAction = "delete", "rotatekeys", "register" {
        Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#ACTIONPATH, {"action": (tAction), "id": (tName)}.%ToJSON()))
    }
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tLabel = $List(tCase, 1) _ " " _ $List(tCase, 2) _ $Select($List(tCase, 2) = ..#ACTIONPATH: " " _ $List(tCase, 3), 1: "")
        Set tSC = ..Request($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ..#NOOAUTHUSER, .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.OAuthServerWire).Refusal(tRaw), "403 AUTH.NOPRIVILEGE " _ ..#PAIR, tLabel _ ": refused naming the pair: " _ tStatus _ " " _ $Extract(tRaw, 1, 200))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName) _ $ClassMethod(..#PROBE, "Holds", tFresh) _ $ClassMethod(..#PROBE, "Stored", tName).%Get("Description"), "10before", "nothing is created, changed or deleted")
    For tSuffix = "Create", "Update", "SetSecrets", "RotateKeys", "Register", "Delete" {
        Set tTool = "OcuPilot.Screen.Tool.OAuthClient" _ tSuffix
        Set tTarget = $Select(tSuffix = "Create": tFresh, 1: tName)
        Set tArgs = $Select(tSuffix = "Create": ..Body(tFresh), tSuffix = "Update": {"Description": "agent"}, 1: {})
        Do tArgs.%Set("ApplicationName", tTarget, "string")
        Set tSC = ##class(OcuPilot.Test.OAuthServerWire).Mint(tTool, tTarget, tArgs, ..#NOOAUTHUSER, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tTool _ ": is minted for the principal: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
        If '$IsObject($Get(tProposal)) Continue
        Set tSC = ..Request("POST", "/proposal/" _ tProposal.%Get("proposalId") _ "/confirm", "", ..#NOOAUTHUSER, .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.OAuthServerWire).Refusal(tRaw), "403 AUTH.NOPRIVILEGE " _ ..#PAIR, tTool _ ": its confirm is refused naming the pair: " _ tStatus _ " " _ $Extract(tRaw, 1, 200))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName) _ $ClassMethod(..#PROBE, "Holds", tFresh) _ $ClassMethod(..#PROBE, "Stored", tName).%Get("Description"), "10before", "and still nothing is created, changed or deleted")
}

/// <p>AD-29, AD-53: a real principal holding only the install namespace's code read and the screen's
/// two declared pairs creates a configuration with its secrets, reads and edits it, rotates its keys,
/// registers it against the fixture and deletes it, on the screen's own routes and row actions. None
/// of those emits an OcuPilot agent-write marker, where
/// <method>TestEachToolIsMintedAndConfirmedWithAMarker</method> shows each agent confirm does.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthClientSave.HandleUpdate</method> emits the
/// agent-write marker after its write -- the marker assertion goes red.</p>
Method TestTheDeclaredPairsAloneDoEveryWrite()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Least")
    Set tUser = ..#LEASTUSER
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBody = ..Body(tName)
    Do tBody.%Set("ClientSecret", $ClassMethod(..#PROBE, "Secret", "least"), "string")
    Do tBody.%Set("InitialAccessToken", $ClassMethod(..#PROBE, "Secret", "leastinitial"), "string")
    Set tSC = ..Request("POST", ..#CREATEPATH, tBody.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 201, "its create answers 201: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals((tRaw [ "secretsRefused") || (tRaw [ "tokenRefused"), 0, "and stores both secrets")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Stored", tName).%Get("SecretLength") > 0, "which the instance holds")
    Set tSC = ..Request("GET", ..#FORMPATH _ "?applicationName=" _ tName, "", tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its form read answers the principal")
    Set tSC = ..Request("PUT", ..EditPath(tName), "{""Description"":""least edit""}", tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its edit answers 200: " _ $Extract(tRaw, 1, 300))
    For tAction = "rotatekeys", "register" {
        Set tSC = ..Request("POST", ..#ACTIONPATH, {"action": (tAction), "id": (tName)}.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, "its " _ tAction _ " answers 200: " _ $Extract(tRaw, 1, 300))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("ClientId"), $Parameter(..#FIXTURE, "CLIENTID"), "the registration landed")
    Set tSC = ..Request("POST", ..#ACTIONPATH, {"action": "delete", "id": (tName)}.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its delete answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "which deletes the configuration")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, ..#TOOLPREFIX, .tData), 0, "and no Save or row action emitted an agent-write marker (AD-53): " _ $Extract($Get(tData), 1, 200))
}

/// <p>AD-5: the form read offers the server descriptions, the SSL/TLS configurations and the X.509
/// credentials only through those screens' own gates -- the test account is offered the probe
/// description and the demo configuration and credential, and the least principal, holding the
/// editor's pairs but not <code>%Admin_Secure</code>, the description alone.</p>
Method TestTheFormReadOffersOnlyWhatTheCallerCanRead()
{
    For tUser = "", ..#LEASTUSER {
        Set tLabel = $Select(tUser = "": "the test account", 1: "the least principal")
        Set tSC = ..Request("GET", ..#FORMPATH, "", tUser, .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tLabel _ ": the form read answers")
        Set tBody = ""
        Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tBody = "" }
        If '$IsObject(tBody) Continue
        Do $$$AssertTrue(tBody.%Get("serverDescriptions").%ToJSON() [ ("""" _ ..ServerId _ """"), tLabel _ ": offered the probe description")
        Set tNames = tBody.%Get("sslConfigurations").%ToJSON() _ "|" _ tBody.%Get("credentials").%ToJSON()
        If tUser = "" {
            Do $$$AssertTrue((tNames [ ("""" _ $Parameter(..#PROBE, "SSLCONFIG") _ """")) && (tNames [ ("""" _ $Parameter(..#PROBE, "CREDENTIAL") _ """")), tLabel _ ": offered the demo configuration and credential: " _ tNames)
        } Else {
            Do $$$AssertEquals(tNames, "[]|[]", tLabel _ ": offered neither list")
        }
    }
}

/// <p>AC7, AD-15: each of the six tools, minted for the least principal and confirmed over the wire
/// as that principal, applies its write and leaves exactly one agent marker naming its proposal; the
/// secrets confirm takes a secret in its body, and no marker carries it.</p>
Method TestEachToolIsMintedAndConfirmedWithAMarker()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Marker")
    Set tUser = ..#LEASTUSER
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "marker")
    Set tIdOnly = "{""ApplicationName"":""" _ tName _ """}"
    Set tSteps = $ListBuild($ListBuild("Create", ..Body(tName).%ToJSON(), "", "created"), $ListBuild("Update", "{""ApplicationName"":""" _ tName _ """,""Description"":""agent""}", "", "updated"))
    Set tSteps = tSteps _ $ListBuild($ListBuild("SetSecrets", tIdOnly, "{""ClientSecret"":""" _ tSecret _ """}", "updated"), $ListBuild("RotateKeys", tIdOnly, "", "updated"))
    Set tSteps = tSteps _ $ListBuild($ListBuild("Register", tIdOnly, "", "updated"), $ListBuild("Delete", tIdOnly, "", "deleted"))
    For tI = 1:1:$ListLength(tSteps) {
        Set tStep = $List(tSteps, tI)
        Set tTool = "OcuPilot.Screen.Tool.OAuthClient" _ $List(tStep, 1)
        Set tSC = ##class(OcuPilot.Test.OAuthServerWire).Mint(tTool, tName, ##class(%DynamicObject).%FromJSON($List(tStep, 2)), tUser, .tProposal, .tHttp, .tFault, .tTurnKey)
        Do $$$AssertStatusOK(tSC, tTool _ ": is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
        If '$IsObject($Get(tProposal)) Quit
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tSC = ..Request("POST", "/proposal/" _ tProposal.%Get("proposalId") _ "/confirm", $List(tStep, 3), tUser, .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tTool _ ": is confirmed over the wire: " _ $Extract(tRaw, 1, 300))
        Do $$$AssertTrue(tRaw [ ("""action"":""" _ $List(tStep, 4) _ """"), tTool _ ": publishing " _ $List(tStep, 4))
        Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposal.%Get("proposalId") _ """", .tData), 1, tTool _ ": one agent marker names its proposal")
        Do $$$AssertEquals($Get(tData) [ tSecret, 0, tTool _ ": and carries no secret")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "the last confirm deleted the configuration")
}

/// <p>One request as <var>pUser</var>, the test account when empty.</p>
Method Request(pMethod As %String, pPath As %String, pBody As %String, pUser As %String, Output pStatus As %Integer, Output pRaw As %String, Output pHeaders) As %Status
{
    Set tUser = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestUsername(), 1: pUser)
    Set tPassword = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestPassword(), 1: ..PreparedPassword)
    Set tBody = $Select(pMethod = "GET": "", 1: pBody)
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath, tUser, tPassword, .pStatus, .pRaw, .pHeaders, tBody, $Select(pMethod = "GET": "", 1: "application/json"))
}

/// <p><parameter>EDITPATH</parameter> for <var>pName</var>, its segment encoded by the one shared
/// encoder.</p>
ClassMethod EditPath(pName As %String) As %String
{
    Quit $Replace(..#EDITPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pName))
}

}
