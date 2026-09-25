/// <p>Story 12.7's routes and tools against the instance itself, as real principals (AD-8, AD-12,
/// AD-15, AD-29, AD-39, AD-53, AD-55): each editor route answers one JSON envelope; every route, both
/// row actions, the tab's read and every agent confirm are refused to a principal without
/// <code>%Admin_OAuth2_Server</code>, naming the pair; a principal holding the tab's two pairs and
/// nothing else reads the tab and the form, edits with a password, rotates the keys and deletes, with
/// no agent marker, keeps only stored roles, and mints an edit whose clients are hidden from it; and
/// each of the five tools is minted and confirmed over the wire with one agent marker.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture,
/// an account holding <code>%All</code>, no authorization server configuration, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the legs create and delete two
/// users, two roles and the instance's configuration.</p>
Class OcuPilot.Test.OAuthAuthorizationServerWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FORMPATH = "/oauth/authorization-server/form";

Parameter SAVEPATH = "/oauth/authorization-server";

Parameter ACTIONPATH = "/screens/security.oauthserver/action";

Parameter READPATH = "/screens/security.oauthserver/read";

Parameter PROBE = "OcuPilot.Test.OAuthAuthorizationServerProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter WIRE = "OcuPilot.Test.OAuthServerWire";

Parameter PAIR = "%Admin_OAuth2_Server:USE";

/// <p>What every one of the five tools' names begins with.</p>
Parameter TOOLPREFIX = "security.oauthserver.";

/// <p>The principal holding the install namespace's code read, the system database read and the OAuth
/// 2.0 client resource -- an administrative resource, so OcuPilot signs it in -- and not the
/// authorization server resource.</p>
Parameter NONEUSER = "OcuPilotWireOAuthAuthNone";

Parameter NONEROLE = "OcuPilotWireOAuthAuthNoneRole";

/// <p>The principal holding the install namespace's code read and the tab's two declared pairs, and
/// nothing else.</p>
Parameter LEASTUSER = "OcuPilotWireOAuthAuthLeast";

