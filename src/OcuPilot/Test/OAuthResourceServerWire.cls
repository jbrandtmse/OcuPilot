/// <p>Story 12.6's routes and tools against the instance itself, as real principals (AD-8, AD-12,
/// AD-15, AD-29, AD-39, AD-53, AD-55): each editor route answers one JSON envelope; every route, the
/// row action and every agent confirm is refused to a principal without <code>%Admin_Secure</code>,
/// naming the pair; a principal holding the screen's pairs creates with a secret and mappings, reads,
/// edits and deletes, with no agent marker; and each of the six tools is minted and confirmed over the
/// wire with one agent marker.</p>
/// <p><b>The writing principal also holds <code>%Admin_OAuth2_Client:USE</code></b>, because the
/// vendor's own resource server write opens the server description through
/// <code>OAuth2.ServerDefinition.OpenByIssuer</code>, which checks that resource (measured on
/// <code>ocupilot-b-ci</code>: a caller holding the screen's pairs alone was answered 422 on a create
/// and 500 on a description-only <code>PUT</code>).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture,
/// an account holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because the legs create and delete two users, two roles, resource servers, service
/// mappings and server descriptions.</p>
Class OcuPilot.Test.OAuthResourceServerWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FORMPATH = "/oauth/resource-server/form";

Parameter CREATEPATH = "/oauth/resource-server";

Parameter EDITPATH = "/oauth/resource-server/:id";

Parameter ACTIONPATH = "/screens/security.oauthresourceservers/action";

Parameter PROBE = "OcuPilot.Test.OAuthResourceServerProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter WIRE = "OcuPilot.Test.OAuthServerWire";

Parameter PAIR = "%Admin_Secure:USE";

/// <p>What every one of the six tools' names begins with.</p>
Parameter TOOLPREFIX = "security.oauthresourceservers.";

/// <p>The principal holding the install namespace's code read, the system database read and the OAuth
/// 2.0 client resource, and not <code>%Admin_Secure</code>.</p>
Parameter NOSECUREUSER = "OcuPilotWireOAuthResourceNone";

Parameter NOSECUREROLE = "OcuPilotWireOAuthResourceNoneRole";

/// <p>The principal holding the install namespace's code read, the screen's two declared pairs and the
/// OAuth 2.0 client resource the vendor's write needs, and nothing else.</p>
Parameter LEASTUSER = "OcuPilotWireOAuthResourceLeast";