Parameter LEASTROLE = "OcuPilotWireOAuthAuthLeastRole";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthAuthorizationServerWire creates and deletes users, roles and this instance's OAuth 2.0 authorization server configuration and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
        For tUser = ..#NONEUSER, ..#LEASTUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthAuthorizationServerWire left user " _ tUser))
        }
        For tRole = ..#NONEROLE, ..#LEASTROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthAuthorizationServerWire left role " _ tRole))
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
        Set tRows = $ListBuild($ListBuild(..#NONEUSER, ..#NONEROLE, tCodeRead _ ",%DB_IRISSYS:R,%Admin_OAuth2_Client:U"), $ListBuild(..#LEASTUSER, ..#LEASTROLE, tCodeRead _ ",%DB_IRISSYS:R,%Admin_OAuth2_Server:U"))
        For tI = 1:1:$ListLength(tRows) {
            Set tRow = $List(tRows, tI)
            If ##class(Security.Users).Exists($List(tRow, 1)) Do ##class(Security.Users).Delete($List(tRow, 1))
            If ##class(Security.Roles).Exists($List(tRow, 2)) Do ##class(Security.Roles).Delete($List(tRow, 2))
            Set tSC = ##class(Security.Roles).Create($List(tRow, 2), "OcuPilot test: OAuth 2.0 authorization server principal (throwaway)", $List(tRow, 3), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create($List(tRow, 1), $List(tRow, 2), ..PreparedPassword, "OcuPilot OAuth test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.OAuthAuthorizationServerWire; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#NONEUSER, "%Admin_OAuth2_Server", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_OAuth2_Server", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_OAuth2_Registration", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_Secure", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%DB_IRISSYS", "WRITE") = 1) {
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
    Do $$$AssertStatusOK(tSC, "the configuration and every probe object are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

ClassMethod Id() As %String
{
    Quit ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
}

/// <p>AD-12, AD-39: the form read, the create and the edit each answer exactly one JSON envelope over a
/// real HTTP request; a create naming nothing is refused on the editor's own envelope code, an edit
/// with no configuration is 404 on its own, and a key outside the editor's fields is refused.</p>
Method TestEachRouteAnswersOneJsonEnvelopeOverTheWire()
{
    Set tCases = $ListBuild($ListBuild("GET", ..#FORMPATH, "", 200, ""))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#SAVEPATH, "{}", 422, ##class(OcuPilot.Api.Error).#OAUTHSERVERVALIDATION))
    Set tCases = tCases _ $ListBuild($ListBuild("PUT", ..#SAVEPATH, "{}", 404, ##class(OcuPilot.Api.Error).#OAUTHSERVERCONFIGABSENT))
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
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds"), 0, "and nothing is created")
}

/// <p>AC8, AD-8: the form read, both Save routes, both row actions and the tab's read are refused 403
/// to a real principal without <code>%Admin_OAuth2_Server</code>, naming the pair, and nothing is
/// created, changed, rotated or deleted; the agent's confirm of each tool, minted for that principal,
/// is refused the same way over the wire.</p>
/// <p>Mutation (Rule 19): remove the form route's gate
/// (<method>OcuPilot.Area.Security.OAuthAuthorizationServerRules.HandleForm</method> skips
/// <method>OcuPilot.Area.Security.OAuthAuthorizationServerRules.Gate</method>) -- the form read answers
/// and this goes red.</p>
Method TestACallerWithoutTheResourceIsRefusedEverywhere()
{
    Set tUser = ..#NONEUSER
    Set tBody = $ClassMethod(..#PROBE, "Body").%ToJSON()
    Do ..AssertRefused(tUser, "POST", ..#SAVEPATH, tBody)
    Set tArgs = $ClassMethod(..#PROBE, "Body")
    Do tArgs.%Set("Name", ..Id(), "string")
    Do ..AssertConfirmRefused(tUser, "Create", tArgs)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds"), 0, "no configuration is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tBefore = $ClassMethod(..#PROBE, "Stored")
    For tCase = $ListBuild("GET", ..#FORMPATH, ""), $ListBuild("GET", ..#READPATH, ""), $ListBuild("PUT", ..#SAVEPATH, "{""Description"":""denied""}"), $ListBuild("POST", ..#ACTIONPATH, ..ActionBody("delete")), $ListBuild("POST", ..#ACTIONPATH, ..ActionBody("rotatekeys")) {
        Do ..AssertRefused(tUser, $List(tCase, 1), $List(tCase, 2), $List(tCase, 3))
    }
    For tSuffix = "Update", "SetPassword", "RotateKeys", "Delete" {
        Set tArgs = $Select(tSuffix = "Update": {"Description": "agent"}, 1: {})
        Do tArgs.%Set("Name", ..Id(), "string")
        Do ..AssertConfirmRefused(tUser, tSuffix, tArgs)
    }
    Set tAfter = $ClassMethod(..#PROBE, "Stored")
    Do $$$AssertEquals($Select($IsObject(tAfter): tAfter.%Get("Description") _ " " _ tAfter.%Get("KeyCount") _ " " _ tAfter.%Get("PasswordLength"), 1: ""), "seeded " _ tBefore.%Get("KeyCount") _ " 0", "and nothing is changed, rotated or deleted")
}

/// <p>Assert that <var>pMethod</var> <var>pPath</var> as <var>pUser</var> is refused 403 naming
/// <parameter>PAIR</parameter>.</p>
Method AssertRefused(pUser As %String, pMethod As %String, pPath As %String, pBody As %String)
{
    Set tSC = ..Request(pMethod, pPath, pBody, pUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#WIRE, "Refusal", tRaw), "403 AUTH.NOPRIVILEGE " _ ..#PAIR, pMethod _ " " _ pPath _ ": refused naming the pair: " _ tStatus _ " " _ $Extract(tRaw, 1, 200))
}

/// <p>Assert that tool <var>pSuffix</var>, minted for <var>pUser</var> with <var>pArgs</var>, has its
/// confirm refused 403 naming <parameter>PAIR</parameter>.</p>
Method AssertConfirmRefused(pUser As %String, pSuffix As %String, pArgs As %DynamicObject)
{
    Set tTool = "OcuPilot.Screen.Tool.OAuthAuthorizationServer" _ pSuffix
    Set tSC = $ClassMethod(..#WIRE, "Mint", tTool, ..Id(), pArgs, pUser, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, tTool _ ": is minted for the principal: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ..Request("POST", "/proposal/" _ tProposal.%Get("proposalId") _ "/confirm", $Select(pSuffix = "SetPassword": "{""ServerPassword"":""ocupilotdeniedprobe000""}", 1: ""), pUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#WIRE, "Refusal", tRaw), "403 AUTH.NOPRIVILEGE " _ ..#PAIR, tTool _ ": its confirm is refused naming the pair: " _ tStatus _ " " _ $Extract(tRaw, 1, 200))
}

/// <p>AD-29, AD-53: a real principal holding the tab's two pairs and nothing else reads the tab and the
/// form -- the registered clients hidden from it --, edits the configuration with its key password,
/// rotates the keys and deletes it, on the screen's own routes and row actions. None of those emits an
/// OcuPilot agent-write marker.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthAuthorizationServerSave.HandleUpdate</method>
/// emits the agent-write marker after its write -- the marker assertion goes red.</p>
Method TestTheDeclaredPairsDoEveryScreenWrite()
{
    Set tUser = ..#LEASTUSER
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "Least"), .tClientId), "with a registered client")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Request("GET", ..#READPATH, "", tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ (tRaw [ $ClassMethod(..#PROBE, "Issuer")), "200 1", "the tab's read answers the principal the configuration: " _ $Extract(tRaw, 1, 200))
    Set tSC = ..Request("GET", ..#FORMPATH, "", tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ (tRaw [ """clientsHidden"":true") _ " " _ (tRaw [ tClientId), "200 1 0", "the form read answers it, the clients hidden: " _ $Extract(tRaw, 1, 200))
    Set tPassword = $ClassMethod(..#PROBE, "Secret", "least")
    Set tSC = ..Request("PUT", ..#SAVEPATH, {"Description": "least edit", "AccessTokenInterval": 1200, "ServerPassword": (tPassword)}.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its edit answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals(tRaw [ "passwordRefused", 0, "and stores the password")
    Set tStored = $ClassMethod(..#PROBE, "Stored")
    Do $$$AssertEquals(tStored.%Get("Description") _ " " _ tStored.%Get("AccessTokenInterval") _ " " _ tStored.%Get("PasswordLength") _ " " _ tStored.%Get("CustomizationRoles"), "least edit 1200 " _ $Length(tPassword) _ " %DB_IRISSYS", "which the instance holds, the stored roles kept")
    Set tKeys = tStored.%Get("KeyCount")
    Set tSC = ..Request("POST", ..#ACTIONPATH, ..ActionBody("rotatekeys"), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its rotation answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Stored").%Get("KeyCount") > tKeys, "and the key set grows")
    Set tSC = ..Request("POST", ..#ACTIONPATH, ..ActionBody("delete"), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its delete answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds") _ " " _ $ClassMethod(..#PROBE, "ClientCount"), "0 0", "which deletes the configuration and its client")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, ..#TOOLPREFIX, .tData), 0, "and no Save or row action emitted an agent-write marker (AD-53): " _ $Extract($Get(tData), 1, 200))
}

/// <p>A principal who cannot read the roles list keeps only stored roles on an edit: restating the
/// stored customization roles over the wire answers 200, and adding one it cannot read answers 422
/// <code>OAUTH.CUSTOMIZATIONROLES.ABSENT</code> on the field, with the stored roles kept.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthAuthorizationServerRules.CustomizationViolations</method>
/// reads the stored roles from <method>OcuPilot.Area.Security.OAuthAuthorizationServerRules.Defaults</method>
/// rather than the fresh read -- the added role is admitted and this goes red.</p>
Method TestACallerWhoCannotReadTheRolesKeepsOnlyStoredRoles()
{
    Set tUser = ..#LEASTUSER
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tSC = ..Request("PUT", ..#SAVEPATH, {"Description": "restated", "CustomizationRoles": ["%DB_IRISSYS"]}.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "restating the stored roles answers 200: " _ $Extract(tRaw, 1, 300))
    Set tStored = $ClassMethod(..#PROBE, "Stored")
    Do $$$AssertEquals(tStored.%Get("Description") _ " " _ tStored.%Get("CustomizationRoles"), "restated %DB_IRISSYS", "and the instance holds the edit")
    Set tSC = ..Request("PUT", ..#SAVEPATH, {"Description": "added", "CustomizationRoles": ["%DB_IRISSYS", "%Manager"]}.%ToJSON(), tUser, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ..ViolationCode(tRaw, "CustomizationRoles"), "422 OAUTH.CUSTOMIZATIONROLES.ABSENT", "adding a role it cannot read is refused on the field: " _ $Extract(tRaw, 1, 300))
    Set tStored = $ClassMethod(..#PROBE, "Stored")
    Do $$$AssertEquals(tStored.%Get("Description") _ " " _ tStored.%Get("CustomizationRoles"), "restated %DB_IRISSYS", "and nothing is sent")
}

/// <p>Matrix row "Agent change, clients hidden": a real principal without
/// <code>%Admin_OAuth2_Registration:USE</code>, minting an edit of a configuration with a registered
/// client in its own process, gets a proposal minted destructive with
/// <code>OAUTH.SERVERCLIENTSHIDDEN</code> and no <code>Clients</code> card row.</p>
Method TestAHiddenClientsProposalIsMintedAsThePrincipal()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "Hidden"), .tClientId), "with a registered client")
    Set tArgs = {"Description": "hidden"}
    Do tArgs.%Set("Name", ..Id(), "string")
    Set tOut = ..MintedAs(..#LEASTUSER, "OcuPilot.Screen.Tool.OAuthAuthorizationServerUpdate", tArgs)
    Do $$$AssertEquals(tOut.%Get("error"), "", "the principal's process minted: " _ tOut.%ToJSON())
    Do $$$AssertEquals(tOut.%Get("username") _ " " _ (tOut.%Get("proposalId") '= ""), ..#LEASTUSER _ " 1", "as the principal, a proposal: " _ tOut.%Get("problem"))
    If tOut.%Get("proposalId") = "" Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tOut.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals($Get(tValues("destructive")) _ " " _ $Get(tValues("consequence")), "1 OAUTH.SERVERCLIENTSHIDDEN", "destructive, naming the hidden effect")
    Do $$$AssertEquals(tOut.%Get("fields"), "Description", "and its card carries the edit's row and no clients row")
}

/// <p>The code <var>pRaw</var>'s <code>detail.violations</code> carries for <var>pField</var>, or
/// <code>""</code>.</p>
ClassMethod ViolationCode(pRaw As %String, pField As %String) As %String
{
    Set tCode = ""
    Try {
        Set tRows = ##class(%DynamicObject).%FromJSON(pRaw).%Get("detail").%Get("violations")
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get("field") = pField Set tCode = tRow.%Get("code") Quit
        }
    } Catch {
        Set tCode = ""
    }
    Quit tCode
}

/// <p>Tool <var>pTool</var>'s proposal of <var>pArgs</var>, minted in a process logged in as
/// <var>pUser</var> (<method>MintAs</method>), as <code>{username, http, problem, proposalId,
/// fields}</code> or <code>{error}</code>.</p>
Method MintedAs(pUser As %String, pTool As %String, pArgs As %DynamicObject) As %DynamicObject
{
    Set tOut = {"error": ""}
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit {"error": "no turn was seeded"}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.OAuthAuthorizationServerWire).MintAs($Job, pUser, tTurnKey, pTool, pArgs.%ToJSON())::10
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

/// <p>Log in as <var>pUser</var>, mint <var>pTool</var>'s proposal of <var>pArgs</var> (JSON) under
/// turn <var>pTurnKey</var>, and signal <code>{error, username, http, problem, proposalId,
/// fields}</code> -- <code>fields</code> the card rows' field names, comma-separated -- to process
/// <var>pParent</var>.</p>
/// <p><b>Caller contract:</b> <code>JOB</code>ed by <method>MintedAs</method> and by nothing else;
/// <code>$System.Security.Login</code> switches this process's own user context.</p>
ClassMethod MintAs(pParent As %Integer, pUser As %String, pTurnKey As %String, pTool As %String, pArgs As %String)
{
    Set tOut = {"error": ""}
    Try {
        If '$SYSTEM.Security.Login(pUser) {
            Do tOut.%Set("error", "the login as " _ pUser _ " failed")
            Quit
        }
        Do tOut.%Set("username", $Username, "string")
        Set tArgs = ##class(%DynamicObject).%FromJSON(pArgs)
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), $Username, "", pTurnKey, tArgs, "OcuPilot.Kernel.Agent.Limits", .tProposal, .tHttp, .tFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), ..Id(), $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
        Do tOut.%Set("http", +$Get(tHttp), "number")
        Set tProblem = ""
        If $IsObject($Get(tFault)) Set tProblem = $Select(tFault.%GetTypeOf("detail") = "object": tFault.%Get("detail").%Get("problem"), 1: tFault.%Get("reason"))
        Do tOut.%Set("problem", tProblem, "string")
        Set tId = ""
        Set tFields = ""
        If $IsObject($Get(tProposal)) {
            Set tId = tProposal.%Get("proposalId")
            Set tIterator = tProposal.%Get("changed").%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) { Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ tRow.%Get("field") }
        }
        Do tOut.%Set("proposalId", tId, "string")
        Do tOut.%Set("fields", tFields, "string")
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>AC7, AD-15: each of the five tools, minted and confirmed over the wire, applies its write and
/// leaves exactly one agent marker naming its proposal; the password confirm takes the password in its
/// body, and no marker carries it. The test account confirms them: a principal the customization
/// roles list refuses can keep only stored roles, so it cannot compose a create.</p>
Method TestEachToolIsMintedAndConfirmedWithAMarker()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = $ClassMethod(..#PROBE, "Secret", "marker")
    Set tCreate = $ClassMethod(..#PROBE, "Body")
    Set tSteps = $ListBuild($ListBuild("Create", tCreate.%ToJSON(), "", "created"), $ListBuild("Update", "{""Description"":""agent""}", "", "updated"), $ListBuild("SetPassword", "{}", "{""ServerPassword"":""" _ tPassword _ """}", "updated"), $ListBuild("RotateKeys", "{}", "", "updated"), $ListBuild("Delete", "{}", "", "deleted"))
    For tI = 1:1:$ListLength(tSteps) {
        Set tStep = $List(tSteps, tI)
        Set tTool = "OcuPilot.Screen.Tool.OAuthAuthorizationServer" _ $List(tStep, 1)
        Set tArgs = ##class(%DynamicObject).%FromJSON($List(tStep, 2))
        Do tArgs.%Set("Name", ..Id(), "string")
        Set tSC = $ClassMethod(..#WIRE, "Mint", tTool, ..Id(), tArgs, tUser, .tProposal, .tHttp, .tFault, .tTurnKey)
        Do $$$AssertStatusOK(tSC, tTool _ ": is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
        If '$IsObject($Get(tProposal)) Quit
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tSC = ..Request("POST", "/proposal/" _ tProposal.%Get("proposalId") _ "/confirm", $List(tStep, 3), "", .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tTool _ ": is confirmed over the wire: " _ $Extract(tRaw, 1, 300))
        Do $$$AssertTrue(tRaw [ ("""action"":""" _ $List(tStep, 4) _ """"), tTool _ ": publishing " _ $List(tStep, 4))
        Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposal.%Get("proposalId") _ """", .tData), 1, tTool _ ": one agent marker names its proposal")
        Do $$$AssertEquals($Get(tData) [ tPassword, 0, tTool _ ": and carries no password")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
        If $List(tStep, 1) = "SetPassword" Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%Get("PasswordLength"), $Length(tPassword), tTool _ ": the instance stores the password")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds"), 0, "the last confirm deleted the configuration")
}

/// <p>A row action's request body: <var>pAction</var> on the configuration, named by its issuer as the
/// tab's row carries it.</p>
ClassMethod ActionBody(pAction As %String) As %String
{
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", $ClassMethod(..#PROBE, "Issuer"), "string")
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