Parameter LEASTROLE = "OcuPilotWireOAuthResourceLeastRole";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthResourceServerWire creates and deletes users, roles and OAuth 2.0 resource servers on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
        For tUser = ..#NOSECUREUSER, ..#LEASTUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthResourceServerWire left user " _ tUser))
        }
        For tRole = ..#NOSECUREROLE, ..#LEASTROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthResourceServerWire left role " _ tRole))
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
        Set tRows = $ListBuild($ListBuild(..#NOSECUREUSER, ..#NOSECUREROLE, tCodeRead _ ",%DB_IRISSYS:R,%Admin_OAuth2_Client:U"), $ListBuild(..#LEASTUSER, ..#LEASTROLE, tCodeRead _ ",%DB_IRISSYS:R,%Admin_Secure:U,%Admin_OAuth2_Client:U"))
        For tI = 1:1:$ListLength(tRows) {
            Set tRow = $List(tRows, tI)
            If ##class(Security.Users).Exists($List(tRow, 1)) Do ##class(Security.Users).Delete($List(tRow, 1))
            If ##class(Security.Roles).Exists($List(tRow, 2)) Do ##class(Security.Roles).Delete($List(tRow, 2))
            Set tSC = ##class(Security.Roles).Create($List(tRow, 2), "OcuPilot test: OAuth 2.0 resource server principal (throwaway)", $List(tRow, 3), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create($List(tRow, 1), $List(tRow, 2), ..PreparedPassword, "OcuPilot OAuth test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.OAuthResourceServerWire; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#NOSECUREUSER, "%Admin_Secure", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_Secure", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%DB_IRISSYS", "WRITE") = 1) {
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
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "AddServer", ..Issuer())
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe object is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

ClassMethod Issuer() As %String
{
    Quit $ClassMethod(..#PROBE, "Issuer", "wire")
}

/// <p>A create's body for server <var>pName</var>.</p>
ClassMethod Body(pName As %String) As %DynamicObject
{
    Set tBody = {"Audiences": ["aud.wire"]}
    Do tBody.%Set("Name", pName, "string")
    Do tBody.%Set("IssuerEndpoint", ..Issuer(), "string")
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
    Set tCases = tCases _ $ListBuild($ListBuild("GET", ..#FORMPATH _ "?name=" _ tAbsent, "", 404, ##class(OcuPilot.Api.Error).#OAUTHRESOURCESERVERNAMEABSENT))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#CREATEPATH, "{}", 422, ##class(OcuPilot.Api.Error).#OAUTHRESOURCESERVERVALIDATION))
    Set tCases = tCases _ $ListBuild($ListBuild("PUT", ..EditPath(tAbsent), "{}", 404, ##class(OcuPilot.Api.Error).#OAUTHRESOURCESERVERNAMEABSENT))
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

/// <p>AC8, AD-8: the form read, both Save routes and the row action are refused 403 to a real principal
/// without <code>%Admin_Secure</code>, naming the pair, and nothing is created, changed or deleted; the
/// agent's confirm of each tool, minted for that principal, is refused the same way over the wire.</p>
/// <p>Mutation (Rule 19): remove the form route's gate (<method>OcuPilot.Area.Security.OAuthResourceServerRules.HandleForm</method>
/// skips <method>OcuPilot.Area.Security.OAuthResourceServerRules.Gate</method>) -- the form read answers
/// and this goes red.</p>
Method TestACallerWithoutTheResourceIsRefusedEverywhere()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Denied")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddResource", tName, ..Issuer(), $ListBuild("aud.wire"), {"Description": "before"}), "a server is created")
    Set tFresh = $ClassMethod(..#PROBE, "Name", "DeniedNew")
    Set tCases = $ListBuild($ListBuild("GET", ..#FORMPATH, ""), $ListBuild("GET", ..#FORMPATH _ "?name=" _ tName, ""))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#CREATEPATH, ..Body(tFresh).%ToJSON()), $ListBuild("PUT", ..EditPath(tName), "{""Description"":""after""}"))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#ACTIONPATH, {"action": "delete", "id": (tName)}.%ToJSON()))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tLabel = $List(tCase, 1) _ " " _ $List(tCase, 2)
        Set tSC = ..Request($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ..#NOSECUREUSER, .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#WIRE, "Refusal", tRaw), "403 AUTH.NOPRIVILEGE " _ ..#PAIR, tLabel _ ": refused naming the pair: " _ tStatus _ " " _ $Extract(tRaw, 1, 200))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName) _ $ClassMethod(..#PROBE, "Holds", tFresh) _ $ClassMethod(..#PROBE, "Stored", tName).%Get("Description"), "10before", "nothing is created, changed or deleted")
    For tSuffix = "Create", "Update", "SetSecret", "AddMapping", "RemoveMapping", "Delete" {
        Set tTool = "OcuPilot.Screen.Tool.OAuthResourceServer" _ tSuffix
        Set tTarget = $Select(tSuffix = "Create": tFresh, 1: tName)
        Set tArgs = $Case(tSuffix, "Create": ..Body(tFresh), "Update": {"Description": "agent"}, "AddMapping": {"Service": "%Service_Bindings", "Key": "USER"}, "RemoveMapping": {"Service": "%Service_Bindings", "Key": "USER"}, : {})
        If tSuffix = "RemoveMapping" Do $ClassMethod(..#PROBE, "Map", "%Service_Bindings", "USER", tName)
        Do tArgs.%Set("Name", tTarget, "string")
        Set tSC = $ClassMethod(..#WIRE, "Mint", tTool, tTarget, tArgs, ..#NOSECUREUSER, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tTool _ ": is minted for the principal: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
        If '$IsObject($Get(tProposal)) Continue
        Set tSC = ..Request("POST", "/proposal/" _ tProposal.%Get("proposalId") _ "/confirm", $Select(tSuffix = "SetSecret": "{""ClientSecret"":""ocupilotdeniedprobe000""}", 1: ""), ..#NOSECUREUSER, .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#WIRE, "Refusal", tRaw), "403 AUTH.NOPRIVILEGE " _ ..#PAIR, tTool _ ": its confirm is refused naming the pair: " _ tStatus _ " " _ $Extract(tRaw, 1, 200))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName) _ $ClassMethod(..#PROBE, "Holds", tFresh) _ $ClassMethod(..#PROBE, "Stored", tName).%Get("Description") _ $ClassMethod(..#PROBE, "Stored", tName).%Get("SecretLength"), "10before0", "and still nothing is created, changed or deleted")
}

/// <p>AD-29, AD-53: a real principal holding the screen's pairs creates a server with its secret and
/// the two default mappings, reads and edits it, moves a mapping and deletes it, on the screen's own
/// routes and row action. None of those emits an OcuPilot agent-write marker.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthResourceServerSave.HandleUpdate</method>
/// emits the agent-write marker after its write -- the marker assertion goes red.</p>
Method TestTheDeclaredPairsDoEveryScreenWrite()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Least")
    Set tUser = ..#LEASTUSER
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBody = ..Body(tName)
    Do tBody.%Set("ClientSecret", $ClassMethod(..#PROBE, "Secret", "least"), "string")
    Do tBody.%Set("mappingsAdded", [{"Service": "%Service_WebGateway", "Key": "*"}, {"Service": "%Service_Bindings", "Key": "*"}])
    Set tSC = ..Request("POST", ..#CREATEPATH, tBody.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 201, "its create answers 201: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals((tRaw [ "secretRefused") || (tRaw [ "mappingsRefused"), 0, "and stores the secret and both mappings")
    Do $$$AssertEquals(($ClassMethod(..#PROBE, "Stored", tName).%Get("SecretLength") > 0) _ " " _ $ClassMethod(..#PROBE, "MappingsOf", tName), "1 %Service_Bindings/*,%Service_WebGateway/*", "which the instance holds")
    Set tSC = ..Request("GET", ..#FORMPATH _ "?name=" _ tName, "", tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its form read answers the principal")
    ; The namespace the principal reads: the form offers, and the rules admit, the caller's own list.
    Set tEdit = {"Description": "least edit", "mappingsRemoved": [{"Service": "%Service_Bindings", "Key": "*"}], "mappingsAdded": [{"Service": "%Service_Bindings", "Key": ($NAMESPACE)}]}
    Set tSC = ..Request("PUT", ..EditPath(tName), tEdit.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its edit answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Description") _ " " _ $ClassMethod(..#PROBE, "MappingsOf", tName), "least edit %Service_Bindings/" _ $ZConvert($NAMESPACE, "L") _ ",%Service_WebGateway/*", "which the instance holds")
    Set tSC = ..Request("POST", ..#ACTIONPATH, {"action": "delete", "id": (tName)}.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its delete answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName) _ " " _ $ClassMethod(..#PROBE, "MappingsOf", tName), "0 ", "which deletes the server and its mappings")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, ..#TOOLPREFIX, .tData), 0, "and no Save or row action emitted an agent-write marker (AD-53): " _ $Extract($Get(tData), 1, 200))
}

/// <p>AC7, AD-15: each of the six tools, minted for the principal and confirmed over the wire as that
/// principal, applies its write and leaves exactly one agent marker naming its proposal; the secret
/// confirm takes the secret in its body, and no marker carries it.</p>
Method TestEachToolIsMintedAndConfirmedWithAMarker()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Marker")
    Set tUser = ..#LEASTUSER
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "marker")
    Set tIdOnly = "{""Name"":""" _ tName _ """}"
    Set tMapping = "{""Name"":""" _ tName _ """,""Service"":""%Service_Bindings"",""Key"":""USER""}"
    Set tSteps = $ListBuild($ListBuild("Create", ..Body(tName).%ToJSON(), "", "created"), $ListBuild("Update", "{""Name"":""" _ tName _ """,""Description"":""agent""}", "", "updated"))
    Set tSteps = tSteps _ $ListBuild($ListBuild("SetSecret", tIdOnly, "{""ClientSecret"":""" _ tSecret _ """}", "updated"), $ListBuild("AddMapping", tMapping, "", "updated"))
    Set tSteps = tSteps _ $ListBuild($ListBuild("RemoveMapping", tMapping, "", "updated"), $ListBuild("Delete", tIdOnly, "", "deleted"))
    For tI = 1:1:$ListLength(tSteps) {
        Set tStep = $List(tSteps, tI)
        Set tTool = "OcuPilot.Screen.Tool.OAuthResourceServer" _ $List(tStep, 1)
        Set tSC = $ClassMethod(..#WIRE, "Mint", tTool, tName, ##class(%DynamicObject).%FromJSON($List(tStep, 2)), tUser, .tProposal, .tHttp, .tFault, .tTurnKey)
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
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "the last confirm deleted the server")
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
